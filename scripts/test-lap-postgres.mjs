// Disposable real PostgreSQL validation. Requires Docker and postgres:17-bookworm.
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { readFileSync, readdirSync } from 'node:fs';
const name = `fitness-lap-test-${process.pid}`;
const docker = (...args) => execFileSync('docker', args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
const sql = (text) => execFileSync('docker', ['exec', '-i', name, 'psql', '-U', 'postgres', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], { input: text, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
const user = '00000000-0000-0000-0000-000000000001';
const other = '00000000-0000-0000-0000-000000000002';
const item = '10000000-0000-0000-0000-000000000001';
const second = '10000000-0000-0000-0000-000000000002';
const asUser = (query, uid=user) => `set role authenticated; set request.jwt.claim.sub = '${uid}'; ${query}`;
const call = (query, uid=user) => sql(asUser(query, uid));
const lap = (n=1) => `select advance_plan_item_lap('${item}', ${n});`;
const toggle = (id=item) => `select toggle_plan_item_timer('${id}');`;
const done = (value=true) => `select set_plan_item_done('${item}', ${value});`;
const row = () => JSON.parse(sql(`select row_to_json(p) from plan_items p where id='${item}';`));
const rejects = (query, message, uid=user) => assert.throws(() => call(query,uid), (e) => e.stderr.includes(message));
const concurrent = (query) => new Promise(resolve => {
  const proc = spawn('docker', ['exec','-i',name,'psql','-U','postgres','-X','-qAt','-v','ON_ERROR_STOP=1']);
  let out=''; let err=''; proc.stdout.on('data',d=>out+=d);proc.stderr.on('data',d=>err+=d);
  proc.on('close',code=>resolve({code,out,err})); proc.stdin.end(asUser(query));
});
try {
  docker('run','--rm','-d','--name',name,'-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-bookworm');
  for(let i=0;i<160;i++) {try {docker('exec',name,'pg_isready','-h','127.0.0.1','-U','postgres');break;} catch {await new Promise(r=>setTimeout(r,250));}}
  sql(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key,email text);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth to authenticated, anon;
    grant execute on function auth.uid() to authenticated, anon;`);
  for(const file of readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort()) sql(readFileSync(`supabase/migrations/${file}`,'utf8'));
  sql(`insert into auth.users values ('${user}','lap@example.test'),('${other}','other@example.test');
    insert into daily_plans(id,user_id,plan_date,plan_markdown) values
      ('20000000-0000-0000-0000-000000000001','${user}',(now() at time zone 'Asia/Hong_Kong')::date,'Test');
    insert into plan_items(id,user_id,plan_id,section_type,section_title_en,section_title_zh,section_position,item_position,title_en,title_zh,description_en,description_zh,prescription)
      select x.id::uuid,'${user}','20000000-0000-0000-0000-000000000001','main_workout','Main','訓練',0,x.pos,'March','踏步','March gently','輕鬆踏步','2 minutes'
      from (values ('${item}',0),('${second}',1)) x(id,pos);`);
  assert.equal(row().lap_number,1);assert.equal(row().lap_start_total_seconds,0);
  rejects(lap(),'Start the stopwatch');
  rejects(toggle(),'not editable',other);
  call(toggle());
  sql(`update exercise_intervals set started_at=clock_timestamp()-interval '10 seconds' where ended_at is null;`);
  const first=JSON.parse(call(lap()));assert.equal(first.lap_number,2);assert.ok(first.lap_start_total_seconds>=10);
  assert.equal(sql('select count(*) from exercise_intervals;'),'1');
  rejects(lap(),'Lap has changed');rejects(lap(2),'not editable',other);
  call(toggle());rejects(lap(2),'Start the stopwatch');
  const boundary=row().lap_start_total_seconds;
  call(toggle());assert.equal(row().lap_start_total_seconds,boundary);assert.equal(row().lap_number,2);
  call(toggle(second));rejects(lap(2),'Start the stopwatch');call(toggle());
  const results=await Promise.all([concurrent(lap(2)),concurrent(lap(2))]);
  assert.equal(results.filter(r=>r.code===0).length,1);assert.equal(row().lap_number,3);
  assert.ok(results.some(r=>r.err.includes('Lap has changed')));
  await Promise.all([concurrent(lap(3)),concurrent(done())]);
  assert.ok(row().completed_at);assert.equal(sql('select count(*) from exercise_intervals where ended_at is null;'),'0');
  rejects(lap(row().lap_number),'not editable');rejects(toggle(),'not editable');
  const total=Number(sql(`select sum(duration_seconds) from exercise_intervals where plan_item_id='${item}';`));
  assert.ok(total>=row().lap_start_total_seconds);
  call(done(false));assert.equal(sql('select count(*) from exercise_intervals where ended_at is null;'),'0');
  call(toggle());
  sql("update daily_plans set plan_date=plan_date-1;");rejects(lap(row().lap_number),'not editable');
  sql("update daily_plans set plan_date=plan_date+1,status='executed';");rejects(lap(row().lap_number),'not editable');
  assert.equal(sql("select has_function_privilege('anon','advance_plan_item_lap(uuid,integer)','execute');"),'f');
  console.log('PostgreSQL: migrations, defaults, lap persistence, pause/resume/switch, duplicate concurrency, Done race, ownership, historical/finished plans and anonymous restrictions passed.');
} finally {try {docker('rm','-f','-v',name);} catch { /* Already removed. */ }}

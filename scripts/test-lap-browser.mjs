// Run against the local dev server with fixture Supabase URL http://127.0.0.1:54329.
import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const browser = await chromium.launch({headless:true, executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE});
const page = await browser.newPage({viewport:{width:1280,height:900}});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
let items=["March in place","Squats"].map((title,index)=>({id:`lap-review-${index}`,user_id:'review',plan_id:'lap-review',section_type:'main_workout',section_title_en:'Lap stopwatch review',section_title_zh:'計時測試',section_position:0,item_position:index,title_en:title,title_zh:'訓練動作',description_en:'Keep a comfortable pace.',description_zh:'保持舒適的速度。',prescription:'2 minutes',planned_seconds:120,completed_at:null,lap_number:1,lap_start_total_seconds:0,created_at:new Date().toISOString()}));
const intervals=[];let failNext=false;let delayNext=false;let lapCalls=0;
const total=id=>intervals.filter(i=>i.plan_item_id===id).reduce((sum,i)=>sum+(i.ended_at?i.duration_seconds:Math.max(0,Math.floor((Date.now()-Date.parse(i.started_at))/1000))),0);
const close=(i,reason)=>{i.duration_seconds=Math.floor((Date.now()-Date.parse(i.started_at))/1000);i.ended_at=new Date().toISOString();i.stop_reason=reason;};
await page.route('http://127.0.0.1:54329/**', async route=>{
  const url=new URL(route.request().url()); const request=route.request();
  const send=body=>route.fulfill({json:body,headers:{'access-control-allow-origin':'*'}});
  if(request.method()==='OPTIONS')return route.fulfill({status:200,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-allow-methods':'*'}});
  if(url.pathname.endsWith('/plan_items')) {const result=structuredClone(items);if(delayNext){delayNext=false;await new Promise(r=>setTimeout(r,900));}return send(result);}
  if(url.pathname.endsWith('/exercise_intervals'))return send(intervals);
  const body=request.postDataJSON();const item=items.find(i=>i.id===body.p_plan_item_id);
  if(url.pathname.endsWith('/toggle_plan_item_timer')) {
    const active=intervals.find(i=>!i.ended_at);if(active)close(active,active.plan_item_id===item.id?'pause':'switch');
    if(active?.plan_item_id!==item.id)intervals.push({id:`interval-${intervals.length}`,user_id:'review',plan_item_id:item.id,started_at:new Date(Date.now()-5000).toISOString(),ended_at:null,duration_seconds:0,stop_reason:null});
  } else if(url.pathname.endsWith('/advance_plan_item_lap')) {
    lapCalls++;assert.equal(body.p_expected_lap_number,item.lap_number);item.lap_number++;item.lap_start_total_seconds=total(item.id);
    if(failNext){failNext=false;return route.fulfill({status:503,json:{message:'Response interrupted after save'}});}
  } else if(url.pathname.endsWith('/set_plan_item_done')) {
    if(body.p_done)intervals.filter(i=>i.plan_item_id===item.id&&!i.ended_at).forEach(i=>close(i,'done'));
    item.completed_at=body.p_done?new Date().toISOString():null;
  } else throw new Error(`Unexpected fixture request: ${url}`);
  return send({});
});
const cards=page.locator('.plan-item-card');const card=cards.nth(0);
const button=name=>page.getByRole('button',{name,exact:true});
async function waitFor(check) {for(let n=0;n<100;n++){if(await check())return;await new Promise(r=>setTimeout(r,50));}throw new Error('Condition timed out');}
const lapLabel=()=>card.locator('.plan-item-timer.lap small').innerText();
try {
  await page.goto('http://localhost:3012/dev/stopwatch');
  assert.equal(await lapLabel(),'Lap 1');assert.ok(await button('New lap: March in place').isDisabled());
  await button('Start: March in place').focus();await page.keyboard.press('Enter');
  await waitFor(()=>button('New lap: March in place').isEnabled());
  assert.equal(await card.locator('.plan-item-timer-state').innerText(),'Running');
  assert.equal(await card.locator('.plan-item-timer').first().locator('span').innerText(),await card.locator('.plan-item-timer.lap span').innerText());
  await button('New lap: March in place').click();await waitFor(async()=>await lapLabel()==='Lap 2');
  assert.ok(total(items[0].id)>=5);assert.ok((await card.locator('.plan-item-timer.lap span').innerText()).endsWith('00'));
  await button('Pause: March in place').click();await waitFor(()=>button('Start: March in place').isEnabled());
  const frozen=await card.locator('.plan-item-timers').innerText();await page.waitForTimeout(1200);assert.equal(await card.locator('.plan-item-timers').innerText(),frozen);
  await button('Start: March in place').click();await waitFor(()=>button('New lap: March in place').isEnabled());assert.equal(await lapLabel(),'Lap 2');
  await button('Start: Squats').click();await waitFor(()=>button('New lap: Squats').isEnabled());assert.ok(await button('New lap: March in place').isDisabled());
  await button('Start: March in place').click();await waitFor(()=>button('New lap: March in place').isEnabled());
  // An obsolete focus refresh must not overwrite a newer lap.
  delayNext=true;await page.evaluate(()=>window.dispatchEvent(new Event('focus')));await page.waitForTimeout(100);
  await button('New lap: March in place').click();await waitFor(async()=>await lapLabel()==='Lap 3');await page.waitForTimeout(1000);assert.equal(await lapLabel(),'Lap 3');
  // The server committed, but the response failed: refresh instead of replaying the mutation.
  failNext=true;await button('New lap: March in place').click();await button('Refresh stopwatch').waitFor();
  assert.ok(await button('New lap: March in place').isDisabled());const calls=lapCalls;
  await button('Refresh stopwatch').click();await waitFor(async()=>await lapLabel()==='Lap 4');assert.equal(lapCalls,calls);
  await page.screenshot({path:'/tmp/fitness-lap-desktop.png',fullPage:true});
  await button('Mark done: March in place').click();await waitFor(()=>button('Mark not done: March in place').isEnabled());
  const doneTime=await card.locator('.plan-item-timers').innerText();await page.waitForTimeout(1200);assert.equal(await card.locator('.plan-item-timers').innerText(),doneTime);
  assert.ok(await button('Start: March in place').isDisabled());assert.ok(await button('New lap: March in place').isDisabled());
  await button('Mark not done: March in place').click();await waitFor(()=>button('Start: March in place').isEnabled());assert.ok(await button('New lap: March in place').isDisabled());
  await page.reload();await page.evaluate(()=>window.dispatchEvent(new Event('focus')));await waitFor(async()=>await lapLabel()==='Lap 4');
  await page.setViewportSize({width:375,height:812});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.screenshot({path:'/tmp/fitness-lap-mobile.png',fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('Browser: keyboard Start, first lap, lap reset, pause/resume/switch, stale fetch, uncertain save recovery, Done freeze, reload persistence and mobile overflow passed.');
} finally {await browser.close();}

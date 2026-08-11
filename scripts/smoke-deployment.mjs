import assert from "node:assert/strict";

const inputUrl = process.argv[2] || process.env.DEPLOYMENT_URL;
if (!inputUrl) {
  console.error("Usage: npm run smoke -- https://deployment.example");
  process.exit(2);
}

const baseUrl = new URL(inputUrl);
baseUrl.pathname = "/";
baseUrl.search = "";
baseUrl.hash = "";

const requestHeaders = {};
if (process.env.VERCEL_PROTECTION_BYPASS) {
  requestHeaders["x-vercel-protection-bypass"] = process.env.VERCEL_PROTECTION_BYPASS;
}

async function checkedFetch(pathname, options = {}) {
  const response = await fetch(new URL(pathname, baseUrl), {
    ...options,
    headers: { ...requestHeaders, ...options.headers },
    signal: AbortSignal.timeout(15_000)
  });
  return response;
}

const root = await checkedFetch("/", { redirect: "manual" });
assert.equal(root.status, 307, "Root must redirect unauthenticated users.");
assert.equal(root.headers.get("location"), "/login");

const login = await checkedFetch("/login");
assert.equal(login.status, 200, "Login page must be reachable.");
const loginHtml = await login.text();
assert.match(loginHtml, /<title>Fitness Genii<\/title>/);

const live = await checkedFetch("/api/health/live");
assert.equal(live.status, 200, "Liveness must return HTTP 200.");
const livePayload = await live.json();
assert.equal(livePayload.status, "live");
assert.equal(livePayload.service, "fitness-genii");
assert.ok(live.headers.get("x-fitness-genii-commit"));

const ready = await checkedFetch("/api/health/ready");
assert.equal(ready.status, 200, "Readiness must return HTTP 200.");
const readyPayload = await ready.json();
assert.equal(readyPayload.status, "ready");
assert.equal(readyPayload.checks?.supabase?.status, "up");

const generation = await checkedFetch("/api/plans/generate");
assert.equal(generation.status, 405, "Generation GET must remain method-protected.");

const cron = await checkedFetch("/api/cron/finalize-unfinished");
assert.equal(cron.status, 401, "Cron must remain authorization-protected.");

const assetPaths = [
  ...loginHtml.matchAll(/(?:src|href)="([^"#?]+\.(?:js|css|png|svg|webmanifest))"/g)
].map((match) => match[1]);
const uniqueAssetPaths = [...new Set(assetPaths)];
const assetResults = await Promise.all(
  uniqueAssetPaths.map(async (pathname) => ({
    pathname,
    status: (await checkedFetch(pathname)).status
  }))
);
const failedAssets = assetResults.filter(({ status }) => status >= 400);
assert.deepEqual(failedAssets, [], "All login assets must be reachable.");

console.log(
  JSON.stringify(
    {
      status: "passed",
      url: baseUrl.origin,
      commit: livePayload.commit,
      environment: livePayload.environment,
      region: livePayload.region,
      readiness_ms: readyPayload.checks.supabase.latency_ms,
      assets_checked: assetResults.length
    },
    null,
    2
  )
);

import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import ts from "typescript";

const require = createRequire(import.meta.url);

function loadTypeScriptModule(relativePath) {
  const source = fs.readFileSync(new URL(relativePath, import.meta.url), "utf8");
  const compiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022
    }
  }).outputText;
  const testModule = { exports: {} };
  new Function("exports", "module", "require", compiled)(
    testModule.exports,
    testModule,
    require
  );
  return testModule.exports;
}

const {
  checkSupabaseHealth,
  deploymentMetadata,
  healthResponseHeaders,
  isHealthCheckPath
} = loadTypeScriptModule("../src/lib/health.ts");

assert.equal(isHealthCheckPath("/api/health/live"), true);
assert.equal(isHealthCheckPath("/api/health/ready"), true);
assert.equal(isHealthCheckPath("/api/plans/generate"), false);

const environment = {
  VERCEL_ENV: "preview",
  VERCEL_GIT_COMMIT_SHA: "1234567890abcdef",
  VERCEL_URL: "fitness-genii-preview.vercel.app",
  VERCEL_REGION: "iad1"
};

assert.deepEqual(deploymentMetadata(environment), {
  service: "fitness-genii",
  environment: "preview",
  commit: "1234567890ab",
  deployment_url: "fitness-genii-preview.vercel.app",
  region: "iad1"
});
assert.deepEqual(healthResponseHeaders(environment), {
  "Cache-Control": "no-store, max-age=0",
  "X-Fitness-Genii-Commit": "1234567890ab"
});

const missingConfiguration = await checkSupabaseHealth({ environment: {} });
assert.deepEqual(missingConfiguration, {
  status: "down",
  latency_ms: 0,
  reason: "configuration_missing"
});

const callTimes = [100, 112];
let observedUrl;
let observedOptions;
const healthy = await checkSupabaseHealth({
  environment: {
    NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
    NEXT_PUBLIC_SUPABASE_ANON_KEY: "public-test-key"
  },
  fetchImpl: async (url, options) => {
    observedUrl = url;
    observedOptions = options;
    return new Response(JSON.stringify({ version: "v2.test", name: "GoTrue" }), {
      status: 200,
      headers: { "content-type": "application/json" }
    });
  },
  now: () => callTimes.shift()
});

assert.equal(observedUrl.toString(), "https://example.supabase.co/auth/v1/health");
assert.equal(observedOptions.headers.apikey, "public-test-key");
assert.equal(observedOptions.cache, "no-store");
assert.deepEqual(healthy, { status: "up", latency_ms: 12 });

const upstreamFailure = await checkSupabaseHealth({
  environment: {
    NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
    NEXT_PUBLIC_SUPABASE_ANON_KEY: "public-test-key"
  },
  fetchImpl: async () => new Response("unavailable", { status: 503 })
});
assert.equal(upstreamFailure.status, "down");
assert.equal(upstreamFailure.reason, "http_503");

const invalidResponse = await checkSupabaseHealth({
  environment: {
    NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
    NEXT_PUBLIC_SUPABASE_ANON_KEY: "public-test-key"
  },
  fetchImpl: async () => new Response("not-json", { status: 200 })
});
assert.equal(invalidResponse.status, "down");
assert.equal(invalidResponse.reason, "invalid_response");

const unreachable = await checkSupabaseHealth({
  environment: {
    NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
    NEXT_PUBLIC_SUPABASE_ANON_KEY: "public-test-key"
  },
  fetchImpl: async () => {
    throw new Error("network unavailable");
  }
});
assert.equal(unreachable.status, "down");
assert.equal(unreachable.reason, "unreachable");

console.log("Health check tests passed.");

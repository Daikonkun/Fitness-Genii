export type HealthEnvironment = Record<string, string | undefined>;

export type SupabaseHealthResult =
  | {
      status: "up";
      latency_ms: number;
    }
  | {
      status: "down";
      latency_ms: number;
      reason: "configuration_missing" | "invalid_response" | "unreachable" | `http_${number}`;
    };

type FetchLike = typeof fetch;

const SERVICE_NAME = "fitness-genii";
const DEFAULT_TIMEOUT_MS = 3_000;

function elapsedMilliseconds(startedAt: number, now: () => number) {
  return Math.max(0, Math.round(now() - startedAt));
}

export function isHealthCheckPath(pathname: string) {
  return pathname === "/api/health" || pathname.startsWith("/api/health/");
}

export function deploymentMetadata(environment: HealthEnvironment = process.env) {
  const commit = environment.VERCEL_GIT_COMMIT_SHA?.slice(0, 12) || "local";

  return {
    service: SERVICE_NAME,
    environment: environment.VERCEL_ENV || environment.NODE_ENV || "unknown",
    commit,
    deployment_url: environment.VERCEL_URL || null,
    region: environment.VERCEL_REGION || null
  };
}

export function healthResponseHeaders(environment: HealthEnvironment = process.env) {
  const metadata = deploymentMetadata(environment);

  return {
    "Cache-Control": "no-store, max-age=0",
    "X-Fitness-Genii-Commit": metadata.commit
  };
}

export async function checkSupabaseHealth({
  environment = process.env,
  fetchImpl = fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  now = Date.now
}: {
  environment?: HealthEnvironment;
  fetchImpl?: FetchLike;
  timeoutMs?: number;
  now?: () => number;
} = {}): Promise<SupabaseHealthResult> {
  const startedAt = now();
  const supabaseUrl = environment.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = environment.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !publishableKey) {
    return {
      status: "down",
      latency_ms: elapsedMilliseconds(startedAt, now),
      reason: "configuration_missing"
    };
  }

  try {
    const healthUrl = new URL("/auth/v1/health", supabaseUrl);
    const response = await fetchImpl(healthUrl, {
      headers: { apikey: publishableKey },
      cache: "no-store",
      signal: AbortSignal.timeout(timeoutMs)
    });

    if (!response.ok) {
      return {
        status: "down",
        latency_ms: elapsedMilliseconds(startedAt, now),
        reason: `http_${response.status}`
      };
    }

    const payload = (await response.json().catch(() => null)) as
      | { version?: unknown }
      | null;

    if (!payload || typeof payload.version !== "string") {
      return {
        status: "down",
        latency_ms: elapsedMilliseconds(startedAt, now),
        reason: "invalid_response"
      };
    }

    return {
      status: "up",
      latency_ms: elapsedMilliseconds(startedAt, now)
    };
  } catch {
    return {
      status: "down",
      latency_ms: elapsedMilliseconds(startedAt, now),
      reason: "unreachable"
    };
  }
}

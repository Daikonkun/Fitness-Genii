import {
  checkSupabaseHealth,
  deploymentMetadata,
  healthResponseHeaders
} from "@/lib/health";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await checkSupabaseHealth();
  const ready = supabase.status === "up";

  return Response.json(
    {
      status: ready ? "ready" : "not_ready",
      ...deploymentMetadata(),
      checked_at: new Date().toISOString(),
      checks: { supabase }
    },
    {
      status: ready ? 200 : 503,
      headers: healthResponseHeaders()
    }
  );
}

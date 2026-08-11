import { deploymentMetadata, healthResponseHeaders } from "@/lib/health";

export const dynamic = "force-dynamic";

export async function GET() {
  return Response.json(
    {
      status: "live",
      ...deploymentMetadata(),
      checked_at: new Date().toISOString()
    },
    { headers: healthResponseHeaders() }
  );
}

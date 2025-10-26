export const dynamic = "force-dynamic";

function shortSha(sha?: string) {
  return sha ? sha.slice(0, 8) : "unknown";
}

export async function GET() {
  const payload = {
    app: process.env.NEXT_PUBLIC_APP_NAME || "Construct-IQ",
    env: process.env.VERCEL_ENV || "development",
    commit: shortSha(process.env.VERCEL_GIT_COMMIT_SHA),
    url: process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "local",
    now: new Date().toISOString(),
  };
  return new Response(JSON.stringify(payload), {
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

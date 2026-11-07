import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 120;

const BACKEND_TIMEOUT_MS = 120_000;

export async function POST(request: Request) {
  const backendUrl = (process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:3101").replace(/\/$/, "");
  const authorization = request.headers.get("authorization");
  if (!authorization) return NextResponse.json({ detail: "Missing authorization header" }, { status: 401 });

  try {
    const upstream = await fetch(`${backendUrl}/api/support-resistance/relative-performance/live-quotes`, {
      method: "POST",
      headers: {
        Authorization: authorization,
        "Content-Type": request.headers.get("content-type") || "application/json",
        Accept: "application/json",
      },
      body: await request.text(),
      cache: "no-store",
      signal: AbortSignal.timeout(BACKEND_TIMEOUT_MS),
    });
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "Content-Type": upstream.headers.get("content-type") || "application/json",
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    const timedOut = error instanceof Error && error.name === "TimeoutError";
    return NextResponse.json({ detail: timedOut
      ? `Live quote batch exceeded ${BACKEND_TIMEOUT_MS / 1000} seconds.`
      : "Unable to reach the relative-performance quote service." }, { status: timedOut ? 504 : 502 });
  }
}

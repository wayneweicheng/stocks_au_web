import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const BACKEND_TIMEOUT_MS = 120_000;

export async function POST(request: Request) {
  const backendUrl = (process.env.BACKEND_URL || "http://127.0.0.1:3101").replace(/\/$/, "");
  const authorization = request.headers.get("authorization");
  if (!authorization) {
    return NextResponse.json({ detail: "Missing authorization header" }, { status: 401 });
  }

  try {
    const upstream = await fetch(`${backendUrl}/api/spx-map-comparison/prompt`, {
      method: "POST",
      headers: {
        Authorization: authorization,
        Accept: "application/json",
        "Content-Type": request.headers.get("content-type") || "application/json",
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
      ? `SPX prompt generation exceeded ${BACKEND_TIMEOUT_MS / 1000} seconds.`
      : "Unable to reach the SPX prompt service." }, { status: timedOut ? 504 : 502 });
  }
}

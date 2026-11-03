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
    const upstream = await fetch(`${backendUrl}/api/spx-map-comparison/preview`, {
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
    const detail = error instanceof Error && error.name === "TimeoutError"
      ? `SPX D1/D2 preview exceeded ${BACKEND_TIMEOUT_MS / 1000} seconds.`
      : "Unable to reach the SPX D1/D2 preview service.";
    return NextResponse.json({ detail }, { status: error instanceof Error && error.name === "TimeoutError" ? 504 : 502 });
  }
}

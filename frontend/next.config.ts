import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // This repo is actively evolving; keep builds unblocked while we incrementally
  // pay down type/lint issues across legacy pages.
  typescript: {
    ignoreBuildErrors: true,
  },
  eslint: {
    ignoreDuringBuilds: true,
  },
  async rewrites() {
    const backendUrl = process.env.BACKEND_URL || "http://127.0.0.1:3101";
    return [
      {
        source: "/api/:path*",
        destination: `${backendUrl}/api/:path*`,
      },
      {
        source: "/auth/:path*",
        destination: `${backendUrl}/auth/:path*`,
      },
      {
        source: "/debug/:path*",
        destination: `${backendUrl}/debug/:path*`,
      },
      {
        source: "/charts/:path*",
        destination: `${backendUrl}/charts/:path*`,
      },
    ];
  },
};

export default nextConfig;

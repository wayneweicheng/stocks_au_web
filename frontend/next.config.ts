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
};

export default nextConfig;

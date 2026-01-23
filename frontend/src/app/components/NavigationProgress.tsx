"use client";

import { useEffect, useState, useRef } from "react";
import { usePathname, useSearchParams } from "next/navigation";

export default function NavigationProgress() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [isNavigating, setIsNavigating] = useState(false);
  const [showBar, setShowBar] = useState(false);
  const [progress, setProgress] = useState(0);
  const delayTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Reset when navigation completes (pathname or searchParams change)
  useEffect(() => {
    if (delayTimerRef.current) {
      clearTimeout(delayTimerRef.current);
      delayTimerRef.current = null;
    }
    setIsNavigating(false);
    setShowBar(false);
    setProgress(0);
  }, [pathname, searchParams]);

  // Listen for click events on links
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      const link = target.closest("a");

      // Check if it's an internal navigation link
      if (link) {
        const href = link.getAttribute("href");
        if (href && href.startsWith("/") && !href.startsWith("//")) {
          // It's an internal link - start navigation tracking
          setIsNavigating(true);
          setProgress(20);

          // Only show the bar after 150ms delay to avoid flashing on fast navigations
          if (delayTimerRef.current) {
            clearTimeout(delayTimerRef.current);
          }
          delayTimerRef.current = setTimeout(() => {
            setShowBar(true);
          }, 150);
        }
      }
    };

    document.addEventListener("click", handleClick, true);
    return () => document.removeEventListener("click", handleClick, true);
  }, []);

  // Animate progress while navigating
  useEffect(() => {
    if (!isNavigating) return;

    const interval = setInterval(() => {
      setProgress((prev) => {
        // Slow down as we approach 90%
        if (prev >= 90) return prev;
        if (prev >= 70) return prev + 1;
        if (prev >= 50) return prev + 2;
        return prev + 5;
      });
    }, 100);

    return () => clearInterval(interval);
  }, [isNavigating]);

  // Cleanup timer on unmount
  useEffect(() => {
    return () => {
      if (delayTimerRef.current) {
        clearTimeout(delayTimerRef.current);
      }
    };
  }, []);

  if (!showBar || progress === 0) return null;

  return (
    <div className="fixed top-0 left-0 right-0 z-[100] h-1 bg-transparent pointer-events-none">
      <div
        className="h-full bg-gradient-to-r from-emerald-500 to-green-400 transition-all duration-150 ease-out shadow-[0_0_10px_rgba(16,185,129,0.7)]"
        style={{
          width: `${progress}%`,
          opacity: isNavigating ? 1 : 0,
        }}
      />
    </div>
  );
}

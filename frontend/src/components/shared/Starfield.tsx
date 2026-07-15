'use client';

import { useEffect, useState } from 'react';

interface Star {
  id: number;
  top: number;
  left: number;
  size: number;
  duration: number;
  delay: number;
}

interface StarfieldProps {
  count: number;
  /** [min, max] percentage range for each star's vertical position. */
  topRange?: [number, number];
}

export default function Starfield({ count, topRange = [0, 100] }: StarfieldProps) {
  const [min, max] = topRange;

  // Stars are randomized client-side only, after mount, so the server-rendered
  // markup (which has no way to know the client's random values) always matches
  // what React hydrates against — avoids a hydration mismatch.
  const [stars, setStars] = useState<Star[]>([]);

  useEffect(() => {
    setStars(
      Array.from({ length: count }).map((_, id) => ({
        id,
        top: min + Math.random() * (max - min),
        left: Math.random() * 100,
        size: Math.random() * 2 + 1,
        duration: Math.random() * 3 + 2,
        delay: Math.random() * 5,
      }))
    );
    // Mount-once by design, mirroring the two implementations this replaced —
    // count/topRange are fixed configuration per call site, not reactive state.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      {stars.map((s) => (
        <div
          key={s.id}
          className="absolute rounded-full bg-white animate-twinkle"
          style={{
            top: `${s.top}%`,
            left: `${s.left}%`,
            width: `${s.size}px`,
            height: `${s.size}px`,
            animationDuration: `${s.duration}s`,
            animationDelay: `${s.delay}s`,
          }}
        />
      ))}
    </>
  );
}

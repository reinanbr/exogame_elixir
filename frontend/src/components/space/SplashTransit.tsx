'use client';

import { useEffect, useRef, useState } from 'react';

interface SplashTransitProps {
  size?: number;
  /** When true, the current lap accelerates smoothly to completion instead of looping forever. */
  finish?: boolean;
  /** Fires exactly once, right as the accelerated lap reaches its natural end. */
  onFinish?: () => void;
}

const NORMAL_CYCLE_MS = 5000;
const MAX_SPEED = 12;
const ACCEL_PER_MS = 0.03;

type Keyframes = [number, number][];

function interp(kf: Keyframes, t: number) {
  for (let i = 0; i < kf.length - 1; i++) {
    const [t0, v0] = kf[i];
    const [t1, v1] = kf[i + 1];
    if (t >= t0 && t <= t1) {
      const f = t1 === t0 ? 0 : (t - t0) / (t1 - t0);
      return v0 + (v1 - v0) * f;
    }
  }
  return kf[kf.length - 1][1];
}

// Mirrors the transit-dot / transit-star CSS keyframes, but driven by a
// progress value we control — so we can accelerate toward the end of a lap
// instead of cutting the animation off mid-frame.
const DOT_LEFT: Keyframes = [[0, -60], [0.44, -6], [0.5, 50], [0.56, 106], [1, 160]];
const DOT_OPACITY: Keyframes = [[0, 0], [0.06, 1], [0.94, 1], [1, 0]];
const STAR_BRIGHTNESS: Keyframes = [[0, 1], [0.4, 1], [0.5, 0.8], [0.6, 1], [1, 1]];

export default function SplashTransit({ size = 180, finish = false, onFinish }: SplashTransitProps) {
  const [progress, setProgress] = useState(0);
  const finishRef = useRef(finish);
  const doneRef = useRef(false);

  useEffect(() => {
    finishRef.current = finish;
  }, [finish]);

  useEffect(() => {
    let raf: number;
    let last = performance.now();
    // Kept wrapped to [0, 1) at all times — never left to grow unbounded across
    // laps — so whenever `finish` flips true we ramp up speed from whatever the
    // lap's current position actually is, instead of jumping to the end.
    let localProgress = 0;
    let speed = 1;

    const loop = (now: number) => {
      const dt = now - last;
      last = now;

      if (finishRef.current) {
        speed = Math.min(speed + dt * ACCEL_PER_MS, MAX_SPEED);
      }

      localProgress += (dt * speed) / NORMAL_CYCLE_MS;

      if (finishRef.current) {
        if (localProgress >= 1) {
          if (!doneRef.current) {
            doneRef.current = true;
            setProgress(1);
            onFinish?.();
          }
          return;
        }
      } else if (localProgress >= 1) {
        localProgress -= 1;
      }

      setProgress(localProgress);
      raf = requestAnimationFrame(loop);
    };

    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [onFinish]);

  const dotLeft = interp(DOT_LEFT, progress);
  const dotOpacity = interp(DOT_OPACITY, progress);
  const brightness = interp(STAR_BRIGHTNESS, progress);
  const dashoffset = 100 * (1 - progress);

  return (
    <div className="pointer-events-none select-none">
      <div className="relative" style={{ width: size, height: size }}>
        <div
          className="absolute inset-0 rounded-full bg-gradient-to-br from-yellow-100 via-orange-300 to-orange-500 shadow-[0_0_30px_10px_rgba(251,146,60,0.35)]"
          style={{ filter: `brightness(${brightness})` }}
        />
        <div
          className="absolute top-1/2 rounded-full bg-[#0a0a1a]"
          style={{
            width: size * 0.16,
            height: size * 0.16,
            marginTop: -(size * 0.08),
            left: `${dotLeft}%`,
            opacity: dotOpacity,
          }}
        />
      </div>
      <svg
        viewBox="0 0 120 40"
        className="overflow-visible"
        style={{ width: size * 1.15, marginTop: -size * 0.08 }}
      >
        <line x1="4" y1="4" x2="4" y2="32" stroke="rgba(255,255,255,0.25)" strokeWidth="1" />
        <line x1="4" y1="32" x2="116" y2="32" stroke="rgba(255,255,255,0.25)" strokeWidth="1" />
        <path
          d="M6,10 L46,10 C50,10 50,24 54,24 L66,24 C70,24 70,10 74,10 L114,10"
          fill="none"
          stroke="#67e8f9"
          strokeWidth="1.6"
          strokeLinecap="round"
          pathLength={100}
          strokeDasharray={100}
          style={{ strokeDashoffset: dashoffset }}
        />
      </svg>
    </div>
  );
}

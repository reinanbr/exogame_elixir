interface ExoplanetTransitProps {
  className?: string;
  style?: React.CSSProperties;
  size?: number;
  duration?: number;
  delay?: number;
}

/**
 * Mini animation of the transit method used to detect real exoplanets:
 * a dark planet crosses in front of its star, dimming it, while a light
 * curve graph draws the resulting dip in brightness in sync below.
 */
export default function ExoplanetTransit({
  className = '',
  style,
  size = 96,
  duration = 8,
  delay = 0,
}: ExoplanetTransitProps) {
  const timing = { animationDuration: `${duration}s`, animationDelay: `${delay}s` };

  return (
    <div className={`select-none ${className}`} style={style}>
      <div className="relative" style={{ width: size, height: size }}>
        <div
          className="absolute inset-0 rounded-full bg-gradient-to-br from-yellow-100 via-orange-300 to-orange-500 shadow-[0_0_30px_10px_rgba(251,146,60,0.35)] animate-transit-star"
          style={timing}
        />
        <div
          className="absolute top-1/2 rounded-full bg-[#0a0a1a] animate-transit-dot"
          style={{ width: size * 0.16, height: size * 0.16, marginTop: -(size * 0.08), ...timing }}
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
          className="animate-transit-curve"
          style={timing}
        />
      </svg>
    </div>
  );
}

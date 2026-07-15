interface HabitableZoneDiagramProps {
  className?: string;
  style?: React.CSSProperties;
  size?: number;
}

/** Closed elliptical subpath, for combining two into a filled ring via fill-rule="evenodd". */
function ellipsePath(cx: number, cy: number, rx: number, ry: number) {
  return `M ${cx - rx},${cy} A ${rx},${ry} 0 1,0 ${cx + rx},${cy} A ${rx},${ry} 0 1,0 ${cx - rx},${cy} Z`;
}

/**
 * Mini diagram of a star's habitable zone: too hot (inner), just right
 * (middle, where liquid water can exist), too cold (outer) — each band
 * holding a representative planet.
 */
export default function HabitableZoneDiagram({
  className = '',
  style,
  size = 150,
}: HabitableZoneDiagramProps) {
  return (
    <svg
      viewBox="0 0 160 80"
      className={`overflow-visible select-none ${className}`}
      style={{ width: size, height: size * 0.5, ...style }}
    >
      <defs>
        <radialGradient id="hz-star" cx="35%" cy="35%" r="65%">
          <stop offset="0%" stopColor="#fff6d0" />
          <stop offset="55%" stopColor="#ffcf6b" />
          <stop offset="100%" stopColor="#ff9a3c" />
        </radialGradient>
      </defs>

      {/* concentric zone bands, each confined strictly to its own ring so they never bleed into each other */}
      <path
        d={`${ellipsePath(20, 40, 85, 32)} ${ellipsePath(20, 40, 55, 24)}`}
        fillRule="evenodd"
        fill="#38bdf8"
        fillOpacity="0.16"
        stroke="#38bdf8"
        strokeWidth="1.3"
        opacity="0.7"
      />
      <path
        d={`${ellipsePath(20, 40, 55, 24)} ${ellipsePath(20, 40, 30, 16)}`}
        fillRule="evenodd"
        fill="#34d399"
        fillOpacity="0.2"
        stroke="#34d399"
        strokeWidth="1.8"
        className="animate-zone-glow"
        style={{ animationDuration: '4s' }}
      />
      <ellipse cx="20" cy="40" rx="30" ry="16" fill="#fb7185" fillOpacity="0.18" stroke="#fb7185" strokeWidth="1.3" opacity="0.75" />

      {/* star */}
      <circle cx="20" cy="40" r="10" fill="url(#hz-star)" />

      {/* too hot planet, on the inner ring */}
      <circle cx="50" cy="40" r="3.2" fill="#a8a29e" />
      {/* just right planet, on the habitable ring */}
      <circle cx="75" cy="40" r="4.2" fill="#60a5fa" stroke="#bbf7d0" strokeWidth="0.6" />
      {/* too cold planet, on the outer ring */}
      <circle cx="105" cy="40" r="5" fill="#93c5fd" opacity="0.9" />
    </svg>
  );
}

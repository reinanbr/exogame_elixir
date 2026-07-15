interface SizeComparisonDiagramProps {
  className?: string;
  style?: React.CSSProperties;
  size?: number;
}

/**
 * Mini side-by-side size comparison, like the real TOI-1452 b vs Earth
 * imagery: the exoplanet rendered ~70% larger than Earth.
 */
export default function SizeComparisonDiagram({
  className = '',
  style,
  size = 110,
}: SizeComparisonDiagramProps) {
  return (
    <div className={`flex items-end gap-3 select-none ${className}`} style={style}>
      <div className="flex flex-col items-center gap-1">
        <div
          className="rounded-full animate-float-slow"
          style={{
            width: size * 0.68,
            height: size * 0.68,
            background: 'radial-gradient(circle at 35% 30%, #a5f3fc, #22d3ee 45%, #0e7490 100%)',
            boxShadow: '0 0 18px 4px rgba(34,211,238,0.35)',
          }}
        />
        <span className="text-[10px] text-white/60 tracking-wide whitespace-nowrap">TOI-1452 b</span>
      </div>
      <div className="flex flex-col items-center gap-1">
        <div
          className="rounded-full animate-float"
          style={{
            width: size * 0.4,
            height: size * 0.4,
            background: 'radial-gradient(circle at 35% 30%, #bae6fd, #38bdf8 40%, #15803d 75%, #166534 100%)',
            boxShadow: '0 0 14px 3px rgba(56,189,248,0.3)',
          }}
        />
        <span className="text-[10px] text-white/60 tracking-wide">Terra</span>
      </div>
    </div>
  );
}

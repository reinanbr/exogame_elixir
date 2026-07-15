interface InfoHoverProps {
  children: React.ReactNode;
  text: string;
  className?: string;
  tooltipClassName?: string;
}

/**
 * Wraps a decorative element so hovering it reveals a small explanatory
 * tooltip. Pure CSS (group-hover) — no JS state, no hydration concerns.
 */
export default function InfoHover({
  children,
  text,
  className = '',
  tooltipClassName = '',
}: InfoHoverProps) {
  return (
    <div className={`group cursor-help pointer-events-auto ${className}`}>
      {children}
      <div
        className={`absolute z-50 w-56 rounded-lg border border-white/15 bg-[#0d0a24]/95 backdrop-blur-xl px-3 py-2 text-xs leading-relaxed text-white/90 shadow-2xl shadow-black/50 opacity-0 scale-95 pointer-events-none transition-all duration-200 group-hover:opacity-100 group-hover:scale-100 ${tooltipClassName}`}
      >
        {text}
      </div>
    </div>
  );
}

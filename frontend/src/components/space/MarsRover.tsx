interface MarsRoverProps {
  className?: string;
}

/**
 * A Curiosity/Perseverance-style rover trundling across the alien surface,
 * with an astronaut following  on foot behind it. The pair drifts across the
 * whole width of the screen on a slow loop; wheels and legs/arms animate on
 * their own faster cycles independent of that traverse.
 */
export default function MarsRover({ className = '' }: MarsRoverProps) {
  return (
    <div
      aria-hidden="true"
      className={`absolute pointer-events-none animate-rover-cross ${className}`}
    >
      <div className="animate-rover-bob">
        <svg viewBox="0 0 220 100" width={180} className="overflow-visible">
          <defs>
            <linearGradient id="rover-deck" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#e9ebef" />
              <stop offset="100%" stopColor="#aeb2bd" />
            </linearGradient>
            <linearGradient id="suit-white" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#ffffff" />
              <stop offset="100%" stopColor="#c7ccd6" />
            </linearGradient>
          </defs>

          {/* contact shadows */}
          <ellipse cx="150" cy="87" rx="46" ry="4" fill="rgba(0,0,0,0.35)" />
          <ellipse cx="54" cy="87" rx="15" ry="3.5" fill="rgba(0,0,0,0.3)" />

          {/* astronaut, trailing behind the rover */}
          <g>
            <rect x="33" y="41" width="11" height="20" rx="2.5" fill="#9aa0ab" />
            <rect
              x="60"
              y="60"
              width="6"
              height="19"
              rx="3"
              fill="#dfe2e8"
              className="animate-walk-swing"
              style={{ transformOrigin: '63px 60px' }}
            />
            <rect
              x="47"
              y="60"
              width="6"
              height="19"
              rx="3"
              fill="#f3f4f7"
              className="animate-walk-swing"
              style={{ transformOrigin: '50px 60px', animationDelay: '-0.3s' }}
            />
            <rect x="41" y="39" width="25" height="23" rx="7" fill="url(#suit-white)" />
            <rect x="41" y="48" width="25" height="5" fill="#e11d48" opacity="0.55" />
            <rect
              x="60"
              y="42"
              width="5.5"
              height="16"
              rx="2.5"
              fill="#dfe2e8"
              className="animate-walk-swing"
              style={{ transformOrigin: '63px 42px', animationDelay: '-0.3s' }}
            />
            <rect
              x="43"
              y="42"
              width="5.5"
              height="16"
              rx="2.5"
              fill="#f3f4f7"
              className="animate-walk-swing"
              style={{ transformOrigin: '46px 42px' }}
            />
            <circle cx="54" cy="30" r="11" fill="url(#suit-white)" stroke="#c7ccd6" strokeWidth="1" />
            <ellipse cx="57" cy="30.5" rx="6.5" ry="7.5" fill="#0e1320" />
            <ellipse cx="55" cy="27" rx="2" ry="2.6" fill="rgba(255,255,255,0.35)" />
          </g>

          {/* rover, out in front */}
          <g>
            <g className="animate-wheel-spin" style={{ transformOrigin: '123px 78px' }}>
              <circle cx="123" cy="78" r="9" fill="#2c2e33" />
              <circle cx="123" cy="78" r="4.5" fill="#6b6e76" />
              <line x1="123" y1="70" x2="123" y2="86" stroke="#4a4d54" strokeWidth="1.4" />
              <line x1="115" y1="78" x2="131" y2="78" stroke="#4a4d54" strokeWidth="1.4" />
            </g>
            <g
              className="animate-wheel-spin"
              style={{ transformOrigin: '151px 80px', animationDelay: '-0.35s' }}
            >
              <circle cx="151" cy="80" r="9.5" fill="#2c2e33" />
              <circle cx="151" cy="80" r="4.8" fill="#6b6e76" />
              <line x1="151" y1="71.5" x2="151" y2="88.5" stroke="#4a4d54" strokeWidth="1.4" />
              <line x1="142.5" y1="80" x2="159.5" y2="80" stroke="#4a4d54" strokeWidth="1.4" />
            </g>
            <g
              className="animate-wheel-spin"
              style={{ transformOrigin: '179px 78px', animationDelay: '-0.7s' }}
            >
              <circle cx="179" cy="78" r="9" fill="#2c2e33" />
              <circle cx="179" cy="78" r="4.5" fill="#6b6e76" />
              <line x1="179" y1="70" x2="179" y2="86" stroke="#4a4d54" strokeWidth="1.4" />
              <line x1="171" y1="78" x2="187" y2="78" stroke="#4a4d54" strokeWidth="1.4" />
            </g>

            <path d="M118,58 L123,70 M151,55 L151,72 M184,58 L179,70" stroke="#7a7d85" strokeWidth="2" fill="none" />

            <rect x="112" y="46" width="76" height="20" rx="4" fill="url(#rover-deck)" stroke="#8b8e97" strokeWidth="1" />
            <rect x="108" y="41" width="13" height="10" rx="2" fill="#3a3c42" />

            <line x1="150" y1="46" x2="150" y2="14" stroke="#8b8e97" strokeWidth="2.5" />
            <rect x="141" y="7" width="18" height="9" rx="2" fill="#3a3c42" />
            <circle cx="146" cy="11.5" r="2" fill="#67e8f9" />
            <circle cx="154" cy="11.5" r="2" fill="#67e8f9" />

            <line x1="160" y1="46" x2="168" y2="24" stroke="#8b8e97" strokeWidth="1.4" />
            <circle cx="168" cy="24" r="1.8" fill="#c7ccd6" />

            <path d="M188,52 L204,58 L204,74" stroke="#8b8e97" strokeWidth="3" fill="none" strokeLinecap="round" />
            <circle cx="204" cy="76" r="3.5" fill="#3a3c42" />
          </g>
        </svg>
      </div>
    </div>
  );
}

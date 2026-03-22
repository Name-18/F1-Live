import React from 'react'

export default function Background() {
  return (
    <div style={s.root} aria-hidden="true">

      {/* Base radial — deep red center glow from top */}
      <div style={s.glowTop} />

      {/* Bottom corner accent */}
      <div style={s.glowBottomLeft} />
      <div style={s.glowBottomRight} />

      {/* Horizontal scan lines — subtle texture */}
      <div style={s.scanLines} />

      {/* Circuit-inspired SVG line art */}
      <svg style={s.svg} viewBox="0 0 1440 900" preserveAspectRatio="xMidYMid slice">
        <defs>
          <filter id="blur4">
            <feGaussianBlur stdDeviation="4" />
          </filter>
          <filter id="blur2">
            <feGaussianBlur stdDeviation="2" />
          </filter>
        </defs>

        {/* Far background grid — very faint */}
        {Array.from({ length: 18 }).map((_, i) => (
          <line key={`h${i}`}
            x1="0" y1={i * 52} x2="1440" y2={i * 52}
            stroke="#1A0005" strokeWidth="0.5" />
        ))}
        {Array.from({ length: 24 }).map((_, i) => (
          <line key={`v${i}`}
            x1={i * 62} y1="0" x2={i * 62} y2="900"
            stroke="#1A0005" strokeWidth="0.5" />
        ))}

        {/* Circuit track lines — left side */}
        <g opacity="0.18" filter="url(#blur2)">
          <polyline
            points="0,600 120,600 180,520 180,300 260,220 420,220 500,300 500,480 580,560 720,560"
            fill="none" stroke="#E8002D" strokeWidth="2" strokeLinejoin="round" />
          <polyline
            points="0,620 110,620 170,540 170,300 255,210 420,210 510,295 510,485 595,570 720,570"
            fill="none" stroke="#E8002D" strokeWidth="1" strokeLinejoin="round" />
        </g>

        {/* Circuit track lines — right side */}
        <g opacity="0.15" filter="url(#blur2)">
          <polyline
            points="1440,400 1320,400 1260,340 1180,340 1100,420 1100,600 1020,680 860,680 800,600 800,480"
            fill="none" stroke="#E8002D" strokeWidth="2" strokeLinejoin="round" />
          <polyline
            points="1440,415 1325,415 1265,355 1180,355 1095,435 1095,605 1015,690 860,690 790,610 790,480"
            fill="none" stroke="#E8002D" strokeWidth="1" strokeLinejoin="round" />
        </g>

        {/* Bright accent dots at corners / chicanes */}
        {[
          [180, 300], [420, 220], [500, 300], [500, 480],
          [1100, 420], [1100, 600], [860, 680],
        ].map(([cx, cy], i) => (
          <circle key={i} cx={cx} cy={cy} r="3"
            fill="#E8002D" opacity="0.35" filter="url(#blur4)" />
        ))}

        {/* Speed lines — top right diagonal streaks */}
        <g opacity="0.06" stroke="#E8002D" strokeWidth="1">
          {[0,18,36,54,72,90].map((offset, i) => (
            <line key={i}
              x1={900 + offset} y1="0"
              x2={1440 + offset} y2={540 + offset} />
          ))}
        </g>

        {/* Speed lines — bottom left */}
        <g opacity="0.05" stroke="#E8002D" strokeWidth="1">
          {[0,20,40,60].map((offset, i) => (
            <line key={i}
              x1={0} y1={400 + offset}
              x2={500 - offset} y2={900} />
          ))}
        </g>
      </svg>

      {/* Vignette — darkens edges */}
      <div style={s.vignette} />

    </div>
  )
}

const s = {
  root: {
    position: 'fixed',
    inset: 0,
    zIndex: 0,
    pointerEvents: 'none',
    overflow: 'hidden',
  },

  // Deep red radial from top center
  glowTop: {
    position: 'absolute',
    top: -200,
    left: '50%',
    transform: 'translateX(-50%)',
    width: 900,
    height: 600,
    background: 'radial-gradient(ellipse at center, rgba(140,0,22,0.22) 0%, transparent 70%)',
    borderRadius: '50%',
  },

  // Subtle accent bottom left
  glowBottomLeft: {
    position: 'absolute',
    bottom: -100,
    left: -100,
    width: 500,
    height: 400,
    background: 'radial-gradient(ellipse at center, rgba(100,0,16,0.18) 0%, transparent 70%)',
    borderRadius: '50%',
  },

  // Subtle accent bottom right
  glowBottomRight: {
    position: 'absolute',
    bottom: -80,
    right: -80,
    width: 400,
    height: 320,
    background: 'radial-gradient(ellipse at center, rgba(80,0,12,0.14) 0%, transparent 70%)',
    borderRadius: '50%',
  },

  // Repeating horizontal scan lines
  scanLines: {
    position: 'absolute',
    inset: 0,
    backgroundImage: 'repeating-linear-gradient(0deg, transparent, transparent 3px, rgba(0,0,0,0.08) 3px, rgba(0,0,0,0.08) 4px)',
    pointerEvents: 'none',
  },

  svg: {
    position: 'absolute',
    inset: 0,
    width: '100%',
    height: '100%',
  },

  // Edge vignette
  vignette: {
    position: 'absolute',
    inset: 0,
    background: 'radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.65) 100%)',
  },
}

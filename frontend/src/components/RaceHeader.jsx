import React from 'react'
import { useRaceStore } from '../store/raceStore'

const STATUS_CONFIG = {
  green:     { label: 'RACING',        bg: '#00C853', color: '#000' },
  yellow:    { label: 'YELLOW FLAG',   bg: '#FFD700', color: '#000' },
  sc:        { label: 'SAFETY CAR',    bg: '#FFA500', color: '#000' },
  vsc:       { label: 'VIRTUAL SC',    bg: '#FFD700', color: '#000' },
  red:       { label: 'RED FLAG',      bg: '#E8002D', color: '#fff' },
  chequered: { label: 'RACE OVER',     bg: '#ffffff', color: '#000' },
  finished:  { label: 'LAST RACE',     bg: '#333',    color: '#aaa' },
  unknown:   { label: 'AWAITING DATA', bg: '#222',    color: '#555' },
}

export default function RaceHeader() {
  const { session, sessionStatus, currentLap, weather, connected, isLive, dataSource } = useRaceStore()
  const cfg = STATUS_CONFIG[sessionStatus] || STATUS_CONFIG.unknown

  const airTemp   = weather?.air_temperature   != null ? `${Math.round(weather.air_temperature)}°C`   : '--'
  const trackTemp = weather?.track_temperature != null ? `${Math.round(weather.track_temperature)}°C` : '--'
  const windSpeed = weather?.wind_speed        != null ? `${Math.round(weather.wind_speed)} m/s`      : '--'

  const gpTitle    = session?.gp_name || session?.name || 'RACE'
  const circuitStr = session?.circuit || ''
  const countryStr = session?.country || ''
  const seasonStr  = session?.season  ? `${session.season}` : ''
  const roundStr   = session?.round   ? `Round ${session.round}` : ''

  return (
    <header style={s.header}>

      {/* Left: F1 logo image */}
      <div style={s.brand}>
        <div style={s.logoWrap}>
          <img src="/logo.webp" alt="F1" style={s.logoImg} />
        </div>
        <span style={s.logoLive}></span>
      </div>

      {/* Center: GP name + circuit */}
      <div style={s.center}>
        <div style={s.gpName}>{gpTitle}</div>
        <div style={s.meta}>
          {circuitStr && <span style={s.circuit}>{circuitStr}</span>}
          {countryStr && <span style={s.country}>{countryStr}</span>}
          {seasonStr  && <span style={s.pill}>{seasonStr}</span>}
          {roundStr   && <span style={s.pill}>{roundStr}</span>}
        </div>
      </div>

      {/* Right: live/historical badge + status + lap + weather */}
      <div style={s.right}>

        {/* Data source indicator */}
        <div style={isLive ? s.liveTag : s.histTag}>
          {isLive ? '● LIVE' : '◷ LAST RACE'}
        </div>

        {/* Session status */}
        <div style={{ ...s.badge, background: cfg.bg, color: cfg.color }}>
          {cfg.label}
        </div>

        {/* Lap counter — only during live */}
        {isLive && currentLap > 0 && (
          <div style={s.lap}>
            <span style={s.lapLabel}>LAP</span>
            <span style={s.lapNum}>{currentLap}</span>
          </div>
        )}

        {/* Weather — only during live */}
        {isLive && (
          <div style={s.weatherRow}>
            <span style={s.wItem}>Air <span style={s.wVal}>{airTemp}</span></span>
            <span style={s.wItem}>Track <span style={s.wVal}>{trackTemp}</span></span>
            <span style={s.wItem}>Wind <span style={s.wVal}>{windSpeed}</span></span>
          </div>
        )}

      </div>
    </header>
  )
}

const s = {
  header: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '0 20px', height: 64, background: '#0A0A0A',
    borderBottom: '2px solid #E8002D', position: 'sticky',
    top: 0, zIndex: 100, gap: 12, overflow: 'hidden',
  },
  brand: { display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 },
  logoWrap: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
  },
  logoImg: {
    height: 52,
    width: 'auto',
    display: 'block',
    mixBlendMode: 'screen',
  },
  logoLive: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 13,
    fontWeight: 700, color: '#666', letterSpacing: '0.2em',
    alignSelf: 'center',
    marginLeft: 2,
  },
  center: { flex: 1, textAlign: 'center', minWidth: 0, overflow: 'hidden' },
  gpName: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 20, fontWeight: 800,
    letterSpacing: '0.06em', color: '#fff', textTransform: 'uppercase',
    lineHeight: 1.1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
  },
  meta: {
    display: 'flex', justifyContent: 'center', alignItems: 'center',
    gap: 6, marginTop: 2, flexWrap: 'nowrap', overflow: 'hidden',
  },
  circuit: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 11, fontWeight: 600,
    color: '#E8002D', letterSpacing: '0.1em', textTransform: 'uppercase',
    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
  },
  country: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 11,
    color: '#555', whiteSpace: 'nowrap', flexShrink: 0,
  },
  pill: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 10,
    color: '#333', background: '#1A1A1A', padding: '1px 6px',
    borderRadius: 3, whiteSpace: 'nowrap', flexShrink: 0,
  },
  right: { display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 },
  liveTag: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 11, fontWeight: 800,
    letterSpacing: '0.1em', color: '#00C853',
    animation: 'pulse 1.5s ease-in-out infinite',
  },
  histTag: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 11,
    letterSpacing: '0.08em', color: '#444',
  },
  badge: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 11, fontWeight: 800,
    letterSpacing: '0.12em', padding: '3px 9px', borderRadius: 3,
    textTransform: 'uppercase', whiteSpace: 'nowrap', flexShrink: 0,
  },
  lap: { display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1, flexShrink: 0 },
  lapLabel: {
    fontFamily: "'Barlow Condensed', sans-serif", fontSize: 9,
    fontWeight: 600, color: '#555', letterSpacing: '0.15em',
  },
  lapNum: { fontFamily: "'Share Tech Mono', monospace", fontSize: 20, color: '#E8002D' },
  weatherRow: { display: 'flex', alignItems: 'center', gap: 10, borderLeft: '1px solid #1E1E1E', paddingLeft: 10, flexShrink: 0 },
  wItem: { fontFamily: "'Barlow Condensed', sans-serif", fontSize: 11, color: '#555', whiteSpace: 'nowrap' },
  wVal:  { color: '#888' },
}
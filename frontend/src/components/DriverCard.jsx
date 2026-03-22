import React, { useState } from 'react'

const TYRE = {
  SOFT:         { bg:'#E8002D', color:'#fff', s:'S' },
  MEDIUM:       { bg:'#FFD700', color:'#000', s:'M' },
  HARD:         { bg:'#FFFFFF', color:'#000', s:'H' },
  INTERMEDIATE: { bg:'#39B54A', color:'#fff', s:'I' },
  WET:          { bg:'#0067FF', color:'#fff', s:'W' },
  UNKNOWN:      { bg:'#2A2A2A', color:'#555', s:'?' },
}

function TyreBadge({ compound }) {
  const c = TYRE[compound] || TYRE.UNKNOWN
  return (
    <div style={{
      width: 22, height: 22, borderRadius: '50%',
      background: c.bg, color: c.color,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: "'Barlow Condensed', sans-serif",
      fontSize: 11, fontWeight: 800, flexShrink: 0,
      border: compound === 'HARD' ? '1px solid #444' : 'none',
    }}>
      {c.s}
    </div>
  )
}

function fmtLap(d) {
  if (!d) return '--:--.---'
  const m = Math.floor(d / 60)
  const sec = (d % 60).toFixed(3).padStart(6, '0')
  return m > 0 ? `${m}:${sec}` : sec
}

function fmtGap(g) {
  if (g == null) return '--'
  if (typeof g === 'string') return g
  return `+${g.toFixed(3)}`
}

export default function DriverCard({ driver, rank, isLeader }) {
  // Open by default
  const [open, setOpen] = useState(true)

  const tc = driver.team_colour ? `#${driver.team_colour}` : '#444'
  const retired = driver.is_retired
  const tyreCompound = driver.tyre_compound || 'UNKNOWN'

  // Don't show expanded panel if there's no meaningful data
  const hasExpandData = driver.country_code || driver.lap_number || driver.headshot_url

  return (
    <div style={{ ...s.wrapper, opacity: retired ? 0.45 : 1 }}>

      {/* ── Main row ── */}
      <div onClick={() => setOpen(!open)} style={s.row}>

        {/* Team colour bar */}
        <div style={{ ...s.bar, background: tc }} />

        {/* Position */}
        <div style={s.posCell}>
          <span style={{
            fontFamily: "'Barlow Condensed', sans-serif",
            fontWeight: 800,
            fontSize: rank === 1 ? 20 : 15,
            lineHeight: 1,
            color: rank === 1 ? '#FFD700' : rank <= 3 ? '#E8002D' : '#fff',
          }}>
            {retired ? 'OUT' : rank}
          </span>
        </div>

        {/* Car number */}
        <div style={{ ...s.numCell, color: tc }}>
          {driver.driver_number}
        </div>

        {/* Driver name block */}
        <div style={s.nameCell}>
          <div style={s.acronym}>{driver.name_acronym}</div>
          <div style={s.fullName}>{driver.full_name}</div>
        </div>

        {/* Team */}
        <div style={s.teamCell}>{driver.team_name}</div>

        {/* Tyre */}
        <div style={s.tyreCell}>
          <TyreBadge compound={tyreCompound} />
          {driver.tyre_age > 0 && (
            <span style={s.tyreAge}>{driver.tyre_age}L</span>
          )}
        </div>

        {/* Last lap */}
        <div style={s.lapCell}>{fmtLap(driver.last_lap_duration)}</div>

        {/* Gap */}
        <div style={s.gapCell}>
          {isLeader
            ? <span style={s.leaderTag}>LEADER</span>
            : fmtGap(driver.gap_to_leader)}
        </div>

        {/* Interval */}
        <div style={s.intCell}>
          {isLeader ? '—' : fmtGap(driver.interval)}
        </div>

        {/* Pits */}
        <div style={s.pitsCell}>
          <span style={s.pitLabel}>PIT</span>
          <span style={s.pitCount}>{driver.pit_count || 0}</span>
        </div>

        {/* Toggle arrow */}
        <div style={{ ...s.arrow, transform: open ? 'rotate(90deg)' : 'none' }}>›</div>
      </div>

      {/* ── Expanded detail panel ── */}
      {open && (
        <div style={s.panel}>
          <div style={s.grid}>

            <div style={s.item}>
              <span style={s.iLabel}>Car No.</span>
              <span style={{ ...s.iVal, color: tc }}>{driver.driver_number || '—'}</span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Nationality</span>
              <span style={s.iVal}>{driver.country_code || '—'}</span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Current Lap</span>
              <span style={s.iVal}>{driver.lap_number || '—'}</span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Tyre</span>
              <span style={{
                ...s.iVal,
                color: TYRE[tyreCompound]?.bg || '#888',
              }}>
                {tyreCompound !== 'UNKNOWN' ? tyreCompound : '—'}
              </span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Tyre Age</span>
              <span style={s.iVal}>
                {driver.tyre_age > 0 ? `${driver.tyre_age} laps` : '—'}
              </span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Pit Stops</span>
              <span style={s.iVal}>{driver.pit_count ?? 0}</span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Status</span>
              <span style={{
                ...s.iVal,
                color: retired ? '#E8002D' : '#00C853',
              }}>
                {retired ? 'RETIRED' : 'RACING'}
              </span>
            </div>

            <div style={s.item}>
              <span style={s.iLabel}>Team</span>
              <span style={{ ...s.iVal, color: tc }}>{driver.team_name || '—'}</span>
            </div>

            {driver.points != null && (
              <div style={s.item}>
                <span style={s.iLabel}>Points</span>
                <span style={{ ...s.iVal, color: '#E8002D' }}>{driver.points}</span>
              </div>
            )}

            {driver.fastest_lap && (
              <div style={s.item}>
                <span style={s.iLabel}>Fastest Lap</span>
                <span style={{ ...s.iVal, color: '#A855F7' }}>{driver.fastest_lap}</span>
              </div>
            )}

            {driver.status && driver.status !== 'RACING' && driver.status !== 'Finished' && (
              <div style={s.item}>
                <span style={s.iLabel}>Finish Status</span>
                <span style={{ ...s.iVal, color: '#E8002D' }}>{driver.status}</span>
              </div>
            )}

            {/* Headshot — only if URL exists */}
            {driver.headshot_url && (
              <div style={{ marginLeft: 'auto', alignSelf: 'center' }}>
                <img
                  src={driver.headshot_url}
                  alt={driver.full_name}
                  style={s.headshot}
                  onError={e => { e.target.style.display = 'none' }}
                />
              </div>
            )}

          </div>
        </div>
      )}
    </div>
  )
}

const s = {
  wrapper: {
    position: 'relative',
    zIndex: 0,
    borderBottom: '1px solid rgba(255,255,255,0.04)',
    background: 'rgba(10,0,4,0.75)',
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    minHeight: 48,
    cursor: 'pointer',
    transition: 'background 0.12s',
  },
  bar:      { width: 3, alignSelf: 'stretch', flexShrink: 0 },
  posCell:  { width: 40, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 },
  numCell:  { width: 36, fontFamily: "'Share Tech Mono', monospace", fontSize: 13, flexShrink: 0, paddingLeft: 4 },
  nameCell: { width: 140, flexShrink: 0, paddingLeft: 8 },
  acronym:  { fontFamily: "'Barlow Condensed', sans-serif", fontSize: 15, fontWeight: 700, letterSpacing: '0.05em', color: '#fff', lineHeight: 1 },
  fullName: { fontFamily: "'Barlow', sans-serif", fontSize: 10, color: '#555', lineHeight: 1, marginTop: 2 },
  teamCell: { flex: 1, fontFamily: "'Barlow Condensed', sans-serif", fontSize: 12, color: '#777', paddingLeft: 8, minWidth: 80, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
  tyreCell: { width: 60, display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 },
  tyreAge:  { fontFamily: "'Share Tech Mono', monospace", fontSize: 10, color: '#555' },
  lapCell:  { width: 100, fontFamily: "'Share Tech Mono', monospace", fontSize: 12, color: '#ccc', textAlign: 'right', paddingRight: 12, flexShrink: 0 },
  gapCell:  { width: 80,  fontFamily: "'Share Tech Mono', monospace", fontSize: 12, color: '#888', textAlign: 'right', paddingRight: 12, flexShrink: 0 },
  intCell:  { width: 80,  fontFamily: "'Share Tech Mono', monospace", fontSize: 12, color: '#555', textAlign: 'right', paddingRight: 12, flexShrink: 0 },
  pitsCell: { width: 44, display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 },
  pitLabel: { fontFamily: "'Barlow Condensed', sans-serif", fontSize: 9, color: '#444', letterSpacing: '0.1em', lineHeight: 1 },
  pitCount: { fontFamily: "'Share Tech Mono', monospace", fontSize: 14, color: '#777', lineHeight: 1 },
  leaderTag:{ fontFamily: "'Barlow Condensed', sans-serif", fontSize: 10, fontWeight: 700, color: '#FFD700', letterSpacing: '0.1em' },
  arrow:    { width: 24, textAlign: 'center', color: '#333', fontSize: 18, transition: 'transform 0.18s', flexShrink: 0 },

  // Expanded panel
  panel: {
    position: 'relative',
    zIndex: 0,
    background: 'rgba(6,0,2,0.88)',
    borderTop: '1px solid rgba(232,0,45,0.08)',
    padding: '10px 16px 14px 46px',   // left pad aligns with driver name column
  },
  grid: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '10px 24px',
    alignItems: 'flex-start',
  },
  item: {
    display: 'flex',
    flexDirection: 'column',
    gap: 2,
    minWidth: 80,
  },
  iLabel: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 9,
    color: '#444',
    letterSpacing: '0.14em',
    textTransform: 'uppercase',
  },
  iVal: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 14,
    fontWeight: 700,
    color: '#bbb',
    letterSpacing: '0.04em',
  },
  headshot: {
    height: 56,
    objectFit: 'contain',
    borderRadius: 3,
    filter: 'grayscale(15%)',
  },
}

// Note: DriverCard already handles jolpica fields since they share the same
// driver object shape. Points, status, and fastest_lap are shown in the
// expanded panel automatically when present.
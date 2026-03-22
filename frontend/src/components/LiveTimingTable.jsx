import React from 'react'
import { useRaceStore } from '../store/raceStore'
import DriverCard from './DriverCard'

const COLS = [
  { label: '',         width: 3   },
  { label: 'POS',      width: 40  },
  { label: 'NO.',      width: 36  },
  { label: 'DRIVER',   width: 140, pl: 8 },
  { label: 'TEAM',     flex: 1,   pl: 8 },
  { label: 'TYRE',     width: 60  },
  { label: 'LAST LAP', width: 100, align: 'right', pr: 12 },
  { label: 'GAP',      width: 80,  align: 'right', pr: 12 },
  { label: 'INT',      width: 80,  align: 'right', pr: 12 },
  { label: 'PITS',     width: 44  },
  { label: '',         width: 24  },
]

export default function LiveTimingTable() {
  const drivers   = useRaceStore((s) => s.drivers)
  const connected = useRaceStore((s) => s.connected)

  return (
    <div style={s.outer}>

      {/* ── Column headers ── always rendered first, never inside a driver card */}
      <div style={s.headerRow}>
        {COLS.map((col, i) => (
          <div key={i} style={{
            ...s.hCell,
            width:        col.width,
            flex:         col.flex,
            textAlign:    col.align || 'left',
            paddingLeft:  col.pl  || 0,
            paddingRight: col.pr  || 0,
            flexShrink:   col.flex ? undefined : 0,
          }}>
            {col.label}
          </div>
        ))}
      </div>

      {/* ── Driver rows ── rendered strictly below the header */}
      <div style={s.driverList}>
        {!connected && drivers.length === 0 && (
          <div style={s.empty}>
            <div style={s.spinner} />
            <div style={s.emptyTitle}>Connecting to live timing…</div>
            <div style={s.emptyHint}>Make sure the Flask backend is running on port 5000</div>
          </div>
        )}

        {connected && drivers.length === 0 && (
          <div style={s.empty}>
            <div style={s.emptyTitle}>Awaiting session data</div>
            <div style={s.emptyHint}>Live timing appears during active race weekends</div>
          </div>
        )}

        {drivers.map((driver, idx) => (
          <DriverCard
            key={driver.driver_number}
            driver={driver}
            rank={idx + 1}
            isLeader={idx === 0}
          />
        ))}

        {drivers.length > 0 && (
          <div style={s.footer}>
            {drivers.length} drivers · click any row to collapse / expand
          </div>
        )}
      </div>

    </div>
  )
}

const s = {
  outer: {
    display: 'flex',
    flexDirection: 'column',   // header on top, driverList below — always
    width: '100%',
  },
  headerRow: {
    display: 'flex',
    alignItems: 'center',
    height: 34,
    background: 'rgba(8,0,3,0.92)',
    borderBottom: '2px solid #E8002D',
    borderTop: '1px solid rgba(232,0,45,0.15)',
    backdropFilter: 'blur(8px)',
    flexShrink: 0,             // never shrink or reorder
    order: 0,                  // explicitly first
  },
  hCell: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 10,
    fontWeight: 700,
    color: '#E8002D',
    letterSpacing: '0.12em',
    textTransform: 'uppercase',
  },
  driverList: {
    display: 'flex',
    flexDirection: 'column',
    order: 1,                  // explicitly after headerRow
  },
  empty: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '80px 24px',
    gap: 12,
  },
  spinner: {
    width: 28,
    height: 28,
    border: '2px solid #1A1A1A',
    borderTop: '2px solid #E8002D',
    borderRadius: '50%',
    animation: 'spin 0.8s linear infinite',
  },
  emptyTitle: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 16,
    fontWeight: 700,
    color: '#444',
    letterSpacing: '0.1em',
    textTransform: 'uppercase',
  },
  emptyHint: {
    fontFamily: "'Barlow', sans-serif",
    fontSize: 12,
    color: '#2A2A2A',
    textAlign: 'center',
  },
  footer: {
    padding: '10px 16px',
    fontFamily: "'Barlow', sans-serif",
    fontSize: 11,
    color: '#2A2A2A',
    borderTop: '1px solid #111',
    textAlign: 'center',
  },
}
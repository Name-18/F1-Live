import React, { useState } from 'react'
import { Toaster } from 'react-hot-toast'
import { useSocket } from './hooks/useSocket'
import Background from './components/Background'
import RaceHeader from './components/RaceHeader'
import LiveTimingTable from './components/LiveTimingTable'
import AlertFeed from './components/AlertFeed'
import StandingsPanel from './components/StandingsPanel'

export default function App() {
  useSocket()
  const [view, setView] = useState('live')

  return (
    <div style={s.root}>
      <style>{`
        @keyframes spin    { to { transform: rotate(360deg); } }
        @keyframes pulse   { 0%,100% { opacity:1; } 50% { opacity:0.4; } }
        @media (max-width: 768px) { .alert-panel { display: none !important; } }
      `}</style>

      {/* Atmospheric background — sits behind everything */}
      <Background />

      <Toaster position="top-center" containerStyle={{ top: 72 }} toastOptions={{ duration: 5000 }} />

      {/* Everything else sits above the background */}
      <div style={s.shell}>

        <RaceHeader />

        <nav style={s.nav}>
          {[
            { id: 'live',      label: 'LIVE TIMING' },
            { id: 'standings', label: 'STANDINGS'   },
          ].map(({ id, label }) => (
            <button key={id} onClick={() => setView(id)}
              style={{ ...s.navBtn, ...(view === id ? s.navActive : {}) }}>
              {label}
            </button>
          ))}
        </nav>

        <div style={s.body}>
          {view === 'live' && (
            <>
              <div style={s.timingScroll}>
                <LiveTimingTable />
              </div>
              <div className="alert-panel" style={s.alertWrap}>
                <AlertFeed />
              </div>
            </>
          )}
          {view === 'standings' && (
            <div style={s.standingsScroll}>
              <StandingsPanel />
            </div>
          )}
        </div>

      </div>
    </div>
  )
}

const HEAD_H = 72
const NAV_H  = 40
const BODY_H = `calc(100vh - ${HEAD_H + NAV_H}px)`

const s = {
  root: {
    position: 'relative',
    height: '100vh',
    overflow: 'hidden',
    background: '#000',
    color: '#fff',
  },
  shell: {
    position: 'relative',
    zIndex: 1,
    display: 'flex',
    flexDirection: 'column',
    height: '100vh',
  },
  nav: {
    display: 'flex',
    flexShrink: 0,
    borderBottom: '1px solid rgba(232,0,45,0.2)',
    background: 'rgba(5,0,2,0.82)',
    backdropFilter: 'blur(8px)',
    paddingLeft: 16,
    height: NAV_H,
  },
  navBtn: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 12,
    fontWeight: 700,
    letterSpacing: '0.12em',
    padding: '0 20px',
    background: 'none',
    border: 'none',
    color: '#444',
    cursor: 'pointer',
    borderBottom: '2px solid transparent',
    transition: 'color 0.2s',
  },
  navActive: {
    color: '#E8002D',
    borderBottom: '2px solid #E8002D',
  },
  body: {
    display: 'flex',
    flexDirection: 'row',
    height: BODY_H,
    overflow: 'hidden',
  },
  timingScroll: {
    flex: 1,
    overflowY: 'auto',
    overflowX: 'auto',
    minWidth: 0,
  },
  alertWrap: {
    width: 260,
    flexShrink: 0,
    height: '100%',
    overflow: 'hidden',
    borderLeft: '1px solid rgba(232,0,45,0.12)',
  },
  standingsScroll: {
    flex: 1,
    overflowY: 'auto',
    minWidth: 0,
  },
}
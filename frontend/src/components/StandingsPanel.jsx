import React, { useEffect, useState } from 'react'
import axios from 'axios'

const BACKEND = import.meta.env.VITE_BACKEND_URL 

const TEAM_COLORS = {
  'red_bull':       '#3671C6',
  'ferrari':        '#E8002D',
  'mercedes':       '#27F4D2',
  'mclaren':        '#FF8000',
  'aston_martin':   '#229971',
  'alpine':         '#FF87BC',
  'williams':       '#64C4FF',
  'rb':             '#6692FF',
  'kick_sauber':    '#52E252',
  'haas':           '#B6BABD',
}

function teamColor(teamId) {
  return TEAM_COLORS[teamId] || '#888'
}

export default function StandingsPanel() {
  const [tab, setTab]               = useState('drivers')
  const [drivers, setDrivers]       = useState([])
  const [constructors, setConstructors] = useState([])
  const [lastRace, setLastRace]     = useState(null)
  const [loading, setLoading]       = useState(true)

  useEffect(() => {
    Promise.all([
      axios.get(`${BACKEND}/api/standings/drivers`),
      axios.get(`${BACKEND}/api/standings/constructors`),
      axios.get(`${BACKEND}/api/race/last`),
    ]).then(([d, c, r]) => {
      setDrivers(d.data)
      setConstructors(c.data)
      setLastRace(r.data)
      setLoading(false)
    }).catch(() => setLoading(false))
  }, [])

  if (loading) return (
    <div style={s.loading}>
      <div style={s.spinner} />
      <span style={s.loadingText}>Loading standings…</span>
    </div>
  )

  return (
    <div style={s.wrap}>
      {/* Last race banner */}
      {lastRace?.race_name && (
        <div style={s.lastRaceBanner}>
          <span style={s.lastRaceLabel}>LAST RACE</span>
          <span style={s.lastRaceName}>{lastRace.race_name}</span>
          <span style={s.lastRaceCircuit}>{lastRace.circuit} · {lastRace.country}</span>
          {lastRace.results?.[0] && (
            <span style={s.lastRaceWinner}>
              Winner: <strong>{lastRace.results[0].full_name}</strong> ({lastRace.results[0].team_name})
            </span>
          )}
        </div>
      )}

      {/* Tabs */}
      <div style={s.tabs}>
        {['drivers', 'constructors', 'lastrace'].map(t => (
          <button key={t} onClick={() => setTab(t)} style={{ ...s.tab, ...(tab === t ? s.tabActive : {}) }}>
            {t === 'drivers' ? 'DRIVERS' : t === 'constructors' ? 'CONSTRUCTORS' : 'RACE RESULT'}
          </button>
        ))}
      </div>

      {/* Driver standings */}
      {tab === 'drivers' && (
        <div>
          <div style={s.headerRow}>
            <span style={{...s.hCell, width:40}}>POS</span>
            <span style={{...s.hCell, flex:1}}>DRIVER</span>
            <span style={{...s.hCell, width:120}}>TEAM</span>
            <span style={{...s.hCell, width:60, textAlign:'right'}}>PTS</span>
            <span style={{...s.hCell, width:50, textAlign:'right'}}>WINS</span>
          </div>
          {drivers.map(d => (
            <div key={d.driver_id} style={s.row}>
              <div style={{...s.bar, background: teamColor(d.team_id)}} />
              <span style={{...s.cell, width:36, fontFamily:"'Share Tech Mono',monospace", color: d.position===1?'#FFD700':d.position<=3?'#E8002D':'#fff', fontSize:d.position===1?18:14}}>
                {d.position}
              </span>
              <div style={{...s.cell, flex:1}}>
                <div style={s.driverName}>{d.full_name}</div>
                <div style={s.nat}>{d.nationality}</div>
              </div>
              <span style={{...s.cell, width:120, color:'#888', fontSize:11, fontFamily:"'Barlow Condensed',sans-serif"}}>{d.team_name}</span>
              <span style={{...s.cell, width:60, textAlign:'right', fontFamily:"'Share Tech Mono',monospace", color:'#E8002D', fontSize:15}}>{d.points}</span>
              <span style={{...s.cell, width:50, textAlign:'right', fontFamily:"'Share Tech Mono',monospace", color:'#666', fontSize:13}}>{d.wins}</span>
            </div>
          ))}
        </div>
      )}

      {/* Constructor standings */}
      {tab === 'constructors' && (
        <div>
          <div style={s.headerRow}>
            <span style={{...s.hCell, width:40}}>POS</span>
            <span style={{...s.hCell, flex:1}}>TEAM</span>
            <span style={{...s.hCell, width:60, textAlign:'right'}}>PTS</span>
            <span style={{...s.hCell, width:50, textAlign:'right'}}>WINS</span>
          </div>
          {constructors.map(c => (
            <div key={c.team_id} style={s.row}>
              <div style={{...s.bar, background: teamColor(c.team_id)}} />
              <span style={{...s.cell, width:36, fontFamily:"'Share Tech Mono',monospace", color: c.position===1?'#FFD700':c.position<=3?'#E8002D':'#fff', fontSize:c.position===1?18:14}}>
                {c.position}
              </span>
              <div style={{...s.cell, flex:1}}>
                <div style={s.driverName}>{c.team_name}</div>
                <div style={s.nat}>{c.nationality}</div>
              </div>
              <span style={{...s.cell, width:60, textAlign:'right', fontFamily:"'Share Tech Mono',monospace", color:'#E8002D', fontSize:15}}>{c.points}</span>
              <span style={{...s.cell, width:50, textAlign:'right', fontFamily:"'Share Tech Mono',monospace", color:'#666', fontSize:13}}>{c.wins}</span>
            </div>
          ))}
        </div>
      )}

      {/* Last race result */}
      {tab === 'lastrace' && lastRace?.results && (
        <div>
          <div style={s.headerRow}>
            <span style={{...s.hCell, width:40}}>POS</span>
            <span style={{...s.hCell, flex:1}}>DRIVER</span>
            <span style={{...s.hCell, width:120}}>TEAM</span>
            <span style={{...s.hCell, width:50, textAlign:'right'}}>LAPS</span>
            <span style={{...s.hCell, width:80}}>STATUS</span>
            <span style={{...s.hCell, width:50, textAlign:'right'}}>PTS</span>
          </div>
          {lastRace.results.map(r => (
            <div key={r.driver_id} style={s.row}>
              <div style={{...s.bar, background:'#E8002D', opacity: r.position<=3?1:0.3}} />
              <span style={{...s.cell, width:36, fontFamily:"'Share Tech Mono',monospace", color: r.position===1?'#FFD700':r.position<=3?'#E8002D':'#fff', fontSize:r.position===1?18:14}}>
                {r.position}
              </span>
              <div style={{...s.cell, flex:1}}>
                <div style={s.driverName}>{r.full_name}</div>
                {r.fastest_lap && <div style={{...s.nat, color:'#A855F7'}}>FL: {r.fastest_lap}</div>}
              </div>
              <span style={{...s.cell, width:120, color:'#888', fontSize:11, fontFamily:"'Barlow Condensed',sans-serif"}}>{r.team_name}</span>
              <span style={{...s.cell, width:50, textAlign:'right', fontFamily:"'Share Tech Mono',monospace", color:'#666', fontSize:12}}>{r.laps}</span>
              <span style={{...s.cell, width:80, fontSize:11, fontFamily:"'Barlow Condensed',sans-serif", color: r.status==='Finished'?'#00C853':'#E8002D'}}>{r.status}</span>
              <span style={{...s.cell, width:50, textAlign:'right', fontFamily:"'Share Tech Mono',monospace", color:'#E8002D', fontSize:13}}>{r.points}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

const s = {
  wrap:    { width:'100%' },
  loading: { display:'flex', alignItems:'center', gap:12, padding:'40px 24px' },
  spinner: { width:24, height:24, border:'2px solid #222', borderTop:'2px solid #E8002D', borderRadius:'50%', animation:'spin 0.8s linear infinite' },
  loadingText: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:14, color:'#555', letterSpacing:'0.1em' },
  lastRaceBanner: { display:'flex', flexWrap:'wrap', alignItems:'center', gap:12, padding:'10px 16px', background:'rgba(8,0,3,0.85)', borderBottom:'1px solid #1A1A1A' },
  lastRaceLabel: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:700, color:'#E8002D', letterSpacing:'0.15em' },
  lastRaceName:  { fontFamily:"'Barlow Condensed',sans-serif", fontSize:15, fontWeight:700, color:'#fff' },
  lastRaceCircuit: { fontFamily:"'Barlow',sans-serif", fontSize:11, color:'#666' },
  lastRaceWinner:  { fontFamily:"'Barlow',sans-serif", fontSize:12, color:'#aaa', marginLeft:'auto' },
  tabs:    { display:'flex', borderBottom:'1px solid #1A1A1A' },
  tab:     { fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, fontWeight:700, letterSpacing:'0.12em', padding:'10px 20px', background:'none', border:'none', color:'#444', cursor:'pointer', borderBottom:'2px solid transparent' },
  tabActive: { color:'#E8002D', borderBottom:'2px solid #E8002D' },
  headerRow: { display:'flex', alignItems:'center', padding:'6px 0', background:'rgba(8,0,3,0.85)', borderBottom:'1px solid #E8002D' },
  hCell:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:700, color:'#E8002D', letterSpacing:'0.12em', flexShrink:0, paddingLeft:4 },
  row:     { display:'flex', alignItems:'center', background:'rgba(10,0,4,0.72)', borderBottom:'1px solid #1A1A1A', minHeight:44 },
  bar:     { width:3, alignSelf:'stretch', flexShrink:0 },
  cell:    { paddingLeft:8, flexShrink:0, display:'flex', alignItems:'center' },
  driverName: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:14, fontWeight:700, color:'#fff', lineHeight:1 },
  nat:     { fontFamily:"'Barlow',sans-serif", fontSize:10, color:'#666', lineHeight:1, marginTop:2 },
}

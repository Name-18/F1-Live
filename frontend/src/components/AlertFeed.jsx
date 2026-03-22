import React from 'react'
import { useRaceStore } from '../store/raceStore'

const TYPE_CONFIG = {
  safety_car:  { label: 'SAFETY CAR',         color: '#FFA500', dot: '#FFA500' },
  vsc:         { label: 'VIRTUAL SAFETY CAR',  color: '#FFD700', dot: '#FFD700' },
  red_flag:    { label: 'RED FLAG',            color: '#E8002D', dot: '#E8002D' },
  dnf:         { label: 'DNF',                 color: '#E8002D', dot: '#E8002D' },
  incident:    { label: 'INCIDENT',            color: '#FFA500', dot: '#FFA500' },
  fastest_lap: { label: 'FASTEST LAP',         color: '#A855F7', dot: '#A855F7' },
  chequered:   { label: 'CHEQUERED',           color: '#ffffff', dot: '#ffffff' },
}

function timeAgo(isoStr) {
  if (!isoStr) return ''
  const diff = (Date.now() - new Date(isoStr).getTime()) / 1000
  if (diff < 60) return `${Math.floor(diff)}s ago`
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  return new Date(isoStr).toLocaleTimeString()
}

export default function AlertFeed() {
  const alerts = useRaceStore((s) => s.alerts)
  const clearAlerts = useRaceStore((s) => s.clearAlerts)

  return (
    <aside style={styles.panel}>
      <div style={styles.panelHeader}>
        <span style={styles.panelTitle}>LIVE ALERTS</span>
        {alerts.length > 0 && (
          <button onClick={clearAlerts} style={styles.clearBtn}>CLEAR</button>
        )}
      </div>

      <div style={styles.feed}>
        {alerts.length === 0 && (
          <div style={styles.noAlerts}>
            <div style={styles.noAlertsText}>No events yet</div>
            <div style={styles.noAlertsHint}>Incidents, flags, DNFs and fastest laps will appear here</div>
          </div>
        )}

        {alerts.map((alert) => {
          const cfg = TYPE_CONFIG[alert.type] || { label: alert.type?.toUpperCase(), color: '#888', dot: '#888' }
          return (
            <div key={alert.id} style={styles.alertItem}>
              <div style={{ ...styles.alertDot, background: cfg.dot }} />
              <div style={styles.alertContent}>
                <div style={{ ...styles.alertType, color: cfg.color }}>{cfg.label}</div>
                {alert.driver_name && (
                  <div style={styles.alertDriver}>{alert.driver_name}</div>
                )}
                {alert.team && (
                  <div style={styles.alertTeam}>{alert.team}</div>
                )}
                {alert.message && (
                  <div style={styles.alertMessage}>{alert.message}</div>
                )}
                <div style={styles.alertTime}>{timeAgo(alert.time)}</div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Race control legend */}
      <div style={styles.legend}>
        <div style={styles.legendTitle}>FLAG LEGEND</div>
        {[
          { color: '#00C853', label: 'Green — Racing' },
          { color: '#FFD700', label: 'Yellow — Caution' },
          { color: '#FFA500', label: 'Orange — Safety Car' },
          { color: '#E8002D', label: 'Red — Stopped' },
          { color: '#A855F7', label: 'Purple — Fastest Lap' },
          { color: '#ffffff', label: 'Chequered — Race Over' },
        ].map(({ color, label }) => (
          <div key={label} style={styles.legendItem}>
            <div style={{ ...styles.legendDot, background: color }} />
            <span style={styles.legendLabel}>{label}</span>
          </div>
        ))}
      </div>
    </aside>
  )
}

const styles = {
  panel: {
    width: 260,
    flexShrink: 0,
    background: '#0A0A0A',
    borderLeft: '1px solid #1A1A1A',
    display: 'flex',
    flexDirection: 'column',
    height: 'calc(100vh - 64px)',
    position: 'sticky',
    top: 64,
    overflow: 'hidden',
  },
  panelHeader: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '12px 16px',
    borderBottom: '1px solid #1A1A1A',
    flexShrink: 0,
  },
  panelTitle: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 11,
    fontWeight: 700,
    color: '#E8002D',
    letterSpacing: '0.15em',
  },
  clearBtn: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 10,
    fontWeight: 700,
    color: '#444',
    background: 'none',
    border: '1px solid #222',
    borderRadius: 2,
    padding: '2px 8px',
    cursor: 'pointer',
    letterSpacing: '0.1em',
  },
  feed: {
    flex: 1,
    overflowY: 'auto',
    padding: '8px 0',
  },
  noAlerts: {
    padding: '32px 16px',
    textAlign: 'center',
  },
  noAlertsText: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 14,
    color: '#333',
    letterSpacing: '0.1em',
  },
  noAlertsHint: {
    fontFamily: "'Barlow', sans-serif",
    fontSize: 11,
    color: '#222',
    marginTop: 6,
    lineHeight: 1.4,
  },
  alertItem: {
    display: 'flex',
    gap: 10,
    padding: '10px 16px',
    borderBottom: '1px solid #111',
    alignItems: 'flex-start',
  },
  alertDot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
    flexShrink: 0,
    marginTop: 4,
  },
  alertContent: {
    flex: 1,
    minWidth: 0,
  },
  alertType: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 12,
    fontWeight: 700,
    letterSpacing: '0.1em',
    lineHeight: 1,
  },
  alertDriver: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 14,
    fontWeight: 700,
    color: '#fff',
    marginTop: 3,
    lineHeight: 1,
  },
  alertTeam: {
    fontFamily: "'Barlow', sans-serif",
    fontSize: 11,
    color: '#555',
    marginTop: 1,
  },
  alertMessage: {
    fontFamily: "'Barlow', sans-serif",
    fontSize: 11,
    color: '#666',
    marginTop: 4,
    lineHeight: 1.3,
  },
  alertTime: {
    fontFamily: "'Share Tech Mono', monospace",
    fontSize: 10,
    color: '#333',
    marginTop: 4,
  },
  legend: {
    borderTop: '1px solid #1A1A1A',
    padding: '12px 16px',
    flexShrink: 0,
  },
  legendTitle: {
    fontFamily: "'Barlow Condensed', sans-serif",
    fontSize: 10,
    fontWeight: 700,
    color: '#333',
    letterSpacing: '0.15em',
    marginBottom: 8,
  },
  legendItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    marginBottom: 5,
  },
  legendDot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
    flexShrink: 0,
  },
  legendLabel: {
    fontFamily: "'Barlow', sans-serif",
    fontSize: 11,
    color: '#555',
  },
}
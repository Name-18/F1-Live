import { useEffect, useRef } from 'react'
import { io } from 'socket.io-client'
import toast from 'react-hot-toast'
import { useRaceStore } from '../store/raceStore'

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:5000'

const ALERT_CONFIG = {
  safety_car:  { emoji: '🟡', label: 'SAFETY CAR',         bg: '#FFA500', color: '#000' },
  vsc:         { emoji: '🟡', label: 'VIRTUAL SAFETY CAR', bg: '#FFD700', color: '#000' },
  red_flag:    { emoji: '🔴', label: 'RED FLAG',            bg: '#E8002D', color: '#fff' },
  dnf:         { emoji: '💥', label: 'DNF / RETIREMENT',    bg: '#1A1A1A', color: '#E8002D' },
  incident:    { emoji: '⚠️', label: 'INCIDENT',            bg: '#222',    color: '#FFA500' },
  fastest_lap: { emoji: '⚡', label: 'FASTEST LAP',         bg: '#7B00FF', color: '#fff' },
  chequered:   { emoji: '🏁', label: 'CHEQUERED FLAG',      bg: '#fff',    color: '#000' },
}

export function useSocket() {
  const socketRef = useRef(null)
  const { setRaceUpdate, setConnected, pushAlert } = useRaceStore()

  useEffect(() => {
    const socket = io(BACKEND_URL, { transports: ['websocket', 'polling'] })
    socketRef.current = socket

    socket.on('connect', () => { setConnected(true); console.log('[WS] Connected') })
    socket.on('disconnect', () => { setConnected(false); console.log('[WS] Disconnected') })
    socket.on('race_update', (data) => { setRaceUpdate(data) })

    const eventTypes = ['safety_car', 'vsc', 'red_flag', 'dnf', 'incident', 'fastest_lap', 'chequered']
    eventTypes.forEach((type) => {
      socket.on(type, (data) => {
        const cfg = ALERT_CONFIG[type] || {}
        pushAlert({ ...data, type, label: cfg.label })
        const driverInfo = data.driver_name ? ` — ${data.driver_name}` : ''
        const msg = data.message || `${cfg.label}${driverInfo}`
        toast(msg, {
          duration: type === 'chequered' ? 8000 : 5000,
          style: {
            background: cfg.bg || '#1A1A1A', color: cfg.color || '#fff',
            fontFamily: "'Barlow Condensed', sans-serif", fontWeight: 700,
            fontSize: '15px', letterSpacing: '0.05em',
            border: `1px solid ${cfg.bg || '#333'}`, borderRadius: '4px', padding: '10px 16px',
          },
          icon: cfg.emoji,
        })
      })
    })

    return () => socket.disconnect()
  }, [])

  return socketRef
}
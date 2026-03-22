import { create } from 'zustand'

export const useRaceStore = create((set) => ({
  connected:     false,
  setConnected:  (v) => set({ connected: v }),

  session:        null,
  sessionStatus:  'unknown',
  currentLap:     0,
  weather:        {},
  drivers:        [],
  isLive:         false,
  dataSource:     'jolpica',  // 'openf1' | 'jolpica'
  alerts:         [],

  setRaceUpdate: (data) => set({
    session:       data.session,
    sessionStatus: data.session_status,
    currentLap:    data.current_lap,
    weather:       data.weather || {},
    drivers:       data.drivers || [],
    isLive:        data.is_live || false,
    dataSource:    data.data_source || 'jolpica',
  }),

  pushAlert:   (alert) => set((state) => ({
    alerts: [{ ...alert, id: Date.now() + Math.random() }, ...state.alerts].slice(0, 50),
  })),
  clearAlerts: () => set({ alerts: [] }),
}))
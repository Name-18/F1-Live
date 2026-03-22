# F1 Live Tracker - Full Project Setup Script
# Run this from D:\My_Space\Project_F1 Live Score
# Usage: Right-click PowerShell -> Run as Administrator, then:
#   cd "D:\My_Space\Project_F1 Live Score"
#   .\setup.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "   F1 LIVE TRACKER - Project Setup" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }

# ─────────────────────────────────────────
# CREATE FOLDER STRUCTURE
# ─────────────────────────────────────────
Write-Host "[1/5] Creating folder structure..." -ForegroundColor Yellow

$folders = @(
    "backend",
    "backend\services",
    "backend\routes",
    "frontend",
    "frontend\src",
    "frontend\src\components",
    "frontend\src\hooks",
    "frontend\src\store",
    "frontend\src\styles",
    ".vscode"
)

foreach ($f in $folders) {
    $path = Join-Path $root $f
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "  Created: $f" -ForegroundColor Green
    } else {
        Write-Host "  Exists:  $f" -ForegroundColor Gray
    }
}

# ─────────────────────────────────────────
# HELPER FUNCTION
# ─────────────────────────────────────────
function Write-File($relativePath, $content) {
    $fullPath = Join-Path $root $relativePath
    # Ensure parent directory exists
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $fullPath -Value $content -Encoding UTF8 -NoNewline
    Write-Host "  Written: $relativePath" -ForegroundColor Green
}

# ─────────────────────────────────────────
# BACKEND FILES
# ─────────────────────────────────────────
Write-Host ""
Write-Host "[2/5] Writing backend files..." -ForegroundColor Yellow

Write-File "backend\requirements.txt" @'
flask==3.0.3
flask-socketio==5.3.6
flask-cors==4.0.1
requests==2.32.3
python-engineio==4.9.1
python-socketio==5.11.3
'@

Write-File "backend\app.py" @'
from flask import Flask
from flask_socketio import SocketIO
from flask_cors import CORS
from config import Config
from routes.race_routes import race_bp
from routes.driver_routes import driver_bp
from routes.socket_events import register_socket_events
from services.poller import start_poller

socketio = SocketIO()

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app, resources={r"/api/*": {"origins": Config.CORS_ORIGINS}})
    socketio.init_app(
        app,
        cors_allowed_origins=Config.CORS_ORIGINS,
        async_mode="threading"
    )

    app.register_blueprint(race_bp, url_prefix="/api")
    app.register_blueprint(driver_bp, url_prefix="/api")

    register_socket_events(socketio)

    return app

app = create_app()

if __name__ == "__main__":
    start_poller(socketio)
    socketio.run(app, host="0.0.0.0", port=5000, debug=False, use_reloader=False)
'@

Write-File "backend\config.py" @'
import os

class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "f1-live-tracker-secret")
    OPENF1_BASE_URL = "https://api.openf1.org/v1"
    POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 3))
    CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "*").split(",")
    DEBUG = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
'@

Write-File "backend\Procfile" @'
web: gunicorn --worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker --workers 1 --bind 0.0.0.0:$PORT app:app
'@

Write-File "backend\.env.example" @'
SECRET_KEY=your-secret-key-here
CORS_ORIGINS=http://localhost:5173,https://your-netlify-app.netlify.app
POLL_INTERVAL=3
FLASK_DEBUG=false
'@

Write-File "backend\requirements.render.txt" @'
flask==3.0.3
flask-socketio==5.3.6
flask-cors==4.0.1
requests==2.32.3
python-engineio==4.9.1
python-socketio==5.11.3
gevent==24.2.1
gevent-websocket==0.10.1
gunicorn==22.0.0
'@

# ── services ──
Write-File "backend\services\__init__.py" ""

Write-File "backend\services\openf1_client.py" @'
import requests
from config import Config

BASE = Config.OPENF1_BASE_URL

def _get(endpoint, params=None):
    try:
        r = requests.get(f"{BASE}{endpoint}", params=params, timeout=8)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"[OpenF1] Error fetching {endpoint}: {e}")
        return []

def get_latest_session():
    sessions = _get("/sessions", {"session_type": "Race"})
    if sessions:
        return max(sessions, key=lambda s: s.get("date_start", ""))
    return None

def get_drivers(session_key):
    return _get("/drivers", {"session_key": session_key})

def get_positions(session_key):
    return _get("/position", {"session_key": session_key})

def get_laps(session_key):
    return _get("/laps", {"session_key": session_key})

def get_race_control(session_key):
    return _get("/race_control", {"session_key": session_key})

def get_pit_stops(session_key):
    return _get("/pit", {"session_key": session_key})

def get_stints(session_key):
    return _get("/stints", {"session_key": session_key})

def get_car_data(session_key, driver_number):
    data = _get("/car_data", {"session_key": session_key, "driver_number": driver_number})
    return data[-1] if data else {}

def get_weather(session_key):
    data = _get("/weather", {"session_key": session_key})
    return data[-1] if data else {}

def get_intervals(session_key):
    return _get("/intervals", {"session_key": session_key})
'@

Write-File "backend\services\race_state.py" @'
import threading

_lock = threading.Lock()

_state = {
    "session": None,
    "drivers": {},
    "positions": {},
    "laps": {},
    "stints": {},
    "pit_stops": {},
    "intervals": {},
    "race_control": [],
    "weather": {},
    "session_status": "unknown",
    "retired_drivers": set(),
    "total_laps": 0,
    "current_lap": 0,
}

def get_state():
    with _lock:
        return dict(_state)

def update(key, value):
    with _lock:
        _state[key] = value

def update_driver(driver_number, data):
    with _lock:
        _state["drivers"][str(driver_number)] = data

def update_position(driver_number, data):
    with _lock:
        _state["positions"][str(driver_number)] = data

def update_lap(driver_number, data):
    with _lock:
        _state["laps"][str(driver_number)] = data

def update_stint(driver_number, data):
    with _lock:
        _state["stints"][str(driver_number)] = data

def update_pit(driver_number, data):
    with _lock:
        if str(driver_number) not in _state["pit_stops"]:
            _state["pit_stops"][str(driver_number)] = []
        _state["pit_stops"][str(driver_number)] = data

def update_interval(driver_number, data):
    with _lock:
        _state["intervals"][str(driver_number)] = data

def add_race_control(msg):
    with _lock:
        _state["race_control"].append(msg)

def add_retired(driver_number):
    with _lock:
        _state["retired_drivers"].add(str(driver_number))

def get_retired():
    with _lock:
        return set(_state["retired_drivers"])
'@

Write-File "backend\services\event_detector.py" @'
from services import race_state

_seen_rc_messages = set()
_seen_dnf_drivers = set()

TYRE_COMPOUND_COLORS = {
    "SOFT": "#E8002D",
    "MEDIUM": "#FFF200",
    "HARD": "#FFFFFF",
    "INTERMEDIATE": "#39B54A",
    "WET": "#0067FF",
}

def detect_events(new_rc_messages, positions_list, drivers_map):
    events = []

    for msg in new_rc_messages:
        msg_id = msg.get("date", "") + msg.get("message", "")
        if msg_id in _seen_rc_messages:
            continue
        _seen_rc_messages.add(msg_id)
        race_state.add_race_control(msg)

        text = msg.get("message", "").upper()
        flag = msg.get("flag", "").upper()

        if "SAFETY CAR DEPLOYED" in text or (flag == "SC" and "DEPLOYED" in text):
            events.append({"type": "safety_car", "status": "deployed", "message": msg.get("message"), "time": msg.get("date")})
            race_state.update("session_status", "sc")

        elif "SAFETY CAR IN THIS LAP" in text or "SAFETY CAR RETURNING" in text:
            events.append({"type": "safety_car", "status": "ending", "message": msg.get("message"), "time": msg.get("date")})

        elif "VIRTUAL SAFETY CAR DEPLOYED" in text:
            events.append({"type": "vsc", "status": "deployed", "message": msg.get("message"), "time": msg.get("date")})
            race_state.update("session_status", "vsc")

        elif "VIRTUAL SAFETY CAR ENDING" in text:
            events.append({"type": "vsc", "status": "ending", "message": msg.get("message"), "time": msg.get("date")})

        elif "RED FLAG" in text or flag == "RED":
            events.append({"type": "red_flag", "message": msg.get("message"), "time": msg.get("date")})
            race_state.update("session_status", "red")

        elif "GREEN FLAG" in text or flag == "GREEN":
            race_state.update("session_status", "green")

        elif "CHEQUERED FLAG" in text or flag == "CHEQUERED":
            events.append({"type": "chequered", "message": msg.get("message"), "time": msg.get("date")})
            race_state.update("session_status", "chequered")

        elif "INCIDENT" in text or "INVESTIGATION" in text:
            events.append({"type": "incident", "message": msg.get("message"), "time": msg.get("date")})

        elif "FASTEST LAP" in text:
            driver_number = msg.get("driver_number")
            driver = drivers_map.get(str(driver_number), {})
            events.append({
                "type": "fastest_lap",
                "driver_number": driver_number,
                "driver_name": driver.get("full_name", f"Car {driver_number}"),
                "team": driver.get("team_name", ""),
                "message": msg.get("message"),
                "time": msg.get("date"),
            })

    for pos in positions_list:
        dn = str(pos.get("driver_number", ""))
        status = str(pos.get("position", "")).upper()
        if status in ("DNF", "RETIRED", "OUT") and dn not in _seen_dnf_drivers:
            _seen_dnf_drivers.add(dn)
            race_state.add_retired(dn)
            driver = drivers_map.get(dn, {})
            events.append({
                "type": "dnf",
                "driver_number": dn,
                "driver_name": driver.get("full_name", f"Car {dn}"),
                "team": driver.get("team_name", ""),
                "time": pos.get("date"),
            })

    return events
'@

Write-File "backend\services\broadcaster.py" @'
from services import race_state

def _build_driver_list(state):
    drivers = state.get("drivers", {})
    positions = state.get("positions", {})
    laps = state.get("laps", {})
    stints = state.get("stints", {})
    pits = state.get("pit_stops", {})
    intervals = state.get("intervals", {})
    retired = state.get("retired_drivers", set())

    driver_list = []
    for dn, driver in drivers.items():
        pos = positions.get(dn, {})
        lap = laps.get(dn, {})
        stint = stints.get(dn, {})
        pit_list = pits.get(dn, [])
        interval = intervals.get(dn, {})

        driver_list.append({
            "driver_number": dn,
            "full_name": driver.get("full_name", ""),
            "name_acronym": driver.get("name_acronym", ""),
            "team_name": driver.get("team_name", ""),
            "team_colour": driver.get("team_colour", "FFFFFF"),
            "headshot_url": driver.get("headshot_url", ""),
            "country_code": driver.get("country_code", ""),
            "position": pos.get("position", 99),
            "last_lap_duration": lap.get("lap_duration"),
            "lap_number": lap.get("lap_number", 0),
            "is_pit_out_lap": lap.get("is_pit_out_lap", False),
            "tyre_compound": stint.get("compound", "UNKNOWN"),
            "tyre_age": stint.get("tyre_age_at_start", 0),
            "pit_count": len(pit_list),
            "gap_to_leader": interval.get("gap_to_leader"),
            "interval": interval.get("interval"),
            "is_retired": dn in retired,
        })

    driver_list.sort(key=lambda d: int(d["position"]) if str(d["position"]).isdigit() else 99)
    return driver_list


def broadcast_state(socketio):
    state = race_state.get_state()
    session = state.get("session") or {}
    driver_list = _build_driver_list(state)

    payload = {
        "session": {
            "name": session.get("session_name", ""),
            "circuit": session.get("circuit_short_name", ""),
            "country": session.get("country_name", ""),
            "date": session.get("date_start", ""),
            "gp_name": session.get("meeting_name", ""),
        },
        "session_status": state.get("session_status", "unknown"),
        "current_lap": state.get("current_lap", 0),
        "weather": state.get("weather", {}),
        "drivers": driver_list,
    }
    socketio.emit("race_update", payload)


def broadcast_events(socketio, events):
    for event in events:
        socketio.emit(event["type"], event)
'@

Write-File "backend\services\poller.py" @'
import threading
import time
from config import Config
from services import openf1_client as api, race_state
from services.event_detector import detect_events

_poller_thread = None

def _build_snapshot(session_key, drivers_map):
    positions = api.get_positions(session_key)
    laps = api.get_laps(session_key)
    stints = api.get_stints(session_key)
    pits = api.get_pit_stops(session_key)
    intervals = api.get_intervals(session_key)
    rc = api.get_race_control(session_key)
    weather = api.get_weather(session_key)

    pos_by_driver = {}
    for p in positions:
        dn = str(p.get("driver_number"))
        existing = pos_by_driver.get(dn)
        if not existing or p.get("date", "") > existing.get("date", ""):
            pos_by_driver[dn] = p
    for dn, p in pos_by_driver.items():
        race_state.update_position(dn, p)

    lap_by_driver = {}
    max_lap = 0
    for lap in laps:
        dn = str(lap.get("driver_number"))
        ln = lap.get("lap_number", 0)
        if ln > max_lap:
            max_lap = ln
        existing = lap_by_driver.get(dn)
        if not existing or ln > existing.get("lap_number", 0):
            lap_by_driver[dn] = lap
    for dn, lap in lap_by_driver.items():
        race_state.update_lap(dn, lap)
    race_state.update("current_lap", max_lap)

    stint_by_driver = {}
    for s in stints:
        dn = str(s.get("driver_number"))
        existing = stint_by_driver.get(dn)
        if not existing or s.get("stint_number", 0) > existing.get("stint_number", 0):
            stint_by_driver[dn] = s
    for dn, s in stint_by_driver.items():
        race_state.update_stint(dn, s)

    pit_by_driver = {}
    for p in pits:
        dn = str(p.get("driver_number"))
        if dn not in pit_by_driver:
            pit_by_driver[dn] = []
        pit_by_driver[dn].append(p)
    for dn, ps in pit_by_driver.items():
        race_state.update_pit(dn, ps)

    interval_by_driver = {}
    for iv in intervals:
        dn = str(iv.get("driver_number"))
        existing = interval_by_driver.get(dn)
        if not existing or iv.get("date", "") > existing.get("date", ""):
            interval_by_driver[dn] = iv
    for dn, iv in interval_by_driver.items():
        race_state.update_interval(dn, iv)

    race_state.update("weather", weather)
    return rc, list(pos_by_driver.values())


def _poll_loop(socketio):
    from services.broadcaster import broadcast_events, broadcast_state
    session = api.get_latest_session()
    if not session:
        print("[Poller] No session found.")
        return

    session_key = session.get("session_key")
    race_state.update("session", session)
    print(f"[Poller] Tracking session: {session.get('session_name')} @ {session.get('circuit_short_name')}")

    drivers = api.get_drivers(session_key)
    drivers_map = {str(d["driver_number"]): d for d in drivers}
    for dn, d in drivers_map.items():
        race_state.update_driver(dn, d)

    while True:
        try:
            rc_messages, positions = _build_snapshot(session_key, drivers_map)
            events = detect_events(rc_messages, positions, drivers_map)
            if events:
                broadcast_events(socketio, events)
            broadcast_state(socketio)
        except Exception as e:
            print(f"[Poller] Error: {e}")
        time.sleep(Config.POLL_INTERVAL)


def start_poller(socketio):
    global _poller_thread
    if _poller_thread and _poller_thread.is_alive():
        return
    _poller_thread = threading.Thread(target=_poll_loop, args=(socketio,), daemon=True)
    _poller_thread.start()
    print("[Poller] Started.")
'@

# ── routes ──
Write-File "backend\routes\__init__.py" ""

Write-File "backend\routes\race_routes.py" @'
from flask import Blueprint, jsonify
from services import race_state
from services import openf1_client as api

race_bp = Blueprint("race", __name__)

@race_bp.get("/health")
def health():
    return jsonify({"status": "ok"})

@race_bp.get("/race/current")
def current_race():
    state = race_state.get_state()
    session = state.get("session") or {}
    return jsonify({
        "session": session,
        "session_status": state.get("session_status"),
        "current_lap": state.get("current_lap"),
        "weather": state.get("weather"),
        "race_control": state.get("race_control", [])[-20:],
    })

@race_bp.get("/schedule")
def schedule():
    sessions = api._get("/sessions", {"year": 2025})
    return jsonify(sessions)
'@

Write-File "backend\routes\driver_routes.py" @'
from flask import Blueprint, jsonify
from services import race_state

driver_bp = Blueprint("driver", __name__)

@driver_bp.get("/drivers")
def get_drivers():
    state = race_state.get_state()
    return jsonify(list(state.get("drivers", {}).values()))

@driver_bp.get("/drivers/<driver_number>")
def get_driver(driver_number):
    state = race_state.get_state()
    driver = state.get("drivers", {}).get(str(driver_number))
    if not driver:
        return jsonify({"error": "Not found"}), 404
    return jsonify({
        **driver,
        "position": state.get("positions", {}).get(str(driver_number), {}),
        "last_lap": state.get("laps", {}).get(str(driver_number), {}),
        "stint": state.get("stints", {}).get(str(driver_number), {}),
        "pit_stops": state.get("pit_stops", {}).get(str(driver_number), []),
        "interval": state.get("intervals", {}).get(str(driver_number), {}),
    })
'@

Write-File "backend\routes\socket_events.py" @'
from flask_socketio import emit
from services.broadcaster import broadcast_state, _build_driver_list
from services import race_state

def register_socket_events(socketio):

    @socketio.on("connect")
    def on_connect():
        print("[WS] Client connected")
        state = race_state.get_state()
        session = state.get("session") or {}
        driver_list = _build_driver_list(state)
        emit("race_update", {
            "session": {
                "name": session.get("session_name", ""),
                "circuit": session.get("circuit_short_name", ""),
                "country": session.get("country_name", ""),
                "date": session.get("date_start", ""),
                "gp_name": session.get("meeting_name", ""),
            },
            "session_status": state.get("session_status", "unknown"),
            "current_lap": state.get("current_lap", 0),
            "weather": state.get("weather", {}),
            "drivers": driver_list,
        })

    @socketio.on("disconnect")
    def on_disconnect():
        print("[WS] Client disconnected")
'@

# ─────────────────────────────────────────
# FRONTEND FILES
# ─────────────────────────────────────────
Write-Host ""
Write-Host "[3/5] Writing frontend files..." -ForegroundColor Yellow

Write-File "frontend\index.html" @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>F1 Live Tracker</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@400;600;700;800&family=Barlow:wght@400;500;600&family=Share+Tech+Mono&display=swap" rel="stylesheet" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@

Write-File "frontend\package.json" @'
{
  "name": "f1-live-tracker-frontend",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "socket.io-client": "^4.7.5",
    "zustand": "^4.5.4",
    "axios": "^1.7.2",
    "react-hot-toast": "^2.4.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "vite": "^5.3.4"
  }
}
'@

Write-File "frontend\vite.config.js" @'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:5000',
      '/socket.io': { target: 'http://localhost:5000', ws: true }
    }
  }
})
'@

Write-File "frontend\.env.example" @'
VITE_BACKEND_URL=http://localhost:5000
'@

Write-File "frontend\src\main.jsx" @'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './styles/global.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
'@

Write-File "frontend\src\App.jsx" @'
import React from 'react'
import { Toaster } from 'react-hot-toast'
import { useSocket } from './hooks/useSocket'
import RaceHeader from './components/RaceHeader'
import LiveTimingTable from './components/LiveTimingTable'
import AlertFeed from './components/AlertFeed'

export default function App() {
  useSocket()

  return (
    <div style={styles.root}>
      <style>{`
        @keyframes spin { to { transform: rotate(360deg); } }
        .driver-row:hover { background: #141414 !important; }
        @media (max-width: 768px) {
          .main-layout { flex-direction: column !important; }
          .alert-panel { width: 100% !important; height: auto !important; position: static !important; border-left: none !important; border-top: 1px solid #1A1A1A !important; }
          .team-col { display: none !important; }
          .interval-col { display: none !important; }
        }
      `}</style>

      <Toaster
        position="top-center"
        containerStyle={{ top: 72 }}
        toastOptions={{ duration: 5000 }}
      />

      <RaceHeader />

      <div style={styles.layout} className="main-layout">
        <main style={styles.main}>
          <LiveTimingTable />
        </main>
        <div className="alert-panel">
          <AlertFeed />
        </div>
      </div>
    </div>
  )
}

const styles = {
  root: { minHeight: '100vh', background: '#000', color: '#fff' },
  layout: { display: 'flex', alignItems: 'flex-start', minHeight: 'calc(100vh - 64px)' },
  main: { flex: 1, minWidth: 0, overflowX: 'auto' },
}
'@

Write-File "frontend\src\styles\global.css" @'
@import url('https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@400;600;700;800&family=Barlow:wght@400;500;600&family=Share+Tech+Mono&display=swap');

:root {
  --red: #E8002D;
  --red-bright: #FF0033;
  --red-dim: #9B001E;
  --red-glow: rgba(232, 0, 45, 0.25);
  --black: #000000;
  --font-display: 'Barlow Condensed', sans-serif;
  --font-body: 'Barlow', sans-serif;
  --font-mono: 'Share Tech Mono', monospace;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  background: var(--black);
  color: #fff;
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 1.5;
  overflow-x: hidden;
  -webkit-font-smoothing: antialiased;
}
::-webkit-scrollbar { width: 4px; height: 4px; }
::-webkit-scrollbar-track { background: #111; }
::-webkit-scrollbar-thumb { background: var(--red-dim); border-radius: 2px; }
::-webkit-scrollbar-thumb:hover { background: var(--red); }
::selection { background: var(--red); color: #fff; }
'@

Write-File "frontend\src\store\raceStore.js" @'
import { create } from 'zustand'

export const useRaceStore = create((set) => ({
  connected: false,
  setConnected: (v) => set({ connected: v }),
  session: null,
  sessionStatus: 'unknown',
  currentLap: 0,
  weather: {},
  drivers: [],
  alerts: [],
  setRaceUpdate: (data) => set({
    session: data.session,
    sessionStatus: data.session_status,
    currentLap: data.current_lap,
    weather: data.weather || {},
    drivers: data.drivers || [],
  }),
  pushAlert: (alert) => set((state) => ({
    alerts: [{ ...alert, id: Date.now() + Math.random() }, ...state.alerts].slice(0, 50),
  })),
  clearAlerts: () => set({ alerts: [] }),
}))
'@

Write-File "frontend\src\hooks\useSocket.js" @'
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
'@

Write-File "frontend\src\components\RaceHeader.jsx" @'
import React from 'react'
import { useRaceStore } from '../store/raceStore'

const STATUS_CONFIG = {
  green:     { label: 'RACING',        bg: '#00C853', color: '#000' },
  yellow:    { label: 'YELLOW FLAG',   bg: '#FFD700', color: '#000' },
  sc:        { label: 'SAFETY CAR',    bg: '#FFA500', color: '#000' },
  vsc:       { label: 'VIRTUAL SC',    bg: '#FFD700', color: '#000' },
  red:       { label: 'RED FLAG',      bg: '#E8002D', color: '#fff' },
  chequered: { label: 'RACE OVER',     bg: '#ffffff', color: '#000' },
  unknown:   { label: 'AWAITING DATA', bg: '#333',    color: '#aaa' },
}

export default function RaceHeader() {
  const { session, sessionStatus, currentLap, weather, connected } = useRaceStore()
  const cfg = STATUS_CONFIG[sessionStatus] || STATUS_CONFIG.unknown

  const airTemp   = weather?.air_temperature   != null ? `${Math.round(weather.air_temperature)}°`   : '--'
  const trackTemp = weather?.track_temperature != null ? `${Math.round(weather.track_temperature)}°` : '--'
  const windSpeed = weather?.wind_speed        != null ? `${Math.round(weather.wind_speed)} m/s`     : '--'

  return (
    <header style={s.header}>
      <div style={s.brand}>
        <span style={s.logoF}>F1</span>
        <span style={s.logoLive}>LIVE</span>
        <div style={s.connDot(connected)} title={connected ? 'Connected' : 'Disconnected'} />
      </div>

      <div style={s.center}>
        <div style={s.gpName}>{session?.gp_name || 'F1 LIVE TRACKER'}</div>
        <div style={s.subInfo}>
          {session?.circuit && <span style={s.circuit}>{session.circuit}</span>}
          {session?.country && <span style={s.country}>{session.country}</span>}
        </div>
      </div>

      <div style={s.right}>
        <div style={{ ...s.badge, background: cfg.bg, color: cfg.color }}>{cfg.label}</div>
        {currentLap > 0 && (
          <div style={s.lap}>
            <span style={s.lapLabel}>LAP</span>
            <span style={s.lapNum}>{currentLap}</span>
          </div>
        )}
        <div style={s.weather}>
          <span style={s.wval}>Air {airTemp}</span>
          <span style={s.wval}>Track {trackTemp}</span>
          <span style={s.wval}>Wind {windSpeed}</span>
        </div>
      </div>
    </header>
  )
}

const s = {
  header: { display:'flex', alignItems:'center', justifyContent:'space-between', padding:'0 24px', height:64, background:'#0A0A0A', borderBottom:'2px solid #E8002D', position:'sticky', top:0, zIndex:100, gap:16 },
  brand:  { display:'flex', alignItems:'baseline', gap:6, flexShrink:0 },
  logoF:  { fontFamily:"'Barlow Condensed',sans-serif", fontSize:28, fontWeight:800, color:'#E8002D', letterSpacing:'-0.02em' },
  logoLive: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:13, fontWeight:700, color:'#888', letterSpacing:'0.15em' },
  connDot: (c) => ({ width:8, height:8, borderRadius:'50%', background: c ? '#00C853' : '#E8002D', boxShadow: c ? '0 0 6px #00C853' : '0 0 6px #E8002D', marginLeft:8, alignSelf:'center' }),
  center: { flex:1, textAlign:'center', minWidth:0 },
  gpName: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:22, fontWeight:800, letterSpacing:'0.08em', color:'#fff', textTransform:'uppercase', lineHeight:1, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis' },
  subInfo: { display:'flex', justifyContent:'center', gap:12, marginTop:2 },
  circuit: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, fontWeight:600, color:'#E8002D', letterSpacing:'0.1em', textTransform:'uppercase' },
  country: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, color:'#666' },
  right:  { display:'flex', alignItems:'center', gap:12, flexShrink:0 },
  badge:  { fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, fontWeight:800, letterSpacing:'0.12em', padding:'4px 10px', borderRadius:3, textTransform:'uppercase' },
  lap:    { display:'flex', flexDirection:'column', alignItems:'center', lineHeight:1 },
  lapLabel: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:600, color:'#666', letterSpacing:'0.15em' },
  lapNum: { fontFamily:"'Share Tech Mono',monospace", fontSize:22, color:'#E8002D' },
  weather: { display:'flex', alignItems:'center', gap:8, borderLeft:'1px solid #222', paddingLeft:12 },
  wval:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, color:'#888', whiteSpace:'nowrap' },
}
'@

Write-File "frontend\src\components\DriverCard.jsx" @'
import React, { useState } from 'react'

const TYRE = {
  SOFT:         { bg:'#E8002D', color:'#fff', s:'S' },
  MEDIUM:       { bg:'#FFD700', color:'#000', s:'M' },
  HARD:         { bg:'#FFFFFF', color:'#000', s:'H' },
  INTERMEDIATE: { bg:'#39B54A', color:'#fff', s:'I' },
  WET:          { bg:'#0067FF', color:'#fff', s:'W' },
  UNKNOWN:      { bg:'#333',    color:'#888', s:'?' },
}

function TyreBadge({ compound }) {
  const c = TYRE[compound] || TYRE.UNKNOWN
  return (
    <div style={{ width:22, height:22, borderRadius:'50%', background:c.bg, color:c.color, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:"'Barlow Condensed',sans-serif", fontSize:11, fontWeight:800, flexShrink:0, border: compound==='HARD' ? '1px solid #444' : 'none' }}>
      {c.s}
    </div>
  )
}

function fmtLap(d) {
  if (!d) return '--:--.---'
  const m = Math.floor(d / 60)
  const sec = (d % 60).toFixed(3).padStart(6,'0')
  return m > 0 ? `${m}:${sec}` : sec
}

function fmtGap(g) {
  if (g == null) return '--'
  if (typeof g === 'string') return g
  return `+${g.toFixed(3)}`
}

export default function DriverCard({ driver, rank, isLeader }) {
  const [open, setOpen] = useState(false)
  const tc = driver.team_colour ? `#${driver.team_colour}` : '#444'
  const retired = driver.is_retired

  return (
    <div onClick={() => setOpen(!open)} style={{ ...s.row, opacity: retired ? 0.4 : 1, cursor:'pointer' }}>
      <div style={{ ...s.bar, background: tc }} />
      <div style={s.pos}>
        <span style={{ ...s.posNum, color: rank===1 ? '#FFD700' : rank<=3 ? '#E8002D' : '#fff', fontSize: rank===1 ? 20 : 16 }}>
          {retired ? 'OUT' : rank}
        </span>
      </div>
      <div style={{ ...s.no, color: tc }}>{driver.driver_number}</div>
      <div style={s.name}>
        <div style={s.acro}>{driver.name_acronym}</div>
        <div style={s.full}>{driver.full_name}</div>
      </div>
      <div style={s.team}>{driver.team_name}</div>
      <div style={s.tyre}>
        <TyreBadge compound={driver.tyre_compound} />
        {driver.tyre_age > 0 && <span style={s.tyreAge}>{driver.tyre_age}L</span>}
      </div>
      <div style={s.lap}>{fmtLap(driver.last_lap_duration)}</div>
      <div style={s.gap}>{isLeader ? <span style={s.leader}>LEADER</span> : fmtGap(driver.gap_to_leader)}</div>
      <div style={s.int}>{isLeader ? '—' : fmtGap(driver.interval)}</div>
      <div style={s.pits}>
        <span style={s.pitL}>PIT</span>
        <span style={s.pitN}>{driver.pit_count || 0}</span>
      </div>
      <div style={{ ...s.arrow, transform: open ? 'rotate(90deg)' : 'none' }}>›</div>

      {open && (
        <div style={s.panel} onClick={e => e.stopPropagation()}>
          <div style={s.grid}>
            {[
              ['Nationality',    driver.country_code || '—'],
              ['Current Lap',    driver.lap_number || '—'],
              ['Tyre Compound',  driver.tyre_compound],
              ['Tyre Age',       driver.tyre_age ? `${driver.tyre_age} laps` : '—'],
              ['Pit Stops',      driver.pit_count || 0],
              ['Status',         retired ? 'RETIRED' : 'RACING'],
            ].map(([label, val]) => (
              <div key={label} style={s.item}>
                <span style={s.iLabel}>{label}</span>
                <span style={{ ...s.iVal, color: label==='Status' ? (retired ? '#E8002D' : '#00C853') : label==='Tyre Compound' ? (TYRE[val]?.bg || '#888') : '#ccc' }}>{val}</span>
              </div>
            ))}
            {driver.headshot_url && (
              <div style={{ marginLeft:'auto' }}>
                <img src={driver.headshot_url} alt={driver.full_name} style={{ height:64, objectFit:'contain', borderRadius:4, filter:'grayscale(20%)' }} onError={e => { e.target.style.display='none' }} />
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

const s = {
  row:    { display:'flex', alignItems:'center', background:'#0F0F0F', borderBottom:'1px solid #1A1A1A', minHeight:48, position:'relative', flexWrap:'wrap', transition:'background 0.15s' },
  bar:    { width:3, alignSelf:'stretch', flexShrink:0 },
  pos:    { width:40, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 },
  posNum: { fontFamily:"'Barlow Condensed',sans-serif", fontWeight:800, lineHeight:1 },
  no:     { width:36, fontFamily:"'Share Tech Mono',monospace", fontSize:13, flexShrink:0, paddingLeft:4 },
  name:   { width:130, flexShrink:0, paddingLeft:8 },
  acro:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:15, fontWeight:700, letterSpacing:'0.05em', color:'#fff', lineHeight:1 },
  full:   { fontFamily:"'Barlow',sans-serif", fontSize:10, color:'#666', lineHeight:1, marginTop:1 },
  team:   { flex:1, fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, color:'#888', paddingLeft:8, minWidth:100 },
  tyre:   { width:56, display:'flex', alignItems:'center', gap:4, flexShrink:0 },
  tyreAge:{ fontFamily:"'Share Tech Mono',monospace", fontSize:10, color:'#666' },
  lap:    { width:100, fontFamily:"'Share Tech Mono',monospace", fontSize:13, color:'#ccc', textAlign:'right', paddingRight:12, flexShrink:0 },
  gap:    { width:80,  fontFamily:"'Share Tech Mono',monospace", fontSize:12, color:'#888', textAlign:'right', paddingRight:12, flexShrink:0 },
  int:    { width:80,  fontFamily:"'Share Tech Mono',monospace", fontSize:12, color:'#555', textAlign:'right', paddingRight:12, flexShrink:0 },
  pits:   { width:44, display:'flex', flexDirection:'column', alignItems:'center', flexShrink:0 },
  pitL:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:9, color:'#555', letterSpacing:'0.1em', lineHeight:1 },
  pitN:   { fontFamily:"'Share Tech Mono',monospace", fontSize:15, color:'#888', lineHeight:1 },
  leader: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:700, color:'#FFD700', letterSpacing:'0.1em' },
  arrow:  { width:24, textAlign:'center', color:'#444', fontSize:18, transition:'transform 0.2s', flexShrink:0 },
  panel:  { width:'100%', background:'#0A0A0A', borderTop:'1px solid #1E1E1E', padding:'12px 16px 16px 16px' },
  grid:   { display:'flex', flexWrap:'wrap', gap:16, alignItems:'flex-start' },
  item:   { display:'flex', flexDirection:'column', gap:2, minWidth:100 },
  iLabel: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, color:'#555', letterSpacing:'0.12em', textTransform:'uppercase' },
  iVal:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:15, fontWeight:700, letterSpacing:'0.04em' },
}
'@

Write-File "frontend\src\components\LiveTimingTable.jsx" @'
import React from 'react'
import { useRaceStore } from '../store/raceStore'
import DriverCard from './DriverCard'

const COLS = [
  { label:'',          width:3   },
  { label:'POS',       width:40  },
  { label:'NO.',       width:36  },
  { label:'DRIVER',    width:130 },
  { label:'TEAM',      flex:1, minWidth:100 },
  { label:'TYRE',      width:56  },
  { label:'LAST LAP',  width:100, align:'right' },
  { label:'GAP',       width:80,  align:'right' },
  { label:'INT',       width:80,  align:'right' },
  { label:'PITS',      width:44  },
  { label:'',          width:24  },
]

export default function LiveTimingTable() {
  const drivers   = useRaceStore((s) => s.drivers)
  const connected = useRaceStore((s) => s.connected)

  if (!connected && drivers.length === 0) {
    return (
      <div style={s.empty}>
        <div style={s.spinner} />
        <div style={s.emptyText}>Connecting to live timing…</div>
        <div style={s.emptyHint}>Data updates every 3 seconds during race weekend</div>
      </div>
    )
  }
  if (drivers.length === 0) {
    return (
      <div style={s.empty}>
        <div style={s.emptyText}>Awaiting race session data</div>
        <div style={s.emptyHint}>Live timing will appear when a session is active</div>
      </div>
    )
  }

  return (
    <div>
      <div style={s.header}>
        {COLS.map((col, i) => (
          <div key={i} style={{ ...s.hCell, width:col.width, flex:col.flex, minWidth:col.minWidth, textAlign:col.align||'left', paddingLeft: i===3||i===4 ? 8 : 0, paddingRight: col.align==='right' ? 12 : 0 }}>
            {col.label}
          </div>
        ))}
      </div>
      {drivers.map((d, i) => (
        <DriverCard key={d.driver_number} driver={d} rank={i+1} isLeader={i===0} />
      ))}
      <div style={s.footer}>{drivers.length} drivers · click a row to expand details</div>
    </div>
  )
}

const s = {
  header: { display:'flex', alignItems:'center', padding:'6px 0', background:'#111', borderBottom:'1px solid #E8002D', position:'sticky', top:64, zIndex:90 },
  hCell:  { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:700, color:'#E8002D', letterSpacing:'0.12em', textTransform:'uppercase', flexShrink:0 },
  empty:  { display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', padding:'80px 24px', gap:12 },
  spinner:{ width:32, height:32, border:'2px solid #222', borderTop:'2px solid #E8002D', borderRadius:'50%', animation:'spin 0.8s linear infinite' },
  emptyText: { fontFamily:"'Barlow Condensed',sans-serif", fontSize:18, fontWeight:700, color:'#555', letterSpacing:'0.1em', textTransform:'uppercase' },
  emptyHint: { fontFamily:"'Barlow',sans-serif", fontSize:12, color:'#333', textAlign:'center' },
  footer: { padding:'10px 16px', fontFamily:"'Barlow',sans-serif", fontSize:11, color:'#333', borderTop:'1px solid #111', textAlign:'center' },
}
'@

Write-File "frontend\src\components\AlertFeed.jsx" @'
import React from 'react'
import { useRaceStore } from '../store/raceStore'

const CFG = {
  safety_car:  { label:'SAFETY CAR',         color:'#FFA500', dot:'#FFA500' },
  vsc:         { label:'VIRTUAL SAFETY CAR',  color:'#FFD700', dot:'#FFD700' },
  red_flag:    { label:'RED FLAG',            color:'#E8002D', dot:'#E8002D' },
  dnf:         { label:'DNF',                 color:'#E8002D', dot:'#E8002D' },
  incident:    { label:'INCIDENT',            color:'#FFA500', dot:'#FFA500' },
  fastest_lap: { label:'FASTEST LAP',         color:'#A855F7', dot:'#A855F7' },
  chequered:   { label:'CHEQUERED',           color:'#ffffff', dot:'#ffffff' },
}

function timeAgo(iso) {
  if (!iso) return ''
  const d = (Date.now() - new Date(iso).getTime()) / 1000
  if (d < 60) return `${Math.floor(d)}s ago`
  if (d < 3600) return `${Math.floor(d/60)}m ago`
  return new Date(iso).toLocaleTimeString()
}

export default function AlertFeed() {
  const alerts      = useRaceStore((s) => s.alerts)
  const clearAlerts = useRaceStore((s) => s.clearAlerts)

  return (
    <aside style={s.panel}>
      <div style={s.head}>
        <span style={s.title}>LIVE ALERTS</span>
        {alerts.length > 0 && <button onClick={clearAlerts} style={s.clear}>CLEAR</button>}
      </div>

      <div style={s.feed}>
        {alerts.length === 0 && (
          <div style={s.none}>
            <div style={s.noneText}>No events yet</div>
            <div style={s.noneHint}>Incidents, flags, DNFs and fastest laps will appear here</div>
          </div>
        )}
        {alerts.map((a) => {
          const c = CFG[a.type] || { label: a.type?.toUpperCase(), color:'#888', dot:'#888' }
          return (
            <div key={a.id} style={s.item}>
              <div style={{ ...s.dot, background: c.dot }} />
              <div style={s.body}>
                <div style={{ ...s.type, color: c.color }}>{c.label}</div>
                {a.driver_name && <div style={s.driver}>{a.driver_name}</div>}
                {a.team        && <div style={s.team}>{a.team}</div>}
                {a.message     && <div style={s.msg}>{a.message}</div>}
                <div style={s.time}>{timeAgo(a.time)}</div>
              </div>
            </div>
          )
        })}
      </div>

      <div style={s.legend}>
        <div style={s.legTitle}>FLAG LEGEND</div>
        {[
          { color:'#00C853', label:'Green — Racing' },
          { color:'#FFD700', label:'Yellow — Caution' },
          { color:'#FFA500', label:'Orange — Safety Car' },
          { color:'#E8002D', label:'Red — Stopped' },
          { color:'#A855F7', label:'Purple — Fastest Lap' },
          { color:'#ffffff', label:'Chequered — Race Over' },
        ].map(({ color, label }) => (
          <div key={label} style={s.legItem}>
            <div style={{ ...s.legDot, background: color }} />
            <span style={s.legLabel}>{label}</span>
          </div>
        ))}
      </div>
    </aside>
  )
}

const s = {
  panel:   { width:260, flexShrink:0, background:'#0A0A0A', borderLeft:'1px solid #1A1A1A', display:'flex', flexDirection:'column', height:'calc(100vh - 64px)', position:'sticky', top:64, overflow:'hidden' },
  head:    { display:'flex', alignItems:'center', justifyContent:'space-between', padding:'12px 16px', borderBottom:'1px solid #1A1A1A', flexShrink:0 },
  title:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:11, fontWeight:700, color:'#E8002D', letterSpacing:'0.15em' },
  clear:   { fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:700, color:'#444', background:'none', border:'1px solid #222', borderRadius:2, padding:'2px 8px', cursor:'pointer', letterSpacing:'0.1em' },
  feed:    { flex:1, overflowY:'auto', padding:'8px 0' },
  none:    { padding:'32px 16px', textAlign:'center' },
  noneText:{ fontFamily:"'Barlow Condensed',sans-serif", fontSize:14, color:'#333', letterSpacing:'0.1em' },
  noneHint:{ fontFamily:"'Barlow',sans-serif", fontSize:11, color:'#222', marginTop:6, lineHeight:1.4 },
  item:    { display:'flex', gap:10, padding:'10px 16px', borderBottom:'1px solid #111', alignItems:'flex-start' },
  dot:     { width:6, height:6, borderRadius:'50%', flexShrink:0, marginTop:4 },
  body:    { flex:1, minWidth:0 },
  type:    { fontFamily:"'Barlow Condensed',sans-serif", fontSize:12, fontWeight:700, letterSpacing:'0.1em', lineHeight:1 },
  driver:  { fontFamily:"'Barlow Condensed',sans-serif", fontSize:14, fontWeight:700, color:'#fff', marginTop:3, lineHeight:1 },
  team:    { fontFamily:"'Barlow',sans-serif", fontSize:11, color:'#555', marginTop:1 },
  msg:     { fontFamily:"'Barlow',sans-serif", fontSize:11, color:'#666', marginTop:4, lineHeight:1.3 },
  time:    { fontFamily:"'Share Tech Mono',monospace", fontSize:10, color:'#333', marginTop:4 },
  legend:  { borderTop:'1px solid #1A1A1A', padding:'12px 16px', flexShrink:0 },
  legTitle:{ fontFamily:"'Barlow Condensed',sans-serif", fontSize:10, fontWeight:700, color:'#333', letterSpacing:'0.15em', marginBottom:8 },
  legItem: { display:'flex', alignItems:'center', gap:8, marginBottom:5 },
  legDot:  { width:8, height:8, borderRadius:'50%', flexShrink:0 },
  legLabel:{ fontFamily:"'Barlow',sans-serif", fontSize:11, color:'#555' },
}
'@

# ─────────────────────────────────────────
# ROOT CONFIG FILES
# ─────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Writing root config files..." -ForegroundColor Yellow

Write-File ".vscode\launch.json" @'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run Flask Backend",
      "type": "debugpy",
      "request": "launch",
      "program": "${workspaceFolder}/backend/app.py",
      "cwd": "${workspaceFolder}/backend",
      "env": { "FLASK_DEBUG": "false" },
      "console": "integratedTerminal"
    }
  ]
}
'@

Write-File "netlify.toml" @'
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build]
  base = "frontend"
  command = "npm install && npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "20"
'@

Write-File "render.yaml" @'
services:
  - type: web
    name: f1-live-tracker-api
    runtime: python
    rootDir: backend
    buildCommand: pip install -r requirements.render.txt
    startCommand: gunicorn --worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker --workers 1 --bind 0.0.0.0:$PORT app:app
    envVars:
      - key: CORS_ORIGINS
        value: https://your-netlify-app.netlify.app
      - key: SECRET_KEY
        generateValue: true
      - key: POLL_INTERVAL
        value: 3
'@

Write-File ".gitignore" @'
__pycache__/
*.py[cod]
venv/
.env
node_modules/
frontend/dist/
.DS_Store
'@

# ─────────────────────────────────────────
# INSTALL DEPENDENCIES
# ─────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Installing dependencies..." -ForegroundColor Yellow

# Backend
Write-Host ""
Write-Host "  Installing Python packages..." -ForegroundColor Cyan
Set-Location (Join-Path $root "backend")
pip install -r requirements.txt
Set-Location $root

# Frontend
Write-Host ""
Write-Host "  Installing Node packages..." -ForegroundColor Cyan
Set-Location (Join-Path $root "frontend")
npm install
Set-Location $root

# ─────────────────────────────────────────
# DONE
# ─────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "   SETUP COMPLETE!" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "To run the project, open TWO terminals:" -ForegroundColor White
Write-Host ""
Write-Host "  Terminal 1 (Backend):" -ForegroundColor Yellow
Write-Host "    cd backend" -ForegroundColor Gray
Write-Host "    python app.py" -ForegroundColor Gray
Write-Host ""
Write-Host "  Terminal 2 (Frontend):" -ForegroundColor Yellow
Write-Host "    cd frontend" -ForegroundColor Gray
Write-Host "    npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "  Then open: http://localhost:5173" -ForegroundColor Green
Write-Host ""

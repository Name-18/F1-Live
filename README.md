# F1 Live Tracker

> Real-time Formula 1 race tracking — live lap times, positions, DNF alerts, Safety Car deployments, incidents, and full driver/car details. Built with Flask + React.

![Tech Stack](https://img.shields.io/badge/Backend-Flask-red) ![Tech Stack](https://img.shields.io/badge/Frontend-React-blue) ![Data](https://img.shields.io/badge/Data-OpenF1%20%2B%20Jolpica-orange)
---

---

## Dashboard

<img width="1914" height="864" alt="image" src="https://github.com/user-attachments/assets/621d243c-52de-4904-aa0c-2a3538fa0c2e" />



<img width="1916" height="873" alt="image" src="https://github.com/user-attachments/assets/29cece90-690b-4fa5-a402-f2a8ff676274" />


---

## Features

- **Live timing table** — all drivers sorted by position, updating every 3 seconds during race weekends
- **Smart data switching** — automatically uses OpenF1 during live sessions, Jolpica between races
- **DNF / Retirement alerts** — instant notification when a driver retires
- **Safety Car** — SC and VSC deployment + ending events
- **Red flag** — full race suspension alerts
- **Fastest lap** — purple sector notifications
- **Incident investigations** — race control message tracking
- **Driver detail cards** — expandable rows with tyre compound, age, pit count, nationality, points, status
- **Championship standings** — driver and constructor standings from Jolpica
- **Last race results** — full finishing order with points, fastest lap, status
- **Weather panel** — air temp, track temp, wind speed (during live sessions)
- **Atmospheric UI** — black and red F1 theme with circuit line art background

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18 + Vite |
| Backend | Flask 3 + Flask-SocketIO |
| Real-time transport | WebSocket (Socket.IO, threading mode) |
| Live race data | OpenF1 API (free, no key) |
| Standings / results | Jolpica-F1 API (free, no key) |

---

## Data Architecture

### Two data sources, one smart switcher

The app uses two completely separate APIs depending on whether a race is happening:

```
┌─────────────────────────────────────────────────────────────────┐
│                      session_manager.py                         │
│                                                                 │
│  Checks OpenF1 for most recent race session                     │
│                                                                 │
│  session.date_end < 4 hours ago?                                │
│         │                                                       │
│    YES ─┼──────────────────► OpenF1 (live polling every 3s)    │
│         │                                                       │
│    NO ──┼──────────────────► Jolpica (refresh every 60s)       │
└─────────────────────────────────────────────────────────────────┘
```

### OpenF1 API — Live race data
**Base URL:** `https://api.openf1.org/v1/`
**Used when:** Race session ended less than 4 hours ago

| Endpoint | Data extracted |
|---|---|
| `/sessions` | Session key, meeting name, circuit, country, date_start, date_end |
| `/drivers` | Driver number, full name, acronym, team name, team colour hex, headshot URL, nationality |
| `/position` | Driver position per lap, timestamp — latest per driver kept |
| `/laps` | Lap duration, lap number, is_pit_out_lap — latest lap per driver kept |
| `/stints` | Tyre compound, tyre age at start, stint number — latest stint per driver kept |
| `/pit` | Pit stop entries per driver — count used for pit stop total |
| `/intervals` | Gap to leader, interval to car ahead — latest per driver kept |
| `/race_control` | Message text, flag colour, category — scanned for SC/VSC/Red Flag/DNF/Fastest Lap keywords |
| `/weather` | Air temperature, track temperature, wind speed, humidity, rainfall — latest entry used |

**How deduplication works:** For positions, intervals and weather, the poller keeps only the entry with the most recent `date` timestamp per driver. For laps and stints, it keeps the highest `lap_number` / `stint_number`. This ensures stale entries never overwrite fresh data.

### Jolpica API — Standings and results
**Base URL:** `https://api.jolpi.ca/ergast/f1/`
**Used when:** No live session detected (between race weekends)
**Note:** Drop-in replacement for the deprecated Ergast API (shut down early 2025)

| Endpoint | Data extracted |
|---|---|
| `/{year}/driverstandings/` | Position, points, wins, driver ID, full name, nationality, team name, team ID |
| `/{year}/constructorstandings/` | Position, points, wins, team ID, team name, nationality |
| `/{year}/last/results/` | Race name, circuit, country, date, finishing order with laps/status/points/fastest lap |
| `/{year}/` | Full season race schedule with rounds, circuits, dates |

**Year fallback logic:** Tries 2026 first — if the standings list is empty (season not started yet), automatically falls back to 2025.

### Event detection logic

The `event_detector.py` scans every incoming race control message and compares driver position status against a set of known keywords:

```
Race control message received
        │
        ▼
  Text contains:                    Action
  ─────────────────────────────     ──────────────────────────────
  "SAFETY CAR DEPLOYED"         →   emit safety_car { status: deployed }
  "SAFETY CAR IN THIS LAP"      →   emit safety_car { status: ending }
  "VIRTUAL SAFETY CAR DEPLOYED" →   emit vsc { status: deployed }
  "VIRTUAL SAFETY CAR ENDING"   →   emit vsc { status: ending }
  "RED FLAG" / flag == "RED"    →   emit red_flag
  "GREEN FLAG" / flag == "GREEN"→   update session_status = green
  "CHEQUERED FLAG"              →   emit chequered
  "INCIDENT" / "INVESTIGATION"  →   emit incident
  "FASTEST LAP"                 →   emit fastest_lap { driver, team }

Driver position status == "DNF" / "RETIRED" / "OUT"
  and not seen before           →   emit dnf { driver, team }
```

All seen message IDs and DNF drivers are stored in module-level sets so duplicate events are never re-emitted across poll cycles.

---

## Project Structure

```
F1-Live/
│
├── backend/                          # Flask API server
│   ├── app.py                        # App factory, SocketIO init, blueprint registration
│   ├── config.py                     # Env vars: CORS origins, poll interval, API base URL
│   ├── Procfile                      # Render deploy: gunicorn + gevent worker
│   ├── requirements.txt              # Local dev (Python 3.13, threading mode, no gevent)
│   ├── requirements.render.txt       # Render deploy (Linux, gevent + gunicorn)
│   │
│   ├── services/
│   │   ├── session_manager.py        # ★ Decides OpenF1 vs Jolpica based on date_end
│   │   ├── openf1_client.py          # HTTP wrapper for all OpenF1 endpoints
│   │   ├── jolpica_client.py         # HTTP wrapper for standings, results, schedule
│   │   ├── race_state.py             # Thread-safe in-memory state store (dict + Lock)
│   │   ├── event_detector.py         # ★ Scans race control messages, detects SC/DNF/flags
│   │   ├── poller.py                 # ★ Background thread: polls OpenF1 or Jolpica on loop
│   │   └── broadcaster.py            # Builds driver list payloads, emits via SocketIO
│   │
│   └── routes/
│       ├── race_routes.py            # GET /api/race/current, GET /api/schedule
│       ├── driver_routes.py          # GET /api/drivers, GET /api/drivers/<number>
│       ├── standings_routes.py       # GET /api/standings/drivers, /constructors, /race/last
│       └── socket_events.py          # WS on_connect: sends full current state immediately
│
├── frontend/                         
│   ├── index.html                    # Root HTML, Google Fonts (Barlow Condensed, Share Tech Mono)
│   ├── package.json                  # Dependencies: react, socket.io-client, zustand, axios
│   ├── vite.config.js                # Dev proxy: /api and /socket.io → localhost:5000
│   │
│   └── src/
│       ├── App.jsx                   # Root layout: header + nav + live/standings view switch
│       ├── main.jsx                  # ReactDOM.createRoot entry point
│       │
│       ├── store/
│       │   └── raceStore.js          # Zustand store: drivers, alerts, session, isLive, dataSource
│       │
│       ├── hooks/
│       │   └── useSocket.js          # ★ Socket.IO connection, listens to all event types,
│       │                             #   triggers toast notifications and pushAlert
│       │
│       ├── components/
│       │   ├── Background.jsx        # Fixed atmospheric background: circuit SVG, red glows,
│       │   │                         #   scan lines, vignette
│       │   ├── RaceHeader.jsx        # Sticky top bar: F1 logo, GP name, circuit, status badge,
│       │   │                         #   LIVE/LAST RACE indicator, weather, lap counter
│       │   ├── LiveTimingTable.jsx   # Column headers + maps drivers → DriverCard rows
│       │   ├── DriverCard.jsx        # ★ Single driver row: team bar, position, tyre badge,
│       │   │                         #   lap time, gap, interval, pit count + expandable panel
│       │   ├── AlertFeed.jsx         # Right sidebar: chronological event log + flag legend
│       │   └── StandingsPanel.jsx    # Tabs: driver standings, constructor standings, last race
│       │
│       └── styles/
│           └── global.css            # CSS reset, font vars, scrollbar styling
│
├── .vscode/
│   ├── launch.json                   # F5 debug config: runs app.py from backend/ directory
│   └── tasks.json                    # Ctrl+Shift+B: starts backend + frontend in parallel
│
├── netlify.toml                      # Netlify: SPA redirect, build command, Node version
├── render.yaml                       # Render: build command, start command, env vars
├── .gitignore
└── README.md
```

---

## How Real-Time Works

```
OpenF1 API  ──poll every 3s──►  poller.py
                                    │
                              session_manager
                              (live check)
                                    │
                    ┌───────────────┴───────────────┐
                 is_live=True                  is_live=False
                    │                               │
             openf1_client                   jolpica_client
                    │                               │
             event_detector                  last race results
             (SC / DNF / flags)                     │
                    │                               │
                    └───────────┬───────────────────┘
                                │
                         broadcaster.py
                                │
                       Flask-SocketIO emit
                                │
                    ┌───────────▼───────────┐
                    │    React Frontend      │
                    │    (Zustand store)     │
                    └───────────┬───────────┘
                                │
               ┌────────────────┼────────────────┐
               ▼                ▼                ▼
         LiveTimingTable    AlertFeed        RaceHeader
         (driver rows)    (event log)     (GP name/status)
```

---

## Local Development

### Backend
```bash
cd backend
pip install -r requirements.txt
python app.py
```
Flask runs on `http://localhost:5000`. The poller starts automatically, checks for a live session, and either polls OpenF1 or fetches Jolpica standings.

### Frontend
```bash
cd frontend
npm install
npm run dev
```
React runs on `http://localhost:5173`. Vite proxies `/api` and `/socket.io` to Flask automatically.

---


## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/health` | Backend health check |
| GET | `/api/race/current` | Current session info + weather + race control |
| GET | `/api/drivers` | All drivers in current session |
| GET | `/api/drivers/<number>` | Single driver with full telemetry |
| GET | `/api/standings/drivers` | Championship driver standings |
| GET | `/api/standings/constructors` | Championship constructor standings |
| GET | `/api/race/last` | Last race full results |
| GET | `/api/schedule` | Full season schedule |
| WS | `race_update` | Full state broadcast every 3s |
| WS | `safety_car` | Safety car deployed / ending |
| WS | `vsc` | Virtual safety car deployed / ending |
| WS | `red_flag` | Red flag shown |
| WS | `dnf` | Driver retirement |
| WS | `fastest_lap` | New fastest lap set |
| WS | `incident` | Race incident / investigation |
| WS | `chequered` | Chequered flag — race over |

---

## Limitations

- **Between races:** No live timing data available from any free source. App shows last race results from Jolpica instead.
- **Render cold starts:** Free tier spins down after 15 minutes idle. First request after idle takes ~60 seconds.
- **Data delay:** OpenF1 has a small inherent delay vs the official F1 timing app (~5–30 seconds).
- **No database:** All state is in-memory. A Render restart clears it — the poller re-syncs within one poll cycle.
- **2026 season data:** OpenF1 and Jolpica update as each race weekend happens. First 2026 race will populate automatically.

---

## License

MIT

---

*Built with Flask, React, OpenF1 and Jolpica. Not affiliated with Formula 1 or the FIA.*

import requests
from config import Config

BASE = Config.OPENF1_BASE_URL

def _get(endpoint, params=None):
    try:
        r = requests.get(f"{BASE}{endpoint}", params=params, timeout=10)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"[OpenF1] Error fetching {endpoint}: {e}")
        return []

def get_latest_session():
    """
    Find the most recent race session that actually has driver data.
    Tries each year from newest to oldest, picks the session whose
    /drivers endpoint returns results.
    """
    for year in [2026, 2025, 2024]:
        sessions = _get("/sessions", {"session_type": "Race", "year": year})
        if not sessions:
            continue

        sessions_with_date = [s for s in sessions if s.get("date_start")]
        if not sessions_with_date:
            continue

        # Sort newest first
        sessions_with_date.sort(key=lambda s: s.get("date_start", ""), reverse=True)

        for session in sessions_with_date:
            key = session.get("session_key")
            # Verify this session actually has driver data
            drivers = _get("/drivers", {"session_key": key})
            if drivers:
                print(f"[OpenF1] Using session {key}: {session.get('meeting_name')} ({year})")
                return session
            else:
                print(f"[OpenF1] Session {key} ({session.get('meeting_name')}) has no driver data, skipping")

    print("[OpenF1] No valid session found with driver data")
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
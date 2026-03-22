from flask import Blueprint, jsonify
from services import race_state
from services import openf1_client as api
from datetime import datetime, timezone

race_bp = Blueprint("race", __name__)

@race_bp.get("/health")
def health():
    return jsonify({"status": "ok"})

@race_bp.get("/race/current")
def current_race():
    state = race_state.get_state()
    session = state.get("session") or {}

    # Determine if this session is truly live or just historical
    date_start = session.get("date_start", "")
    is_historical = False
    if date_start:
        try:
            # Parse date and check if it's more than 4 hours old
            from datetime import datetime, timezone, timedelta
            session_dt = datetime.fromisoformat(date_start.replace("Z", "+00:00"))
            age_hours = (datetime.now(timezone.utc) - session_dt).total_seconds() / 3600
            is_historical = age_hours > 4
        except Exception:
            pass

    return jsonify({
        "session": session,
        "session_status": state.get("session_status"),
        "current_lap": state.get("current_lap"),
        "weather": state.get("weather"),
        "race_control": state.get("race_control", [])[-20:],
        "is_historical": is_historical,
    })

@race_bp.get("/schedule")
def schedule():
    sessions = api._get("/sessions", {"year": 2026})
    return jsonify(sessions)
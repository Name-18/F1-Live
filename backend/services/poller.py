import threading
import time
from config import Config
from services import openf1_client as api, race_state
from services.event_detector import detect_events
from services.session_manager import get_live_session

_poller_thread = None
SESSION_RECHECK_SECS = 300   # re-check live status every 5 minutes
JOLPICA_REFRESH_SECS = 60    # refresh Jolpica data every 60 seconds


def _openf1_snapshot(session_key, drivers_map):
    positions = api.get_positions(session_key)
    laps      = api.get_laps(session_key)
    stints    = api.get_stints(session_key)
    pits      = api.get_pit_stops(session_key)
    intervals = api.get_intervals(session_key)
    rc        = api.get_race_control(session_key)
    weather   = api.get_weather(session_key)

    pos_map = {}
    for p in positions:
        dn = str(p.get("driver_number"))
        ex = pos_map.get(dn)
        if not ex or p.get("date","") > ex.get("date",""):
            pos_map[dn] = p
    for dn, p in pos_map.items():
        race_state.update_position(dn, p)

    lap_map, max_lap = {}, 0
    for lap in laps:
        dn = str(lap.get("driver_number"))
        ln = lap.get("lap_number", 0)
        if ln > max_lap: max_lap = ln
        ex = lap_map.get(dn)
        if not ex or ln > ex.get("lap_number", 0):
            lap_map[dn] = lap
    for dn, lap in lap_map.items():
        race_state.update_lap(dn, lap)
    race_state.update("current_lap", max_lap)

    stint_map = {}
    for s in stints:
        dn = str(s.get("driver_number"))
        ex = stint_map.get(dn)
        if not ex or s.get("stint_number",0) > ex.get("stint_number",0):
            stint_map[dn] = s
    for dn, s in stint_map.items():
        race_state.update_stint(dn, s)

    pit_map = {}
    for p in pits:
        dn = str(p.get("driver_number"))
        pit_map.setdefault(dn, []).append(p)
    for dn, ps in pit_map.items():
        race_state.update_pit(dn, ps)

    iv_map = {}
    for iv in intervals:
        dn = str(iv.get("driver_number"))
        ex = iv_map.get(dn)
        if not ex or iv.get("date","") > ex.get("date",""):
            iv_map[dn] = iv
    for dn, iv in iv_map.items():
        race_state.update_interval(dn, iv)

    race_state.update("weather", weather)
    return rc, list(pos_map.values())


def _poll_loop(socketio):
    from services.broadcaster import (
        broadcast_state_openf1,
        broadcast_state_jolpica,
        broadcast_events,
    )

    last_session_check = 0
    is_live    = False
    session_key  = None
    drivers_map  = {}

    while True:
        now = time.time()

        # ── Re-check session status periodically ──────────────────────────────
        if now - last_session_check >= SESSION_RECHECK_SECS:
            session, is_live = get_live_session()
            last_session_check = now
            race_state.update("is_live", is_live)

            if is_live and session:
                session_key = session["session_key"]
                race_state.update("session", session)
                race_state.update("session_key", session_key)
                drivers = api.get_drivers(session_key)
                drivers_map = {str(d["driver_number"]): d for d in drivers}
                for dn, d in drivers_map.items():
                    race_state.update_driver(dn, d)
                race_state.update("drivers_map", drivers_map)
                print(f"[Poller] Mode: LIVE — {session.get('meeting_name')}")
            else:
                print("[Poller] Mode: HISTORICAL — serving Jolpica last race data")

        # ── Broadcast based on current mode ───────────────────────────────────
        if is_live and session_key:
            try:
                rc_msgs, positions = _openf1_snapshot(session_key, drivers_map)
                events = detect_events(rc_msgs, positions, drivers_map)
                if events:
                    broadcast_events(socketio, events)
                broadcast_state_openf1(socketio)
            except Exception as e:
                print(f"[Poller] OpenF1 error: {e}")
            time.sleep(Config.POLL_INTERVAL)

        else:
            # Between races — serve Jolpica, no need to hammer it every 3s
            try:
                broadcast_state_jolpica(socketio)
            except Exception as e:
                print(f"[Poller] Jolpica error: {e}")
            time.sleep(JOLPICA_REFRESH_SECS)


def start_poller(socketio):
    global _poller_thread
    if _poller_thread and _poller_thread.is_alive():
        return
    _poller_thread = threading.Thread(
        target=_poll_loop, args=(socketio,), daemon=True
    )
    _poller_thread.start()
    print("[Poller] Started.")
from services import race_state
from services.jolpica_client import get_last_race_results

TEAM_COLOURS = {
    "mclaren":      "FF8000",
    "ferrari":      "E8002D",
    "red_bull":     "3671C6",
    "mercedes":     "27F4D2",
    "aston_martin": "229971",
    "alpine":       "FF87BC",
    "williams":     "64C4FF",
    "rb":           "6692FF",
    "kick_sauber":  "52E252",
    "haas":         "B6BABD",
    "audi":         "999999",
}


# ─── OpenF1 driver list (live race) ───────────────────────────────────────────

def _openf1_drivers(state):
    drivers   = state.get("drivers", {})
    positions = state.get("positions", {})
    laps      = state.get("laps", {})
    stints    = state.get("stints", {})
    pits      = state.get("pit_stops", {})
    intervals = state.get("intervals", {})
    retired   = state.get("retired_drivers", set())

    rows = []
    for dn, driver in drivers.items():
        pos      = positions.get(dn, {})
        lap      = laps.get(dn, {})
        stint    = stints.get(dn, {})
        pit_list = pits.get(dn, [])
        interval = intervals.get(dn, {})
        rows.append({
            "driver_number":     dn,
            "full_name":         driver.get("full_name", ""),
            "name_acronym":      driver.get("name_acronym", ""),
            "team_name":         driver.get("team_name", ""),
            "team_colour":       driver.get("team_colour", "444444"),
            "headshot_url":      driver.get("headshot_url", ""),
            "country_code":      driver.get("country_code", ""),
            "position":          pos.get("position", 99),
            "last_lap_duration": lap.get("lap_duration"),
            "lap_number":        lap.get("lap_number", 0),
            "is_pit_out_lap":    lap.get("is_pit_out_lap", False),
            "tyre_compound":     stint.get("compound", "UNKNOWN"),
            "tyre_age":          stint.get("tyre_age_at_start", 0),
            "pit_count":         len(pit_list),
            "gap_to_leader":     interval.get("gap_to_leader"),
            "interval":          interval.get("interval"),
            "is_retired":        dn in retired,
            "points":            None,
            "status":            "RETIRED" if dn in retired else "RACING",
            "fastest_lap":       "",
        })
    rows.sort(key=lambda d: int(d["position"]) if str(d["position"]).isdigit() else 99)
    return rows


# ─── Jolpica driver list (between races) ──────────────────────────────────────

def _jolpica_drivers():
    last_race = get_last_race_results()
    if not last_race or not last_race.get("results"):
        return [], None

    rows = []
    for r in last_race["results"]:
        colour = TEAM_COLOURS.get(r.get("team_id", ""), "666666")
        rows.append({
            "driver_number":     str(r.get("grid", 99)),
            "full_name":         r["full_name"],
            "name_acronym":      r.get("code", r["full_name"].split()[-1][:3].upper()),
            "team_name":         r["team_name"],
            "team_colour":       colour,
            "headshot_url":      "",
            "country_code":      "",
            "position":          r["position"],
            "last_lap_duration": None,
            "lap_number":        r["laps"],
            "is_pit_out_lap":    False,
            "tyre_compound":     "UNKNOWN",
            "tyre_age":          0,
            "pit_count":         0,
            "gap_to_leader":     None,
            "interval":          None,
            "is_retired":        r["status"] != "Finished",
            "points":            r["points"],
            "status":            r["status"],
            "fastest_lap":       r.get("fastest_lap", ""),
        })
    return rows, last_race


# ─── Broadcast helpers ────────────────────────────────────────────────────────

def broadcast_state_openf1(socketio):
    state   = race_state.get_state()
    session = state.get("session") or {}
    drivers = _openf1_drivers(state)
    socketio.emit("race_update", {
        "session": {
            "gp_name": session.get("meeting_name", ""),
            "circuit": session.get("circuit_short_name", ""),
            "country": session.get("country_name", ""),
            "date":    session.get("date_start", ""),
            "season":  "",
            "round":   "",
        },
        "session_status": state.get("session_status", "unknown"),
        "current_lap":    state.get("current_lap", 0),
        "weather":        state.get("weather", {}),
        "drivers":        drivers,
        "is_live":        True,
        "data_source":    "openf1",
    })


def broadcast_state_jolpica(socketio):
    """Always fetch fresh Jolpica data — never use OpenF1 session info."""
    drivers, last_race = _jolpica_drivers()

    if last_race:
        session_info = {
            "gp_name": last_race.get("race_name", ""),
            "circuit": last_race.get("circuit", ""),
            "country": last_race.get("country", ""),
            "date":    last_race.get("date", ""),
            "season":  str(last_race.get("season", "")),
            "round":   str(last_race.get("round", "")),
        }
    else:
        session_info = {"gp_name": "", "circuit": "", "country": "", "date": "", "season": "", "round": ""}

    socketio.emit("race_update", {
        "session":        session_info,
        "session_status": "finished",
        "current_lap":    0,
        "weather":        {},
        "drivers":        drivers,
        "is_live":        False,
        "data_source":    "jolpica",
    })


def broadcast_state(socketio):
    """Called on WebSocket connect — use correct source based on live flag."""
    state = race_state.get_state()
    if state.get("is_live"):
        broadcast_state_openf1(socketio)
    else:
        broadcast_state_jolpica(socketio)


def broadcast_events(socketio, events):
    for event in events:
        socketio.emit(event["type"], event)


# Kept for backward compat with socket_events.py
def _build_driver_list(state):
    return _openf1_drivers(state)
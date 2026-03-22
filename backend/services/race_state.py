import threading

_lock  = threading.Lock()
_state = {
    "session":          None,
    "session_key":      None,
    "drivers":          {},
    "drivers_map":      {},
    "positions":        {},
    "laps":             {},
    "stints":           {},
    "pit_stops":        {},
    "intervals":        {},
    "race_control":     [],
    "weather":          {},
    "session_status":   "unknown",
    "retired_drivers":  set(),
    "current_lap":      0,
    "is_live":          False,
    "data_source":      "jolpica",
}

def get_state():
    with _lock:
        return dict(_state)

def update(key, value):
    with _lock:
        _state[key] = value

def update_driver(dn, data):
    with _lock: _state["drivers"][str(dn)] = data

def update_position(dn, data):
    with _lock: _state["positions"][str(dn)] = data

def update_lap(dn, data):
    with _lock: _state["laps"][str(dn)] = data

def update_stint(dn, data):
    with _lock: _state["stints"][str(dn)] = data

def update_pit(dn, data):
    with _lock: _state["pit_stops"][str(dn)] = data

def update_interval(dn, data):
    with _lock: _state["intervals"][str(dn)] = data

def add_race_control(msg):
    with _lock: _state["race_control"].append(msg)

def add_retired(dn):
    with _lock: _state["retired_drivers"].add(str(dn))

def get_retired():
    with _lock: return set(_state["retired_drivers"])
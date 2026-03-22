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
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
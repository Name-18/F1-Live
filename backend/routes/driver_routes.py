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
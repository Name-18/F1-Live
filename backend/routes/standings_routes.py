from flask import Blueprint, jsonify, request
from services.jolpica_client import (
    get_driver_standings,
    get_constructor_standings,
    get_last_race_results,
    get_schedule,
)

standings_bp = Blueprint("standings", __name__)

@standings_bp.get("/standings/drivers")
def driver_standings():
    year = int(request.args.get("year", 2026))
    return jsonify(get_driver_standings(year))

@standings_bp.get("/standings/constructors")
def constructor_standings():
    year = int(request.args.get("year", 2026))
    return jsonify(get_constructor_standings(year))

@standings_bp.get("/race/last")
def last_race():
    year = int(request.args.get("year", 2026))
    return jsonify(get_last_race_results(year))

@standings_bp.get("/schedule")
def schedule():
    year = int(request.args.get("year", 2026))
    return jsonify(get_schedule(year))  
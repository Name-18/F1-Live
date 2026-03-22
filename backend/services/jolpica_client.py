import requests

BASE = "https://api.jolpi.ca/ergast/f1"

def _get(endpoint):
    try:
        url = f"{BASE}{endpoint}"
        print(f"[Jolpica] Fetching: {url}")
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"[Jolpica] Error fetching {endpoint}: {e}")
        return {}

def get_driver_standings(year=2026):
    # Correct Jolpica endpoint format (note lowercase, trailing slash)
    data = _get(f"/{year}/driverstandings/")
    try:
        lists = data["MRData"]["StandingsTable"]["StandingsLists"]
        if not lists:
            # 2026 may not have data yet — fall back to 2025
            if year == 2026:
                print("[Jolpica] No 2026 standings yet, falling back to 2025")
                return get_driver_standings(2025)
            return []
        standings = lists[0]["DriverStandings"]
        return [
            {
                "position":    int(s["position"]),
                "points":      float(s["points"]),
                "wins":        int(s["wins"]),
                "driver_id":   s["Driver"]["driverId"],
                "full_name":   f"{s['Driver']['givenName']} {s['Driver']['familyName']}",
                "code":        s["Driver"].get("code", ""),
                "nationality": s["Driver"]["nationality"],
                "team_name":   s["Constructors"][0]["name"] if s["Constructors"] else "",
                "team_id":     s["Constructors"][0]["constructorId"] if s["Constructors"] else "",
            }
            for s in standings
        ]
    except Exception as e:
        print(f"[Jolpica] Error parsing driver standings: {e}")
        return []

def get_constructor_standings(year=2026):
    data = _get(f"/{year}/constructorstandings/")
    try:
        lists = data["MRData"]["StandingsTable"]["StandingsLists"]
        if not lists:
            if year == 2026:
                print("[Jolpica] No 2026 constructor standings yet, falling back to 2025")
                return get_constructor_standings(2025)
            return []
        standings = lists[0]["ConstructorStandings"]
        return [
            {
                "position":    int(s["position"]),
                "points":      float(s["points"]),
                "wins":        int(s["wins"]),
                "team_id":     s["Constructor"]["constructorId"],
                "team_name":   s["Constructor"]["name"],
                "nationality": s["Constructor"]["nationality"],
            }
            for s in standings
        ]
    except Exception as e:
        print(f"[Jolpica] Error parsing constructor standings: {e}")
        return []

def get_last_race_results(year=2026):
    data = _get(f"/{year}/last/results/")
    try:
        races = data["MRData"]["RaceTable"]["Races"]
        if not races:
            if year == 2026:
                print("[Jolpica] No 2026 race results yet, falling back to 2025")
                return get_last_race_results(2025)
            return {}
        race = races[0]
        return {
            "race_name": race["raceName"],
            "circuit":   race["Circuit"]["circuitName"],
            "country":   race["Circuit"]["Location"]["country"],
            "date":      race["date"],
            "season":    race["season"],
            "round":     race["round"],
            "results": [
                {
                    "position":    int(r["position"]),
                    "driver_id":   r["Driver"]["driverId"],
                    "full_name":   f"{r['Driver']['givenName']} {r['Driver']['familyName']}",
                    "code":        r["Driver"].get("code", ""),
                    "team_name":   r["Constructor"]["name"],
                    "laps":        int(r["laps"]),
                    "status":      r["status"],
                    "points":      float(r["points"]),
                    "grid":        int(r["grid"]),
                    "fastest_lap": r.get("FastestLap", {}).get("Time", {}).get("time", ""),
                }
                for r in race["Results"]
            ],
        }
    except Exception as e:
        print(f"[Jolpica] Error parsing last race: {e}")
        return {}

def get_schedule(year=2026):
    data = _get(f"/{year}/")
    try:
        races = data["MRData"]["RaceTable"]["Races"]
        return [
            {
                "round":      int(r["round"]),
                "race_name":  r["raceName"],
                "circuit":    r["Circuit"]["circuitName"],
                "country":    r["Circuit"]["Location"]["country"],
                "date":       r["date"],
                "time":       r.get("time", ""),
            }
            for r in races
        ]
    except Exception as e:
        print(f"[Jolpica] Error parsing schedule: {e}")
        return []
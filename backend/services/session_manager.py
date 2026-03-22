"""
Session manager — decides whether to use OpenF1 (live) or Jolpica (historical).

Rule:
  - If the most recent race session's date_end is within 4 hours → LIVE (OpenF1)
  - If date_end is older than 4 hours, OR no date_end exists → HISTORICAL (Jolpica)

We check date_end (not date_start) because a race starts and then runs ~2 hours.
date_start being 3h ago doesn't mean the race is over.
"""
from datetime import datetime, timezone
from services import openf1_client as api


def get_live_session():
    """
    Returns (session_dict, is_live).
    is_live=True  → use OpenF1 polling
    is_live=False → use Jolpica
    """
    for year in [2026, 2025]:
        sessions = api._get("/sessions", {"session_type": "Race", "year": year})
        if not sessions:
            continue

        # Only sessions that have a start date
        sessions = [s for s in sessions if s.get("date_start")]
        if not sessions:
            continue

        # Sort newest first by date_start
        sessions.sort(key=lambda s: s["date_start"], reverse=True)

        # Take the single most recent session
        session = sessions[0]

        # Verify it actually has driver data
        drivers = api._get("/drivers", {"session_key": session["session_key"]})
        if not drivers:
            print(f"[Session] {session.get('meeting_name')} has no driver data, skipping")
            continue

        # Use date_end if available, otherwise fall back to date_start
        end_str   = session.get("date_end") or session.get("date_start")
        start_str = session.get("date_start")

        try:
            end_dt      = datetime.fromisoformat(end_str.replace("Z", "+00:00"))
            start_dt    = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            now         = datetime.now(timezone.utc)

            hours_since_end   = (now - end_dt).total_seconds()   / 3600
            hours_since_start = (now - start_dt).total_seconds() / 3600

            print(f"[Session] Most recent race: {session.get('meeting_name')} "
                  f"| started {hours_since_start:.1f}h ago"
                  f"| ended {hours_since_end:.1f}h ago")

            # Live if session ended less than 4 hours ago
            # (covers: race in progress, just finished, or within post-race window)
            if hours_since_end <= 4:
                print(f"[Session] → LIVE (OpenF1)")
                return session, True
            else:
                print(f"[Session] → HISTORICAL (Jolpica) — race ended {hours_since_end:.0f}h ago")
                return session, False

        except Exception as e:
            print(f"[Session] Date parse error for {session.get('meeting_name')}: {e}")
            return session, False

    print("[Session] No sessions found at all")
    return None, False
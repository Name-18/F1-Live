import os

class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "f1-live-tracker-secret")
    OPENF1_BASE_URL = "https://api.openf1.org/v1"
    POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 3))
    # Allow localhost dev + production Netlify URL
    CORS_ORIGINS = os.environ.get(
        "CORS_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000"
    ).split(",")
    DEBUG = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
from flask import Flask
from flask_socketio import SocketIO
from flask_cors import CORS
from config import Config
from routes.race_routes import race_bp
from routes.driver_routes import driver_bp
from routes.standings_routes import standings_bp
from routes.socket_events import register_socket_events
from services.poller import start_poller

socketio = SocketIO()

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app, resources={r"/api/*": {"origins": Config.CORS_ORIGINS}})
    socketio.init_app(
        app,
        cors_allowed_origins=Config.CORS_ORIGINS,
        async_mode="threading"
    )

    app.register_blueprint(race_bp, url_prefix="/api")
    app.register_blueprint(driver_bp, url_prefix="/api")
    app.register_blueprint(standings_bp, url_prefix="/api")

    register_socket_events(socketio)

    return app

app = create_app()

if __name__ == "__main__":
    start_poller(socketio)
    socketio.run(app, host="0.0.0.0", port=5000, debug=False, use_reloader=False)
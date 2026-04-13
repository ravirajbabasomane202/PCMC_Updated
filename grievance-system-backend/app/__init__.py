import logging
import os

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_mail import Mail
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import MetaData

from .config import Config
from .extensions import oauth

convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata = MetaData(naming_convention=convention)

db = SQLAlchemy(metadata=metadata)
migrate = Migrate()
jwt = JWTManager()
mail = Mail()
limiter = Limiter(key_func=get_remote_address, default_limits=["300 per minute"])


def create_app(config_class=None):
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    logger = logging.getLogger(__name__)

    app = Flask(__name__)
    app.config.from_object(config_class or Config)

    # ── Extensions ────────────────────────────────────────────────────────────
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    mail.init_app(app)
    oauth.init_app(app)
    limiter.init_app(app)

    # ── CORS ──────────────────────────────────────────────────────────────────
    cors_origins = app.config.get('CORS_ORIGINS', [
        "http://localhost:*",
        "http://127.0.0.1:*",
        "https://pcmcapp.onrender.com",
        "https://www.nivaran.co.in",
    ])
    CORS(app, resources={r"/*": {
        "origins": cors_origins,
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Authorization", "Content-Type"],
        "expose_headers": ["*"],
        "supports_credentials": True,
    }})

    # ── Google OAuth (optional — only registers if credentials are present) ──
    google_client_id = app.config.get('GOOGLE_CLIENT_ID')
    if google_client_id:
        oauth.register(
            name='google',
            client_id=google_client_id,
            client_secret=app.config.get('GOOGLE_CLIENT_SECRET'),
            server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
            client_kwargs={'scope': 'openid email profile'},
        )
        logger.info("Google OAuth registered")
    else:
        logger.info("Google OAuth not configured — /auth/google routes will return 501")

    # ── Upload folder ─────────────────────────────────────────────────────────
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

    @app.route('/uploads/<path:filename>')
    def uploaded_file(filename):
        return send_from_directory(
            app.config['UPLOAD_FOLDER'], filename, as_attachment=False
        )

    # ── Health check ──────────────────────────────────────────────────────────
    @app.route('/health')
    @limiter.exempt
    def health():
        return jsonify({"status": "ok", "service": "pcmc-grievance-backend"}), 200

    # ── JWT error handlers ────────────────────────────────────────────────────
    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return jsonify({"msg": "Token has expired", "error": "token_expired"}), 401

    @jwt.invalid_token_loader
    def invalid_token_callback(error):
        return jsonify({"msg": "Invalid token", "error": "invalid_token"}), 401

    @jwt.unauthorized_loader
    def missing_token_callback(error):
        return jsonify({"msg": "Authorization token is missing", "error": "authorization_required"}), 401

    # ── Blueprints ────────────────────────────────────────────────────────────
    from .routes.auth_routes import auth_bp
    from .routes.grievance_routes import grievance_bp
    from .routes.user_routes import user_bp
    from .routes.admin_routes import admin_bp
    from .routes.public import public_bp
    from .routes.settings_routes import settings_bp
    from .routes.field_routes import fieldStaff

    app.register_blueprint(auth_bp, url_prefix='/auth')
    app.register_blueprint(grievance_bp, url_prefix='/grievances')
    app.register_blueprint(user_bp, url_prefix='/users')
    app.register_blueprint(admin_bp, url_prefix='/admins')
    app.register_blueprint(settings_bp, url_prefix='/settings')
    app.register_blueprint(public_bp)
    app.register_blueprint(fieldStaff)

    logger.info(f"App created in {app.config.get('ENV', 'development')} mode")
    return app

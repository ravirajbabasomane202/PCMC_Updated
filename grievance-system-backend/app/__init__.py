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


def ensure_master_data():
    from .models import MasterAreas, MasterCategories, MasterConfig, MasterSubjects

    has_changes = False

    if not MasterAreas.query.first():
        area_entries = [
            ("Nigdi-Prdhikaran", "निगडी - प्राधिकरण"),
            ("Akurdi", "आकुर्डी"),
            ("Chinchwadgaon", "चिंचवडगांव"),
            ("Thergaon", "थेरगांव"),
            ("Kiwale", "किवळे"),
            ("Ravet", "रावेत"),
            ("Mamurdi", "मामुर्डी"),
            ("Wakad", "वाकड"),
            ("Punawale", "पुनावळे"),
            ("Bopkhel", "बोपखेल"),
            ("Dapodi-Fugewadi", "दापोडी फुगेवाडी"),
            ("Talawade", "तळवडे"),
            ("Morwadi", "मोरवाडी"),
            ("Bhosari", "भोसरी"),
            ("Chikhali", "चिखली"),
            ("Charholi", "च-होली"),
            ("Moshi", "मोशी"),
            ("Pimprigaon", "पिंपरीगांव"),
            ("Kharalwadi", "खराळवाडी"),
            ("Kasarwadi", "कासारवाडी"),
            ("Kalewadi-Rahatani", "काळेवाडी रहाटणी"),
            ("Chinchwad-Station", "चिंचवड स्टेशन"),
            ("Pimple-Nilakh", "पिंपळे निलख"),
            ("Pimple-Saudagar", "पिंपळे सौदागर"),
            ("Pimple-Gurav", "पिंपळे गुरव"),
            ("New-Sangvi", "नवी सांगवी"),
            ("Old-Sangvi", "जुनी सांगवी"),
            ("Sambhaji-Nagar", "संभाजीनगर"),
            ("Sant-Tukaram-Nagar", "संत तुकाराम नगर"),
            ("Nehru-Nagar", "नेहरूनगर"),
            ("Pimpri-Camp", "पिंपरी कॅम्प"),
            ("Yamuna-Nagar", "यमुनानगर"),
            ("Masulkar-Colony", "मासुळकर कॉलनी"),
            ("Dighi", "दिघी"),
            ("Tathawade", "ताथवडे"),
            ("Dudulgaon", "डुडूळगांव"),
            ("Wadmukhwadi", "वडमुखवाडी"),
            ("AII-PCMC", "पिं.चिं. शहर"),
            ("Walhekar Wadi", "वाल्हेकरवाडी"),
            ("Bhatnagar", "भाटनगर"),
            ("Jadhavwadi-KudalWadi", "जाधववाडी-कुदळवाडी"),
            ("Indrayani Nagar", "इंद्रायणी नगर"),
            ("Rupi Nagar", "रुपीनगर"),
            ("Kalbhor Nagar", "काळभोरनगर"),
            ("Chinchwade Nagar", "चिंचवडेनगर"),
            ("Shivtej Nagar Chikhali", "शिवतेज नगर चिखली"),
        ]
        for name, description in area_entries:
            if not MasterAreas.query.filter_by(name=name).first():
                db.session.add(MasterAreas(name=name, description=description))
        has_changes = True

    category_map = {}
    categories = {
        "Infrastructure": "Roads, bridges, and public works",
        "Sanitation": "Garbage, sewage, and cleanliness",
        "Water Supply": "Water connection and distribution",
        "Electricity": "Street lighting and power supply",
        "Health": "Health centre and medical services",
    }
    for name, desc in categories.items():
        category = MasterCategories.query.filter_by(name=name).first()
        if not category:
            category = MasterCategories(name=name, description=desc)
            db.session.add(category)
            db.session.flush()
            has_changes = True
        category_map[name] = category

    if not MasterSubjects.query.first():
        subject_entries = [
            ("रस्त्यावरील खड्डयांबाबत", "Pot Holes"),
            ("सार्वजनिक शौचालय साफसफाईबाबत", "Cleaning of Public Toilets"),
            ("अनाधिकृत टपऱ्या / हातगाड्या / फेरीवाल्यांबाबत", "Unauthorised Stalls & Hawkers"),
            ("अनाधिकृत मोबाईल टॉवरबाबत", "Unauthorised Mobile Tower"),
            ("किटकनाशक फवारणी", "Spraying Of Pesticides"),
            ("रस्ते दुरूस्ती", "Road repairing"),
            ("पाणी समस्या", "Water problem"),
            ("ड्रेनेज तुंबलेबाबत", "Drainage blockage"),
            ("रस्त्यावरील विद्युत दिव्यांबाबत", "Street lights"),
            ("परिसर साफसफाई / कचरा उचलणेबाबत", "Area Cleaning / Garbage lifting"),
            ("ध्वनी प्रदुषणाबाबत", "Sound Pollution"),
            ("इतर", "Other"),
            ("मृत जनावर", "Dead animal"),
            ("कचराकुंडी साफ नाहीत", "Dustbins not cleaned"),
            ("कचरा गाडीबाबत", "Garbage vehicle not arrived"),
            ("सार्वजनिक स्वच्छतागृहातील विदयुत दिव्याबाबत", "No electricity in public toilet"),
            ("सार्वजनिक स्वच्छतागृहातील पाणी समस्याबाबत", "No water supply in public toilet"),
            ("सार्वजनिक स्वच्छतागृहातील साफसफाईबाबत", "Public toilet blockage-cleaning"),
            ("गतिरोधक", "Speed Breaker"),
            ("कमी दाबाने पाणी पुरवठा", "Low Water Pressure"),
            ("दुषित पाणी पुरवठा", "Contaminated Water Supply"),
            ("अनियमित पाणी पुरवठा", "Irregular Water Supply"),
            ("पाईपलाईन लीकेज", "Pipeline Leakage"),
            ("पेविंग ब्लॉक", "Paving Block"),
            ("वृक्ष छाटणी", "Tree Cutting"),
            ("फुटपाथ दुरुस्ती बाबत", "Regarding pavement repair"),
            ("फुटपाथ साफसफाई बाबत", "Clean Sidewalk"),
            ("भटक्या कुत्र्यांसाठी जन्म नियंत्रण बाबत", "Birth Control for Stray Dogs"),
            ("आजारी किंवा जखमी भटका कुत्रा बाबत", "Sick or Injured Stray Dog"),
            ("भटक्या कुत्र्याने चावा बाबत", "Bite by Stray Dog"),
            ("मोठे मृत जनावरांची विल्हेवाट लावणे बाबत", "Disposal of large dead animals"),
            ("रेबीज ग्रस्त श्वानांची तक्रार बाबत", "Complaints of rabies dogs"),
        ]
        for name, description in subject_entries:
            if not MasterSubjects.query.filter_by(name=name).first():
                db.session.add(MasterSubjects(name=name, description=description))
        has_changes = True

    configs = {
        "DEFAULT_PRIORITY": ("medium", "Default grievance priority"),
        "SLA_CLOSURE_DAYS": ("7", "Days before auto-close after resolution"),
        "MAX_FILE_UPLOADS": ("10", "Maximum file uploads per grievance"),
        "MAINTENANCE_MODE": ("false", "Set to true to enable maintenance mode"),
    }
    for key, (value, desc) in configs.items():
        if not MasterConfig.query.filter_by(key=key).first():
            db.session.add(MasterConfig(key=key, value=value, description=desc))
            has_changes = True

    if has_changes:
        db.session.commit()


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

    # Ensure database tables and seed master data on startup for fresh deployments.
    try:
        with app.app_context():
            db.create_all()
            ensure_master_data()
            logger.info("Database tables and master data ensured.")
    except Exception:
        logger.exception("Failed to create or verify database tables or seed master data")

    logger.info(f"App created in {app.config.get('ENV', 'development')} mode")
    return app

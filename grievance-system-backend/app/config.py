import os
from datetime import timedelta
from dotenv import load_dotenv

basedir = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(basedir, '..', '.env'))


class BaseConfig:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'change-me-in-production'
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or 'change-me-in-production'
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=2)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,       # Detect stale connections automatically
        'pool_recycle': 300,         # Recycle connections every 5 minutes
        'pool_size': 10,             # Base pool (10 workers × 10 = 100 concurrent)
        'max_overflow': 5,           # Allow bursts up to 15 connections
        'pool_timeout': 30,          # Wait up to 30s for a connection
    }
    UPLOAD_FOLDER = os.path.join(basedir, '..', 'uploads')
    ALLOWED_EXTENSIONS = {'pdf', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov'}
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50 MB

    # Security
    SECURITY_PASSWORD_SALT = os.environ.get('SECURITY_PASSWORD_SALT') or 'change-me'
    RESET_TOKEN_SECRET = os.environ.get('RESET_TOKEN_SECRET') or 'change-me'

    # Rate limiting storage (use redis in production for multi-worker support)
    RATELIMIT_STORAGE_URI = os.environ.get('REDIS_URL', 'memory://')
    RATELIMIT_HEADERS_ENABLED = True

    # Mail
    MAIL_SERVER = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_PORT = int(os.environ.get('MAIL_PORT', 587))
    MAIL_USE_TLS = os.environ.get('MAIL_USE_TLS', 'true').lower() in ('true', '1', 't')
    MAIL_USE_SSL = os.environ.get('MAIL_USE_SSL', 'false').lower() in ('true', '1', 't')
    MAIL_USERNAME = os.environ.get('MAIL_USERNAME')
    MAIL_PASSWORD = os.environ.get('MAIL_PASSWORD')

    # Google OAuth (optional — leave blank to disable)
    GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID', '')
    GOOGLE_CLIENT_SECRET = os.environ.get('GOOGLE_CLIENT_SECRET', '')
    GOOGLE_DISCOVERY_URL = 'https://accounts.google.com/.well-known/openid-configuration'

    # Frontend callback URL (for Google OAuth redirect after server-side flow)
    FRONTEND_CALLBACK_URL = os.environ.get('FRONTEND_CALLBACK_URL', 'http://localhost:5500')


class DevelopmentConfig(BaseConfig):
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = (
        os.environ.get('DATABASE_URL') or 'sqlite:///dev.db'
    )
    SQLALCHEMY_ECHO = False  # set True to debug queries


class ProductionConfig(BaseConfig):
    DEBUG = False
    _db_url = os.environ.get('DATABASE_URL', '')
    # Heroku / Render give postgres:// which SQLAlchemy 1.4+ rejects
    if _db_url.startswith('postgres://'):
        _db_url = _db_url.replace('postgres://', 'postgresql://', 1)
    SQLALCHEMY_DATABASE_URI = _db_url or None

    @classmethod
    def init_app(cls, app):
        if not cls.SQLALCHEMY_DATABASE_URI:
            raise RuntimeError('DATABASE_URL environment variable is not set for production')


class TestingConfig(BaseConfig):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    SQLALCHEMY_ECHO = False
    RATELIMIT_ENABLED = False  # Disable rate limits during tests


_ENV = os.environ.get('APP_ENV', 'development').lower()
_CONFIGS = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
}
Config = _CONFIGS.get(_ENV, DevelopmentConfig)

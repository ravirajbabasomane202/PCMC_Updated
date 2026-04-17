import logging
import os

from flask import Blueprint, current_app, jsonify, redirect, request, session, url_for
from flask_jwt_extended import (
    create_access_token, create_refresh_token, get_jwt_identity, jwt_required,
)
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_mail import Message
from itsdangerous import BadTimeSignature, SignatureExpired, URLSafeTimedSerializer
from requests_oauthlib.oauth2_session import OAuth2Session
import requests
from sqlalchemy.exc import IntegrityError
from werkzeug.utils import secure_filename

from .. import db, mail, limiter
from ..models import Role, User
from ..schemas import UserSchema
from ..utils.file_utils import allowed_file

logger = logging.getLogger(__name__)
auth_bp = Blueprint('auth', __name__)


# ── Register ──────────────────────────────────────────────────────────────────

@auth_bp.route('/register', methods=['POST'])
@limiter.limit("10 per hour")
def register():
    data = request.json or {}
    email = data.get('email', '').strip().lower()
    name = data.get('name', '').strip()
    password = data.get('password', '')

    if not all([email, name, password]):
        return jsonify({"msg": "Missing required fields: name, email, password"}), 400
    if len(password) < 6:
        return jsonify({"msg": "Password must be at least 6 characters"}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({"msg": "Email already exists"}), 400

    voter_id = data.get('voter_id')
    if voter_id and User.query.filter_by(voter_id=voter_id).first():
        return jsonify({"msg": "Voter ID already exists"}), 400

    user = User(
        name=name, email=email,
        phone_number=data.get('phone_number'),
        address=data.get('address'),
        voter_id=voter_id,
        role=Role.CITIZEN,
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()
    access_token = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))
    return jsonify({"access_token": access_token, "refresh_token": refresh_token}), 200


# ── Email / Password Login ────────────────────────────────────────────────────

@auth_bp.route('/login', methods=['POST'])
@limiter.limit("20 per minute")
def password_login():
    data = request.json or {}
    email = data.get('email', '').strip().lower()
    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(data.get('password', '')):
        return jsonify({"msg": "Invalid email or password"}), 401
    access_token = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))
    return jsonify({"access_token": access_token, "refresh_token": refresh_token}), 200


# ── Token Refresh ─────────────────────────────────────────────────────────────

@auth_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    current_user_id = get_jwt_identity()
    return jsonify({
        "access_token": create_access_token(identity=current_user_id),
        "refresh_token": create_refresh_token(identity=current_user_id),
    }), 200


# ── Google OAuth (server-side, optional) ─────────────────────────────────────

@auth_bp.route('/google/login')
def google_login():
    if not current_app.config.get('GOOGLE_CLIENT_ID'):
        return jsonify({"msg": "Google OAuth is not configured on this server"}), 501
    try:
        discovery = requests.get(
            current_app.config['GOOGLE_DISCOVERY_URL'], timeout=5
        ).json()
    except requests.exceptions.RequestException as e:
        return jsonify({"msg": "Could not reach Google", "error": str(e)}), 502

    oauth_session = OAuth2Session(
        client_id=current_app.config['GOOGLE_CLIENT_ID'],
        redirect_uri=url_for('auth.google_callback', _external=True),
        scope=["openid", "email", "profile"],
    )
    authorization_url, state = oauth_session.authorization_url(
        discovery['authorization_endpoint']
    )
    session['oauth_state'] = state
    return redirect(authorization_url)


@auth_bp.route('/google/callback')
def google_callback():
    if not current_app.config.get('GOOGLE_CLIENT_ID'):
        return jsonify({"msg": "Google OAuth is not configured on this server"}), 501
    try:
        discovery = requests.get(
            current_app.config['GOOGLE_DISCOVERY_URL'], timeout=5
        ).json()
    except requests.exceptions.RequestException as e:
        return jsonify({"msg": "Could not reach Google", "error": str(e)}), 502

    oauth_session = OAuth2Session(
        client_id=current_app.config['GOOGLE_CLIENT_ID'],
        state=session.get('oauth_state'),
        redirect_uri=url_for('auth.google_callback', _external=True),
    )
    try:
        oauth_session.fetch_token(
            discovery['token_endpoint'],
            client_secret=current_app.config['GOOGLE_CLIENT_SECRET'],
            authorization_response=request.url,
        )
    except Exception as e:
        return jsonify({"msg": "Failed to fetch token from Google", "error": str(e)}), 400

    user_info = oauth_session.get(discovery['userinfo_endpoint']).json()
    email = user_info.get('email', '').strip().lower()
    name = user_info.get('name', 'Google User')

    user = User.query.filter_by(email=email).first()
    if not user:
        user = User(name=name, email=email, role=Role.CITIZEN)
        db.session.add(user)
        db.session.commit()

    token = create_access_token(identity=str(user.id))
    frontend_url = current_app.config.get('FRONTEND_CALLBACK_URL', 'http://localhost:5500')
    return redirect(f"{frontend_url}/login/callback?access_token={token}")


# ── Logout ────────────────────────────────────────────────────────────────────

@auth_bp.route('/logout', methods=['POST'])
def logout():
    # JWT is stateless — client drops the token; optionally add a blocklist here
    return jsonify({"msg": "Logout successful"}), 200


# ── Guest Login ───────────────────────────────────────────────────────────────

@auth_bp.route('/guest-login', methods=['POST'])
@limiter.limit("5 per hour")
def guest_login():
    guest = User(name="Guest User", role=Role.CITIZEN)
    db.session.add(guest)
    db.session.commit()
    return jsonify({
        "access_token": create_access_token(identity=str(guest.id)),
        "refresh_token": create_refresh_token(identity=str(guest.id)),
        "msg": "Logged in as Guest",
    }), 200


# ── Current User ──────────────────────────────────────────────────────────────

@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    user = db.session.get(User, int(get_jwt_identity()))
    if not user:
        return jsonify({"msg": "User not found"}), 404
    return jsonify(UserSchema().dump(user)), 200


@auth_bp.route('/me', methods=['PUT'])
@jwt_required()
def update_current_user():
    current_user_id = int(get_jwt_identity())
    user = db.session.get(User, current_user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    data = request.form
    if 'name' in data:
        user.name = data['name'].strip()
    if 'email' in data:
        new_email = data['email'].strip().lower()
        if User.query.filter(User.email == new_email, User.id != current_user_id).first():
            return jsonify({"msg": "Email already exists"}), 400
        user.email = new_email
    if data.get('password'):
        if len(data['password']) < 6:
            return jsonify({"msg": "Password must be at least 6 characters"}), 400
        user.set_password(data['password'])
    if 'address' in data:
        user.address = data['address']

    if 'profile_picture' in request.files:
        file = request.files['profile_picture']
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            user_dir = os.path.join(current_app.config['UPLOAD_FOLDER'], f'user_{user.id}')
            os.makedirs(user_dir, exist_ok=True)
            file.save(os.path.join(user_dir, filename))
            user.profile_picture = f'user_{user.id}/{filename}'
        else:
            return jsonify({"msg": "Invalid file type"}), 400
    try:
        db.session.commit()
        return jsonify(UserSchema().dump(user))
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Update failed: duplicate data"}), 400
    except Exception as e:
        db.session.rollback()
        logger.error("Profile update error: %s", e)
        return jsonify({"msg": "Update failed"}), 500


# ── OTP ───────────────────────────────────────────────────────────────────────

@auth_bp.route('/otp/request', methods=['POST'])
@limiter.limit("5 per 10 minutes")
def otp_request():
    """Proxy to your existing OTP request logic."""
    # Placeholder: integrate with Twilio or your SMS provider here
    data = request.json or {}
    phone = data.get('phone_number', '').strip()
    if not phone:
        return jsonify({"msg": "phone_number is required"}), 400
    # TODO: generate OTP, store it (e.g. in Redis/DB), send via Twilio
    return jsonify({"msg": "OTP sent"}), 200


@auth_bp.route('/otp/verify', methods=['POST'])
@limiter.limit("10 per 10 minutes")
def otp_verify():
    """Verify OTP and return JWT."""
    data = request.json or {}
    phone = data.get('phone_number', '').strip()
    otp = data.get('otp', '').strip()
    if not phone or not otp:
        return jsonify({"msg": "phone_number and otp are required"}), 400
    # TODO: validate OTP against stored value
    user = User.query.filter_by(phone_number=phone).first()
    if not user:
        return jsonify({"msg": "No account found for this phone number"}), 404
    return jsonify({
        "access_token": create_access_token(identity=str(user.id)),
        "refresh_token": create_refresh_token(identity=str(user.id)),
    }), 200


# ── Password Reset ────────────────────────────────────────────────────────────

@auth_bp.route('/forgot-password', methods=['POST'])
@limiter.limit("5 per hour")
def forgot_password():
    s = URLSafeTimedSerializer(current_app.config['SECRET_KEY'])
    email = (request.get_json() or {}).get('email', '').strip().lower()
    if not email:
        return jsonify({'error': 'Email required'}), 400

    user = User.query.filter_by(email=email).first()
    # Always return same message to prevent user enumeration
    if not user:
        return jsonify({'msg': 'If that email exists, a reset link has been sent.'}), 200

    token = s.dumps(email, salt='password-reset-salt')
    frontend_url = current_app.config.get('FRONTEND_CALLBACK_URL', 'http://localhost:5500')
    reset_link = f"{frontend_url}/reset-password/{token}"

    msg = Message(
        'Password Reset Request',
        sender=current_app.config['MAIL_USERNAME'],
        recipients=[email],
    )
    msg.body = (
        f"Click the link below to reset your PCMC Grievance System password.\n\n"
        f"{reset_link}\n\nThis link expires in 1 hour.\n\n"
        f"If you did not request this, please ignore this email."
    )
    try:
        mail.send(msg)
    except Exception as e:
        logger.error("Email send failed: %s", e)
        return jsonify({'error': 'Failed to send reset email'}), 500
    return jsonify({'msg': 'If that email exists, a reset link has been sent.'}), 200


@auth_bp.route('/reset-password/<token>', methods=['POST'])
def reset_password(token):
    s = URLSafeTimedSerializer(current_app.config['SECRET_KEY'])
    try:
        email = s.loads(token, salt='password-reset-salt', max_age=3600)
    except (SignatureExpired, BadTimeSignature):
        return jsonify({'error': 'Token is invalid or has expired'}), 400

    user = User.query.filter_by(email=email).first_or_404()
    new_password = (request.get_json() or {}).get('password', '')
    if len(new_password) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400
    user.set_password(new_password)
    db.session.commit()
    return jsonify({'msg': 'Password reset successfully'}), 200


# ── Seed Sample Users (Temporary for testing) ─────────────────────────────────

@auth_bp.route('/seed-sample', methods=['POST'])
def seed_sample():
    """Seed sample users if they don't exist. Temporary route for testing."""
    sample_users = [
        ("Admin User", "admin@pcmc.gov.in", Role.ADMIN),
        ("Member Head", "member@pcmc.gov.in", Role.MEMBER_HEAD),
        ("Field Staff", "field@pcmc.gov.in", Role.FIELD_STAFF),
        ("Test Citizen", "citizen@example.com", Role.CITIZEN),
    ]
    seeded = []
    for name, email, role in sample_users:
        if not User.query.filter_by(email=email).first():
            u = User(name=name, email=email, role=role)
            u.set_password("Test@1234")
            db.session.add(u)
            seeded.append(email)
    if seeded:
        db.session.commit()
        return jsonify({"msg": f"Sample users seeded: {seeded}"}), 200
    else:
        return jsonify({"msg": "Sample users already exist"}), 200

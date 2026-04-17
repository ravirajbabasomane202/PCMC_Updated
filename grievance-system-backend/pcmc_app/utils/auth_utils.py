import logging
from functools import wraps

from flask import jsonify, request
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

from ..models import Role, User
from .. import db

logger = logging.getLogger(__name__)


def jwt_required_with_role(roles):
    """Decorator that validates JWT and enforces role-based access."""
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            if request.method == "OPTIONS":
                return jsonify({}), 200
            try:
                verify_jwt_in_request()
                current_user_id = get_jwt_identity()
            except Exception:
                return jsonify({"msg": "Missing or invalid JWT"}), 401

            user = db.session.get(User, int(current_user_id))
            if not user:
                logger.warning("JWT user not found: %s", current_user_id)
                return jsonify({"msg": "User not found"}), 404

            if user.role not in roles:
                logger.warning("Access denied for user %s with role %s", user.id, user.role)
                return jsonify({"msg": "Access forbidden"}), 403

            return fn(user, *args, **kwargs)
        return decorator
    return wrapper


# Convenience decorators
def citizen_required(fn):
    return jwt_required_with_role([Role.CITIZEN])(fn)

def member_head_required(fn):
    return jwt_required_with_role([Role.MEMBER_HEAD])(fn)

def field_staff_required(fn):
    return jwt_required_with_role([Role.FIELD_STAFF])(fn)

def admin_required(fn):
    return jwt_required_with_role([Role.ADMIN])(fn)

def citizen_or_admin_required(fn):
    return jwt_required_with_role([Role.CITIZEN, Role.ADMIN, Role.MEMBER_HEAD, Role.FIELD_STAFF])(fn)

def field_staff_or_admin_required(fn):
    return jwt_required_with_role([Role.FIELD_STAFF, Role.ADMIN, Role.MEMBER_HEAD])(fn)

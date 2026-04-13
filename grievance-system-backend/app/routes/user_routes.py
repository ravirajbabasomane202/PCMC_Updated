from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..models import MasterAreas, NearbyPlace, Role, User
from ..schemas import GrievanceSchema, NearbyPlaceSchema, UserSchema
from ..services.user_service import add_update_user
from ..utils.auth_utils import admin_required
from .. import db

user_bp = Blueprint('user', __name__)
nearby_places_schema = NearbyPlaceSchema(many=True)


@user_bp.route('/', methods=['GET'])
@admin_required
def get_users(user):
    users = User.query.filter(User.role != Role.ADMIN).all()
    return jsonify(UserSchema(many=True).dump(users)), 200


@user_bp.route('/<int:id>', methods=['GET'])
@admin_required
def get_user(user, id):
    target = db.session.get(User, id)
    if not target:
        return jsonify({"msg": "User not found"}), 404
    return jsonify(UserSchema().dump(target)), 200


@user_bp.route('/admin/users', methods=['GET'])
@admin_required
def get_all_users(user):
    users = User.query.all()
    return jsonify(UserSchema(many=True, exclude=['password']).dump(users)), 200


@user_bp.route('/admin/users', methods=['POST'])
@admin_required
def create_user(user):
    data = request.json
    role_mapping = {r.value: r for r in Role}
    if 'role' in data:
        data['role'] = role_mapping.get(data['role'])
        if data['role'] is None:
            return jsonify({"msg": "Invalid role"}), 400
    try:
        return jsonify(add_update_user(data)), 201
    except ValueError as e:
        return jsonify({"msg": str(e)}), 400
    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@user_bp.route('/nearby/<string:category>', methods=['GET'])
@jwt_required()
def get_nearby_by_category(category):
    places = NearbyPlace.query.filter(NearbyPlace.category.ilike(category)).all()
    return jsonify(nearby_places_schema.dump(places))

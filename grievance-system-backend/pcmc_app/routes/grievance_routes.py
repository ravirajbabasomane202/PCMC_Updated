import logging
from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import jwt_required

from .. import db
from ..models import Grievance, GrievanceStatus, MasterConfig, Role, User
from ..schemas import GrievanceSchema, GrievanceCommentSchema
from ..services.grievance_service import (
    accept_grievance, add_comment, confirm_closure, escalate_grievance,
    get_assigned_grievances, get_new_grievances, get_rejection_reason,
    log_audit, reject_grievance, save_workproof_record, submit_grievance,
    update_status,
)
from ..utils.auth_utils import (
    admin_required, citizen_or_admin_required, citizen_required,
    field_staff_or_admin_required, field_staff_required,
    jwt_required_with_role, member_head_required,
)

logger = logging.getLogger(__name__)
grievance_bp = Blueprint('grievances', __name__)


@grievance_bp.route('/', methods=['POST'])
@citizen_required
def create_grievance(user):
    try:
        if request.content_type and request.content_type.startswith('multipart/form-data'):
            data = request.form.to_dict()
        else:
            data = request.json
        files = request.files.getlist('attachments')

        if not data.get('priority'):
            cfg = MasterConfig.query.filter_by(key='DEFAULT_PRIORITY').first()
            data['priority'] = cfg.value if cfg else 'medium'
        if data.get('latitude'):
            data['latitude'] = float(data['latitude'])
        if data.get('longitude'):
            data['longitude'] = float(data['longitude'])

        result = submit_grievance(user.id, data, files)
        log_audit(f"Grievance created by user {user.id}", user.id, result.get('id'))
        return jsonify(result), 201
    except Exception as e:
        logger.error("Error creating grievance: %s", e)
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/mine', methods=['GET'])
@citizen_or_admin_required
def my_grievances(user):
    try:
        if user.role in (Role.ADMIN, Role.MEMBER_HEAD):
            grievances = Grievance.query.order_by(Grievance.created_at.desc()).all()
        else:
            grievances = Grievance.query.filter_by(citizen_id=user.id)\
                .order_by(Grievance.created_at.desc()).all()
        return jsonify([g.to_dict() for g in grievances]), 200
    except Exception as e:
        logger.error("Error fetching grievances for user %s: %s", user.id, e)
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/track', methods=['GET'])
@jwt_required_with_role([Role.CITIZEN])
def track_grievances(user):
    try:
        grievances = Grievance.query.filter_by(citizen_id=user.id)\
            .order_by(Grievance.created_at.desc()).all()
        return jsonify(GrievanceSchema(many=True).dump(grievances)), 200
    except Exception as e:
        logger.error("Error tracking grievances for user %s: %s", user.id, e)
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/all', methods=['GET'])
@member_head_required
def new_grievances(user):
    try:
        result, _ = get_new_grievances()
        return jsonify(result), 200
    except Exception as e:
        logger.error("Error fetching new grievances: %s", e)
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/assigned', methods=['GET'])
@field_staff_required
def assigned_grievances(user):
    try:
        result, _ = get_assigned_grievances(user.id)
        return jsonify(result), 200
    except Exception as e:
        logger.error("Error fetching assigned grievances for user %s: %s", user.id, e)
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/search/<string:complaint_id>', methods=['GET'])
@jwt_required_with_role([Role.CITIZEN, Role.MEMBER_HEAD, Role.FIELD_STAFF, Role.ADMIN])
def search_by_complaint_id(user, complaint_id):
    grievance = Grievance.query.filter_by(complaint_id=complaint_id).first()
    if not grievance:
        return jsonify({"msg": "Grievance not found"}), 404
    return jsonify(GrievanceSchema().dump(grievance)), 200


@grievance_bp.route('/<int:id>', methods=['GET'])
@jwt_required_with_role([Role.CITIZEN, Role.MEMBER_HEAD, Role.FIELD_STAFF, Role.ADMIN])
def get_grievance(user, id):
    grievance = db.session.get(Grievance, id)
    if not grievance:
        return jsonify({"msg": "Grievance not found"}), 404
    if user.role != Role.ADMIN and grievance.citizen_id != user.id:
        if user.role not in (Role.MEMBER_HEAD, Role.FIELD_STAFF) or grievance.assigned_to != user.id:
            return jsonify({"msg": "Access forbidden"}), 403
    return jsonify(GrievanceSchema().dump(grievance)), 200


@grievance_bp.route('/<int:grievance_id>', methods=['PUT'])
@jwt_required_with_role([Role.CITIZEN])
def update_grievance(user, grievance_id):
    grievance = Grievance.query.get_or_404(grievance_id)
    if grievance.citizen_id != user.id:
        return jsonify({"error": "Unauthorized"}), 403
    data = request.get_json()
    for field in ('title', 'description', 'area_id', 'subject_id', 'address'):
        if field in data:
            setattr(grievance, field, data[field])
    try:
        db.session.commit()
        return jsonify({"message": "Grievance updated", "id": grievance.id}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


@grievance_bp.route('/<int:grievance_id>', methods=['DELETE'])
@jwt_required_with_role([Role.CITIZEN, Role.ADMIN])
def delete_grievance(user, grievance_id):
    grievance = Grievance.query.get_or_404(grievance_id)
    if user.role != Role.ADMIN and grievance.citizen_id != user.id:
        return jsonify({"msg": "Permission denied"}), 403
    db.session.delete(grievance)
    db.session.commit()
    log_audit(f"Grievance {grievance_id} deleted", user.id, grievance_id)
    return jsonify({"message": "Grievance deleted"})


@grievance_bp.route('/<int:id>/comments', methods=['POST'])
@jwt_required_with_role([Role.CITIZEN, Role.MEMBER_HEAD, Role.FIELD_STAFF, Role.ADMIN])
def add_grievance_comment(user, id):
    try:
        if request.content_type and request.content_type.startswith('multipart/form-data'):
            data = request.form.to_dict()
            files = request.files.getlist('attachments')
        else:
            data = request.get_json()
            files = []
        comment_text = data.get('comment_text')
        if not comment_text:
            return jsonify({"msg": "Comment text is required"}), 400
        result = add_comment(id, user.id, comment_text, files)
        log_audit(f"Comment added to grievance {id}", user.id, id)
        return jsonify(result), 201
    except Exception as e:
        logger.error("Error adding comment to grievance %s: %s", id, e)
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/<int:id>/close', methods=['POST'])
@citizen_required
def close_grievance(user, id):
    try:
        result = confirm_closure(id, user.id)
        log_audit(f"Grievance {id} closed", user.id, id)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/<int:id>/rejection', methods=['GET'])
@citizen_required
def rejection_reason(user, id):
    try:
        reason = get_rejection_reason(id, user.id)
        return jsonify({"rejection_reason": reason}), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/<int:id>/accept', methods=['POST'])
@member_head_required
def accept(user, id):
    try:
        result = accept_grievance(id, user.id, request.get_json())
        log_audit(f"Grievance {id} accepted", user.id, id)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/<int:id>/reject', methods=['POST'])
@member_head_required
def reject(user, id):
    data = request.get_json() or {}
    reason = data.get('reason')
    if not reason:
        return jsonify({"msg": "Rejection reason is required"}), 400
    try:
        result = reject_grievance(id, user.id, reason)
        log_audit(f"Grievance {id} rejected", user.id, id)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/<int:id>/status', methods=['PUT', 'POST'])
@field_staff_or_admin_required
def update_grievance_status(user, id):
    new_status_str = (request.json or {}).get('status')
    try:
        grievance = db.session.get(Grievance, id)
        if not grievance:
            return jsonify({"error": "Grievance not found"}), 404
        if grievance.assigned_to != user.id and user.role not in (Role.ADMIN, Role.MEMBER_HEAD):
            return jsonify({"error": "Not authorized"}), 403
        old_status = grievance.status
        grievance.status = GrievanceStatus[new_status_str.upper()]
        if grievance.status == GrievanceStatus.RESOLVED:
            grievance.resolved_at = datetime.now(timezone.utc)
        db.session.commit()
        log_audit(f'Status updated from {old_status} to {grievance.status}', user.id, id)
        return jsonify(GrievanceSchema().dump(grievance)), 200
    except (KeyError, ValueError) as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


@grievance_bp.route('/<int:id>/workproof', methods=['POST'])
@field_staff_required
def upload_grievance_workproof(user, id):
    file = request.files.get('file')
    if not file:
        return jsonify({"msg": "File is required"}), 400
    try:
        result = save_workproof_record(id, user.id, file, request.form.get('notes'))
        log_audit(f"Workproof uploaded for grievance {id}", user.id, id)
        return jsonify(result), 201
    except Exception as e:
        return jsonify({"msg": str(e)}), 400


@grievance_bp.route('/<int:id>/feedback', methods=['POST'])
@citizen_required
def submit_feedback(user, id):
    grievance = Grievance.query.get_or_404(id)
    if grievance.citizen_id != user.id or grievance.status != GrievanceStatus.RESOLVED:
        return jsonify({"msg": "Grievance must be resolved and owned by user"}), 400
    data = request.get_json()
    rating = data.get('rating')
    if not isinstance(rating, int) or not (1 <= rating <= 5):
        return jsonify({"msg": "Valid rating (1-5) required"}), 400
    grievance.feedback_rating = rating
    grievance.feedback_text = data.get('feedback_text')
    db.session.commit()
    log_audit(f"Feedback submitted for grievance {id}", user.id, id)
    return jsonify({"msg": "Feedback submitted"}), 200


@grievance_bp.route('/<int:id>/reassign', methods=['PUT'])
@field_staff_or_admin_required
def reassign_grievance(user, id):
    data = request.get_json()
    assignee_id = data.get('assignee_id')
    if not assignee_id:
        return jsonify({"msg": "Assignee ID required"}), 400
    grievance = Grievance.query.get_or_404(id)
    assignee = db.session.get(User, assignee_id)
    if not assignee or assignee.role != Role.FIELD_STAFF:
        return jsonify({"msg": "Assignee must be field staff"}), 400
    grievance.assigned_to = assignee_id
    db.session.commit()
    log_audit(f"Grievance {id} reassigned to {assignee_id}", user.id, id)
    return jsonify({"msg": "Grievance reassigned"}), 200


@grievance_bp.route('/<int:id>/escalate', methods=['POST'])
@admin_required
def escalate(user, id):
    try:
        data = request.get_json() or {}
        result = escalate_grievance(id, user.id, new_assignee_id=data.get('assignee_id'))
        return jsonify(result), 200 if result.get('success') else 404
    except Exception as e:
        return jsonify({"msg": str(e)}), 400

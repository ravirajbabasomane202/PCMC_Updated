import logging
import os
from datetime import datetime, timezone

from flask import Blueprint, Response, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from werkzeug.utils import secure_filename

from ..models import (
    Announcement, Advertisement, AuditLog, Grievance, MasterAreas,
    MasterCategories, MasterConfig, MasterSubjects, NearbyPlace, Role, User,
)
from ..schemas import (
    AnnouncementSchema, AuditLogSchema, GrievanceSchema, MasterAreasSchema,
    MasterSubjectsSchema, NearbyPlaceSchema, UserSchema,
)
from ..services.grievance_service import log_audit
from ..services.report_service import (
    escalate_grievance, generate_report, get_advanced_kpis,
    get_citizen_history, get_location_reports, get_staff_performance,
)
from ..services.user_service import add_update_user
from ..utils.auth_utils import admin_required
from ..utils.kpi_utils import calculate_pending_aging, calculate_resolution_rate, calculate_sla_compliance
from .. import db

logger = logging.getLogger(__name__)
admin_bp = Blueprint('admin', __name__)

nearby_place_schema = NearbyPlaceSchema()
nearby_places_schema = NearbyPlaceSchema(many=True)


# ── Dashboard ────────────────────────────────────────────────────────────────

@admin_bp.route('/dashboard', methods=['GET'])
@admin_required
def dashboard(user):
    return jsonify({
        'resolution_rate': calculate_resolution_rate(),
        'pending_aging': calculate_pending_aging(),
        'sla_compliance': calculate_sla_compliance(),
    }), 200


# ── Users ────────────────────────────────────────────────────────────────────

@admin_bp.route('/users', methods=['GET'])
@admin_required
def list_users(user):
    users = User.query.all()
    return jsonify(UserSchema(many=True, exclude=['password']).dump(users)), 200


@admin_bp.route('/users', methods=['POST'])
@admin_required
def create_user(user):
    data = request.json
    if not data:
        return jsonify({"msg": "No data provided"}), 400
    try:
        return jsonify(add_update_user(data)), 201
    except ValueError as e:
        return jsonify({"msg": str(e)}), 400
    except IntegrityError:
        return jsonify({"msg": "Duplicate data"}), 409
    except Exception as e:
        logger.exception("create_user error")
        return jsonify({"msg": "Failed to create user", "error": str(e)}), 500


@admin_bp.route('/users/<int:id>', methods=['PUT'])
@admin_required
def update_user(user, id):
    data = request.json
    if not data:
        return jsonify({"msg": "No data provided"}), 400
    try:
        return jsonify(add_update_user(data, user_id=id)), 200
    except ValueError as e:
        return jsonify({"msg": str(e)}), 400
    except IntegrityError:
        return jsonify({"msg": "Duplicate data"}), 409
    except (SQLAlchemyError, AttributeError, Exception) as e:
        logger.exception("update_user error")
        return jsonify({"msg": "Failed to update user", "error": str(e)}), 500


@admin_bp.route('/users/<int:id>', methods=['DELETE'])
@admin_required
def delete_user(user, id):
    target = db.session.get(User, id)
    if not target:
        return jsonify({"msg": "User not found"}), 404
    try:
        db.session.delete(target)
        db.session.commit()
        return jsonify({"msg": "User deleted"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Failed to delete user", "error": str(e)}), 500


@admin_bp.route('/users/<int:id>/history', methods=['GET'])
@admin_required
def citizen_history(user, id):
    history = get_citizen_history(id)
    return jsonify(GrievanceSchema(many=True).dump(history)), 200


@admin_bp.route('/users/history', methods=['GET'])
@admin_required
def all_users_history(user):
    users = User.query.filter(User.role == Role.CITIZEN).all()
    schema = GrievanceSchema(many=True)
    result = [
        {
            "user": {"id": u.id, "name": u.name, "email": u.email, "role": u.role.value},
            "grievances": schema.dump(get_citizen_history(u.id)),
        }
        for u in users
    ]
    return jsonify(result), 200


# ── Subjects ─────────────────────────────────────────────────────────────────

@admin_bp.route('/subjects', methods=['GET'])
@admin_required
def list_subjects(user):
    return jsonify(MasterSubjectsSchema(many=True).dump(MasterSubjects.query.all())), 200


@admin_bp.route('/subjects', methods=['POST'])
@admin_required
def manage_subjects(user):
    data = request.json
    schema = MasterSubjectsSchema()
    errors = schema.validate(data)
    if errors:
        return jsonify(errors), 400
    try:
        subject = MasterSubjects(**data)
        db.session.add(subject)
        db.session.commit()
        return jsonify(schema.dump(subject)), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "Failed to save subject"}), 500


@admin_bp.route('/subjects/<int:id>', methods=['PUT'])
@admin_required
def update_subject(user, id):
    data = request.json
    schema = MasterSubjectsSchema()
    errors = schema.validate(data, partial=True)
    if errors:
        return jsonify(errors), 400
    subject = db.session.get(MasterSubjects, id)
    if not subject:
        return jsonify({"error": "Subject not found"}), 404
    subject.name = data.get("name", subject.name)
    subject.description = data.get("description", subject.description)
    db.session.commit()
    return jsonify(schema.dump(subject)), 200


@admin_bp.route('/subjects/<int:id>', methods=['DELETE'])
@admin_required
def delete_subject(user, id):
    subject = db.session.get(MasterSubjects, id)
    if not subject:
        return jsonify({"msg": "Subject not found"}), 404
    try:
        db.session.delete(subject)
        db.session.commit()
        return jsonify({"msg": "Subject deleted"}), 200
    except Exception as e:
        db.session.rollback()
        if 'foreign key' in str(e).lower():
            return jsonify({"msg": "Subject is in use by existing grievances"}), 409
        return jsonify({"msg": "Failed to delete subject"}), 500


# ── Areas ────────────────────────────────────────────────────────────────────

@admin_bp.route('/areas', methods=['GET'])
@admin_required
def list_areas(user):
    return jsonify(MasterAreasSchema(many=True).dump(MasterAreas.query.all())), 200


@admin_bp.route('/areas', methods=['POST'])
@admin_required
def manage_areas(user):
    data = request.json
    schema = MasterAreasSchema()
    errors = schema.validate(data)
    if errors:
        return jsonify(errors), 400
    area = MasterAreas(**data)
    db.session.add(area)
    db.session.commit()
    return jsonify(schema.dump(area)), 201


@admin_bp.route('/areas/<int:id>', methods=['PUT'])
@admin_required
def update_area(user, id):
    data = request.json
    area = db.session.get(MasterAreas, id)
    if not area:
        return jsonify({"error": "Area not found"}), 404
    area.name = data.get('name', area.name)
    area.description = data.get('description', area.description)
    db.session.commit()
    return jsonify(MasterAreasSchema().dump(area)), 200


@admin_bp.route('/areas/<int:id>', methods=['DELETE'])
@admin_required
def delete_area(user, id):
    area = db.session.get(MasterAreas, id)
    if not area:
        return jsonify({"msg": "Area not found"}), 404
    db.session.delete(area)
    db.session.commit()
    return jsonify({"msg": "Area deleted"}), 200


# ── Grievances ───────────────────────────────────────────────────────────────

@admin_bp.route('/grievances/all', methods=['GET'])
@admin_required
def get_all_grievances(user):
    try:
        query = Grievance.query
        if s := request.args.get('status'):
            query = query.filter_by(status=s)
        if p := request.args.get('priority'):
            query = query.filter_by(priority=p)
        if a := request.args.get('area_id', type=int):
            query = query.filter_by(area_id=a)
        if sub := request.args.get('subject_id', type=int):
            query = query.filter_by(subject_id=sub)
        grievances = query.order_by(Grievance.created_at.desc()).all()
        return jsonify([g.to_dict() for g in grievances])
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@admin_bp.route('/reassign/<int:grievance_id>', methods=['POST'])
@admin_required
def reassign_grievance(user, grievance_id):
    data = request.get_json()
    new_assignee_id = data.get('assigned_to')
    if not new_assignee_id:
        return jsonify({"success": False, "message": "Assignee ID required"}), 400
    grievance = db.session.get(Grievance, grievance_id)
    if not grievance:
        return jsonify({"success": False, "message": "Grievance not found"}), 404
    assignee = db.session.get(User, new_assignee_id)
    if not assignee or assignee.role != Role.FIELD_STAFF:
        return jsonify({"success": False, "message": "Invalid assignee"}), 400
    grievance.assigned_to = new_assignee_id
    grievance.assigned_by = user.id
    grievance.updated_at = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify({"success": True, "message": "Grievance reassigned"})


@admin_bp.route('/grievances/<int:id>/escalate', methods=['POST'])
@admin_required
def escalate(user, id):
    try:
        data = request.json or {}
        result = escalate_grievance(
            grievance_id=id,
            escalated_by=user.id,
            new_assignee_id=data.get('assignee_id'),
        )
        return jsonify(result), 200 if result.get("success") else 400
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ── Audit Logs ───────────────────────────────────────────────────────────────

@admin_bp.route('/audit-logs', methods=['GET'])
@admin_required
def audit_logs(user):
    logs = AuditLog.query.all()
    return jsonify(AuditLogSchema(many=True).dump(logs)), 200


# ── Reports / KPIs ───────────────────────────────────────────────────────────

@admin_bp.route('/reports', methods=['GET'])
@admin_required
def reports(user):
    filter_type = request.args.get('filter_type', 'all')
    fmt = request.args.get('format', 'pdf')
    report_data = generate_report(filter_type, fmt)
    mime_map = {
        'pdf': ('application/pdf', 'report.pdf'),
        'csv': ('text/csv', 'report.csv'),
        'excel': ('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'report.xlsx'),
    }
    if fmt not in mime_map:
        return jsonify({"error": "Invalid format. Supported: pdf, csv, excel"}), 400
    mimetype, filename = mime_map[fmt]
    return Response(report_data, mimetype=mimetype,
                    headers={"Content-Disposition": f"attachment; filename={filename}"})


@admin_bp.route('/reports/staff-performance', methods=['GET'])
@admin_required
def staff_performance(user):
    return jsonify(get_staff_performance()), 200


@admin_bp.route('/reports/location', methods=['GET'])
@admin_required
def location_reports(user):
    return jsonify(get_location_reports()), 200


@admin_bp.route('/reports/kpis/advanced', methods=['GET'])
@admin_required
def get_advanced_kpis_route(user):
    time_period = request.args.get('time_period', 'all')
    try:
        return jsonify(get_advanced_kpis(time_period)), 200
    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400
    except Exception as e:
        logger.exception("Advanced KPIs error")
        return jsonify({"error": str(e)}), 500


# ── Configs ──────────────────────────────────────────────────────────────────

@admin_bp.route('/configs', methods=['GET', 'POST'])
@admin_required
def manage_configs(user):
    if request.method == 'POST':
        data = request.json
        config = MasterConfig.query.filter_by(key=data['key']).first()
        if config:
            config.value = data['value']
            config.updated_at = datetime.now(timezone.utc)
            if 'description' in data:
                config.description = data['description']
        else:
            config = MasterConfig(key=data['key'], value=data['value'],
                                  description=data.get('description'))
            db.session.add(config)
        db.session.commit()

    configs = MasterConfig.query.all()
    return jsonify([
        {'id': c.id, 'key': c.key, 'value': c.value,
         'description': c.description,
         'created_at': c.created_at, 'updated_at': c.updated_at}
        for c in configs
    ]), 200


@admin_bp.route('/configs/<string:key>', methods=['PUT'])
@admin_required
def update_config(user, key):
    config = MasterConfig.query.filter_by(key=key).first()
    if not config:
        return jsonify({"error": "Config not found"}), 404
    config.value = request.json.get('value')
    config.updated_at = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify({'key': config.key, 'value': config.value}), 200


# ── Announcements ─────────────────────────────────────────────────────────────

@admin_bp.route('/announcements', methods=['GET'])
@jwt_required()
def get_announcements():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    now = datetime.now(timezone.utc)
    query = Announcement.query.filter(
        Announcement.is_active == True,
        db.or_(Announcement.expires_at > now, Announcement.expires_at == None),
    )
    if user.role != Role.ADMIN:
        query = query.filter(db.or_(
            Announcement.target_role == None,
            Announcement.target_role == user.role.value.upper(),
        ))
    announcements = query.order_by(Announcement.created_at.desc()).all()
    return jsonify(AnnouncementSchema(many=True).dump(announcements)), 200


@admin_bp.route('/announcements', methods=['POST'])
@admin_required
def create_announcement(user):
    data = request.json
    schema = AnnouncementSchema()
    errors = schema.validate(data)
    if errors:
        return jsonify(errors), 400
    if data.get("target_role"):
        data["target_role"] = data["target_role"].upper()
    if data.get("expires_at"):
        try:
            data["expires_at"] = datetime.fromisoformat(data["expires_at"].replace("Z", ""))
        except ValueError:
            return jsonify({"error": "Invalid date format for expires_at"}), 400
    announcement = Announcement(**data)
    db.session.add(announcement)
    db.session.commit()
    return jsonify(schema.dump(announcement)), 201


@admin_bp.route('/announcements/<int:id>', methods=['DELETE'])
@admin_required
def delete_announcement(user, id):
    announcement = db.session.get(Announcement, id)
    if not announcement:
        return jsonify({"msg": "Announcement not found"}), 404
    try:
        db.session.delete(announcement)
        db.session.commit()
        return jsonify({"msg": "Announcement deleted"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Failed to delete announcement", "error": str(e)}), 500


# ── Nearby Places ─────────────────────────────────────────────────────────────

@admin_bp.route('/nearby', methods=['POST'])
@admin_required
def add_nearby_place(user):
    place = NearbyPlace(**request.get_json())
    db.session.add(place)
    db.session.commit()
    return jsonify({"message": "Added", "data": nearby_place_schema.dump(place)}), 201


@admin_bp.route('/nearby', methods=['GET'])
@admin_required
def get_all_nearby(user):
    return jsonify(nearby_places_schema.dump(NearbyPlace.query.all()))


@admin_bp.route('/nearby/<int:id>', methods=['PUT'])
@admin_required
def update_nearby(user, id):
    place = NearbyPlace.query.get_or_404(id)
    for key, value in request.get_json().items():
        setattr(place, key, value)
    db.session.commit()
    return jsonify({"message": "Updated", "data": nearby_place_schema.dump(place)})


@admin_bp.route('/nearby/<int:id>', methods=['DELETE'])
@admin_required
def delete_nearby(user, id):
    place = NearbyPlace.query.get_or_404(id)
    db.session.delete(place)
    db.session.commit()
    return jsonify({"message": "Deleted"})


# ── Advertisements ────────────────────────────────────────────────────────────

@admin_bp.route('/ads', methods=['GET'])
@admin_required
def get_ads(user):
    try:
        now = datetime.now(timezone.utc)
        # Deactivate expired ads
        Advertisement.query.filter(
            Advertisement.is_active == True,
            Advertisement.expires_at != None,
            Advertisement.expires_at <= now,
        ).update({"is_active": False})
        db.session.commit()
        ads = Advertisement.query.order_by(Advertisement.created_at.desc()).all()
        return jsonify([ad.to_dict() for ad in ads])
    except Exception as e:
        return jsonify({'error': str(e)}), 500


def _save_ad_image(file):
    """Save an uploaded ad image and return its relative path."""
    ads_folder = os.path.join(current_app.config['UPLOAD_FOLDER'], 'ads')
    os.makedirs(ads_folder, exist_ok=True)
    filename = secure_filename(file.filename)
    file.save(os.path.join(ads_folder, filename))
    return f'ads/{filename}'


@admin_bp.route('/ads', methods=['POST'])
@admin_required
def create_ad(user):
    if 'title' not in request.form:
        return jsonify({'error': 'Title is required'}), 400
    try:
        expires_at = None
        if expires_str := request.form.get('expires_at'):
            expires_at = datetime.fromisoformat(expires_str.replace('Z', '+00:00'))

        image_url = None
        if 'image_file' in request.files:
            f = request.files['image_file']
            if f.filename:
                image_url = _save_ad_image(f)

        ad = Advertisement(
            title=request.form['title'],
            description=request.form.get('description'),
            image_url=image_url,
            link_url=request.form.get('link_url'),
            expires_at=expires_at,
            is_active=request.form.get('is_active', 'true').lower() == 'true',
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        db.session.add(ad)
        db.session.commit()
        return jsonify({'message': 'Advertisement created', 'data': ad.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@admin_bp.route('/ads/<int:ad_id>', methods=['PUT'])
@admin_required
def update_ad(user, ad_id):
    ad = Advertisement.query.get_or_404(ad_id)
    ad.title = request.form.get('title', ad.title)
    ad.description = request.form.get('description', ad.description)
    ad.link_url = request.form.get('link_url', ad.link_url)
    if (is_active_str := request.form.get('is_active')) is not None:
        ad.is_active = is_active_str.lower() in ('true', '1')
    if expires_str := request.form.get('expires_at'):
        ad.expires_at = datetime.fromisoformat(expires_str.replace('Z', '+00:00'))
    if 'image_file' in request.files:
        f = request.files['image_file']
        if f and f.filename:
            if ad.image_url:
                old = os.path.join(current_app.config['UPLOAD_FOLDER'], ad.image_url)
                if os.path.exists(old):
                    os.remove(old)
            ad.image_url = _save_ad_image(f)
    db.session.commit()
    return jsonify({"message": "Advertisement updated"}), 200


@admin_bp.route('/ads/<int:ad_id>', methods=['DELETE'])
@admin_required
def delete_ad(user, ad_id):
    ad = Advertisement.query.get_or_404(ad_id)
    db.session.delete(ad)
    db.session.commit()
    return jsonify({"message": "Advertisement deleted"}), 200

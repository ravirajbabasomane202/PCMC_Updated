import logging
import os
from datetime import datetime, timedelta, timezone

from flask import current_app
from marshmallow import ValidationError
from werkzeug.utils import secure_filename

from ..config import Config
from ..models import (
    AuditLog, CommentAttachment, Grievance, GrievanceAttachment,
    GrievanceComment, GrievanceStatus, Priority, User, Role, Workproof,
)
from ..schemas import GrievanceCommentSchema, GrievanceSchema, WorkproofSchema
from ..utils.file_utils import upload_files
from .. import db

logger = logging.getLogger(__name__)


# ── Audit ───────────────────────────────────────────────────────────────────

def log_audit(action, user_id, grievance_id=None):
    try:
        log = AuditLog(action=action, performed_by=user_id, grievance_id=grievance_id)
        db.session.add(log)
        db.session.commit()
    except Exception as e:
        logger.error("Audit log failed for action '%s': %s", action, e)
        raise


# ── Submission ───────────────────────────────────────────────────────────────

def submit_grievance(citizen_id, data, files):
    schema = GrievanceSchema()
    try:
        validated = schema.load(data)
    except ValidationError as err:
        raise ValueError(f"Invalid grievance data: {err.messages}")

    grievance = Grievance(
        citizen_id=citizen_id,
        subject_id=validated['subject_id'],
        area_id=validated['area_id'],
        title=validated['title'],
        description=validated['description'],
        latitude=validated.get('latitude'),
        longitude=validated.get('longitude'),
        address=validated.get('address'),
        status=GrievanceStatus.NEW,
        priority=validated.get('priority', Priority.MEDIUM),
    )
    db.session.add(grievance)
    db.session.flush()

    if files:
        try:
            for path, typ, size in upload_files(files, grievance.id):
                db.session.add(GrievanceAttachment(
                    grievance_id=grievance.id,
                    file_path=path,
                    file_type=typ,
                    file_size=size,
                ))
        except ValueError:
            db.session.rollback()
            raise

    db.session.commit()
    log_audit(f'Grievance created (ID {grievance.complaint_id})', citizen_id, grievance.id)
    return schema.dump(grievance)


# ── Queries ──────────────────────────────────────────────────────────────────

def get_my_grievances(citizen_id, page=1, per_page=20):
    result = (Grievance.query
              .filter_by(citizen_id=citizen_id)
              .order_by(Grievance.created_at.desc())
              .paginate(page=page, per_page=per_page, error_out=False))
    return GrievanceSchema(many=True).dump(result.items), result.total


def get_grievance_details(id, user_id):
    grievance = db.session.get(Grievance, id)
    if not grievance:
        return None
    user = db.session.get(User, user_id)
    if not user:
        return None
    if user.role != Role.ADMIN and grievance.citizen_id != user_id:
        return None
    _check_auto_close(grievance)
    return GrievanceSchema().dump(grievance)


def get_new_grievances(page=1, per_page=20):
    result = (Grievance.query
              .order_by(Grievance.created_at.desc())
              .paginate(page=page, per_page=per_page, error_out=False))
    return GrievanceSchema(many=True).dump(result.items), result.total


def get_assigned_grievances(employer_id, page=1, per_page=20):
    result = (Grievance.query
              .filter_by(assigned_to=employer_id)
              .order_by(Grievance.created_at.desc())
              .paginate(page=page, per_page=per_page, error_out=False))
    return GrievanceSchema(many=True).dump(result.items), result.total


# ── Actions ──────────────────────────────────────────────────────────────────

def add_comment(grievance_id, user_id, comment_text, files=None):
    grievance = Grievance.query.get_or_404(grievance_id)
    comment = GrievanceComment(
        grievance_id=grievance_id,
        user_id=user_id,
        comment_text=comment_text,
        is_public=True,
    )
    db.session.add(comment)
    db.session.flush()

    if files:
        for path, file_type, file_size in upload_files(files, grievance_id):
            db.session.add(CommentAttachment(
                comment_id=comment.id,
                file_path=path,
                file_type=file_type,
                file_size=file_size,
            ))

    db.session.commit()
    return GrievanceCommentSchema().dump(comment)


def confirm_closure(id, citizen_id):
    grievance = db.session.get(Grievance, id)
    if not grievance or grievance.citizen_id != citizen_id or grievance.status != GrievanceStatus.RESOLVED:
        raise ValueError("Invalid operation")
    grievance.status = GrievanceStatus.CLOSED
    grievance.updated_at = datetime.now(timezone.utc)
    db.session.commit()
    log_audit('Grievance closed', citizen_id, id)
    return {"msg": "Closed"}


def get_rejection_reason(id, citizen_id):
    grievance = db.session.get(Grievance, id)
    if not grievance or grievance.citizen_id != citizen_id or grievance.status != GrievanceStatus.REJECTED:
        raise ValueError("Invalid operation")
    return grievance.rejection_reason


def accept_grievance(id, head_id, data):
    grievance = db.session.get(Grievance, id)
    head_user = db.session.get(User, head_id)
    if not grievance or grievance.status != GrievanceStatus.NEW or grievance.area_id != head_user.department_id:
        raise ValueError("Invalid operation")
    grievance.priority = Priority[data['priority']]
    grievance.assigned_to = data['assigned_to']
    grievance.assigned_by = head_id
    grievance.status = GrievanceStatus.IN_PROGRESS
    db.session.commit()
    log_audit('Grievance accepted and assigned', head_id, id)
    return {"msg": "Accepted"}


def reject_grievance(id, head_id, reason):
    grievance = db.session.get(Grievance, id)
    if not grievance:
        raise ValueError("Grievance not found")
    grievance.status = GrievanceStatus.REJECTED
    grievance.rejection_reason = reason
    db.session.commit()
    log_audit('Grievance rejected', head_id, id)
    return {"msg": "Rejected"}


def update_status(id, employer_id, new_status):
    grievance = db.session.get(Grievance, id)
    if not grievance or grievance.assigned_to != employer_id:
        raise ValueError("Invalid operation")
    old_status = grievance.status
    grievance.status = GrievanceStatus[new_status.upper()]
    if grievance.status == GrievanceStatus.RESOLVED:
        grievance.resolved_at = datetime.now(timezone.utc)
    db.session.commit()
    log_audit(f'Status updated from {old_status} to {grievance.status}', employer_id, id)
    return {"msg": "Status updated"}


def reassign_grievance(id, new_assigned_to, admin_id):
    grievance = db.session.get(Grievance, id)
    if not grievance:
        raise ValueError("Grievance not found")
    grievance.assigned_to = new_assigned_to
    db.session.commit()
    log_audit('Grievance reassigned', admin_id, id)
    return {"msg": "Reassigned"}


def save_workproof_record(grievance_id, employer_id, file, notes):
    grievance = db.session.get(Grievance, grievance_id)
    if not grievance or grievance.assigned_to != employer_id:
        raise ValueError("Invalid operation")

    upload_folder = current_app.config.get("UPLOAD_FOLDER", "uploads")
    grievance_folder = os.path.join(upload_folder, str(grievance_id))
    os.makedirs(grievance_folder, exist_ok=True)
    filename = secure_filename(file.filename)
    filepath = os.path.join(grievance_folder, filename)
    file.save(filepath)

    # Store relative path only
    relative_path = os.path.join(str(grievance_id), filename).replace('\\', '/')

    workproof = Workproof(
        grievance_id=grievance_id,
        uploaded_by=employer_id,
        file_path=relative_path,
        notes=notes or '',
        file_type=filename.rsplit('.', 1)[-1].lower(),
        file_size=os.path.getsize(filepath),
    )
    db.session.add(workproof)
    db.session.commit()
    return WorkproofSchema().dump(workproof)


def escalate_grievance(grievance_id, escalated_by, new_assignee_id=None):
    MAX_ESCALATION = 3
    grievance = db.session.get(Grievance, grievance_id)
    if not grievance:
        raise ValueError("Grievance not found")
    if grievance.escalation_level >= MAX_ESCALATION:
        return {"success": False, "msg": "Already at maximum escalation level"}

    grievance.escalation_level += 1
    if new_assignee_id:
        assignee = db.session.get(User, new_assignee_id)
        if not assignee:
            raise ValueError("New assignee not found")
        grievance.assigned_to = new_assignee_id
        grievance.assigned_by = escalated_by

    grievance.updated_at = datetime.now(timezone.utc)
    db.session.commit()
    log_audit(f"Grievance escalated to level {grievance.escalation_level}", escalated_by, grievance_id)
    return {"success": True, "msg": f"Escalated to level {grievance.escalation_level}"}


# ── Internal ─────────────────────────────────────────────────────────────────

def _check_auto_close(grievance):
    if grievance.status == GrievanceStatus.RESOLVED and grievance.resolved_at:
        sla_days = getattr(Config, 'SLA_CLOSURE_DAYS', 7)
        if datetime.now(timezone.utc) - grievance.resolved_at > timedelta(days=int(sla_days)):
            grievance.status = GrievanceStatus.CLOSED
            db.session.commit()
            log_audit('Auto-closed due to SLA', grievance.assigned_to, grievance.id)

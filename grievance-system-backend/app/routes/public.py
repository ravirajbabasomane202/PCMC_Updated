from flask import Blueprint, jsonify, current_app
from .. import db
from ..models import MasterSubjects, MasterAreas
from ..schemas import MasterSubjectsSchema, MasterAreasSchema

public_bp = Blueprint('public', __name__)

subjects_schema = MasterSubjectsSchema(many=True)
areas_schema = MasterAreasSchema(many=True)


@public_bp.route('/')
def index():
    return jsonify({"service": "PCMC Grievance System API", "status": "running"}), 200


@public_bp.route('/health')
def health():
    """Lightweight health check — used by Docker, load-balancers, and uptime monitors."""
    try:
        db.session.execute(db.text('SELECT 1'))
        db_ok = True
    except Exception:
        db_ok = False

    status = "ok" if db_ok else "degraded"
    code = 200 if db_ok else 503
    return jsonify({
        "status": status,
        "db": "ok" if db_ok else "error",
        "service": "pcmc-grievance-backend",
    }), code


@public_bp.route('/subjects', methods=['GET'])
def get_subjects():
    """Get all available grievance subjects."""
    subjects = MasterSubjects.query.all()
    return jsonify(subjects_schema.dump(subjects)), 200


@public_bp.route('/areas', methods=['GET'])
def get_areas():
    """Get all available grievance areas."""
    areas = MasterAreas.query.all()
    return jsonify(areas_schema.dump(areas)), 200

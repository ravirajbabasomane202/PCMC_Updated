"""
manage.py - CLI management commands for the Grievance System.

Usage:
  python manage.py create-db        # Drop and recreate all tables
  python manage.py seed             # Seed master data (areas, subjects, configs)
  python manage.py seed-sample      # Add sample/test users and grievances
  python manage.py create-superadmin  # Create the default super admin user
  python manage.py run              # Run the Flask development server
"""

import sys
from pcmc_app import create_app, db
from pcmc_app.models import (
    MasterAreas, MasterCategories, MasterConfig, MasterSubjects, Role, User,
)

app = create_app()


def create_db():
    with app.app_context():
        db.drop_all()
        db.create_all()
        print("✅ Database tables created.")


def seed():
    """Seed master areas, categories, subjects and default configs."""
    with app.app_context():
        # Areas
        areas = [
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
        for name, description in areas:
            if not MasterAreas.query.filter_by(name=name).first():
                db.session.add(MasterAreas(name=name, description=description))

        # Categories
        categories = {
            "Infrastructure": "Roads, bridges, and public works",
            "Sanitation": "Garbage, sewage, and cleanliness",
            "Water Supply": "Water connection and distribution",
            "Electricity": "Street lighting and power supply",
            "Health": "Health centre and medical services",
        }
        cat_map = {}
        for name, desc in categories.items():
            c = MasterCategories.query.filter_by(name=name).first()
            if not c:
                c = MasterCategories(name=name, description=desc)
                db.session.add(c)
                db.session.flush()
            cat_map[name] = c

        # Subjects
        subjects = [
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
        for name, description in subjects:
            if not MasterSubjects.query.filter_by(name=name).first():
                db.session.add(MasterSubjects(
                    name=name, description=description,
                    category_id=None,
                ))

        # Configs
        configs = {
            "DEFAULT_PRIORITY": ("medium", "Default grievance priority"),
            "SLA_CLOSURE_DAYS": ("7", "Days before auto-close after resolution"),
            "MAX_FILE_UPLOADS": ("10", "Maximum file uploads per grievance"),
            "MAINTENANCE_MODE": ("false", "Set to true to enable maintenance mode"),
        }
        for key, (value, desc) in configs.items():
            if not MasterConfig.query.filter_by(key=key).first():
                db.session.add(MasterConfig(key=key, value=value, description=desc))

        db.session.commit()
        print("✅ Master data seeded.")


def seed_sample():
    """Create sample test users (dev only)."""
    with app.app_context():
        samples = [
            ("Admin User",    "admin@pcmc.gov.in",      Role.ADMIN),
            ("Member Head",   "member@pcmc.gov.in",     Role.MEMBER_HEAD),
            ("Field Staff",   "field@pcmc.gov.in",      Role.FIELD_STAFF),
            ("Test Citizen",  "citizen@example.com",    Role.CITIZEN),
        ]
        for name, email, role in samples:
            if not User.query.filter_by(email=email).first():
                u = User(name=name, email=email, role=role)
                u.set_password("Test@1234")
                db.session.add(u)
        db.session.commit()
        print("✅ Sample users created (password: Test@1234).")


def create_superadmin():
    """Create the default super admin account."""
    with app.app_context():
        email = "superadmin@pcmc.gov.in"
        if User.query.filter_by(email=email).first():
            print(f"⚠️  Super admin already exists: {email}")
            return
        u = User(name="Super Admin", email=email, role=Role.ADMIN)
        u.set_password("SuperAdmin@1234")
        db.session.add(u)
        db.session.commit()
        print(f"✅ Super admin created: {email}  (Change the password immediately!)")


def run():
    app.run(debug=True)


COMMANDS = {
    "create-db": create_db,
    "seed": seed,
    "seed-sample": seed_sample,
    "create-superadmin": create_superadmin,
    "run": run,
}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else None
    if cmd not in COMMANDS:
        print(__doc__)
        sys.exit(1)
    COMMANDS[cmd]()

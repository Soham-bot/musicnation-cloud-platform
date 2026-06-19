from flask import Flask, jsonify, request, g
from flask_cors import CORS
import boto3
import pymysql
import os
import hashlib
import json
from datetime import datetime
from botocore.exceptions import NoCredentialsError, ClientError

app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────
S3_BUCKET   = "musicnation-tracks"
AWS_REGION  = "us-east-1"
PRESIGN_EXP = 3600

DB_CONFIG = {
    "host":   os.getenv("MYSQL_HOST",     "localhost"),
    "user":   os.getenv("MYSQL_USER",     "musicnation"),
    "passwd": os.getenv("MYSQL_PASSWORD", "musicnation123"),
    "db":     os.getenv("MYSQL_DB",       "musicnation_db"),
    "port":   int(os.getenv("MYSQL_PORT", 3306)),
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor,
}

# ─────────────────────────────────────────────────────────────
# In-memory catalog (fallback if DB not available)
# ─────────────────────────────────────────────────────────────
TRACKS = [
    {"id": 1, "title": "Kesariya",          "artist": "Arijit Singh",    "duration": "4:34", "s3_key": "Kesariya.mp3",         "genre": "Romantic"},
    {"id": 2, "title": "Tum Hi Ho",          "artist": "Arijit Singh",    "duration": "4:22", "s3_key": "tum_hi_ho.mp3",         "genre": "Romantic"},
    {"id": 3, "title": "Raataan Lambiyan",   "artist": "Jubin Nautiyal",  "duration": "3:14", "s3_key": "raataan_lambiyan.mp3",  "genre": "Romantic"},
    {"id": 4, "title": "Apna Bana Le",       "artist": "Arijit Singh",    "duration": "4:05", "s3_key": "apna_bana_le.mp3",      "genre": "Devotional"},
    {"id": 5, "title": "Tera Ban Jaunga",    "artist": "Akhil Sachdeva",  "duration": "3:52", "s3_key": "tera_ban_jaunga.mp3",   "genre": "Romantic"},
    {"id": 6, "title": "Dil Diyan Gallan",   "artist": "Atif Aslam",      "duration": "4:18", "s3_key": "dil_diyan_gallan.mp3",  "genre": "Romantic"},
]

# ─────────────────────────────────────────────────────────────
# DB helpers
# ─────────────────────────────────────────────────────────────
def get_db():
    if "db" not in g:
        try:
            g.db = pymysql.connect(**DB_CONFIG)
        except Exception:
            g.db = None
    return g.db

@app.teardown_appcontext
def close_db(e=None):
    db = g.pop("db", None)
    if db:
        db.close()

def db_query(sql, args=(), one=False):
    conn = get_db()
    if not conn:
        return None
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args)
            conn.commit()
            result = cur.fetchone() if one else cur.fetchall()
            return result
    except Exception as ex:
        return None

def get_s3_client():
    return boto3.client("s3", region_name=AWS_REGION)

# ─────────────────────────────────────────────────────────────
# ROUTES — Core
# ─────────────────────────────────────────────────────────────

@app.route("/")
def home():
    return jsonify({"message": "MusicNation API is running!", "status": "healthy", "version": "3.0"})

@app.route("/health")
def health():
    db_ok = get_db() is not None
    return jsonify({"status": "ok", "db": "connected" if db_ok else "unavailable", "timestamp": datetime.utcnow().isoformat()})

@app.route("/buckets")
def list_buckets():
    try:
        s3 = get_s3_client()
        response = s3.list_buckets()
        bucket_names = [b["Name"] for b in response["Buckets"]]
        return jsonify({"status": "success", "buckets": bucket_names})
    except NoCredentialsError:
        return jsonify({"error": "AWS credentials not configured"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ─────────────────────────────────────────────────────────────
# ROUTES — Catalog & Streaming
# ─────────────────────────────────────────────────────────────

@app.route("/catalog")
def catalog():
    s3 = get_s3_client()
    has_credentials = True
    try:
        boto3.client("sts", region_name=AWS_REGION).get_caller_identity()
    except (NoCredentialsError, ClientError):
        has_credentials = False

    # Try to get tracks from DB, fall back to in-memory
    db_tracks = db_query("SELECT id, title, artist, duration, s3_key, genre FROM tracks WHERE is_active=1 ORDER BY id")
    source_tracks = db_tracks if db_tracks else TRACKS

    enriched = []
    for track in source_tracks:
        t = {
            "id":       track["id"],
            "title":    track["title"],
            "artist":   track["artist"],
            "duration": track["duration"],
            "genre":    track.get("genre", ""),
        }
        s3_key = track.get("s3_key", "")
        if has_credentials and s3_key:
            try:
                url = s3.generate_presigned_url("get_object",
                    Params={"Bucket": S3_BUCKET, "Key": s3_key}, ExpiresIn=PRESIGN_EXP)
                t["stream_url"] = url
                t["playable"]   = True
            except ClientError:
                t["stream_url"] = None
                t["playable"]   = False
                t["reason"]     = "File not yet in S3"
        else:
            t["stream_url"] = None
            t["playable"]   = False
            t["reason"]     = "AWS credentials not configured" if not has_credentials else "No S3 key"
        enriched.append(t)

    return jsonify({"status": "success", "total_tracks": len(enriched),
                    "aws_connected": has_credentials, "tracks": enriched})

@app.route("/stream/<int:track_id>")
def stream(track_id):
    # Try DB first, fall back to in-memory
    db_track = db_query("SELECT s3_key FROM tracks WHERE id=%s AND is_active=1", (track_id,), one=True)
    s3_key = db_track["s3_key"] if db_track else next((t["s3_key"] for t in TRACKS if t["id"] == track_id), None)
    if not s3_key:
        return jsonify({"error": "Track not found"}), 404

    try:
        s3  = get_s3_client()
        url = s3.generate_presigned_url("get_object",
            Params={"Bucket": S3_BUCKET, "Key": s3_key}, ExpiresIn=PRESIGN_EXP)

        # Log play event to DB
        db_query("INSERT INTO play_events (track_id, region) VALUES (%s, %s)",
                 (track_id, "ap-south-1"))

        # Increment play count
        db_query("UPDATE tracks SET play_count = play_count + 1 WHERE id=%s", (track_id,))

        return jsonify({"status": "success", "stream_url": url, "track_id": track_id})
    except NoCredentialsError:
        return jsonify({"error": "AWS credentials not configured"}), 500
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "NoSuchKey":
            return jsonify({"error": f"File not found in S3"}), 404
        return jsonify({"error": str(e)}), 500

# ─────────────────────────────────────────────────────────────
# ROUTES — Analytics
# ─────────────────────────────────────────────────────────────

@app.route("/analytics")
def analytics():
    # Total plays
    total = db_query("SELECT COUNT(*) as total FROM play_events", one=True)
    # Top tracks
    top = db_query("""
        SELECT t.title, t.artist, COUNT(p.id) as plays
        FROM play_events p JOIN tracks t ON p.track_id = t.id
        GROUP BY t.id, t.title, t.artist
        ORDER BY plays DESC LIMIT 6
    """)
    # Plays by region
    by_region = db_query("""
        SELECT region, COUNT(*) as plays
        FROM play_events GROUP BY region ORDER BY plays DESC
    """)
    # Recent activity
    recent = db_query("""
        SELECT t.title, t.artist, p.played_at, p.region
        FROM play_events p JOIN tracks t ON p.track_id = t.id
        ORDER BY p.played_at DESC LIMIT 10
    """)

    return jsonify({
        "status": "success",
        "total_plays":  total["total"] if total else 0,
        "top_tracks":   top   or [],
        "by_region":    by_region or [],
        "recent":       [dict(r, played_at=str(r["played_at"])) for r in (recent or [])],
    })

# ─────────────────────────────────────────────────────────────
# ROUTES — Monitoring
# ─────────────────────────────────────────────────────────────

@app.route("/metrics")
def metrics():
    import psutil
    cpu  = psutil.cpu_percent(interval=1)
    mem  = psutil.virtual_memory()
    disk = psutil.disk_usage("/")

    db_ok = get_db() is not None

    data = {
        "cpu_pct":    round(cpu, 1),
        "mem_pct":    round(mem.percent, 1),
        "mem_used_mb": round(mem.used / 1024 / 1024, 1),
        "mem_total_mb": round(mem.total / 1024 / 1024, 1),
        "disk_pct":   round(disk.percent, 1),
        "disk_used_gb": round(disk.used / 1024**3, 2),
        "disk_total_gb": round(disk.total / 1024**3, 2),
        "db":         "connected" if db_ok else "unavailable",
        "timestamp":  datetime.utcnow().isoformat(),
    }

    # Store to DB
    db_query(
        "INSERT INTO system_metrics (cpu_pct, mem_pct, disk_pct, api_status, active_conn) VALUES (%s,%s,%s,'ok',0)",
        (data["cpu_pct"], data["mem_pct"], data["disk_pct"])
    )

    # Last 12 historical readings
    history = db_query("""
        SELECT cpu_pct, mem_pct, disk_pct, recorded_at
        FROM system_metrics ORDER BY recorded_at DESC LIMIT 12
    """)
    data["history"] = [dict(h, recorded_at=str(h["recorded_at"])) for h in (history or [])]

    return jsonify({"status": "success", **data})

# ─────────────────────────────────────────────────────────────
# ROUTES — Users / RBAC
# ─────────────────────────────────────────────────────────────

@app.route("/users")
def get_users():
    users = db_query("""
        SELECT u.id, u.username, u.email, r.name as role,
               u.is_active, u.last_login, u.created_at
        FROM users u JOIN roles r ON u.role_id = r.id
        ORDER BY u.id
    """)
    if users is None:
        return jsonify({"error": "Database unavailable"}), 503
    return jsonify({"status": "success", "users": [
        dict(u, last_login=str(u["last_login"]), created_at=str(u["created_at"])) for u in users
    ]})

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    if not data or "username" not in data or "password" not in data:
        return jsonify({"error": "username and password required"}), 400

    user = db_query("""
        SELECT u.id, u.username, u.email, u.password_hash, r.name as role
        FROM users u JOIN roles r ON u.role_id = r.id
        WHERE u.username=%s AND u.is_active=1
    """, (data["username"],), one=True)

    if not user:
        return jsonify({"error": "Invalid credentials"}), 401

    # Simple demo auth — in production use bcrypt
    import bcrypt
    try:
        valid = bcrypt.checkpw(data["password"].encode(), user["password_hash"].encode())
    except Exception:
        valid = False

    if not valid:
        return jsonify({"error": "Invalid credentials"}), 401

    # Update last login
    db_query("UPDATE users SET last_login=NOW() WHERE id=%s", (user["id"],))

    # Audit log
    db_query("INSERT INTO audit_log (user_id, action, resource, ip_address) VALUES (%s,'login','auth',%s)",
             (user["id"], request.remote_addr))

    return jsonify({
        "status": "success",
        "user": {"id": user["id"], "username": user["username"],
                 "email": user["email"], "role": user["role"]}
    })

# ─────────────────────────────────────────────────────────────
# ROUTES — Audit Log
# ─────────────────────────────────────────────────────────────

@app.route("/audit")
def audit():
    logs = db_query("""
        SELECT a.id, u.username, a.action, a.resource, a.detail, a.ip_address, a.logged_at
        FROM audit_log a LEFT JOIN users u ON a.user_id = u.id
        ORDER BY a.logged_at DESC LIMIT 50
    """)
    if logs is None:
        return jsonify({"error": "Database unavailable"}), 503
    return jsonify({"status": "success", "logs": [
        dict(l, logged_at=str(l["logged_at"])) for l in logs
    ]})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)


# ─────────────────────────────────────────────────────────────
# ROUTES — Workflow / Task Management
# ─────────────────────────────────────────────────────────────

@app.route("/tasks")
def get_tasks():
    tasks = db_query("""
        SELECT t.id, t.title, t.description, t.status, t.priority,
               t.due_date, t.created_at, t.updated_at,
               ua.username as assigned_to, uc.username as created_by
        FROM tasks t
        LEFT JOIN users ua ON t.assigned_to = ua.id
        LEFT JOIN users uc ON t.created_by  = uc.id
        ORDER BY FIELD(t.priority,'critical','high','medium','low'), t.created_at DESC
    """)
    if tasks is None:
        return jsonify({"error": "Database unavailable"}), 503
    return jsonify({"status": "success", "tasks": [
        dict(t,
             due_date=str(t["due_date"]) if t["due_date"] else None,
             created_at=str(t["created_at"]),
             updated_at=str(t["updated_at"])
        ) for t in tasks
    ]})

@app.route("/tasks/<int:task_id>/status", methods=["PATCH"])
def update_task_status(task_id):
    data   = request.get_json()
    status = data.get("status") if data else None
    valid  = ("pending", "in_progress", "approved", "rejected", "done")
    if status not in valid:
        return jsonify({"error": f"status must be one of {valid}"}), 400
    rows = db_query("UPDATE tasks SET status=%s WHERE id=%s", (status, task_id))
    db_query("INSERT INTO audit_log (action, resource, detail) VALUES (%s,%s,%s)",
             ("task_update", f"task:{task_id}", f"status → {status}"))
    return jsonify({"status": "success", "task_id": task_id, "new_status": status})

# ─────────────────────────────────────────────────────────────
# ROUTES — Executive Reporting Portal
# ─────────────────────────────────────────────────────────────

@app.route("/executive")
def executive():
    # Total plays & growth
    total_plays   = db_query("SELECT COUNT(*) as c FROM play_events", one=True)
    total_tracks  = db_query("SELECT COUNT(*) as c FROM tracks WHERE is_active=1", one=True)
    total_users   = db_query("SELECT COUNT(*) as c FROM users WHERE is_active=1", one=True)
    tasks_pending = db_query("SELECT COUNT(*) as c FROM tasks WHERE status IN ('pending','in_progress')", one=True)

    # Top artist by play count
    top_artist = db_query("""
        SELECT t.artist, COUNT(p.id) as plays
        FROM play_events p JOIN tracks t ON p.track_id = t.id
        GROUP BY t.artist ORDER BY plays DESC LIMIT 1
    """, one=True)

    # Plays by region
    by_region = db_query("""
        SELECT region, COUNT(*) as plays
        FROM play_events GROUP BY region ORDER BY plays DESC
    """)

    # Task summary
    task_summary = db_query("""
        SELECT status, COUNT(*) as count FROM tasks GROUP BY status
    """)

    # Recent 5 plays
    recent = db_query("""
        SELECT t.title, t.artist, p.played_at, p.region
        FROM play_events p JOIN tracks t ON p.track_id = t.id
        ORDER BY p.played_at DESC LIMIT 5
    """)

    # Latest system health
    latest_metric = db_query("""
        SELECT cpu_pct, mem_pct, disk_pct, recorded_at
        FROM system_metrics ORDER BY recorded_at DESC LIMIT 1
    """, one=True)

    return jsonify({
        "status":        "success",
        "kpis": {
            "total_plays":    total_plays["c"]   if total_plays   else 0,
            "total_tracks":   total_tracks["c"]  if total_tracks  else 0,
            "total_users":    total_users["c"]   if total_users   else 0,
            "tasks_pending":  tasks_pending["c"] if tasks_pending else 0,
            "top_artist":     top_artist["artist"] if top_artist  else "—",
            "top_artist_plays": top_artist["plays"] if top_artist else 0,
        },
        "by_region":    by_region    or [],
        "task_summary": task_summary or [],
        "recent_plays": [dict(r, played_at=str(r["played_at"])) for r in (recent or [])],
        "system_health": dict(latest_metric, recorded_at=str(latest_metric["recorded_at"])) if latest_metric else None,
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)

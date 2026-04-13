"""
Gunicorn production configuration for PCMC Grievance System.

Tuned for ~100 concurrent users on a 2-CPU / 2 GB RAM server.
Scale worker_class and workers for larger deployments.

Start with:
  gunicorn -c gunicorn.conf.py "app:create_app()"
"""
import multiprocessing
import os

# ── Binding ───────────────────────────────────────────────────────────────────
bind = f"0.0.0.0:{os.environ.get('PORT', '5000')}"

# ── Workers ───────────────────────────────────────────────────────────────────
# Threaded workers handle concurrent requests without gevent monkey-patching issues.
worker_class = "gthread"
threads = int(os.environ.get("WEB_THREADS", "4"))
worker_connections = 1000          # Not used by gthread, kept for compatibility

# Rule of thumb: (2 × CPU cores) + 1
# For a 2-core machine → 5 workers; 100 users / 5 workers = 20 req/worker
workers = int(os.environ.get("WEB_CONCURRENCY", multiprocessing.cpu_count() * 2 + 1))

# ── Timeouts ──────────────────────────────────────────────────────────────────
timeout = 60           # Kill workers that hang longer than 60 s
graceful_timeout = 30  # Grace period on SIGTERM before SIGKILL
keepalive = 5          # Keep-alive connections (reduces TCP overhead)

# ── Logging ───────────────────────────────────────────────────────────────────
accesslog = "-"        # stdout
errorlog = "-"         # stderr
loglevel = os.environ.get("LOG_LEVEL", "info")
access_log_format = '%(h)s "%(r)s" %(s)s %(b)s %(D)sµs'

# ── Process naming ────────────────────────────────────────────────────────────
proc_name = "pcmc-grievance"

# ── Security / reliability ────────────────────────────────────────────────────
max_requests = 1000         # Restart workers after N requests (prevents memory leaks)
max_requests_jitter = 100   # Randomise restarts to avoid thundering herd
preload_app = True          # Load app before forking (saves memory via CoW)

# ── Hooks ─────────────────────────────────────────────────────────────────────
def on_starting(server):
    server.log.info("PCMC Grievance System starting …")

def worker_exit(server, worker):
    server.log.info(f"Worker {worker.pid} exited")

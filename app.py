import threading
import time
import uuid
import json
import base64
from flask import Flask, request, Response
from werkzeug.exceptions import RequestEntityTooLarge
from processor import remove_background

app = Flask(__name__, static_folder="static", static_url_path="")

MAX_FILE_SIZE = 5 * 1024 * 1024
app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE

RATE_LIMIT_PER_HOUR = 10
_rate_limit = {}
_rate_limit_lock = threading.Lock()

_jobs = []
_jobs_lock = threading.Lock()
_jobs_event = threading.Event()
_job_results = {}

_requests_total = 0
_processing_seconds_sum = 0.0
_errors_total = 0
_metrics_lock = threading.Lock()


def _worker():
    while True:
        job = None
        with _jobs_lock:
            if _jobs:
                job = _jobs.pop(0)

        if job is None:
            _jobs_event.wait()
            _jobs_event.clear()
            continue

        job_id, image_bytes = job
        _job_results[job_id] = {"status": "processing"}

        try:
            result_bytes = remove_background(image_bytes)
            b64 = base64.b64encode(result_bytes).decode()
            _job_results[job_id] = {"status": "done", "image": b64}
        except Exception as e:
            _job_results[job_id] = {"status": "error", "message": str(e)}


threading.Thread(target=_worker, daemon=True).start()


def _check_rate_limit(ip):
    now = time.time()
    with _rate_limit_lock:
        timestamps = _rate_limit.get(ip, [])
        cutoff = now - 3600
        timestamps = [t for t in timestamps if t > cutoff]
        if len(timestamps) >= RATE_LIMIT_PER_HOUR:
            return False
        timestamps.append(now)
        _rate_limit[ip] = timestamps
    return True


@app.route("/", methods=["GET"])
def index():
    return app.send_static_file("index.html")


@app.route("/remove-bg", methods=["POST"])
def remove_bg():
    global _requests_total, _errors_total

    with _metrics_lock:
        _requests_total += 1

    if not _check_rate_limit(request.remote_addr):
        with _metrics_lock:
            _errors_total += 1
        return {"error": "Rate limit exceeded. Maximum 10 uploads per hour."}, 429

    if "file" not in request.files:
        with _metrics_lock:
            _errors_total += 1
        return {"error": "No file provided"}, 422

    image_file = request.files["file"]
    image_bytes = image_file.read()

    if len(image_bytes) > MAX_FILE_SIZE:
        with _metrics_lock:
            _errors_total += 1
        return {"error": "File too large. Maximum size is 5MB."}, 413

    job_id = str(uuid.uuid4())
    with _jobs_lock:
        _jobs.append((job_id, image_bytes))
    _jobs_event.set()

    return {"job_id": job_id}, 202


@app.route("/queue/<job_id>")
def queue_stream(job_id):
    def generate():
        while True:
            with _jobs_lock:
                result = _job_results.get(job_id)
                if result:
                    if result["status"] in ("done", "error"):
                        event = json.dumps(result)
                        terminal = True
                    else:
                        event = json.dumps({"status": "processing"})
                        terminal = False
                else:
                    position = None
                    for i, (jid, _) in enumerate(_jobs):
                        if jid == job_id:
                            position = i + 1
                            break
                    if position is not None:
                        event = json.dumps({"status": "queued", "position": position})
                        terminal = False
                    else:
                        event = json.dumps(
                            {"status": "error", "message": "Job not found"}
                        )
                        terminal = True

            yield f"data: {event}\n\n"

            if terminal:
                with _jobs_lock:
                    _job_results.pop(job_id, None)
                return

            time.sleep(2)

    return Response(
        generate(),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
    )


@app.route("/metrics", methods=["GET"])
def metrics():
    with _metrics_lock:
        total = _requests_total
        total_time = _processing_seconds_sum
        errors = _errors_total

    text = (
        f"# HELP labpng_requests_total Total requests\n"
        f"# TYPE labpng_requests_total counter\n"
        f"labpng_requests_total {total}\n"
        f"# HELP labpng_processing_seconds_sum Total processing time in seconds\n"
        f"# TYPE labpng_processing_seconds_sum counter\n"
        f"labpng_processing_seconds_sum {total_time}\n"
        f"# HELP labpng_errors_total Total errors\n"
        f"# TYPE labpng_errors_total counter\n"
        f"labpng_errors_total {errors}\n"
    )
    return text, 200, {"Content-Type": "text/plain; charset=utf-8"}


@app.errorhandler(RequestEntityTooLarge)
def handle_413(exception):
    return {"error": "File too large. Maximum size is 5MB."}, 413


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)

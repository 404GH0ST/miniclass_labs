import os

from flask import Flask, abort, jsonify, request

app = Flask(__name__)
HTTP_FLAG = os.getenv("WRI_HTTP_FLAG", "WRI{deployment_flag_missing}")
LAB_PROFILE = os.getenv("WRI_LAB_PROFILE", "unknown")

PROFILES = {
    "1001": {"id": 1001, "name": "Student One", "note": "Own training record"},
    "1002": {"id": 1002, "name": "Student Two", "note": "Designated validation record"},
}


@app.get("/")
def index():
    return f"WRI CySec authorized {LAB_PROFILE} training target\n"


@app.get("/health")
def health():
    return jsonify(status="ok", profile=LAB_PROFILE, scope="host-only lab")


@app.get("/internal/")
def internal():
    return f"Hidden endpoint found. Record it, then stop.\nHTTP enumeration flag: {HTTP_FLAG}\n"


@app.get("/profile")
def profile():
    profile_id = request.args.get("id", "1001")
    if profile_id not in PROFILES:
        abort(404)
    return jsonify(PROFILES[profile_id])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)

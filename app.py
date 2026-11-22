import os

from flask import Flask, jsonify


def create_app():
    app = Flask(__name__)

    version = os.getenv("APP_VERSION", "1.0.0")

    @app.get("/health")
    def health():
        if os.getenv("HEALTH_FAILURE") == "true":
            return jsonify(status="error"), 503

        return jsonify(status="ok"), 200

    @app.get("/version")
    def get_version():
        return jsonify(version=version), 200

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
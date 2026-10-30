"""Exercise Godot's real HTTP downloader against a local, deterministic server."""
import hashlib
import json
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PAYLOAD = b"test installer payload\n"


class Fixture(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        status = 200
        body = PAYLOAD
        if self.path == "/metadata":
            body = json.dumps({
                "tag_name": "v0.3.0", "draft": False, "prerelease": False,
                "assets": [{"name": "OneMoreTry-v0.3.0-Windows-x64-Setup.exe",
                            "size": len(PAYLOAD),
                            "digest": "sha256:" + hashlib.sha256(PAYLOAD).hexdigest()}],
            }).encode()
        elif self.path == "/malformed":
            body = b"invalid JSON"
        elif self.path == "/unavailable":
            status = 403
        elif self.path == "/missing":
            status = 404
        elif self.path == "/tampered":
            body = b"x" * len(PAYLOAD)
        elif self.path == "/truncated":
            body = PAYLOAD[:3]
        elif self.path == "/oversized":
            body = PAYLOAD * 2
        elif self.path == "/slow":
            time.sleep(0.3)
        self.send_response(status)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Cancellation intentionally closes the connection.


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        result = subprocess.run([
            "godot", "--headless", "--script", "tests/updater_tests.gd", "--",
            "--test", f"--fixture-url=http://127.0.0.1:{server.server_port}",
        ], timeout=45)
    finally:
        server.shutdown()
        server.server_close()
    raise SystemExit(result.returncode)

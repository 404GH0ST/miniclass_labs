#!/usr/bin/env python3
"""Intentionally enumerable status page for the Week 3 recon lab."""
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

FLAG = os.environ.get("WRI_STATUS_FLAG", "WRI{unavailable}")
BIND = os.environ.get("WRI_STATUS_HOST", "127.0.0.1")
PORT = int(os.environ.get("WRI_STATUS_PORT", "8083"))

PAGE = f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>WRI Legacy Build Agent</title></head>
<body>
  <h1>WRI Legacy Build Agent</h1>
  <p>Status: running (legacy)</p>
  <p>Queue: 3 pending jobs</p>
  <p>Diagnostic code: {FLAG}</p>
  <!-- deployment banner {FLAG} -->
</body>
</html>
"""


class StatusHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer((BIND, PORT), StatusHandler).serve_forever()

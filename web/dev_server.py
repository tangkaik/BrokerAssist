from __future__ import annotations

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


BACKEND_ORIGIN = "http://127.0.0.1:8001"
HOST = "127.0.0.1"
PORT = 4173


class BrokerAssistDevHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self) -> None:
        if self.path.startswith(("/api/v1/", "/media/")):
            self.proxy_to_backend()
            return
        super().do_GET()

    def do_HEAD(self) -> None:
        if self.path.startswith(("/api/v1/", "/media/")):
            self.proxy_to_backend(include_body=False)
            return
        super().do_HEAD()

    def do_POST(self) -> None:
        self.proxy_to_backend()

    def do_PUT(self) -> None:
        self.proxy_to_backend()

    def do_PATCH(self) -> None:
        self.proxy_to_backend()

    def do_DELETE(self) -> None:
        self.proxy_to_backend()

    def do_OPTIONS(self) -> None:
        self.proxy_to_backend()

    def proxy_to_backend(self, include_body: bool = True) -> None:
        content_length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(content_length) if content_length else None
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in {"host", "content-length", "connection", "accept-encoding"}
        }
        request = Request(
            f"{BACKEND_ORIGIN}{self.path}",
            data=body,
            headers=headers,
            method=self.command,
        )
        try:
            with urlopen(request, timeout=60) as response:
                self.send_response(response.status)
                for key, value in response.headers.items():
                    if key.lower() not in {"transfer-encoding", "connection"}:
                        self.send_header(key, value)
                self.end_headers()
                if include_body:
                    self.wfile.write(response.read())
        except HTTPError as error:
            self.send_response(error.code)
            for key, value in error.headers.items():
                if key.lower() not in {"transfer-encoding", "connection"}:
                    self.send_header(key, value)
            self.end_headers()
            if include_body:
                self.wfile.write(error.read())
        except URLError as error:
            message = f'{{"success":false,"error":{{"code":502,"message":"Backend unavailable: {error.reason}"}}}}'
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            if include_body:
                self.wfile.write(message.encode("utf-8"))


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), BrokerAssistDevHandler)
    print(
        f"Serving BrokerAssist Web on http://{HOST}:{PORT} "
        f"and proxying API requests to {BACKEND_ORIGIN}",
        flush=True,
    )
    server.serve_forever()

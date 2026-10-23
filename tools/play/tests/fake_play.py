"""Un «Google Play» falso (servidor HTTP local) para probar publish.py sin credenciales reales. SÓLO para pruebas."""
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

STATE = {}


def reset(**kw):
    STATE.clear()
    STATE.update({"edits": {}, "next": 1, "bundles": kw.get("bundles", []), "tracks": kw.get("tracks", {}), "log": [],
                  "reviews": kw.get("reviews", []), "draft_app": kw.get("draft_app", False), "deny": kw.get("deny", False), "committed": [], "uploads": {}})


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj=None, headers=None):
        body = json.dumps(obj if obj is not None else {}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _err(self, code, msg):
        self._send(code, {"error": {"code": code, "message": msg, "errors": [{"message": msg, "reason": "x"}]}})

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def do_POST(self):
        path = self.path.split("?")[0]
        STATE["log"].append(("POST", path))
        if path == "/token":
            self._body()
            return self._send(200, {"access_token": "fake", "token_type": "Bearer", "expires_in": 3600})
        if STATE["deny"]:
            return self._err(403, "The caller does not have permission")
        if re.search(r"/applications/[^/]+/edits$", path):
            self._body()
            eid = "e%d" % STATE["next"]
            STATE["next"] += 1
            STATE["edits"][eid] = {"bundle": None, "tracks": {}}
            return self._send(200, {"id": eid})
        m = re.search(r"/upload/androidpublisher/v3/applications/[^/]+/edits/(e\d+)/bundles$", path)
        if m:
            self._body()
            STATE["uploads"][m.group(1)] = 0
            host = self.headers.get("Host")
            return self._send(200, {}, {"Location": "http://%s/session/%s" % (host, m.group(1))})
        m = re.search(r"/edits/(e\d+):validate$", path)
        if m:
            return self._send(200, {"id": m.group(1)})
        m = re.search(r"/edits/(e\d+):commit$", path)
        if m:
            STATE["committed"].append(STATE["edits"][m.group(1)])
            return self._send(200, {"id": m.group(1)})
        self._err(404, "no existe %s" % path)

    def do_PUT(self):
        path = self.path.split("?")[0]
        STATE["log"].append(("PUT", path))
        m = re.search(r"/session/(e\d+)$", path)
        if m:
            data = self._body()
            eid = m.group(1)
            cr = re.match(r"bytes (\d+)-(\d+)/(\d+)", self.headers.get("Content-Range", ""))
            total = int(cr.group(3)) if cr else len(data)
            STATE["uploads"][eid] += len(data)
            if STATE["uploads"][eid] < total:
                return self._send(308, {}, {"Range": "bytes=0-%d" % (STATE["uploads"][eid] - 1)})
            vc = 1000 + len(STATE["bundles"]) + 1 + (5 if STATE.get("high") else 0)
            if any(int(b["versionCode"]) == vc for b in STATE["bundles"]):
                return self._err(400, "apkUpgradeVersionConflict")
            STATE["edits"][eid]["bundle"] = vc
            return self._send(200, {"versionCode": vc, "sha256": "ab" * 32})
        if STATE["deny"]:
            return self._err(403, "The caller does not have permission")
        m = re.search(r"/edits/(e\d+)/tracks/(\w+)$", path)
        if m:
            body = json.loads(self._body() or b"{}")
            if STATE["draft_app"] and any(r.get("status") != "draft" for r in body.get("releases", [])):
                return self._err(400, "Only releases with status draft may be created on draft app.")
            STATE["edits"][m.group(1)]["tracks"][m.group(2)] = body
            return self._send(200, body)
        self._err(404, "no existe %s" % path)

    def do_GET(self):
        path = self.path.split("?")[0]
        STATE["log"].append(("GET", path))
        if STATE["deny"]:
            return self._err(403, "The caller does not have permission")
        m = re.search(r"/applications/[^/]+/tracks/(\w+)/releases$", path)
        if m:
            return self._send(200, {"releases": [{"releaseName": r.get("name"), "releaseLifecycleState": "RELEASE_LIFECYCLE_STATE_" + r.get("status", "").upper(),
                                                   "activeArtifacts": [{"versionCode": c} for c in r.get("versionCodes", [])]} for r in STATE["tracks"].get(m.group(1), [])]})
        if path.endswith("/reviews"):
            q = self.path.split("?", 1)[1] if "?" in self.path else ""
            revs = STATE.get("reviews", [])
            if "token=p2" in q:
                return self._send(200, {"reviews": revs[2:]})
            if len(revs) > 2:
                return self._send(200, {"reviews": revs[:2], "tokenPagination": {"nextPageToken": "p2"}})
            return self._send(200, {"reviews": revs} if revs else {})
        if path.endswith("/bundles"):
            return self._send(200, {"bundles": STATE["bundles"]})
        if path.endswith("/tracks"):
            return self._send(200, {"tracks": [{"track": k, "releases": v} for k, v in STATE["tracks"].items()]})
        self._err(404, "no existe %s" % path)

    def do_DELETE(self):
        path = self.path.split("?")[0]
        STATE["log"].append(("DELETE", path))
        m = re.search(r"/edits/(e\d+)$", path)
        if m:
            STATE["edits"].pop(m.group(1), None)
            return self._send(204, {})
        self._err(404, "no existe")


def start():
    srv = HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv

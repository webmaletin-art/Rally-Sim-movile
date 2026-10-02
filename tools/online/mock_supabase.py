"""Servidor de mentira que imita lo mínimo de Supabase (Auth anónimo + las dos funciones del ranking) para probar el cliente del juego sin internet.
Uso: python3 tools/online/mock_supabase.py [puerto]   (el test godot/tests/online_test.gd lo arma solo)"""
import json, sys, time, uuid
from http.server import BaseHTTPRequestHandler, HTTPServer

KEY = "test-anon-key-0123456789abcdef"
SESSIONS, SCORES = {}, {}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        body = json.loads(self.rfile.read(n) or b"{}")
        if self.headers.get("apikey") != KEY:
            return self._send(401, {"message": "Invalid API key"})
        p = self.path
        if p.startswith("/auth/v1/signup"):
            uid = str(uuid.uuid4()); tok = "tok-" + uid; SESSIONS[tok] = uid
            return self._send(200, {"access_token": tok, "refresh_token": "ref-" + uid, "expires_in": 3600, "user": {"id": uid}})
        if p.startswith("/auth/v1/token"):
            r = body.get("refresh_token", "")
            if r.startswith("ref-"):
                uid = r[4:]; tok = "tok2-" + uid; SESSIONS[tok] = uid
                return self._send(200, {"access_token": tok, "refresh_token": r, "expires_in": 3600, "user": {"id": uid}})
            return self._send(400, {"error_description": "Invalid Refresh Token"})
        auth = (self.headers.get("Authorization") or "").replace("Bearer ", "")
        uid = SESSIONS.get(auth)
        if p.startswith("/rest/v1/rpc/submit_score"):
            if not uid: return self._send(401, {"message": "sin sesión"})
            v = float(body["p_value"])
            if body["p_board"] != "drift" and v < 30: return self._send(400, {"message": "tiempo imposible"})
            k = (body["p_track"], body["p_board"]); cur = SCORES.setdefault(k, {})
            prev = cur.get(uid, (None,))[0]
            better = prev is None or (v > prev if body["p_board"] == "drift" else v < prev)
            if better: cur[uid] = (v, body.get("p_name", "Piloto"), body.get("p_car", ""))
            return self._send(200, {"saved": better, "best": cur[uid][0], "rank": 1})
        if p.startswith("/rest/v1/rpc/get_leaderboard"):
            k = (body["p_track"], body["p_board"]); rows = sorted(SCORES.get(k, {}).items(), key=lambda kv: (-kv[1][0] if k[1] == "drift" else kv[1][0]))
            return self._send(200, [{"rank": i + 1, "name": v[1], "value": v[0], "car": v[2], "is_me": u == uid} for i, (u, v) in enumerate(rows)])
        self._send(404, {"message": "no existe"})

if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 54330), H).serve_forever()

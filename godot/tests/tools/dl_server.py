#!/usr/bin/env python3
"""Servidor de prueba para tests/boot_download_test.gd: manifiesto + dos paquetes, con Range, y fallas a propósito.
  · /content.pck: el 1.er pedido se corta a los 2 MB (cierra la conexión);
  · /cars.pck: el 1.er pedido se traba a los 3 MB (no manda nada más: lo tiene que cortar el vigilante del cliente);
  · los pedidos con «Range: bytes=N-» contestan 206 con el resto.
Uso: python3 dl_server.py PUERTO DIRECTORIO  (crea los archivos y el manifest.json en DIRECTORIO)"""
import hashlib, http.server, json, os, sys, time

port, root = int(sys.argv[1]), sys.argv[2]
os.makedirs(root, exist_ok=True)
files = {"content.pck": 6 * 1024 * 1024, "cars.pck": 9 * 1024 * 1024 + 123}
data = {}
for i, (n, size) in enumerate(files.items()):
    b = bytes((j * 7 + i * 13 + (j >> 11)) & 0xff for j in range(size))
    data[n] = b
base = "http://127.0.0.1:%d/" % port
man = {"version": "v1", "url": base + "content.pck", "size": len(data["content.pck"]), "sha256": hashlib.sha256(data["content.pck"]).hexdigest(),
       "packs": [{"name": "cars", "version": "c1", "url": base + "cars.pck", "size": len(data["cars.pck"]), "sha256": hashlib.sha256(data["cars.pck"]).hexdigest()}]}
hits = {}
log = open(os.path.join(root, "server.log"), "w")


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def do_GET(self):
        name = self.path.strip("/")
        if name == "manifest.json":
            b = json.dumps(man).encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)
            return
        if name not in data:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        hits[name] = hits.get(name, 0) + 1
        b = data[name]
        start = 0
        rng = self.headers.get("Range", "")
        if rng.startswith("bytes="):
            start = int(rng[6:].split("-")[0])
        log.write("%s pedido %d desde %d\n" % (name, hits[name], start))
        log.flush()
        body = b[start:]
        self.send_response(206 if start else 200)
        if start:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, len(b) - 1, len(b)))
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if hits[name] == 1 and name == "content.pck":
            self.wfile.write(body[:2 * 1024 * 1024])
            self.wfile.flush()
            self.close_connection = True
            return
        if hits[name] == 1 and name == "cars.pck":
            self.wfile.write(body[:3 * 1024 * 1024])
            self.wfile.flush()
            time.sleep(30)  # trabado
            return
        self.wfile.write(body)


class S(http.server.ThreadingHTTPServer):
    daemon_threads = True


S(("127.0.0.1", port), H).serve_forever()

"""Piezas comunes de las herramientas de publicación en Google Play (tools/play). Reutilizable por cualquier juego del estudio.

Nunca imprime ni guarda el JSON de la cuenta de servicio: sólo se lee de la variable de entorno GOOGLE_PLAY_SERVICE_ACCOUNT (o de un archivo
indicado en GOOGLE_PLAY_SERVICE_ACCOUNT_FILE para pruebas locales) y se usa en memoria."""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def load_config(path=None):
    path = path or os.path.join(os.path.dirname(__file__), "game.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def repo_path(rel):
    return os.path.join(ROOT, rel)


# ───────────────────────── mensajes ─────────────────────────
class Report:
    """Lista de comprobaciones con tres niveles: OK, AVISO (no frena) y BLOQUEO (frena la publicación)."""

    def __init__(self, title):
        self.title = title
        self.rows = []

    def ok(self, msg):
        self.rows.append(("OK", msg))

    def warn(self, msg):
        self.rows.append(("AVISO", msg))

    def block(self, msg):
        self.rows.append(("BLOQUEO", msg))

    def info(self, msg):
        self.rows.append(("INFO", msg))

    @property
    def blockers(self):
        return [m for k, m in self.rows if k == "BLOQUEO"]

    def render(self):
        icons = {"OK": "✅", "AVISO": "⚠️", "BLOQUEO": "⛔", "INFO": "ℹ️"}
        out = ["## " + self.title, ""]
        for k, m in self.rows:
            out.append("- %s **%s** — %s" % (icons[k], k, m))
        return "\n".join(out) + "\n"

    def emit(self):
        text = self.render()
        print(text)
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a", encoding="utf-8") as f:
                f.write(text + "\n")
        for m in self.blockers:
            print("::error::%s" % m)
        for k, m in self.rows:
            if k == "AVISO":
                print("::warning::%s" % m)


# ───────────────────────── cuenta de servicio ─────────────────────────
def service_account_info():
    """Devuelve el dict de la cuenta de servicio o None si no hay (nunca lo imprime)."""
    raw = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT", "").strip()
    path = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_FILE", "").strip()
    if not raw and path and os.path.exists(path):
        raw = open(path, encoding="utf-8").read()
    if not raw:
        return None
    try:
        info = json.loads(raw)
    except ValueError:
        raise SystemExit("::error::GOOGLE_PLAY_SERVICE_ACCOUNT no es un JSON válido (tiene que ser el contenido COMPLETO del archivo .json de la cuenta de servicio).")
    for k in ("client_email", "private_key", "token_uri"):
        if not info.get(k):
            raise SystemExit("::error::El JSON de GOOGLE_PLAY_SERVICE_ACCOUNT no es de una cuenta de servicio (falta «%s»)." % k)
    return info


def masked_account(info):
    mail = info.get("client_email", "")
    name, _, dom = mail.partition("@")
    return "%s…@%s" % (name[:3], dom)


def build_service(info, read_only=False):
    from google.oauth2 import service_account
    creds = service_account.Credentials.from_service_account_info(info, scopes=[SCOPE])
    svc = _build_service(creds)
    if read_only:
        guard_read_only(svc)
    return svc


def guard_read_only(svc):
    """Candado de SÓLO LECTURA: cualquier pedido a la API de Play que no sea GET se rechaza ANTES de salir de la máquina (el token OAuth viaja por otro canal)."""
    http = svc._http
    orig = http.request

    def only_get(uri, method="GET", *a, **kw):
        if str(method).upper() != "GET":
            raise RuntimeError("MODO SOLO LECTURA: se bloqueó un pedido %s a la API de Google Play (%s)" % (method, str(uri).split("?")[0][-80:]))
        return orig(uri, method, *a, **kw)
    http.request = only_get


def _build_service(creds):
    endpoint = os.environ.get("PLAY_API_ENDPOINT")  # SÓLO para las pruebas con un Google Play falso (tools/play/tests); en producción no se usa
    if endpoint:
        from googleapiclient.discovery import build_from_document
        from googleapiclient.discovery_cache import get_static_doc
        doc = json.loads(get_static_doc("androidpublisher", "v3"))
        doc["rootUrl"] = endpoint
        return build_from_document(doc, credentials=creds)
    from googleapiclient.discovery import build
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


# ───────────────────────── errores de Google, en castellano ─────────────────────────
HINTS = [
    (r"apkUpgradeVersionConflict|already been used|versionCode.*(used|duplicate)",
     "Ese código de versión (versionCode) YA existe en Play. Hay que volver a armar el AAB con un número más alto (el flujo lo calcula solo)."),
    (r"draft app|only releases with status draft",
     "La app todavía está en borrador en Play Console (nunca se publicó una versión): Google sólo deja crear versiones en estado «borrador» por la API. "
     "Se puede reintentar con release_status=draft y terminar el primer envío a mano en Play Console."),
    (r"The caller does not have permission|forbidden|403",
     "La cuenta de servicio no tiene permiso. En Play Console → Usuarios y permisos → invitá el correo de la cuenta de servicio y dale permisos de la app "
     "(publicar en pruebas / administrar versiones). Puede tardar hasta ~24 h en activarse. Verificá también que la «Google Play Android Developer API» esté habilitada en Google Cloud."),
    (r"applicationNotFound|No application was found|Package not found|404",
     "Play no encuentra la app «%PKG%» para esa cuenta de servicio (la cuenta SÍ se autenticó: Google respondió). Causas posibles: (1) en Play Console el paquete recién queda "
     "asociado a la app cuando se sube el PRIMER AAB a mano (Prueba y publicación → Pruebas internas → Crear versión): hasta entonces la API contesta «Package not found»; "
     "(2) la cuenta de servicio no tiene permisos sobre esa app (Play Console → Usuarios y permisos → la cuenta → Permisos de la app); (3) el permiso es de hace menos de ~24 h."),
    (r"signature|certificate|signed with|upload key|different key",
     "La firma del AAB no coincide con la clave de subida registrada en Play. Usá el keystore de subida correcto (no lo cambies sin pedir el restablecimiento de la clave en Play Console)."),
    (r"versionCode.*lower|lower than|downgrade",
     "El versionCode es menor que el de una versión ya publicada."),
    (r"releaseNotes|release notes|language",
     "Las notas de la versión tienen un problema (idioma no admitido o más de 500 caracteres)."),
]


def explain_http_error(err, package=""):
    """Convierte un HttpError de Google en un texto comprensible (sin credenciales)."""
    try:
        status = getattr(err, "status_code", None) or err.resp.status
        body = err.content.decode("utf-8", "replace") if getattr(err, "content", None) else str(err)
        msg = json.loads(body).get("error", {}).get("message", body)
    except Exception:
        status, msg = "?", str(err)
    text = "Google respondió %s: %s" % (status, msg)
    hay = "%s %s" % (status, msg)
    for pat, hint in HINTS:
        if re.search(pat, hay, re.I):
            return text + "\n   → " + hint.replace("%PKG%", package)
    return text


def fail(msg, code=1):
    print("::error::" + msg)
    print("⛔ " + msg)
    sys.exit(code)

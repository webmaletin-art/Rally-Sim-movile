#!/usr/bin/env python3
"""Ficha de Google Play: lee los textos (store_listing/ficha.md y novedades.md), controla límites e imágenes y, con credenciales, los sube.

Uso:
  python3 tools/play/listing.py check                       # sólo controla (sin red ni credenciales)
  python3 tools/play/listing.py sync --mode validate        # sube a una edición temporal, la valida y la BORRA (no publica nada)
  python3 tools/play/listing.py sync --mode publish         # sube y confirma (los cambios de la ficha pasan por revisión de Google)

Límites de Google (2026): título 30 · descripción corta 80 · completa 4000 · notas de la versión 500 por idioma ·
ícono 512×512 PNG (hasta 1 MB) · gráfico de funciones 1024×500 JPG/PNG sin transparencia · capturas de teléfono 2 a 8,
JPG o PNG sin transparencia, lado entre 320 y 3840 px y el lado largo no más del doble del corto."""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from play_common import Report, build_service, explain_http_error, fail, load_config, masked_account, repo_path, service_account_info  # noqa: E402

LIM = {"title": 30, "short": 80, "full": 4000, "notes": 500}
LABEL = re.compile(r"^\*\*(.+?)\*\*:?\s*(.*)$")


def parse_ficha(path):
    """{idioma_play: {title, short, full}} leyendo las secciones «## <idioma>» de ficha.md (en el orden de game.json)."""
    text = open(path, encoding="utf-8").read().split("\n")
    heads = [i for i, l in enumerate(text) if l.startswith("## ")] + [len(text)]
    out = []
    for a, b in zip(heads, heads[1:]):
        sec = text[a:b]
        labels = [(j, LABEL.match(l)) for j, l in enumerate(sec) if LABEL.match(l)]
        if len(labels) < 3:
            continue
        title = labels[0][1].group(2).strip()
        short = labels[1][1].group(2).strip()
        j0 = labels[2][0]
        end = next((j for j in range(j0 + 1, len(sec)) if sec[j].startswith("**") or sec[j].startswith("###")), len(sec))
        full = "\n".join(sec[j0 + 1:end]).strip()
        out.append({"heading": sec[0][3:].strip(), "title": title, "short": short, "full": full})
    return out


def parse_novedades(path):
    """{idioma_play: texto} del bloque con etiquetas <es-419>…</es-419> de novedades.md."""
    text = open(path, encoding="utf-8").read()
    return {m.group(1): m.group(2).strip() for m in re.finditer(r"<([a-z]{2,3}-[A-Za-z0-9]+)>\n(.*?)\n</\1>", text, re.S)}


def load_texts(cfg):
    sections = parse_ficha(repo_path(cfg["listing"]["ficha"]))
    langs = list(cfg["languages"])
    texts = {}
    for lang, sec in zip(langs, sections):
        texts[lang] = sec
    return texts, sections


def image_info(path):
    from PIL import Image
    with Image.open(path) as im:
        has_alpha = im.mode in ("RGBA", "LA") or "transparency" in im.info
        return {"size": im.size, "format": im.format, "alpha": has_alpha, "bytes": os.path.getsize(path)}


def check(cfg, rep=None):
    rep = rep or Report("Ficha de Google Play (textos e imágenes)")
    li = cfg["listing"]
    # textos
    try:
        texts, sections = load_texts(cfg)
    except FileNotFoundError:
        rep.block("No existe %s" % li["ficha"])
        return rep
    langs = list(cfg["languages"])
    if len(sections) != len(langs):
        rep.block("ficha.md tiene %d idiomas y game.json espera %d (%s)" % (len(sections), len(langs), ", ".join(langs)))
    for lang, t in texts.items():
        bad = []
        if not t["title"] or len(t["title"]) > LIM["title"]:
            bad.append("título %d/%d" % (len(t["title"]), LIM["title"]))
        if not t["short"] or len(t["short"]) > LIM["short"]:
            bad.append("descripción corta %d/%d" % (len(t["short"]), LIM["short"]))
        if not t["full"] or len(t["full"]) > LIM["full"]:
            bad.append("descripción completa %d/%d" % (len(t["full"]), LIM["full"]))
        if bad:
            rep.block("%s: fuera de límite (%s)" % (lang, "; ".join(bad)))
        else:
            rep.ok("%s: título %d/30 · corta %d/80 · completa %d/4000" % (lang, len(t["title"]), len(t["short"]), len(t["full"])))
    # notas de la versión
    try:
        notes = parse_novedades(repo_path(li["novedades"]))
    except FileNotFoundError:
        notes = {}
        rep.block("No existe %s (notas de la versión)" % li["novedades"])
    for lang in langs:
        n = notes.get(lang)
        if n is None:
            rep.block("Falta la nota de versión en %s" % lang)
        elif len(n) > LIM["notes"]:
            rep.block("Nota de versión %s: %d/500 caracteres" % (lang, len(n)))
    if notes and all(l in notes and len(notes[l]) <= LIM["notes"] for l in langs):
        rep.ok("Notas de la versión en los %d idiomas (máx. %d de 500 caracteres)" % (len(langs), max(len(v) for v in notes.values())))
    # imágenes
    try:
        import PIL  # noqa: F401
    except ImportError:
        rep.warn("No está Pillow: no se pudieron revisar las imágenes (pip install pillow)")
        return rep
    ic = repo_path(li["icon"])
    if not os.path.exists(ic):
        rep.block("Falta el ícono %s" % li["icon"])
    else:
        i = image_info(ic)
        if i["size"] != (512, 512) or i["format"] != "PNG" or i["bytes"] > 1024 * 1024:
            rep.block("Ícono: tiene que ser PNG de 512×512 y ≤ 1 MB (es %s %s, %d KB)" % (i["format"], i["size"], i["bytes"] // 1024))
        else:
            rep.ok("Ícono 512×512 PNG (%d KB). Es el «DR» provisorio: se puede cambiar cuando haya logo" % (i["bytes"] // 1024))
    fg = repo_path(li["feature_graphic"])
    if not os.path.exists(fg):
        rep.block("Falta el gráfico de funciones %s" % li["feature_graphic"])
    else:
        i = image_info(fg)
        if i["size"] != (1024, 500) or i["format"] not in ("PNG", "JPEG") or i["alpha"]:
            rep.block("Gráfico de funciones: 1024×500 JPG/PNG SIN transparencia (es %s %s alfa=%s)" % (i["format"], i["size"], i["alpha"]))
        else:
            rep.ok("Gráfico de funciones 1024×500 (%d KB)" % (i["bytes"] // 1024))
    sd = repo_path(li["screenshots_dir"])
    shots = sorted(f for f in os.listdir(sd) if f.lower().endswith((".jpg", ".jpeg", ".png"))) if os.path.isdir(sd) else []
    good = 0
    for f in shots:
        i = image_info(os.path.join(sd, f))
        w, h = i["size"]
        mn, mx = min(w, h), max(w, h)
        if mn < 320 or mx > 3840 or mx > 2 * mn or i["alpha"] or i["bytes"] > 8 * 1024 * 1024:
            rep.block("Captura %s no cumple (tamaño %s, alfa=%s, %d KB)" % (f, i["size"], i["alpha"], i["bytes"] // 1024))
        else:
            good += 1
    if good < 2:
        rep.block("Hacen falta al menos 2 capturas de teléfono válidas (hay %d)" % good)
    else:
        rep.ok("%d capturas de teléfono válidas (%s…)" % (good, ", ".join(shots[:3])))
        if good > 8:
            rep.block("Play admite hasta 8 capturas de teléfono (hay %d)" % good)
    rep.info("Capturas de tablet de 7\"/10\": no hay (opcionales; sin ellas la ficha igual se publica, pero Play recomienda subirlas para aparecer en tabletas)")
    # vídeo
    vid = li.get("video_youtube_url")
    if vid:
        if re.match(r"^https://(www\.)?(youtube\.com/watch\?v=|youtu\.be/)[\w-]{11}", vid):
            rep.ok("Vídeo promocional: %s" % vid)
        else:
            rep.block("video_youtube_url no es un enlace de YouTube válido")
    else:
        rep.warn("Vídeo promocional: todavía no hay enlace de YouTube (Play sólo admite vídeos de YouTube). El tráiler existe como archivo; falta subirlo a YouTube y poner la URL en tools/play/game.json → listing.video_youtube_url")
    # datos legales y de contacto
    for key, label in (("privacy_url", "Política de privacidad"), ("delete_account_url", "Página de eliminación de cuenta")):
        url = li.get(key, "")
        if url.startswith("https://"):
            rep.ok("%s: %s (el script NO comprueba que la página responda; ver auditoría en línea)" % (label, url))
        else:
            rep.block("%s sin URL https" % label)
    if re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", li.get("contact_email", "")):
        rep.ok("Correo de contacto: %s" % li["contact_email"])
    else:
        rep.block("Falta el correo de contacto")
    return rep


def sync(cfg, mode):
    info = service_account_info()
    if not info:
        fail("No hay cuenta de servicio (GOOGLE_PLAY_SERVICE_ACCOUNT): no se puede subir la ficha.")
    rep = check(cfg)
    if rep.blockers:
        rep.emit()
        fail("La ficha tiene problemas: no se sube nada.")
    from googleapiclient.http import MediaFileUpload
    pkg = cfg["package"]
    svc = build_service(info)
    print("Cuenta de servicio: %s" % masked_account(info))
    texts, _ = load_texts(cfg)
    li = cfg["listing"]
    default = cfg["default_language"]
    edit_id = None
    try:
        edit_id = svc.edits().insert(packageName=pkg, body={}).execute()["id"]
        for lang, t in texts.items():
            body = {"language": lang, "title": t["title"], "shortDescription": t["short"], "fullDescription": t["full"]}
            if li.get("video_youtube_url") and lang == default:
                body["video"] = li["video_youtube_url"]
            svc.edits().listings().update(packageName=pkg, editId=edit_id, language=lang, body=body).execute()
            print("  texto subido: %s" % lang)
        def put(kind, files):
            svc.edits().images().deleteall(packageName=pkg, editId=edit_id, language=default, imageType=kind).execute()
            for f in files:
                mt = "image/png" if f.lower().endswith(".png") else "image/jpeg"
                svc.edits().images().upload(packageName=pkg, editId=edit_id, language=default, imageType=kind,
                                            media_body=MediaFileUpload(f, mimetype=mt)).execute()
            print("  imágenes %s: %d" % (kind, len(files)))
        put("icon", [repo_path(li["icon"])])
        put("featureGraphic", [repo_path(li["feature_graphic"])])
        sd = repo_path(li["screenshots_dir"])
        put("phoneScreenshots", [os.path.join(sd, f) for f in sorted(os.listdir(sd)) if f.lower().endswith((".jpg", ".jpeg", ".png"))])
        svc.edits().validate(packageName=pkg, editId=edit_id).execute()
        print("✅ Google validó la ficha (edición %s)" % edit_id)
        if mode == "publish":
            r = svc.edits().commit(packageName=pkg, editId=edit_id).execute()
            edit_id = None
            print("✅ Ficha confirmada en Play Console (edición %s). Los cambios pasan por la revisión de Google." % r.get("id"))
        else:
            print("ℹ️ Modo validar: no se confirmó nada.")
    except Exception as e:  # noqa: BLE001
        try:
            msg = explain_http_error(e, pkg)
        except Exception:  # noqa: BLE001
            msg = str(e)
        fail(msg)
    finally:
        if edit_id:
            try:
                svc.edits().delete(packageName=pkg, editId=edit_id).execute()
                print("  (edición temporal borrada)")
            except Exception:  # noqa: BLE001
                pass


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["check", "sync"])
    ap.add_argument("--config")
    ap.add_argument("--mode", choices=["validate", "publish"], default="validate")
    a = ap.parse_args()
    cfg = load_config(a.config)
    if a.cmd == "check":
        rep = check(cfg)
        rep.emit()
        sys.exit(1 if rep.blockers else 0)
    sync(cfg, a.mode)


if __name__ == "__main__":
    main()

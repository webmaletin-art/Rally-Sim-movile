#!/usr/bin/env python3
"""Controla que las bibliotecas nativas de 64 bits de un .aab/.apk estén listas para páginas de memoria de 16 KB (exigencia de Google Play
para apps con API objetivo 35+): cada segmento LOAD del ELF alineado a 0x4000 o más.
Uso: python3 tools/export/check_aab_alignment.py archivo.aab   (sale con código 1 si alguna biblioteca de 64 bits sigue en 4 KB)
Godot 4.4.1 NO cumplía (libgodot_android.so quedaba en 0x1000); desde Godot 4.5 sí. Ver docs/PLAY_STORE.md, sección 7.1."""
import struct
import sys
import zipfile

PAGE_16K = 0x4000

def load_alignments(data: bytes):
    """Devuelve (es_64_bits, [p_align de cada segmento LOAD]) o None si no es un ELF."""
    if data[:4] != b"\x7fELF":
        return None
    is64 = data[4] == 2
    if is64:
        phoff = struct.unpack_from("<Q", data, 0x20)[0]
        phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    else:
        phoff = struct.unpack_from("<I", data, 0x1C)[0]
        phentsize, phnum = struct.unpack_from("<HH", data, 0x2A)
    aligns = []
    for i in range(phnum):
        o = phoff + i * phentsize
        if struct.unpack_from("<I", data, o)[0] != 1:  # PT_LOAD
            continue
        aligns.append(struct.unpack_from("<Q", data, o + 0x30)[0] if is64 else struct.unpack_from("<I", data, o + 0x1C)[0])
    return is64, aligns

def main(path: str) -> int:
    bad = 0
    n = 0
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            if not info.filename.endswith(".so"):
                continue
            res = load_alignments(z.read(info.filename))
            if res is None:
                continue
            is64, aligns = res
            n += 1
            ok = (not is64) or (bool(aligns) and min(aligns) >= PAGE_16K)
            print(("OK   " if ok else "FALLA ") + info.filename + " · LOAD p_align " + ", ".join(hex(a) for a in sorted(set(aligns))) + ("" if is64 else " (32 bits: no se exige)"))
            if not ok:
                bad += 1
    if n == 0:
        print("FALLA: no se encontró ninguna biblioteca .so")
        return 1
    print("16 KB: " + ("todo bien" if bad == 0 else "%d biblioteca(s) de 64 bits sin alinear a 16 KB: Google Play no va a aceptar este archivo" % bad))
    return 1 if bad else 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))

#!/usr/bin/env python3
"""Controllo della CI: le texture che finiscono nel pacchetto del gioco sono compresse per la scheda video e hanno le
mipmap.

Godot senza editor importa le immagini nuove Lossless e senza mipmap (detect_3d non scatta mai), e
tools/godot_vram_textures.py converte solo le texture estratte dai GLB. Una texture Lossless (o Lossy, o Basis) si
decodifica sulla CPU nel fotogramma in cui entra: il 29 ottobre le foto delle Polaroid P11-P16 facevano durare 331 ms
invece di 9 il passo delle Polaroid nella torre a pezzi.

Guarda ogni .import con importer="texture" della cartella del progetto, tranne i file tolti dal pacchetto
(exclude_filter di export_presets.cfg: un file conta se almeno un preset lo esporta). Fallisce se compress/mode non è 2
(VRAM Compressed) o se mipmaps/generate è false, a meno che il file non sia nell'elenco delle eccezioni volute
(tools/ci/texture_lossless_volute.txt: un percorso da res:// per riga, poi " | " e il motivo).

Uso: python3 tools/ci/texture_compresse.py [cartella del progetto, predefinita: godot] [elenco delle eccezioni]
"""
import fnmatch
import os
import re
import sys

QUI = os.path.dirname(os.path.abspath(__file__))
ELENCO = os.path.join(QUI, "texture_lossless_volute.txt")
MODI = {"0": "Lossless", "1": "Lossy", "2": "VRAM Compressed", "3": "VRAM Uncompressed", "4": "Basis Universal"}


def filtri_esclusi(progetto: str) -> list:
    """Le liste di exclude_filter, una per preset."""
    p = os.path.join(progetto, "export_presets.cfg")
    if not os.path.exists(p):
        return [[]]
    testo = open(p, encoding="utf-8").read()
    out = []
    for m in re.finditer(r'^exclude_filter="([^"]*)"', testo, re.M):
        out.append([f.strip() for f in m.group(1).split(",") if f.strip()])
    return out or [[]]


def esportato(rel: str, presets: list) -> bool:
    """Vero se almeno un preset mette il file nel pacchetto (come Godot: senza maiuscole, * vale anche per le
    sottocartelle, il filtro vale per il percorso o per il solo nome)."""
    rel = rel.lower()
    for filtri in presets:
        if not any(fnmatch.fnmatchcase(rel, f.lower()) or fnmatch.fnmatchcase(os.path.basename(rel), f.lower())
                   for f in filtri):
            return True
    return False


def leggi_eccezioni(percorso: str) -> dict:
    out = {}
    if not os.path.exists(percorso):
        return out
    for n, riga in enumerate(open(percorso, encoding="utf-8"), 1):
        riga = riga.strip()
        if not riga or riga.startswith("#"):
            continue
        if " | " not in riga or not riga.split(" | ", 1)[1].strip():
            print(f"{percorso}:{n}: manca il motivo (formato: res://percorso | motivo)")
            out[None] = True
            continue
        file, motivo = riga.split(" | ", 1)
        out[file.strip()] = motivo.strip()
    return out


def controlla(progetto: str, elenco: str = ELENCO) -> int:
    presets = filtri_esclusi(progetto)
    eccezioni = leggi_eccezioni(elenco)
    errori = []
    usate = set()
    totale = 0
    for d, cartelle, files in os.walk(progetto):
        cartelle[:] = [c for c in cartelle if c != ".godot" and not os.path.exists(os.path.join(d, c, ".gdignore"))]
        for f in files:
            if not f.endswith(".import"):
                continue
            p = os.path.join(d, f)
            testo = open(p, encoding="utf-8", errors="replace").read()
            if not re.search(r'^importer="texture"\s*$', testo, re.M):
                continue
            rel = os.path.relpath(p, progetto)[: -len(".import")].replace(os.sep, "/")
            if not esportato(rel, presets):
                continue
            totale += 1
            modo = re.search(r"^compress/mode=(\d+)", testo, re.M)
            mip = re.search(r"^mipmaps/generate=(\w+)", testo, re.M)
            modo = modo.group(1) if modo else "?"
            mip = mip.group(1) if mip else "?"
            if modo == "2" and mip == "true":
                continue
            res = "res://" + rel
            if res in eccezioni:
                usate.add(res)
                continue
            cosa = []
            if modo != "2":
                cosa.append(MODI.get(modo, "compress/mode=" + modo))
            if mip != "true":
                cosa.append("senza mipmap")
            errori.append(f"{res}: {', '.join(cosa)}")
    for res in sorted(set(k for k in eccezioni if k) - usate):
        print(f"avviso: {res} è nell'elenco delle eccezioni ma non serve più (compressa, tolta dal pacchetto o sparita)")
    if eccezioni.get(None):
        errori.append(f"{elenco}: righe senza motivo")
    print(f"texture nel pacchetto: {totale}, eccezioni volute: {len(usate)}, da correggere: {len(errori)}")
    for e in errori:
        print("ERRORE " + e)
    if errori:
        print("Reimportala VRAM Compressed con le mipmap (le normal map come normal map), o mettila nell'elenco col "
              f"motivo ({os.path.relpath(elenco)}). Le texture che uno script legge sulla CPU (get_image) restano come sono.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(controlla(sys.argv[1] if len(sys.argv) > 1 else "godot", sys.argv[2] if len(sys.argv) > 2 else ELENCO))

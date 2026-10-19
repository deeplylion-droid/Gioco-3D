#!/usr/bin/env python3
"""Controlla un pacchetto del gioco esportato (.pck, o un .exe con il .pck dentro).

- Ogni file .import nel pacchetto rimanda a dati importati (path=, path.s3tc=...) che ci sono davvero
  (il plugin EsportaSenzaDoppioni fa rimandare i doppioni alla copia che resta: qui si vede che c'è).
- Stampa il peso per tipo di file e le cartelle più pesanti.

Uso: python3 tools/verifica_pck.py build/windows/SplashLagoon.pck [quante cartelle stampare]
Esce con 1 se un rimando non trova i suoi dati.
"""
import collections
import re
import struct
import sys


def leggi(percorso):
    f = open(percorso, "rb")
    inizio = 0
    if f.read(4) != b"GDPC":
        # pacchetto dentro l'eseguibile: in fondo ci sono la sua dimensione e la firma
        f.seek(-4, 2)
        assert f.read(4) == b"GDPC", "nessun pacchetto Godot"
        f.seek(-12, 2)
        dim = struct.unpack("<Q", f.read(8))[0]
        inizio = f.tell() - 8 - dim
        f.seek(inizio)
        assert f.read(4) == b"GDPC"
    ver, _ma, _mi, _pa, flags = struct.unpack("<5I", f.read(20))
    base = struct.unpack("<Q", f.read(8))[0]
    if flags & 2:  # FILES_RELATIVE: offset dei file contati dall'inizio del pacchetto
        base += inizio
    if ver >= 3:
        f.seek(inizio + struct.unpack("<Q", f.read(8))[0])
    else:
        f.read(64)
    file = {}
    for _ in range(struct.unpack("<I", f.read(4))[0]):
        lung = struct.unpack("<I", f.read(4))[0]
        nome = f.read(lung).rstrip(b"\0").decode()
        off, dim = struct.unpack("<QQ", f.read(16))
        f.read(16)  # md5
        if ver >= 2:
            f.read(4)  # flag
        file[nome.removeprefix("res://")] = (off + base, dim)
    return f, file


def main():
    f, file = leggi(sys.argv[1])
    quante = int(sys.argv[2]) if len(sys.argv) > 2 else 15
    rotti = []
    sorgente = {}  # dati importati -> file sorgente (per contare il peso nella cartella giusta)
    for nome, (off, dim) in file.items():
        if not nome.endswith(".import"):
            continue
        f.seek(off)
        testo = f.read(dim).decode("utf-8", "replace")
        for dati in re.findall(r'^path[.\w]*="res://([^"]+)"', testo, re.M):
            sorgente.setdefault(dati, nome.removesuffix(".import"))
            if dati not in file:
                rotti.append((nome, dati))
    tipi = collections.Counter()
    cartelle = collections.Counter()
    for nome, (_off, dim) in file.items():
        tipi[nome.rsplit(".", 1)[-1]] += dim
        cartelle["/".join(sorgente.get(nome, nome).split("/")[:3])] += dim
    tot = sum(d for _o, d in file.values())
    print(f"{len(file)} file, {tot / 1e6:.0f} MB")
    print("per tipo:", ", ".join(f"{k} {v / 1e6:.0f} MB" for k, v in tipi.most_common(6)))
    for k, v in cartelle.most_common(quante):
        print(f"  {v / 1e6:6.0f} MB  {k}")
    for nome, rotto in rotti:
        print(f"ROTTO: {nome} rimanda a {rotto}, che non c'è")
    print(f"rimandi dei file .import: {'tutti ok' if not rotti else str(len(rotti)) + ' rotti'}")
    return 1 if rotti else 0


if __name__ == "__main__":
    sys.exit(main())

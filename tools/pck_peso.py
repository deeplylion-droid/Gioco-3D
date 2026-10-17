#!/usr/bin/env python3
"""Quanto pesa ogni cartella dentro un PCK di Godot 4 (o un .exe con il PCK incorporato).

Legge l'indice del pacchetto (formato 2 e 3) e somma le dimensioni dei file per cartella, fino alla
profondità indicata. I file importati stanno in .godot/imported/ con il nome del sorgente davanti
(es. "sala_area_bimbi.glb-<hash>.scn"): per attribuirli alla cartella giusta si usano i file .import
del pacchetto, che dicono dove sta il sorgente.

Uso: python3 tools/pck_peso.py <file.pck|file.exe> [profondità, di serie 3] [--file N: i N file più grandi]
"""
import struct, sys, collections


def apri(path):
    f = open(path, 'rb')
    data = f.read(4)
    base = 0
    if data != b'GDPC':
        # PCK incorporato: in fondo all'exe ci sono la dimensione del pacchetto e la firma
        f.seek(-4, 2)
        if f.read(4) != b'GDPC':
            raise SystemExit('nessun PCK in ' + path)
        f.seek(-12, 2)
        size = struct.unpack('<Q', f.read(8))[0]
        f.seek(-12 - size, 2)
        base = f.tell()
        if f.read(4) != b'GDPC':
            raise SystemExit('PCK incorporato non trovato')
    return f, base


def indice(path):
    f, base = apri(path)
    ver, maj, mi, pa = struct.unpack('<4I', f.read(16))
    flags = struct.unpack('<I', f.read(4))[0]
    file_base = struct.unpack('<Q', f.read(8))[0]
    if ver >= 3:
        dir_off = struct.unpack('<Q', f.read(8))[0]
        f.seek(base + dir_off)
    else:
        f.read(16 * 4)
    n = struct.unpack('<I', f.read(4))[0]
    voci = []
    for _ in range(n):
        ln = struct.unpack('<I', f.read(4))[0]
        nome = f.read(ln).rstrip(b'\0').decode('utf-8', 'replace')
        off, size = struct.unpack('<QQ', f.read(16))
        f.read(16)
        f.read(4)
        voci.append((nome, size, off))
    return voci, f, base, file_base


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    path = args[0]
    prof = int(args[1]) if len(args) > 1 else 3
    quanti = int(sys.argv[sys.argv.index('--file') + 1]) if '--file' in sys.argv else 0
    voci, f, base, file_base = indice(path)
    # .import -> sorgente: "res://x/y.glb.import" dice dove va "x/y.glb-<hash>.*"
    sorgente = {}
    for nome, size, off in voci:
        if nome.endswith('.import'):
            f.seek(base + file_base + off)
            testo = f.read(size).decode('utf-8', 'replace')
            src = nome[:-len('.import')].replace('res://', '')
            for riga in testo.splitlines():
                if riga.startswith('path') and '.godot/imported/' in riga:
                    dest = riga.split('"')[1].replace('res://', '')
                    sorgente[dest] = src
    tot = collections.Counter()
    grandi = []
    for nome, size, off in voci:
        p = nome.replace('res://', '')
        p = sorgente.get(p, p)
        parti = p.split('/')
        tot['/'.join(parti[:min(prof, len(parti) - 1)]) or '.'] += size
        grandi.append((size, p))
    somma = sum(tot.values())
    print(f'{len(voci)} file, {somma / 1e6:.0f} MB')
    for k, v in sorted(tot.items(), key=lambda x: -x[1])[:40]:
        print(f'{v / 1e6:9.1f} MB  {k}')
    if quanti:
        print('--- i file più grandi')
        for size, p in sorted(grandi, reverse=True)[:quanti]:
            print(f'{size / 1e6:9.1f} MB  {p}')


if __name__ == '__main__':
    main()

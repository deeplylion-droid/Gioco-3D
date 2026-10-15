"""Scrive godot/addons/audio/catalogo.gd (nome del suono -> varianti) e imposta il loop
nei file .import degli OGG che finiscono con "_loop". Si lancia dopo i generatori."""
import glob
import os
import re

from comune import AUDIO, RADICE

ADDON = os.path.join(RADICE, 'godot', 'addons', 'audio')


def nome_suono(base: str) -> str:
    return re.sub(r'_\d\d$', '', base)


def main():
    # anteprima/ ha un .gdignore: non fa parte del gioco
    files = sorted(f for f in glob.glob(os.path.join(AUDIO, '*', '*.ogg'))
                   if os.path.basename(os.path.dirname(f)) != 'anteprima')
    suoni: dict = {}
    for f in files:
        rel = os.path.relpath(f, os.path.join(RADICE, 'godot')).replace(os.sep, '/')
        base = os.path.splitext(os.path.basename(f))[0]
        suoni.setdefault(nome_suono(base), []).append('res://' + rel)
    righe = [
        '# Generato da assets_src/audio/catalogo.py: non modificare a mano.',
        '# Nome del suono -> varianti (file OGG in res://audio/). I nomi che finiscono con',
        '# "_loop" sono fondi o suoni continui e si ripetono senza scatti.',
        'extends RefCounted',
        '',
        '## Sigla rovinata: 96 BPM (1,6 battiti al secondo, come la pulsazione della campana);',
        '## il primo battito cade a questo punto del file (secondi).',
        'const SIGLA_ROVINATA_BPM := 96.0',
        'const SIGLA_ROVINATA_PRIMO_BATTITO := 0.05',
        'const SIGLA_PULITA_BPM := 120.0',
        '',
        'const SUONI := {',
    ]
    for k in sorted(suoni):
        v = ', '.join(f'"{p}"' for p in suoni[k])
        righe.append(f'\t&"{k}": [{v}],')
    righe.append('}')
    os.makedirs(ADDON, exist_ok=True)
    with open(os.path.join(ADDON, 'catalogo.gd'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(righe) + '\n')
    print(f'catalogo.gd: {len(suoni)} suoni, {len(files)} file')
    # loop negli .import (se Godot li ha già creati); altrimenti li crea l'importazione
    n_loop = 0
    for f in files:
        imp = f + '.import'
        if not os.path.exists(imp):
            continue
        txt = open(imp, encoding='utf-8').read()
        voglio = 'true' if os.path.basename(f).endswith('_loop.ogg') else 'false'
        nuovo = re.sub(r'^loop=(true|false)$', f'loop={voglio}', txt, flags=re.M)
        if nuovo != txt:
            open(imp, 'w', encoding='utf-8').write(nuovo)
        n_loop += voglio == 'true'
    print(f'.import con loop=true: {n_loop}')


if __name__ == '__main__':
    main()

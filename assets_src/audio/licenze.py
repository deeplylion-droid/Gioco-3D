"""Scrive godot/audio/LICENZE.md dal registro dei file generati (registro.json)."""
import json
import os

from comune import AUDIO, KENNEY, REGISTRO

PACCHETTI = [
    ('Impact Sounds', 'https://kenney.nl/assets/impact-sounds',
     'footstep_concrete_000-004, impactMetal_light_000-004, impactMetal_heavy_000-004, '
     'impactPlate_light_000-004, impactSoft_medium_000-004'),
    ('RPG Audio', 'https://kenney.nl/assets/rpg-audio',
     'creak1-3, doorClose_1-4, cloth1-2, clothBelt, metalLatch'),
    ('Interface Sounds', 'https://kenney.nl/assets/interface-sounds',
     'click_001, tick_002, toggle_002, switch_002, open_002, close_002'),
    ('Sci-Fi Sounds', 'https://kenney.nl/assets/sci-fi-sounds', 'lowFrequency_explosion_000-001, slime_000-001'),
]


def main():
    with open(REGISTRO, encoding='utf-8') as f:
        reg = json.load(f)
    righe = [
        '# Suoni di Splash Lagoon: fonti e licenze',
        '',
        'Tutti i suoni di questa cartella sono **generati dagli script** in `assets_src/audio/` '
        '(`python genera_tutto.py` con il venv di Blender: numpy, scipy e ffmpeg). Sono di due tipi:',
        '',
        '- **Sintesi procedurale** scritta per questo gioco (rumori filtrati, sintesi modale, bolle, '
        'riverbero a convoluzione con risposte all\'impulso sintetiche, ecc.). Nessun campione esterno.',
        '- **Campioni CC0 di Kenney** (www.kenney.nl) rielaborati: filtrati, trasposti, rallentati, '
        'sovrapposti a parti sintetiche. Licenza **Creative Commons Zero 1.0** (pubblico dominio): uso libero '
        'anche commerciale, il credito non è obbligatorio ma lo diamo volentieri.',
        '',
        'La **sigla della mascotte** (`musica/sigla_pulita.ogg`, `musica/sigla_rovinata.ogg`) è una '
        'melodia originale con arrangiamento originale (carillon, organetto, percussioni giocattolo), '
        'scritta nota per nota in `assets_src/audio/genera_musica.py`. Anche gli stinger sono originali.',
        '',
        'Niente da freesound, niente modelli generativi.',
        '',
        '## Pacchetti Kenney usati (CC0)',
        '',
        '| Pacchetto | Pagina | File usati |',
        '|---|---|---|',
    ]
    for nome, url, file in PACCHETTI:
        righe.append(f'| {nome} | {url} | {file} |')
    righe += [
        '',
        f'I file originali usati sono copiati in `assets_src/audio/sorgenti/kenney/` con le licenze '
        f'({len([x for x in os.listdir(KENNEY) if x.endswith(".ogg")])} file).',
        '',
        '## Elenco dei file',
        '',
        '| File | Durata | Origine | Note |',
        '|---|---|---|---|',
    ]
    tot = 0
    for k, v in reg.items():
        path = os.path.join(AUDIO, k + '.ogg')
        if not os.path.exists(path):
            continue
        tot += os.path.getsize(path)
        fonte = v['fonte'] if v['fonte'] != 'sintesi' else 'sintesi (originale)'
        righe.append(f"| `{k}.ogg` | {v['durata']:.1f} s | {fonte} | {v.get('nota', '')} |")
    righe += ['', f'Totale: {len(reg)} file, {tot / 1048576:.1f} MB (OGG Vorbis, 44,1 kHz; mono i suoni '
              'posizionati, stereo i fondi, la musica e i tuoni).', '']
    with open(os.path.join(AUDIO, 'LICENZE.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(righe))
    print(f'LICENZE.md: {len(reg)} file')


if __name__ == '__main__':
    main()

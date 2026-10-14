"""Grafiche dei cartelloni di prova (Meshy Text to Image), una per palette. SENZA SCRITTE:
i nomi provvisori (nave, compagnia, acquapark) non sono approvati.

Uso: python assets_src/ambiente/cartelloni/meshy_cartelloni.py
Gli ID dei task restano in meshy_task.json (rilanciando non si ripagano i task già fatti).
"""
import json, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '..', '..', '..', 'tools'))
import meshy  # noqa: E402

STATO = os.path.join(QUI, 'meshy_task.json')
COMUNE = ('flat 1990s cartoon illustration for a family cruise ship water park wall poster, '
          'cheerful and cute, simple bold shapes with thick outlines, bubbles, '
          'absolutely no text, no letters, no words, no numbers, no logos, no signature, '
          'full-bleed artwork filling the whole frame, no border, no frame')
CARTELLONI = {
    'p1': ('a smiling turquoise dolphin jumping over stylised waves under a red and white striped '
           'sun umbrella, color scheme of turquoise, white and red, ' + COMUNE),
    'p2': ('a happy blue whale wearing a little sailor hat splashing in deep blue waves with yellow '
           'starfish and a yellow sun, saturated deep blue and golden yellow colors, ' + COMUNE),
    'p3': ('a friendly octopus and a seahorse playing with a beach ball among waves, faded pastel '
           'pink, mint green and pale yellow, slightly washed-out vintage print colors, ' + COMUNE),
}

st = json.load(open(STATO)) if os.path.exists(STATO) else {}
for k, prompt in CARTELLONI.items():
    if k not in st:
        st[k] = meshy.create('text-to-image', {'ai_model': 'nano-banana-2', 'prompt': prompt,
                                               'aspect_ratio': '16:9'})
        json.dump(st, open(STATO, 'w'), indent=1)
for k in CARTELLONI:
    dest = os.path.join(QUI, f'cartellone_{k}.png')
    if os.path.exists(dest):
        continue
    t = meshy.wait('text-to-image', st[k], every=6)
    print(k, t['status'])
    if t['status'] == 'SUCCEEDED':
        meshy.download(t['image_urls'][0], dest)

"""Gli scarabocchi a pastelli a cera sui muri più vuoti (richiesta dell'utente del 28 ottobre). Legge i muri scelti
(docs/proposte/scarabocchi/scelti.json: nome, zona, centro, normale, largo, alto) e per ognuno il disegno (DISEGNI qui
sotto, deciso con l'utente: cosa disegnano, i colori, l'altezza), e scrive:
- le texture in godot/assets/ambiente/scarabocchi/<nome>.png (RGBA: cera opaca, grana del muro, bordi irregolari;
  sbiadite e rovinate dove il posto è bagnato);
- godot/assets/ambiente/scarabocchi/scarabocchi.json per il nodo Scarabocchi (le decal sul muro).
Solo disegni: niente lettere né numeri, niente frecce né cerchi colorati in fila (sembrerebbero indizi degli enigmi).
Uso: /home/user/tools/blender-venv/bin/python assets_src/scarabocchi/genera.py [nomi dei muri]
"""
import json
import math
import os
import sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
from pastello import Pastello  # noqa: E402
import disegni  # noqa: E402
from motivi import sole, omino, onde, medusa  # noqa: E402,F401

RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
SCELTI = os.path.join(RADICE, 'docs', 'proposte', 'scarabocchi', 'scelti.json')
USCITA = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'scarabocchi')
RES = 'res://assets/ambiente/scarabocchi'
# pixel per metro (2,4 mm per pixel: il tratto grosso di un pastello, 12-16 mm, è largo 5-7 pixel)
PPM = 420
# le zone bagnate: la cera sbiadisce e si stacca a macchie
BAGNATE = {'fiume': 0.55, 'tunnel': 0.6, 'inseguimento': 0.5, 'piscina': 0.45}


# ------------------------------------------------------------------ i disegni per muro
# (scelte consigliate dal coordinatore all'utente: vedi disegni.py). Un disegno per muro, deciso dalla zona, dall'altezza
# e dall'ordine: in basso disegnini e scarabocchi (nei posti bagnati i pesci, il mare e, uno per zona, i bambini
# sott'acqua), in alto, dove un bambino non arriva, quelli a disagio (le manine che salgono, l'occhio solo).
def scegli(m, k_zona):
    if m.get('alto_su'):
        return disegni.ALTI[k_zona % len(disegni.ALTI)]
    serie = disegni.BASSI_BAGNATI if m['zona'] in BAGNATE else disegni.BASSI
    return serie[k_zona % len(serie)]


def main():
    scelti = json.load(open(SCELTI))
    solo = set(sys.argv[1:])
    os.makedirs(USCITA, exist_ok=True)
    elenco = []
    contatori = {}
    for i, m in enumerate(scelti):
        chiave = (m['zona'], bool(m.get('alto_su')))
        k_zona = contatori.get(chiave, 0)
        contatori[chiave] = k_zona + 1
        if solo and m['nome'] not in solo:
            continue
        w, h = int(m['largo'] * PPM), int(m['alto'] * PPM)
        p = Pastello(w, h, 2810 + i)
        disegno = scegli(m, k_zona)
        disegno(p, w, h)
        im = p.finisci(bagnato=BAGNATE.get(m['zona'], 0.0), sbiadito=0.08)
        nome = 'scarabocchio_%s' % m['nome']
        im.save(os.path.join(USCITA, nome + '.png'))
        elenco.append({'nome': nome, 'zona': m['zona'], 'centro': m['centro'], 'normale': m['normale'],
                       'largo': m['largo'], 'alto': m['alto'], 'texture': '%s/%s.png' % (RES, nome),
                       'sbiadito': 0.0})
        print(nome, w, h, disegno.__name__)
    json.dump(elenco, open(os.path.join(USCITA, 'scarabocchi.json'), 'w'), indent='\t')


if __name__ == '__main__':
    main()

"""Kit di dettagli della sala: piccoli oggetti fatti con Meshy (text-to-3D, PBR).

Uso: MESHY_API_KEY=... python3 tools/blender/dettagli_meshy.py
GLB grezzi in assets_src/ambiente_dettagli/meshy/<nome>.glb (+ .json con prompt e task). Se il file c'e' gia', non lo rifa.
La pulizia (scala, texture 2K in JPG) la fa dettagli_kit.py.
"""
import os, sys, threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ambienti2_meshy as am

am.DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets_src', 'ambiente_dettagli', 'meshy')

OGGETTI = {
    'paperella': 'small yellow rubber duck bath toy, faded and dirty, scuffed vinyl, realistic',
    'secchiello': 'small plastic beach toy bucket with handle, faded red plastic, dirty, realistic',
    'paletta': 'small plastic toy beach spade shovel, faded blue plastic, dirty, realistic',
    'barchetta': 'small plastic toy sailboat, faded white and red plastic, scratched, realistic',
    'ciabatta': 'single rubber flip-flop sandal, worn, faded blue foam sole with white strap, dirty, realistic',
    'maschera_sub': 'children swimming diving mask with snorkel tube, faded pink silicone, scratched lens, realistic',
    'pistola_acqua': 'plastic toy water gun pistol, faded green and orange plastic, dirty, realistic, 1990s',
    'pesce_gomma': 'small rubber squeeze toy fish, faded orange, worn vinyl, realistic',
}

if __name__ == '__main__':
    os.makedirs(am.DEST, exist_ok=True)
    th = [threading.Thread(target=am.genera, args=kv) for kv in OGGETTI.items()]
    [x.start() for x in th]; [x.join() for x in th]

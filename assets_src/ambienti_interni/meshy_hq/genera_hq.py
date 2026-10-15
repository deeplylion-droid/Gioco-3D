"""Oggetti di qualità alta per il pezzo campione (corridoio, zona del tornello, stanzino).
Per ogni oggetto: immagine di riferimento (Meshy text-to-image, solo uso interno, in rif/) ->
image-to-3d meshy-7.1 con geometria 4k, texture PBR 4K e remesh al numero di poligoni dato.
Uso: python3 genera_hq.py [nome ...]  (senza argomenti: tutti quelli che mancano). Scarica <nome>.glb."""
import json, os, sys, time, concurrent.futures as cf, urllib.request
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(QUI, 'rif'), exist_ok=True)
STILE = ('Game-ready 3D asset concept render in the clean style of Poppy Playtime chapter 1: soft rounded bevelled edges, '
         'smooth well-defined shapes, believable materials with subtle wear, light rust at the edges and a few scratches, '
         'not grungy. Single isolated object, three-quarter front view, neutral studio lighting, plain light grey background, '
         'no text, no letters, no logos, no people.')
OGGETTI = {
    # nome: (descrizione, poligoni)
    'tornello_telaio': ('A full-height stainless steel security turnstile FRAME ONLY, WITHOUT the central rotor: two side panels '
                        'made of curved vertical comb bars forming a half-cylinder cage, a rounded top canopy box connecting them, '
                        'brushed steel with dark grey painted base plates.', 60000),
    'tornello_rotore': ('Only the rotating rotor of a full-height turnstile: a thick vertical brushed steel central post with '
                        'three wings, each wing a vertical column of twelve horizontal rounded steel bars, evenly spaced at 120 degrees.', 40000),
    'finestra_gabbiotto': ('A ticket booth service window frame for a wall: thick rounded powder-coated teal metal frame, '
                           'a small stainless steel counter shelf at the bottom, rubber seals, NO glass inside the frame, empty opening.', 25000),
    'quadro_pulsante': ('A small wall-mounted yellow industrial control box with one big red mushroom emergency push button '
                        'and a small green indicator lamp, rounded corners, four screws.', 15000),
    'porta_tagliafuoco': ('A heavy watertight steel ship door leaf only (no frame), painted dark red, rounded corners, '
                          'raised stiffening ribs, two lever handles and dog clamps, a small round porthole window with thick rim.', 40000),
    'porta_servizio': ('A steel service door leaf only (no frame), painted grey-blue, rounded corners, a small rectangular wired glass '
                       'window near the top, a metal push plate, subtle dents.', 30000),
    'armadietto_corpo': ('A single tall metal school gym locker cabinet WITHOUT its door: open front showing the empty inside with a '
                         'hat shelf and coat hook, painted teal green, rounded edges, louvered vent slots on the sides, small base plinth.', 25000),
    'armadietto_anta': ('A single tall metal locker door only: painted teal green, rounded corners, louvered vent slots at top and '
                        'bottom, a lift handle with padlock loop, a blank small number plate, subtle dents.', 15000),
    'panca': ('A locker room bench: three thick rounded varnished wooden slats on sturdy rounded grey steel legs, worn wood, 2 m long.', 20000),
    'lampada_muro': ('A ship bulkhead wall lamp: oval cast metal base, protective metal cage over a glowing red glass dome, '
                     'industrial, chunky rounded shapes.', 15000),
    'plafoniera_neon': ('A ceiling fluorescent light fixture: rounded white-painted metal housing with two glowing white fluorescent '
                        'tubes and end caps, slightly dirty.', 15000),
    'valvola_volantino': ('An industrial pipe gate valve with a big red round handwheel on a short flanged pipe section with bolts.', 20000),
    'flangia_tubo': ('A short section of industrial pipe with two bolted flanges and a wall bracket clamp, painted grey metal, light rust.', 15000),
    'cartello_pericolo': ('A yellow triangular hazard warning sign on a small metal plate showing only a pictogram of a person slipping '
                          'on a wet floor, screws in the corners, no text.', 8000),
    'rastrelliera': ('A wall-mounted equipment rack made of yellow painted round steel tubes: three uprights, two horizontal rails '
                     'with four hooks, and a top mesh shelf.', 25000),
    'scrivania': ('An old small metal office desk with a drawer, grey-green paint, rounded corners, worn top.', 20000),
    'sprinkler': ('A ceiling fire sprinkler head pointing down: brass body with a red glass bulb, a round deflector plate '
                  'and a short threaded pipe stub with a hexagonal fitting.', 6000),
    'condotto_aria': ('A short straight section of rectangular galvanized sheet metal air duct with rounded edges, raised '
                      'flange joints at both ends with bolts, and a small louvered vent grille on one side.', 20000),
    'bacheca': ('An empty cork bulletin board with a rounded wooden frame, a few push pins, landscape format.', 10000),
}


def _scarica(url, path):
    for k in range(4):
        try:
            return meshy.download(url, path)
        except Exception as e:
            time.sleep(5 + 5 * k)
    raise RuntimeError('download ' + url)


def fai(nome):
    out = os.path.join(QUI, nome + '.glb')
    if os.path.exists(out):
        return nome, 'esiste'
    desc, poly = OGGETTI[nome]
    rif = os.path.join(QUI, 'rif', nome + '.png')
    info = {}
    if not os.path.exists(rif):
        tid = meshy.create('text-to-image', dict(ai_model='nano-banana-pro', prompt=desc + ' ' + STILE, aspect_ratio='1:1'))
        t = meshy.wait('text-to-image', tid)
        if t['status'] != 'SUCCEEDED':
            return nome, 'immagine ' + t['status']
        _scarica(t['image_urls'][0], rif)
        info['immagine'] = tid
    info['image_task'] = info.get('immagine')
    corpo = dict(
        input_task_id=info['immagine'] if info.get('immagine') else None,
        image_url=None if info.get('immagine') else 'data:image/png;base64,' + __import__('base64').b64encode(open(rif, 'rb').read()).decode(),
        ai_model='meshy-7.1', geometry_resolution='4k', should_texture=True, enable_pbr=True, texture_resolution='4k',
        should_remesh=True, topology='triangle', target_polycount=poly, remove_lighting=True)
    tid = meshy.create('image-to-3d', {k: v for k, v in corpo.items() if v is not None})
    t = meshy.wait('image-to-3d', tid, timeout=3600)
    info.update(task=tid, status=t['status'], descrizione=desc, poligoni=poly)
    json.dump(info, open(os.path.join(QUI, nome + '.json'), 'w'), indent=1)
    if t['status'] != 'SUCCEEDED':
        return nome, '3d ' + t['status'] + ' ' + str(t.get('task_error'))
    _scarica(t['model_urls']['glb'], out)
    return nome, 'ok'


if __name__ == '__main__':
    nomi = sys.argv[1:] or list(OGGETTI)
    with cf.ThreadPoolExecutor(6) as ex:
        for n, s in ex.map(fai, nomi):
            print(n, s, flush=True)

"""Oggetti di qualità alta per il pezzo campione (corridoio, zona del tornello, stanzino).
Per ogni oggetto: immagine di riferimento (Meshy text-to-image, solo uso interno, in rif/) ->
image-to-3d meshy-7.1 con geometria 4k, texture PBR 4K e remesh al numero di poligoni dato.
Uso: python3 genera_hq.py [nome ...]  (senza argomenti: tutti quelli che mancano). Scarica <nome>.glb."""
import json, os, sys, time, concurrent.futures as cf, urllib.request
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))  # ambienti tecnici (sala pompe, camera delle onde)
os.makedirs(os.path.join(QUI, 'rif'), exist_ok=True)
STILE = ('Game-ready 3D asset concept render in the clean style of Poppy Playtime chapter 1: soft rounded bevelled edges, '
         'smooth well-defined shapes, believable materials with subtle wear, light rust at the edges and a few scratches, '
         'not grungy. Single isolated object, three-quarter front view, neutral studio lighting, plain light grey background, '
         'no text, no letters, no logos, no people.')
OGGETTI = {
    # sala pompe
    'pompa_gialla': ('A large industrial centrifugal water pump unit on a concrete-grey steel skid: spiral volute casing with '
                     'bolted cover, coupling guard, and a big electric motor with cooling fins painted bright yellow, '
                     'flanged inlet and outlet nozzles.', 60000),
    'pompa_rossa': ('A large industrial centrifugal water pump unit on a steel skid: spiral volute casing with bolted cover, '
                    'coupling guard, and a big electric motor with cooling fins painted bright red, flanged inlet and outlet nozzles.', 60000),
    'pompa_blu': ('A large industrial centrifugal water pump unit on a steel skid: spiral volute casing with bolted cover, '
                  'coupling guard, and a big electric motor with cooling fins painted bright blue, flanged inlet and outlet nozzles.', 60000),
    'turbina_avviamento': ('A small axial water turbine impeller: eight curved stainless steel blades around a rounded hub, '
                           'inside a thin steel outer ring, front view slightly angled.', 25000),
    'filtro_tondo': ('A big vertical cylindrical industrial water filter tank, painted teal green, domed top and bottom, '
                     'two bolted flange rings, a round bolted manhole on the side, four short legs, a pressure gauge.', 50000),
    'manometro': ('An old round industrial pressure gauge with a white dial, black numbers-free tick marks, red needle, '
                  'chrome bezel and a short threaded brass stem.', 8000),
    'quadro_elettrico': ('A wall-mounted grey steel electrical control cabinet with a closed door, rows of rotary switches, '
                         'round indicator lamps, a small analog meter window, cable glands at the bottom, rounded corners.', 30000),
    'monitor_crt': ('An old 1990s beige CRT computer monitor with a deep back, curved dark glass screen, small knobs under the screen.', 20000),
    'leva_braccio': ('A big industrial lever arm only: a long steel bar painted with yellow and black stripes ending with a red ball knob, '
                     'with a round pivot hub at the other end.', 12000),
    'paratia': ('A heavy steel sluice gate panel: thick plate with horizontal stiffening ribs, rounded edges, bolts, '
                'a yellow and black hazard stripe band at the bottom edge, worn grey paint.', 30000),
    'quadro_strumenti': ('A wall panel with three round pressure gauges and two small valves on short pipes, painted grey-green.', 25000),
    # dopo il questionario del 15 ottobre: leva nuova (base e braccio separati, il braccio ruota), chiavistello
    # della porta tirato dal cavo della leva, chiusura stagna azionata dalle turbine
    'leva_base': ('A heavy cast iron wall-mounted lever housing: a thick rectangular base plate with four big bolts, a round '
                  'pivot boss in the middle, and a curved notched quadrant guide plate above it, dark green paint worn at '
                  'the edges. No lever arm.', 25000),
    'leva_maniglia': ('A thick industrial lever arm only: a long chunky steel bar painted bright red, a black rubber handle '
                      'grip at the top end, a round pivot eye with a bolt at the bottom end.', 15000),
    'chiavistello': ('A heavy industrial sliding door bolt latch mechanism mounted on a steel plate: a thick round steel bolt '
                     'in two guide brackets, a spring, and a small pulley wheel where a steel cable pulls the bolt, '
                     'yellow and black paint on the bolt.', 20000),
    'attuatore_stagno': ('A hydraulic watertight door seal actuator: a short thick steel cylinder with a piston rod and clevis, '
                         'three small pipe connections with brass unions on top, a round pressure gauge, teal paint.', 25000),
    # per le proposte della tappa 7 (dietro le quinte dell'acquapark): solo render, non nel gioco
    'caldaia': ('A big old industrial boiler: a horizontal riveted steel cylinder painted dark red with a round furnace door '
                'and a big pressure gauge on the front, pipes and a valve wheel on top, on a steel frame base.', 50000),
    'gonfiabili_mucchio': ('A messy pile of deflated colorful pool inflatables on the floor: crumpled swim rings, an orange '
                           'inflatable crocodile, folded air mattresses in blue and yellow, vinyl with soft wrinkles.', 40000),
    'scaffale_magazzino': ('A grey metal storage shelving unit with four shelves holding cardboard boxes, folded pool '
                           'inflatables, coiled hoses and plastic buckets.', 40000),
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

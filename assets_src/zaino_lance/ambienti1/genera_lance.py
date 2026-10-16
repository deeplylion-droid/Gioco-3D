"""Proposte per la lancia dello zaino-pompa (16 ottobre, "dobbiamo competere con il grab pack").
Per ogni proposta: immagine di riferimento (Meshy text-to-image, solo uso interno, in rif/) ->
image-to-3d meshy-7.1 con geometria 4k, texture PBR 4K e remesh. Il tubo verso lo zaino si fa in Blender.
Uso: python3 genera_lance.py immagini [nome ...]   poi   python3 genera_lance.py 3d [nome ...]
Scarica <nome>.glb e <nome>.json (task)."""
import base64, json, os, sys, time, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(QUI, 'rif'), exist_ok=True)
STILE = ('Game-ready 3D asset concept render in the clean style of Poppy Playtime chapter 1: soft rounded bevelled edges, '
         'smooth well-defined chunky shapes, believable materials with subtle wear and a few scratches. '
         'Single isolated object seen from the side, slightly from above, the nozzle pointing to the left, the whole object '
         'fully visible, neutral studio lighting, plain light grey background, no text, no letters, no logos, no people, no hands.')
LANCE = {
    # nome: (descrizione, poligoni)
    'lancia_a_pompiere': ('A heavy real firefighter hose nozzle held like a gun: a long polished brass nozzle barrel with a '
                          'knurled adjustable fog tip, a big brass bale lever valve on top, a black rubber pistol grip under it, '
                          'a brass swivel coupling at the back with a short stub of thick red reinforced fire hose. '
                          'Heavy, professional, 60 cm long.', 30000),
    'lancia_b_cannone': ('A giant toy water cannon blaster from the 1990s: chunky glossy plastic in turquoise, yellow and orange, '
                         'a fat barrel ending in a wide flared orange nozzle with four radial fins, a round pressure gauge dial '
                         'with a needle on top, a big yellow pump grip under the barrel, an orange trigger handle, '
                         'a short stub of turquoise corrugated hose at the back. Oversized and powerful, 70 cm long.', 30000),
    'lancia_c_industriale': ('An industrial high pressure maintenance water lance for a water park: a thick steel barrel with '
                             'yellow and black hazard stripes, a big round pressure gauge with a steel bezel on the side, a black '
                             'pistol grip with a red trigger, a sturdy carry handle on top, a wide steel nozzle with a rubber '
                             'bumper ring, a short stub of black reinforced hose with a steel crimp fitting at the back. '
                             '65 cm long.', 30000),
}


def _scarica(url, path):
    for k in range(4):
        try:
            return meshy.download(url, path)
        except Exception:
            time.sleep(5 + 5 * k)
    raise RuntimeError('download ' + url)


def immagine(nome):
    rif = os.path.join(QUI, 'rif', nome + '.png')
    if os.path.exists(rif):
        return nome, 'esiste'
    tid = meshy.create('text-to-image', dict(ai_model='nano-banana-pro', prompt=LANCE[nome][0] + ' ' + STILE, aspect_ratio='1:1'))
    t = meshy.wait('text-to-image', tid)
    if t['status'] != 'SUCCEEDED':
        return nome, 'immagine ' + t['status']
    _scarica(t['image_urls'][0], rif)
    json.dump(dict(immagine=tid), open(os.path.join(QUI, nome + '.json'), 'w'), indent=1)
    return nome, 'ok'


def modello(nome):
    out = os.path.join(QUI, nome + '.glb')
    if os.path.exists(out):
        return nome, 'esiste'
    desc, poly = LANCE[nome]
    rif = os.path.join(QUI, 'rif', nome + '.png')
    info = json.load(open(os.path.join(QUI, nome + '.json'))) if os.path.exists(os.path.join(QUI, nome + '.json')) else {}
    corpo = dict(image_url='data:image/png;base64,' + base64.b64encode(open(rif, 'rb').read()).decode(),
                 ai_model='meshy-7.1', geometry_resolution='4k', should_texture=True, enable_pbr=True, texture_resolution='4k',
                 should_remesh=True, topology='triangle', target_polycount=poly, remove_lighting=True)
    tid = meshy.create('image-to-3d', corpo)
    t = meshy.wait('image-to-3d', tid, timeout=3600)
    info.update(task=tid, status=t['status'], descrizione=desc, poligoni=poly)
    json.dump(info, open(os.path.join(QUI, nome + '.json'), 'w'), indent=1)
    if t['status'] != 'SUCCEEDED':
        return nome, '3d ' + t['status'] + ' ' + str(t.get('task_error'))
    _scarica(t['model_urls']['glb'], out)
    return nome, 'ok'


if __name__ == '__main__':
    fase, nomi = sys.argv[1], sys.argv[2:] or list(LANCE)
    with cf.ThreadPoolExecutor(3) as ex:
        for n, s in ex.map(immagine if fase == 'immagini' else modello, nomi):
            print(n, s, flush=True)

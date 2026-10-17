"""Oggetti per le due pile negli angoli dell'entrata della sala principale (punto 8 della prova v0.3.2): una di
palloni da spiaggia gonfi e sgonfi, una di scatoloni di diversi colori, un po' rovinati e umidi.
Per ogni oggetto: immagine di riferimento (Meshy text-to-image, solo uso interno, in rif/) -> image-to-3d meshy-7.1
con texture PBR e remesh. Uso: python3 genera_angoli.py [nome ...]  (scarica <nome>.glb e <nome>.json)"""
import base64, json, os, sys, time, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
STILE = ('Game-ready 3D asset concept render in the clean style of Poppy Playtime chapter 1: soft rounded bevelled edges, '
         'smooth well-defined shapes, believable materials with wear, dirt and light rust, 1990s cruise ship water park. '
         'Single isolated object, three-quarter front view, neutral studio lighting, plain light grey background, '
         'no text, no letters, no logos, no people.')
OGGETTI = {
    # palloni da spiaggia (gonfi in due colori, mezzo sgonfio, sgonfio)
    'pallone_gonfio_a': ('An inflated classic beach ball with six panels in red, yellow, blue and white, glossy vinyl, slightly faded and dusty.', 6000),
    'pallone_gonfio_b': ('An inflated beach ball with six panels in turquoise, orange, pink and white, glossy vinyl, faded, with a few water stains.', 6000),
    'pallone_mezzo': ('A half deflated beach ball with red, yellow and blue panels, sagging and wrinkled on one side, faded vinyl.', 8000),
    'pallone_sgonfio': ('A completely deflated beach ball lying flat and crumpled, colorful vinyl panels in red, yellow, blue and white, dusty.', 8000),
    # scatoloni di vari colori, un po' rovinati e umidi
    'scatolone_marrone': ('A closed brown corrugated cardboard box with packing tape, slightly crushed corners and dark damp stains at the bottom.', 4000),
    'scatolone_blu': ('A closed cardboard box printed in faded light blue with a white wave pattern, damp stains, dented edges, no text.', 4000),
    'scatolone_rosso': ('A closed cardboard box printed in faded red with yellow stripes, damp and slightly sagging, torn tape, no text.', 4000),
    'scatolone_giallo': ('A closed cardboard box printed in faded yellow with orange dots, water stains and a crushed corner, no text.', 4000),
    'scatolone_verde': ('A long flat closed cardboard box printed in faded green, damp, bent at one end, no text.', 4000),
}


def _scarica(url, path):
    for k in range(4):
        try:
            return meshy.download(url, path)
        except Exception:
            time.sleep(5 + 5 * k)
    raise RuntimeError('download ' + url)


def fai(nome):
    out = os.path.join(QUI, nome + '.glb')
    if os.path.exists(out):
        return nome, 'esiste'
    desc, poly = OGGETTI[nome]
    rif = os.path.join(QUI, 'rif', nome + '.png')
    if not os.path.exists(rif):
        tid = meshy.create('text-to-image', dict(ai_model='nano-banana-pro', prompt=desc + ' ' + STILE, aspect_ratio='1:1'))
        t = meshy.wait('text-to-image', tid)
        if t['status'] != 'SUCCEEDED':
            return nome, 'immagine ' + t['status']
        _scarica(t['image_urls'][0], rif)
    corpo = dict(image_url='data:image/png;base64,' + base64.b64encode(open(rif, 'rb').read()).decode(),
                 ai_model='meshy-7.1', geometry_resolution='4k', should_texture=True, enable_pbr=True, texture_resolution='4k',
                 should_remesh=True, topology='triangle', target_polycount=poly, remove_lighting=True)
    tid = meshy.create('image-to-3d', corpo)
    t = meshy.wait('image-to-3d', tid, timeout=3600)
    json.dump(dict(task=tid, status=t['status'], descrizione=desc, poligoni=poly), open(os.path.join(QUI, nome + '.json'), 'w'), indent=1)
    if t['status'] != 'SUCCEEDED':
        return nome, '3d ' + t['status'] + ' ' + str(t.get('task_error'))
    _scarica(t['model_urls']['glb'], out)
    return nome, 'ok'


if __name__ == '__main__':
    nomi = sys.argv[1:] or list(OGGETTI)
    with cf.ThreadPoolExecutor(6) as ex:
        for n, s in ex.map(fai, nomi):
            print(n, s, flush=True)

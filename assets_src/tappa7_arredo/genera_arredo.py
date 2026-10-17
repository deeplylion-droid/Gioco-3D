"""Oggetti per le proposte di arredamento della strada di risalita (tappa 7 B, punto 12 della prova v0.3.1):
A "deposito della festa" (roba da piscina messa via) e B "manutenzione" (prodotti e attrezzi dell'acquapark).
Per ogni oggetto: immagine di riferimento (Meshy text-to-image, solo uso interno, in rif/) -> image-to-3d meshy-7.1
con texture PBR e remesh. Uso: python3 genera_arredo.py [nome ...]  (scarica <nome>.glb e <nome>.json)"""
import base64, json, os, sys, time, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
STILE = ('Game-ready 3D asset concept render in the clean style of Poppy Playtime chapter 1: soft rounded bevelled edges, '
         'smooth well-defined shapes, believable materials with wear, dirt and light rust, 1990s cruise ship water park. '
         'Single isolated object, three-quarter front view, neutral studio lighting, plain light grey background, '
         'no text, no letters, no logos, no people.')
OGGETTI = {
    # A: deposito della festa
    'lettini_impilati': ('A stack of five white plastic pool sun loungers stacked on top of each other, slightly yellowed and dirty.', 20000),
    'ombrelloni_chiusi': ('Three closed beach parasols with turquoise and white striped fabric tied up, standing in a heavy round concrete base, leaning.', 15000),
    'testa_mascotte': ('A giant foam mascot costume head of a smiling cartoon dolphin, faded turquoise, big glossy eyes, '
                       'a dark mesh mouth opening, dirty and slightly deflated, unsettling, sitting on the floor.', 20000),
    'carrello_asciugamani': ('A laundry cart on wheels made of a grey metal frame and a canvas bag, full of folded striped pool towels, a few hanging out.', 20000),
    'cassa_tubi': ('A big wooden crate full of colourful foam pool noodles in orange, yellow, green and pink, sticking out on top.', 15000),
    'coccodrillo_sgonfio': ('A deflated inflatable green crocodile pool float lying flat and crumpled on the floor, faded, with its big smiling face.', 15000),
    # B: manutenzione
    'fusti_cloro': ('A group of three blue plastic chemical drums for pool chlorine with white screw caps, one with a hazard diamond pictogram, no text.', 15000),
    'sacchi_sale': ('A wooden pallet with stacked white plastic sacks of pool salt, a few torn and spilling, wrapped in loose plastic film.', 20000),
    'transpallet': ('A manual hand pallet jack with a long handle, yellow painted forks, worn and scratched.', 15000),
    'carrello_attrezzi': ('A red metal tool trolley with three drawers, a pool skimmer net and a long brush leaning on it, a bucket on top.', 20000),
    # più pieno (16 ottobre, "molto vuota"): roba da appendere e da accatastare
    'salvagente_anulare': ('An orange and white ring lifebuoy with a grey rope around it, hanging on a small steel wall hook, faded.', 6000),
    'casse_plastica': ('A stack of three stackable blue plastic crates with handle holes, scratched and dirty, one slightly askew.', 8000),
    'materassini_arrotolati': ('A bundle of four rolled up foam pool mats in faded blue, yellow and pink, tied with a strap, standing upright.', 8000),
    'rullo_tubo': ('A wall mounted red hose reel with a coiled flat grey water hose, metal bracket, worn paint.', 10000),
    'sedie_impilate': ('A stack of six white plastic patio chairs stacked into each other, yellowed and dirty.', 12000),
    # per tutte e due: dove andare
    'cartello_uscita': ('A rectangular green emergency exit sign light box with a white running man pictogram and a white arrow, glowing, no text.', 6000),
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

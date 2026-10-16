"""Oggetti di scena di prova generati con Meshy (capitolo 1, acquapark).

Flusso: Text to Image (immagine di riferimento, sfondo neutro) -> Image to 3D
(con input_task_id, texture PBR). Gli ID dei task finiscono in meshy_task.json,
così rilanciando lo script non si ricreano task già pagati.

Uso (dalla radice del repository):
  python assets_src/ambiente/oggetti/meshy_oggetti.py immagini   # crea/scarica le immagini
  python assets_src/ambiente/oggetti/meshy_oggetti.py modelli    # crea/scarica i GLB
  python assets_src/ambiente/oggetti/meshy_oggetti.py stato
La chiave è in MESHY_API_KEY (mai nel repository).
"""
import json, os, sys, time

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.abspath(os.path.join(QUI, '..', '..', '..'))
sys.path.insert(0, os.path.join(RADICE, 'tools'))
import meshy  # noqa: E402

STATO = os.path.join(QUI, 'meshy_task.json')
COMUNE = ('plain neutral mid-grey seamless studio background, soft even studio lighting, '
          'the whole object fully visible and centered, photorealistic product photo, '
          'no text, no letters, no logos, no people')

OGGETTI = {
    'paperella_gigante': {
        'prompt': ('A large vintage rubber duck pool toy from the 1990s, about 50 cm tall, '
                   'faded yellow vinyl with an orange beak and painted black eyes, scuffed, '
                   'grimy water stains and dirt in the creases, abandoned for years, '
                   'three-quarter front view, ' + COMUNE),
        'poligoni': 12000,
    },
    'delfino_gonfiabile_sgonfio': {
        'prompt': ('A half-deflated inflatable pool toy shaped like a cartoon dolphin, lying '
                   'collapsed on the floor, sagging and crumpled with deep wrinkles and folds, '
                   'faded blue and white vinyl, dirty and stained, 1990s, seen from above at '
                   'three-quarter angle, ' + COMUNE),
        'poligoni': 20000,
    },
    'lettino_plastica': {
        'prompt': ('An old white plastic pool sun lounger from the 1990s, slatted backrest '
                   'raised, yellowed and dirty plastic with grime streaks and small cracks, '
                   'three-quarter view, ' + COMUNE),
        'poligoni': 15000,
    },
    # --- sala principale (vertical slice)
    'salvagente_nave': {
        'prompt': ('A ship lifebuoy ring with alternating faded orange-red and white segments and a '
                   'grey grab rope looped around it, weathered, scratched and dirty, plain with no '
                   'printing, lying flat seen from above at an angle, ' + COMUNE),
        'poligoni': 8000,
    },
    'ciambella_gonfiabile': {
        'prompt': ('An inflatable swim ring for kids with faded red and white stripes, slightly '
                   'deflated and wrinkled, dirty vinyl with water stains, 1990s, three-quarter view '
                   'from above, ' + COMUNE),
        'poligoni': 8000,
    },
    'pallone_spiaggia': {
        'prompt': ('A classic inflatable beach ball with six colored panels (blue, yellow, red, '
                   'white, green, orange), faded and dirty, slightly soft, ' + COMUNE),
        'poligoni': 4000,
    },
    'orsacchiotto_grande': {
        'prompt': ('A big old plush teddy bear sitting slumped, about one meter tall, matted grey-white '
                   'fur stained with dirt, green mold and water marks, a faded red bow at the neck, '
                   'one eye button loose, creepy and sad, abandoned for years, front three-quarter view, '
                   + COMUNE),
        'poligoni': 16000,
    },
    'tubi_galleggianti': {
        'prompt': ('Three foam pool noodles lying on the floor, crossed loosely, faded pink, green '
                   'and yellow foam, dirty and dented, seen from above at an angle, ' + COMUNE),
        'poligoni': 6000,
    },
    'sedia_bagnino': {
        'prompt': ('A tall lifeguard chair from a 1990s indoor pool: white painted steel frame with '
                   'a ladder, a seat about 1.8 meters high with a small backrest, paint peeling with '
                   'rust stains, full object visible, three-quarter view, ' + COMUNE),
        'poligoni': 15000,
    },
    'balena_gonfiabile_sgonfia': {
        'prompt': ('A huge deflated inflatable whale pool float, about three meters long, collapsed '
                   'and crumpled on the floor with big folds, faded blue and white vinyl with a cute '
                   'cartoon face, dirty and stained, seen from above at three-quarter angle, ' + COMUNE),
        'poligoni': 20000,
    },
    'fungo_fontana': {
        'prompt': ('A kids water playground mushroom fountain, a fiberglass mushroom about two meters '
                   'tall with a wide faded red cap with white spots and a pale yellow stem, cracked '
                   'and dirty, chipped paint, ' + COMUNE),
        'poligoni': 8000,
    },
    'cannoncino_acqua': {
        'prompt': ('A kids water playground water cannon on a short metal post with a swivel handle, '
                   'faded yellow and blue plastic, scratched, rust stains on the post, ' + COMUNE),
        'poligoni': 8000,
    },
}

# misure reali per la messa in scena: ('z', altezza) oppure ('lungo', lato maggiore in pianta)
MISURE = {
    'paperella_gigante': ('z', 0.55), 'delfino_gonfiabile_sgonfio': ('lungo', 1.6),
    'lettino_plastica': ('lungo', 1.9), 'salvagente_nave': ('lungo', 0.75),
    'ciambella_gonfiabile': ('lungo', 0.85), 'pallone_spiaggia': ('z', 0.42),
    'orsacchiotto_grande': ('z', 1.0), 'tubi_galleggianti': ('lungo', 1.55),
    'sedia_bagnino': ('z', 2.3), 'balena_gonfiabile_sgonfia': ('lungo', 3.0),
    'fungo_fontana': ('z', 2.0), 'cannoncino_acqua': ('z', 1.1),
}


def carica():
    if os.path.exists(STATO):
        with open(STATO) as f:
            return json.load(f)
    return {}


def salva(st):
    with open(STATO, 'w') as f:
        json.dump(st, f, indent=1, ensure_ascii=False)


def attendi(kind, task_id):
    while True:
        try:
            return meshy.wait(kind, task_id, every=8, timeout=3600)
        except TimeoutError:
            raise
        except Exception as e:  # errori di rete: il task continua, riprova
            print('  rete:', e)
            time.sleep(15)


def immagini():
    st = carica()
    for nome, o in OGGETTI.items():
        rec = st.setdefault(nome, {})
        if 'immagine_task' not in rec:
            rec['immagine_task'] = meshy.create('text-to-image', {
                'ai_model': 'nano-banana-2', 'prompt': o['prompt'], 'aspect_ratio': '1:1'})
            salva(st)
            print(nome, 'immagine creata', rec['immagine_task'])
    for nome in OGGETTI:
        rec = st[nome]
        dest = os.path.join(QUI, nome, 'riferimento.png')
        if os.path.exists(dest):
            continue
        t = attendi('text-to-image', rec['immagine_task'])
        print(nome, t['status'])
        if t['status'] == 'SUCCEEDED':
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            meshy.download(t['image_urls'][0], dest)
            rec['crediti_immagine'] = t.get('consumed_credits')
            salva(st)


def modelli():
    st = carica()
    for nome, o in OGGETTI.items():
        rec = st.get(nome, {})
        if 'immagine_task' not in rec or 'modello_task' in rec:
            continue
        rec['modello_task'] = meshy.create('image-to-3d', {
            'input_task_id': rec['immagine_task'],
            'ai_model': 'latest',
            'should_texture': True, 'enable_pbr': True, 'texture_resolution': '2k',
            'should_remesh': True, 'topology': 'triangle', 'target_polycount': o['poligoni'],
            'target_formats': ['glb'], 'multi_view_thumbnails': True,
        })
        salva(st)
        print(nome, 'modello creato', rec['modello_task'])
    for nome in OGGETTI:
        rec = st.get(nome, {})
        if 'modello_task' not in rec:
            continue
        dest = os.path.join(QUI, nome, nome + '_meshy.glb')
        if os.path.exists(dest):
            continue
        t = attendi('image-to-3d', rec['modello_task'])
        print(nome, t['status'], t.get('task_error'))
        if t['status'] == 'SUCCEEDED':
            meshy.download(t['model_urls']['glb'], dest)
            rec['crediti_modello'] = t.get('consumed_credits')
            salva(st)


def stato():
    st = carica()
    print(json.dumps(st, indent=1))
    print(meshy.balance())


if __name__ == '__main__':
    {'immagini': immagini, 'modelli': modelli, 'stato': stato}[sys.argv[1]]()

"""Area bimbi in alta definizione (proposta, 16 ottobre): struttura di gioco, funghi-fontana e secchio
gigante rifatti con Meshy, più dettagliati e credibili (plastica vera con usura, bulloni, giunti, sporco,
colori sbiaditi), negli stessi colori della disposizione 1 approvata. Solo proposta: niente va nel gioco
finché l'utente non sceglie.

Flusso, come in assets_src/ambiente/oggetti_hq/genera_hq.py:
  immagine di riferimento (Meshy text-to-image o image-to-image, solo uso interno, in rif/)
  -> image-to-3d meshy-7.1 con geometria 4k, texture PBR 4K, remesh a triangoli
  -> il GLB 4K resta fuori dal repository (cartella temporanea, per i render), qui si salva <nome>.glb
     con le texture ridotte a JPG 2K (riduci() di genera_hq.py).
Lo stato di ogni voce (task, prompt, esito) è in <nome>.json.

Uso: python3 assets_src/ambiente/bimbi_hq/genera.py immagine NOME...   (solo l'immagine di riferimento)
     python3 assets_src/ambiente/bimbi_hq/genera.py modello NOME...    (immagine se manca, poi il modello 3D)
     python3 assets_src/ambiente/bimbi_hq/genera.py stato
     python3 assets_src/ambiente/bimbi_hq/genera.py finali     (copia i modelli scelti con il nome finale)
La chiave è in MESHY_API_KEY (mai nel repository)."""
import base64, json, os, sys, time, concurrent.futures as cf
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '../../../tools'))
sys.path.insert(0, os.path.join(QUI, '../oggetti_hq'))
GREZZI = os.environ.get('BIMBI_HQ_GREZZI', os.path.join(QUI, '_grezzi'))   # GLB 4K e anteprime (fuori da git)

STILE = ('Photorealistic studio product photo of real 1990s commercial water park play equipment, very detailed and '
         'believable: fiberglass and rotomolded plastic with a slightly chalky, sun-faded and chlorine-bleached surface, '
         'powder-coated round steel posts, visible hex bolts, clamps, brackets, welded joints and rubber end caps; real '
         'wear: scuffs, fine scratches, chipped paint at the edges, limescale and dried water stains, grime in the corners '
         'and joints, a little rust bleeding from the bolts. Worn but intact and still cheerful: saturated 1990s toy colors '
         'with some faded pastel tones. Single isolated object, the whole object fully visible and centered, soft even '
         'studio lighting, plain light grey background, no people, no text, no letters, no numbers, no logos, no water.')

STRUTTURA = ("A 1990s indoor water park children's play structure, a modular multi-level play tower about 9 meters wide "
             "and 8 meters tall. Four square yellow fiberglass decks, each 2.4 m wide, on round blue steel posts, set close "
             "together in a 2x2 block at different heights: the front-left deck is low at 1.4 m, the front-right and "
             "back-left decks are at 2.6 m, the back-right deck is the highest at 3.8 m. Pointed pyramid roofs of molded "
             "plastic on three of the towers: teal green over the front-left deck, orange over the front-right deck, red "
             "over the back-left deck. The highest back-right tower has no roof: a tall rust-red painted steel frame rises "
             "from it and holds a giant faded red tipping bucket with a thick yellow rim on a horizontal steel axle about "
             "7 m above the ground; a blue water pipe climbs a corner post of the frame and bends over the bucket. Red "
             "horizontal railing tubes with blue vertical bars along the deck edges. A straight yellow staircase with red "
             "handrails climbs from the ground at the front up to the front-left deck. Short steps link the decks. An open "
             "yellow wave slide runs down to the right from the front-right deck.")
VISTA_STRUTTURA = ('Three-quarter view from the front-right, slightly from above, the whole structure visible from the '
                   'floor to the top of the bucket frame.')

FUNGO = ('A kids water playground mushroom fountain about two meters tall, switched off and dry: a wide dome-shaped red '
         'fiberglass cap about 2.1 m across with white spots, the red sun-faded and chalky, small hairline cracks in the '
         'gel coat at the rim, a ring of small brass spray nozzles under the rim crusted with white limescale and green '
         'verdigris, dried water streaks running down; a thick cylindrical pale cream-yellow stem with grime at the '
         'bottom; a round galvanized steel base flange bolted to the floor with rusty hex bolts. No water.')
SECCHIO = ('A giant tipping water bucket for a kids water playground, standing perfectly upright and symmetric: a big '
           'round slightly tapered bucket about 1.6 m tall and 2.3 m wide at the top, faded red rotomolded plastic with '
           'molded horizontal reinforcing ribs, a thick rounded yellow rolled rim, two identical heavy steel pivot hubs '
           'with bolted bearing plates on opposite sides at mid height, empty inside with a dark limescale ring inside '
           'the rim, dried water streaks and scuffs outside.')
MARGINE = 'The entire object is inside the frame with a wide empty margin of background on every side, nothing cropped.'
SOLO_SECCHIO = (' Only the bucket itself: the pivot hubs end in short stub axles, no stand, no legs, no frame, nothing '
                'under the bucket.')

# nome: dict(img=modello immagine, prompt=..., rif=[voci di riferimento] (image-to-image), formato, poligoni)
VOCI = {
    # --- disegno d'insieme della struttura (riferimento interno) e versioni senza secchio per il 3D
    'insieme_a': dict(img='nano-banana-pro', prompt=STRUTTURA + ' ' + VISTA_STRUTTURA + ' ' + STILE, formato='4:3'),
    'insieme_b': dict(img='nano-banana-pro', prompt=STRUTTURA + ' ' + VISTA_STRUTTURA + ' ' + STILE, formato='4:3'),
    'insieme_c': dict(img='gpt-image-2', prompt=STRUTTURA + ' ' + VISTA_STRUTTURA + ' ' + STILE, formato='4:3',
                      poligoni=250000),
    # la stessa struttura senza il secchio (il secchio è un oggetto a parte che si ribalta sul suo perno)
    'insieme_c_vuoto': dict(img='nano-banana-pro', rif=['insieme_c'], formato='4:3', poligoni=250000,
                            prompt='Edit this product photo: remove the red bucket that hangs in the tall frame at the '
                                   'top right, so the frame is empty, and show the frame posts, the top beam, the blue '
                                   'pipe and the two axle bearings on the posts complete where the bucket was. Keep '
                                   'everything else exactly the same: same structure, same colors, same wear, same '
                                   'camera, same light grey background.'),
    # --- funghi-fontana e secchio
    'fungo_a': dict(img='nano-banana-pro', prompt=FUNGO + ' Three-quarter front view, slightly from above. ' + STILE,
                    formato='1:1', poligoni=40000),
    'fungo_b': dict(img='nano-banana-pro', prompt=FUNGO + ' Three-quarter front view, slightly from above. ' + STILE,
                    formato='1:1', poligoni=40000),
    'secchio_a': dict(img='nano-banana-pro', prompt=SECCHIO + ' Front view from slightly above, the two pivot hubs on '
                      'the left and right sides. ' + STILE, formato='1:1', poligoni=30000),
    'secchio_b': dict(img='nano-banana-pro', prompt=SECCHIO + ' Front view from slightly above, the two pivot hubs on '
                      'the left and right sides. ' + STILE, formato='1:1', poligoni=30000),
    # seconda prova: oggetto intero con margine (nelle prime il cappello e i sostegni uscivano dall'immagine)
    'fungo_c': dict(img='nano-banana-pro', prompt=FUNGO + ' Three-quarter front view, slightly from above. ' + MARGINE +
                    ' ' + STILE, formato='1:1', poligoni=40000),
    'fungo_d': dict(img='nano-banana-pro', prompt=FUNGO + ' Three-quarter front view, slightly from above. ' + MARGINE +
                    ' ' + STILE, formato='1:1', poligoni=40000),
    'secchio_c': dict(img='nano-banana-pro', prompt=SECCHIO + SOLO_SECCHIO + ' Front view from slightly above, the two '
                      'pivot hubs on the left and right sides. ' + MARGINE + ' ' + STILE, formato='1:1', poligoni=30000),
    'secchio_d': dict(img='nano-banana-pro', prompt=SECCHIO + SOLO_SECCHIO + ' Front view from slightly above, the two '
                      'pivot hubs on the left and right sides. ' + MARGINE + ' ' + STILE, formato='1:1', poligoni=30000),
}


def _scarica(url, path):
    import meshy
    for k in range(5):
        try:
            return meshy.download(url, path)
        except Exception:
            time.sleep(5 + 5 * k)
    raise RuntimeError('download ' + url)


def _aspetta(tipo, tid, limite=3600):
    """Come meshy.wait, ma un errore di rete o un 429/5xx durante l'attesa non ferma niente (il task continua)."""
    import meshy
    t0 = time.time()
    while time.time() - t0 < limite:
        try:
            t = meshy._req('GET', f'{meshy._path(tipo)}/{tid}')
        except Exception:
            time.sleep(10)
            continue
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            return t
        time.sleep(8)
    raise TimeoutError(f'{tipo} {tid} ancora in corso')


def _dati_uri(path):
    with open(path, 'rb') as f:
        return 'data:image/jpeg;base64,' + base64.b64encode(f.read()).decode()


def _carica(nome):
    f = os.path.join(QUI, nome + '.json')
    return json.load(open(f)) if os.path.exists(f) else {}


def _salva(nome, info):
    json.dump(info, open(os.path.join(QUI, nome + '.json'), 'w'), indent=1, ensure_ascii=False)


def immagine(nome):
    import meshy
    v = VOCI[nome]
    info = _carica(nome)
    rif = os.path.join(QUI, 'rif', nome + '.jpg')
    if info.get('immagine') and os.path.exists(rif):
        return nome, 'immagine già fatta'
    if not info.get('immagine'):
        if v.get('rif'):
            corpo = dict(ai_model=v['img'], prompt=v['prompt'],
                         reference_image_urls=[_dati_uri(os.path.join(QUI, 'rif', r + '.jpg')) for r in v['rif']])
            if v.get('formato'):
                corpo['aspect_ratio'] = v['formato']
            tipo = 'image-to-image'
        else:
            corpo = dict(ai_model=v['img'], prompt=v['prompt'], aspect_ratio=v.get('formato', '1:1'))
            tipo = 'text-to-image'
        info.update(immagine=meshy.create(tipo, corpo), tipo_immagine=tipo, modello_immagine=v['img'],
                    prompt=v['prompt'], riferimenti=v.get('rif', []))
        _salva(nome, info)
    t = _aspetta(info['tipo_immagine'], info['immagine'])
    if t['status'] != 'SUCCEEDED':
        info['immagine_esito'] = t['status']
        info.pop('immagine')
        _salva(nome, info)
        return nome, 'immagine ' + t['status'] + ' ' + str(t.get('task_error'))
    png = rif[:-4] + '.png'
    _scarica(t['image_urls'][0], png)
    from PIL import Image
    Image.open(png).convert('RGB').save(rif, 'JPEG', quality=92)
    os.remove(png)
    return nome, 'immagine pronta'


def modello(nome):
    import meshy
    from genera_hq import riduci
    out = os.path.join(QUI, nome + '.glb')
    if os.path.exists(out):
        return nome, 'esiste'
    r = immagine(nome)
    if not os.path.exists(os.path.join(QUI, 'rif', nome + '.jpg')):
        return r
    v = VOCI[nome]
    info = _carica(nome)
    if not info.get('task') or info.get('status') in ('FAILED', 'CANCELED'):
        corpo = dict(input_task_id=info['immagine'], ai_model='meshy-7.1', geometry_resolution='4k',
                     should_texture=True, enable_pbr=True, texture_resolution='4k', should_remesh=True,
                     topology='triangle', target_polycount=v.get('poligoni', 60000), multi_view_thumbnails=True,
                     target_formats=['glb'])
        info.update(task=meshy.create('image-to-3d', corpo), status='IN_PROGRESS', poligoni=corpo['target_polycount'])
        _salva(nome, info)
    t = _aspetta('image-to-3d', info['task'])
    info['status'] = t['status']
    info['crediti'] = t.get('consumed_credits')
    _salva(nome, info)
    if t['status'] != 'SUCCEEDED':
        return nome, '3d ' + t['status'] + ' ' + str(t.get('task_error'))
    os.makedirs(GREZZI, exist_ok=True)
    grezzo = os.path.join(GREZZI, nome + '_4k.glb')
    _scarica(t['model_urls']['glb'], grezzo)
    anteprime = dict(t.get('thumbnail_urls') or {}, principale=t.get('thumbnail_url'))
    for k, u in anteprime.items():
        if u:
            try:
                _scarica(u, os.path.join(GREZZI, f'{nome}_vista_{k}.png'))
            except Exception:
                pass
    riduci(grezzo, out)
    return nome, 'ok %.1f MB' % (os.path.getsize(out) / 1e6)


# modelli scelti (dopo aver guardato le anteprime di Meshy): nome finale -> voce
FINALI = {
    'struttura_gioco': 'insieme_c_vuoto',   # disegno d'insieme senza secchio (il secchio è un oggetto a parte)
    'fungo_fontana': 'fungo_c',             # cappello largo come quello di prima (fungo_d: cupola, punti dentro)
    'secchio_gigante': 'secchio_d',         # due mozzi sull'asse (secchio_c ne aveva quattro)
}


def finali():
    """Copia i modelli scelti con il nome finale (anche il 4K in GREZZI, per i render)."""
    import shutil
    for fin, voce in FINALI.items():
        shutil.copyfile(os.path.join(QUI, voce + '.glb'), os.path.join(QUI, fin + '.glb'))
        g = os.path.join(GREZZI, voce + '_4k.glb')
        if os.path.exists(g):
            d = os.path.join(GREZZI, fin + '_4k.glb')
            if os.path.exists(d):
                os.remove(d)
            os.link(g, d)
        print(fin, '<-', voce)


def stato():
    for n in VOCI:
        i = _carica(n)
        print(f"{n:22s} immagine={'sì' if os.path.exists(os.path.join(QUI, 'rif', n + '.jpg')) else '-':3s} "
              f"3d={i.get('status', '-'):12s} glb={'sì' if os.path.exists(os.path.join(QUI, n + '.glb')) else '-'}")


if __name__ == '__main__':
    cosa, nomi = sys.argv[1], sys.argv[2:]
    if cosa in ('stato', 'finali'):
        dict(stato=stato, finali=finali)[cosa]()
        sys.exit(0)
    fn = dict(immagine=immagine, modello=modello)[cosa]
    with cf.ThreadPoolExecutor(8) as ex:
        for n, s in ex.map(fn, nomi):
            print(n, s, flush=True)

"""Bambini (creature minori): generazione con Meshy di concept, scene e modelli 3D.

Uso:
    python tools/blender/bambini_meshy.py <job> [<job> ...]   # lancia i job in parallelo
    python tools/blender/bambini_meshy.py --list               # elenca i job

I riferimenti sono solo immagini nostre (docs/concept/ e output di job precedenti).
I design dei due bambini sono descritti a parole nei prompt.
Le immagini generate vanno in $BAMBINI_OUT (default: ./bambini_out), un PNG per immagine:
<job>_<n>.png. Ogni task (id, modello, prompt, riferimenti) viene registrato in
assets_src/bambini/meshy_log.json, così ogni immagine si può rigenerare.
"""
import base64, json, os, sys, threading, time

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import meshy  # noqa: E402

OUT = os.environ.get('BAMBINI_OUT', os.path.join(os.getcwd(), 'bambini_out'))
LOG = os.path.join(REPO, 'assets_src', 'bambini', 'meshy_log.json')
_lock = threading.Lock()

C = 'docs/concept/'
STATUA, SBIRCIA = C + 'medusa_statua.jpg', C + 'medusa_sbircia.jpg'
AMB_A, AMB_B = C + 'ambiente_A_realistico.jpg', C + 'ambiente_B_colorato.jpg'

# ---------------------------------------------------------------- blocchi di prompt
STILE = (
    'Photorealistic cinematic 3D render in exactly the same style, lighting and world as the reference '
    'images: an abandoned 1990s indoor water park aboard a shipwrecked family cruise ship, at night. '
    'Red emergency lights, a few cold flickering fluorescent tubes, low drifting fog, wet reflective '
    'pool tiles, rust, peeling paint, sea salt crust, scattered colorful plastic toys (swim rings, '
    'beach balls, rubber ducks). Dark, moody horror atmosphere, highly detailed realistic materials, '
    'Unreal Engine 5 quality. ')
VIETATO = (
    ' Absolutely no text, no letters, no numbers, no logos, no writing on signs, no watermark. '
    'No blood, no gore.')

CORPO_OMBRA = (
    'a small, stocky, chubby shadow creature the size of a small child (about 1.2 metres tall), with a '
    'round soft belly, short stubby legs with rounded feet, short stubby arms ending in small rounded '
    'mitten-like hands with no visible fingers. Its whole body is a seamless dark shadow of glossy, '
    'wet black skin, like an old black neoprene diving wetsuit that covers it completely, with no '
    'anatomical details at all, only water droplets, a dull wet sheen and a few thin strands of dark '
    'green seaweed stuck to it. ')

CUBO_PIASTRELLE = (
    'Instead of a head it has a big white cube, a bit wider than its shoulders (the cube is about '
    'one third of its total height, like a chibi figure). The cube is made of small square white '
    'ceramic swimming-pool tiles with grey grout lines, like a piece of the pool wall: cracked, '
    'chipped, a few tiles missing, wet, with white sea-salt stains, small patches of green algae, a '
    'few tiny barnacles on the edges and orange rust streaks running down. ')
CUBO_SPUGNA = (
    'Instead of a head it has a big white cube, a bit wider than its shoulders (the cube is about '
    'one third of its total height, like a chibi figure). The cube is an old white foam flotation '
    'block from a ship, like a buoyancy block or a swimming float: dense white plastic foam, deeply '
    'cracked and crumbling at the corners, wet, with white sea-salt stains, small patches of green '
    'algae, a few tiny barnacles on the edges and orange rust streaks from an old metal ring. ')
FACCINA_SORRISO = (
    'On the front face of the cube a cute, simple childlike face is drawn with black marker: two '
    'short vertical dashes for eyes, two round soft pink blush cheeks and a small curved smile. ')
FACCINA_RISATA = (
    'On the front face of the cube a cute, simple childlike face is drawn with black marker: eyes '
    'squeezed shut, drawn as two small sideways V shapes, two round soft pink blush cheeks and a big '
    'open laughing mouth drawn as a dark half-circle. ')

def massa(occhi):
    return (
        'The white cube head is breaking apart: its front face has cracked open and big jagged chunks '
        'have fallen away (on the remaining fragments you can still see one marker eye dash and one '
        'pink blush cheek of the cute drawn face). From inside bursts a mass of soft, translucent pink '
        'and magenta tentacles made of the same living tissue as the jellyfish bell of the mascot in '
        'the reference image: glossy, gelatinous, semi-transparent, with glowing luminous radial '
        'channels inside, softly lighting the cube from within. ' + occhi +
        ' A few tentacles curl out over the broken edges of the cube and droop down. Organic and '
        'deeply unsettling, but clean and wet: no blood, no flesh wounds. ')

OCCHI_GIALLI = ('Many round eyeballs of different sizes stare out from the tentacle mass, glossy white '
                'with bright yellow irises and small dark pupils, all looking at the viewer.')
OCCHI_ROSA = ('Many round eyeballs of different sizes stare out from the tentacle mass, each one like '
              'the single eye of the jellyfish mascot in the reference image: glossy, with a pink '
              'iris with a radial pattern and a dark pupil, all looking at the viewer.')

AGNELLO = (
    'a small, chubby plush lamb the size of a small child (about 1.2 metres tall), standing upright on '
    'two legs: it looks like a child completely covered by an old handmade plush lamb costume, no skin '
    'visible anywhere. Big round head with cream-white curly fleece on top, small droopy ears, two '
    'curled brown ram horns on the sides, soft pink blush cheeks and a small stitched smile. Its eyes '
    'are two round old brass buttons from a ship officer uniform, tarnished, with a tiny embossed '
    'anchor, sewn on with dark thread in a cross. A red sailor-style ribbon bow is tied at the neck, '
    'with a tiny brass anchor charm hanging from the knot. The body is a sewn plush with big visible '
    'cross-stitched seams down the belly, puffs of curly fleece, short arms slightly open, dark rounded '
    'hooves at the ends of arms and legs, a small fluffy tail. The plush is soaking wet and matted, '
    'stained with sea salt and grey-green algae, with brown water marks, re-sewn in several places '
    'with transparent nylon fishing line and patched with a piece of faded blue-and-white striped '
    'towel. ')

LUPO = (
    'The cute lamb head has split open along its seams and flopped backwards like a hood, hanging '
    'behind the shoulders (still showing its brass button eyes and curly fleece), and out of the neck '
    'rises a big black predator head with the silhouette of a wolf: long snout, tall pointed ears, '
    'but with deep-sea fish traits. Its skin is smooth, glossy, wet black like an abyssal fish, with '
    'gill slits along the sides of the neck and a few small pale bioluminescent dots. The jaws are '
    'wide open showing several rows of white triangular shark teeth, a dark wet mouth and a long pink '
    'tongue; one pale yellow eye with a small red pupil glares at the viewer. Under it, the lamb body '
    'with the red sailor bow and the stitched seams is unchanged. Unsettling, no blood, no gore. ')

OCCHIO_UNICO = (
    'The cute lamb face has split open vertically down the middle along a stitched seam, from the top '
    'of the head to the chin: the soaked fabric parts like two lips with frayed edges and small white '
    'stuffing tufts, and the two brass button eyes are pushed apart to the sides. From inside, a '
    'single huge round eye stares at the viewer: it is exactly like the single eye of the jellyfish '
    'mascot in the reference image, with a pink iris with a radial pattern, a dark pupil and a wet '
    'glossy surface, surrounded by translucent pink and magenta membrane. The rest of the lamb (curly '
    'fleece, horns, red sailor bow, stitched body) is unchanged. Unsettling, no blood, no gore. ')

FIGURA_INTERA = (
    ' Full body visible from head to feet, centered, seen from a slightly low three-quarter front '
    'view, standing still on the wet tiled floor near the camera, with the water park behind it out '
    'of focus. ')

MV = (
    'The same character as in the reference image, exactly the same design, materials, colors and '
    'proportions, full body from head to feet, standing upright in a neutral relaxed pose with the '
    'arms slightly away from the body, on a plain flat light grey background with soft even studio '
    'lighting and no environment, no fog, no floor details, no cast shadows. ')

# ---------------------------------------------------------------- job
# kind img: image-to-image. refs: percorsi del repo oppure "@<job>" (primo output di un job).
JOBS = {}

def img(name, model, prompt, refs, aspect='3:4', mv=False):
    JOBS[name] = dict(kind='img', model=model, prompt=prompt, refs=refs, aspect=aspect, mv=mv)

for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    # 1. testa a cubo, calmo: due materiali del cubo
    img(f'cubo_calmo_piastrelle_{tag}', m, STILE + 'In the scene stands ' + CORPO_OMBRA +
        CUBO_PIASTRELLE + FACCINA_SORRISO + 'Its arms hang at its sides; it is perfectly still, '
        'facing the viewer, cute and wrong at the same time.' + FIGURA_INTERA + VIETATO,
        [STATUA, AMB_A])
    img(f'cubo_calmo_spugna_{tag}', m, STILE + 'In the scene stands ' + CORPO_OMBRA +
        CUBO_SPUGNA + FACCINA_SORRISO + 'Its arms hang at its sides; it is perfectly still, '
        'facing the viewer, cute and wrong at the same time.' + FIGURA_INTERA + VIETATO,
        [STATUA, AMB_A])
    # 2. agnellino, calmo
    img(f'agnello_calmo_{tag}', m, STILE + 'In the scene stands ' + AGNELLO +
        'It is perfectly still, head slightly tilted, facing the viewer, cute and wrong at the same '
        'time.' + FIGURA_INTERA + VIETATO, [STATUA, AMB_A])


# Riferimenti d'identità scelti dopo il primo giro (guardando le immagini):
CUBO = '@cubo_calmo_piastrelle_gpt'
AGN = '@agnello_calmo_gpt'
STESSO_CUBO = ('The same character as in the first reference image: same chubby glossy black wet body '
               'with seaweed, same white cube of cracked pool tiles with algae, barnacles and rust, '
               'same place, same camera framing, same lighting. ')
STESSO_AGN = ('The same plush lamb as in the first reference image: same soaked, stained, stitched '
              'plush body, same red sailor bow with the brass anchor, same place, same camera framing, '
              'same lighting. ')

SCENA = (
    'First-person view from the eyes of a grown-up player standing in the abandoned indoor water park '
    'of the reference images, at night: wide-angle lens, eye height 1.65 metres, like a horror video '
    'game screenshot without any interface. Red emergency lights, low drifting fog, wet reflective '
    'tiles in the foreground, rust, peeling paint, colorful plastic toys scattered around. ')

for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    img(f'cubo_risata_{tag}', m, STESSO_CUBO + 'Now it raises both stubby arms and holds the sides '
        'of its cube head with its mitten hands, as if laughing, and the face drawn on the cube is '
        'different: ' + FACCINA_RISATA + 'Cute and wrong at the same time.' + FIGURA_INTERA + VIETATO,
        [CUBO, AMB_A])
    img(f'cubo_rivelato_rosa_{tag}', m, STESSO_CUBO + massa(OCCHI_ROSA) + 'The body stands still, '
        'arms hanging.' + FIGURA_INTERA + VIETATO, [CUBO, STATUA, SBIRCIA])
    img(f'cubo_rivelato_giallo_{tag}', m, STESSO_CUBO + massa(OCCHI_GIALLI) + 'The body stands '
        'still, arms hanging.' + FIGURA_INTERA + VIETATO, [CUBO, STATUA, SBIRCIA])
    img(f'agnello_lupo_{tag}', m, STESSO_AGN + LUPO + FIGURA_INTERA + VIETATO, [AGN, AMB_A])
    img(f'agnello_occhio_{tag}', m, STESSO_AGN + OCCHIO_UNICO + FIGURA_INTERA + VIETATO,
        [AGN, SBIRCIA, STATUA])
    # scene "visto di sfuggita"
    img(f'scena_cubo_{tag}', m, SCENA + 'Far away, about fifteen metres ahead, at the end of the wet '
        'tiled walkway beside the empty wave pool, the small shadow creature with the white tiled cube '
        'head from the first reference image peeks out from behind a tiled pillar: only its cube head '
        'and one small black arm are visible, its cute drawn smile catching the red emergency light. '
        'It is small in the frame, half lost in the fog and the darkness, seen just for a moment, '
        'slightly motion-blurred, easy to miss. In the foreground a deflated swim ring and a rubber '
        'duck lie on the wet tiles.' + VIETATO, [CUBO, AMB_A, AMB_B], aspect='16:9')
    img(f'scena_agnello_{tag}', m, SCENA + 'In the kids area, a few metres ahead and to the side, a '
        'heap of abandoned soaked plush toys (a big teddy bear, a blue whale, a yellow duck) and '
        'deflated swim rings lies against a tiled wall under a red emergency light. The plush lamb '
        'from the first reference image sits slumped among them like one of the toys, legs stretched '
        'out, arms limp, but its head is turned straight toward the viewer and its brass button eyes '
        'catch the light. It is easy to mistake for a toy at first glance.' + VIETATO,
        [AGN, AMB_A, AMB_B], aspect='16:9')
    # multi-view per il 3D
    img(f'mv_cubo_{tag}', m, MV + 'A small chubby shadow creature with glossy wet black skin like a '
        'wetsuit and a big white cube head of cracked pool tiles with algae, barnacles and rust, with a '
        'cute face drawn in marker on the front (two vertical dash eyes, pink blush cheeks, small '
        'smile). Plain back view without face on the back of the cube.' + VIETATO, [CUBO], mv=True)
    img(f'mv_agnello_{tag}', m, MV + 'A small chubby plush lamb standing upright, soaked and stained, '
        'stitched seams, brass button eyes, red sailor bow with a brass anchor charm, curled brown '
        'horns, dark hooves, small tail.' + VIETATO, [AGN], mv=True)


CUBO_RIV = '@cubo_rivelato_giallo_gpt'
AGN_LUPO = '@agnello_lupo_gpt'
for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    img(f'mv_cubo_rivelato_{tag}', m, MV + 'A small chubby shadow creature with glossy wet black skin '
        'like a wetsuit, with seaweed. Its head is a big white cube of cracked pool tiles with algae, '
        'barnacles and rust, whose front face is broken open: from inside bursts a mass of glossy '
        'translucent pink and magenta tentacles with glowing channels and many round eyeballs with '
        'yellow irises; a few tentacles curl out over the broken edges and droop down. The back of the '
        'cube is intact.' + VIETATO, [CUBO_RIV], mv=True)
    img(f'mv_agnello_lupo_{tag}', m, MV + 'A small chubby soaked plush lamb body standing upright '
        '(stitched seams, striped patch, red sailor bow with a brass anchor charm, dark hooves), whose '
        'lamb head has split open and hangs behind its shoulders like a hood; out of the neck rises a '
        'big glossy black wolf-like head with deep-sea fish traits: tall pointed ears, gill slits, '
        'small pale glowing dots, wide open jaws with rows of white shark teeth and a pink tongue, '
        'pale yellow eyes.' + VIETATO, [AGN_LUPO], mv=True)

# ---------------------------------------------------------------- cubo, corpo versione 2
# Richiesta dell'utente dopo i primi render: il corpo era "troppo pacioccone". La testa a cubo
# resta; il corpo diventa quello di un bambino magro di 7-9 anni in una muta da sub consunta.
# '@ref_testa_cubo' è il render da studio (bambini_render.py, vista davanti) del primo modello,
# ora in assets_src/bambini/scartati/cubo_corpo_v1/cubo_calmo.glb: serve solo per la testa.
CORPO_MUTA = (
    'the realistic, thin body of a 7 to 9 year old child, about 1.2 metres tall including the cube: '
    'narrow shoulders, thin arms and thin legs that are slightly too long for its size, small hands in '
    'black neoprene diving gloves, feet in black neoprene diving booties. No round belly, no chubby '
    'toy-like limbs. The whole body is covered by an old, worn black diving wetsuit for children: matte, '
    'slightly satin neoprene with visible stitched seams and panel lines, knee pads, faded and scuffed '
    'areas, a few small tears with the lighter grey inner lining showing, a high collar that covers the '
    'neck completely under the cube. The wetsuit is wet, with soft reflections only in the folds and '
    'creases, and a few thin strands of dark green seaweed stuck to it. No skin visible anywhere. ')
POSTURA = (
    'Posture: it stands perfectly still, slightly hunched forward with drooping shoulders, thin arms '
    'hanging limp at its sides, the cube head tilted a little to one side. Silent, motionless and '
    'unsettling. ')
TESTA_UGUALE = (
    'The first reference image shows the head to keep: a white cube made of cracked swimming-pool tiles '
    'with grey grout, green algae, small barnacles, orange rust streaks and a cute face drawn in black '
    'marker (two short vertical dash eyes, round pink blush cheeks, small smile). Keep this cube head '
    'exactly the same, same size relative to the body as a big box on the shoulders. ')
for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    img(f'cubo2_calmo_{tag}', m, STILE + TESTA_UGUALE + 'Replace the body completely with ' +
        CORPO_MUTA + POSTURA + 'Place it in the scene of the second reference image: the same abandoned '
        'indoor water park at night, same spot on the wet tiled floor, same camera and lighting.' +
        FIGURA_INTERA + VIETATO, ['@ref_testa_cubo', CUBO, AMB_A])

CUBO2 = '@cubo2_calmo_nbp'  # scelto guardando le immagini: testa inclinata, corpo magro, muta
MV_CUBO2 = (
    'The same character as in the reference image, exactly the same design, materials, colors and '
    'proportions: a thin child-sized figure in an old worn black neoprene wetsuit with stitched seams, '
    'knee pads, small tears showing the light grey lining, black diving gloves and booties and a few '
    'seaweed strands, with a big white cube head of cracked pool tiles with algae, barnacles and rust. '
    'Same pose: standing still, slightly hunched, thin arms hanging, cube head tilted a little to one '
    'side. Full body from head to feet, on a plain flat light grey background with soft even studio '
    'lighting, no environment, no fog. The back view shows a long zipper with a pull strap running down '
    'the back of the wetsuit. ')
for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    img(f'mv_cubo2_calmo_{tag}', m, MV_CUBO2 + 'The front of the cube has a cute face drawn in black '
        'marker (two vertical dash eyes, pink blush cheeks, small smile); no face on the back of the '
        'cube.' + VIETATO, [CUBO2], mv=True)
    img(f'cubo2_rivelato_{tag}', m, 'The same thin child character in the worn wetsuit as in the first '
        'reference image: same body, same pose with the cube head tilted, same place, same camera '
        'framing, same lighting. But its cube head is now broken open like the cube in the second '
        'reference image. ' + massa(OCCHI_GIALLI) + FIGURA_INTERA + VIETATO,
        [CUBO2, CUBO_RIV, STATUA])

CUBO2_RIV = '@cubo2_rivelato_gpt'  # stessa testa inclinata del calmo
for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    img(f'mv_cubo2_rivelato_{tag}', m, MV_CUBO2.replace('with a big white cube head of cracked pool '
        'tiles with algae, barnacles and rust', 'with a big white cube head of cracked pool tiles with '
        'algae, barnacles and rust whose front face is broken open: from inside bursts a mass of glossy '
        'translucent pink and magenta tentacles with glowing channels and many round eyeballs with '
        'yellow irises; a few tentacles curl out over the broken edges and droop down; the back of the '
        'cube is intact') + VIETATO, [CUBO2_RIV], mv=True)

AGN_OCCHIO = '@agnello_occhio_gpt'
for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    img(f'mv_agnello_occhio_{tag}', m, MV + 'A small chubby soaked plush lamb standing upright '
        '(stitched seams, striped patch, red sailor bow with a brass anchor charm, curled brown horns, '
        'dark hooves, small tail), whose cute face has split open vertically along a seam: the fabric '
        'parts like two lips with white stuffing tufts, the two brass button eyes are pushed to the '
        'sides, and from inside a single huge glossy eye with a pink radial iris stares out.' + VIETATO,
        [AGN_OCCHIO], mv=True)

# modelli 3D (multi-image-to-3d, meshy-7.1, PBR). 'from' = job multi-view da cui partire;
# 'immagini' = file locali (in OUT) in un ordine scelto, con la vista frontale per prima.
JOBS['3d_cubo_calmo'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_cubo_nbp'})
JOBS['3d_agnello_calmo'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_agnello_nbp'})
JOBS['3d_cubo2_calmo'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_cubo2_calmo_gpt'})
JOBS['3d_cubo2_rivelato'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_cubo2_rivelato_gpt'})
JOBS['3d_agnello_occhio'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_agnello_occhio_gpt'})
JOBS['3d_cubo_rivelato'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_cubo_rivelato_nbp'})
# nel multi-view GPT del lupo la vista frontale è la seconda: la metto per prima
JOBS['3d_agnello_lupo'] = dict(kind='3d', model='meshy-7.1', **{'from': 'mv_agnello_lupo_gpt'},
                               immagini=['mv_agnello_lupo_gpt_1.png', 'mv_agnello_lupo_gpt_0.png',
                                         'mv_agnello_lupo_gpt_2.png'])


def run_img(name, j):
    refs = []
    for r in j['refs']:
        if r.startswith('@'):
            p = os.path.join(OUT, r[1:] + '_0.png')
        else:
            p = os.path.join(REPO, r)
        mime = 'image/png' if p.endswith('.png') else 'image/jpeg'
        with open(p, 'rb') as f:
            refs.append(f'data:{mime};base64,' + base64.b64encode(f.read()).decode())
    body = dict(ai_model=j['model'], prompt=j['prompt'], reference_image_urls=refs)
    if j['mv']:
        body['generate_multi_view'] = True
    else:
        body['aspect_ratio'] = j['aspect']
    tid = _create('image-to-image', body)
    t = meshy.wait('image-to-image', tid, every=6, timeout=3600)
    _log(name, 'image-to-image', tid, j, t)
    if t['status'] != 'SUCCEEDED':
        print(name, t['status'], t.get('task_error'), flush=True)
        return
    for i, u in enumerate(t['image_urls']):
        meshy.download(u, os.path.join(OUT, f'{name}_{i}.png'))
    print(name, 'OK', len(t['image_urls']), 'immagini', flush=True)


def run_3d(name, j):
    if j.get('immagini'):
        src = dict(image_urls=['data:image/png;base64,' + base64.b64encode(
            open(os.path.join(OUT, f), 'rb').read()).decode() for f in j['immagini']])
    else:
        src = dict(input_task_id=_task_id(j['from']))
    body = dict(**src, ai_model='meshy-7.1', should_texture=True, enable_pbr=True,
                texture_resolution='2k', should_remesh=j.get('remesh', False),
                target_formats=['glb'], image_enhancement=True, remove_lighting=True)
    if j.get('remesh'):
        body.update(topology='triangle', target_polycount=j['remesh'])
    tid = _create('multi-image-to-3d', body)
    t = meshy.wait('multi-image-to-3d', tid, every=10, timeout=3600)
    corto = {k: v for k, v in body.items() if k != 'image_urls'}
    _log(name, 'multi-image-to-3d', tid, dict(j, body=corto), t)
    if t['status'] != 'SUCCEEDED':
        print(name, t['status'], t.get('task_error'), flush=True)
        return
    meshy.download(t['model_urls']['glb'], os.path.join(OUT, f'{name}.glb'))
    if t.get('thumbnail_url'):
        meshy.download(t['thumbnail_url'], os.path.join(OUT, f'{name}_thumb.png'))
    print(name, 'OK glb', flush=True)


def _create(kind, body):
    for k in range(8):
        try:
            return meshy.create(kind, body)
        except RuntimeError as e:
            if '-> 429' in str(e):
                time.sleep(20 + 10 * k)
                continue
            raise
    raise RuntimeError('troppi 429')


def _read_log():
    if os.path.exists(LOG):
        with open(LOG) as f:
            return json.load(f)
    return {}


def _task_id(job):
    return _read_log()[job]['task_id']


def _log(name, kind, tid, j, t):
    with _lock:
        log = _read_log()
        log[name] = dict(kind=kind, task_id=tid, status=t['status'],
                         model=j.get('model', 'meshy-7.1'), prompt=j.get('prompt'),
                         refs=j.get('refs'), aspect=j.get('aspect'), multi_view=j.get('mv'),
                         from_job=j.get('from'), body=j.get('body'),
                         credits=t.get('consumed_credits'))
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, 'w') as f:
            json.dump(log, f, indent=1, ensure_ascii=False)


def main(names):
    os.makedirs(OUT, exist_ok=True)
    ths = []
    for n in names:
        j = JOBS[n]
        fn = run_img if j['kind'] == 'img' else run_3d
        th = threading.Thread(target=lambda n=n, j=j, fn=fn: _safe(fn, n, j))
        th.start(); ths.append(th)
        time.sleep(1.5)
    for th in ths:
        th.join()


def _safe(fn, n, j):
    try:
        fn(n, j)
    except Exception as e:  # noqa: BLE001
        print(n, 'ERRORE', e, flush=True)


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] == '--list':
        print('\n'.join(JOBS))
    else:
        main(sys.argv[1:])

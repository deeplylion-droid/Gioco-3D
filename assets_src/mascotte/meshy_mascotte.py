"""Nuove mascotte (statue squalo e polpo, mostro-squalo): generazione con Meshy.

Uso:
    python assets_src/mascotte/meshy_mascotte.py <job> [<job> ...]   # lancia i job in parallelo
    python assets_src/mascotte/meshy_mascotte.py --list

Catena per ogni variante: immagine di riferimento (image-to-image, solo uso interno, mai mostrata
all'utente) -> multi-view -> modello 3D (multi-image-to-3d, meshy-7.1, PBR 4k).
Le uscite vanno in $MASCOTTE_OUT (default assets_src/mascotte/gen): <job>_<n>.png e <job>.glb.
Ogni task è registrato in assets_src/mascotte/meshy_log.json (id, prompt, crediti).
"""
import base64, json, os, sys, threading, time

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import meshy  # noqa: E402

OUT = os.environ.get('MASCOTTE_OUT', os.path.join(QUI, 'gen'))
LOG = os.path.join(QUI, 'meshy_log.json')
_lock = threading.Lock()

STATUA_MEDUSA = 'docs/concept/medusa_statua.jpg'

# ---------------------------------------------------------------- blocchi di prompt
STUDIO = (
    ' Full figure from the top of the head to the bottom of the base, centered, seen from a slightly '
    'high three-quarter front view, on a plain flat neutral light grey studio background with soft '
    'even lighting, no environment, no floor details. ')
VIETATO = (' Absolutely no text, no letters, no numbers, no logos, no writing, no watermark. '
           'No blood, no gore.')

STATUA = (
    'A life-size painted fiberglass mascot statue from a 1990s family water park aboard a cruise ship, '
    'the same family and the same craftsmanship as the jellyfish mascot statue in the reference image: '
    'a cheerful cartoon character sculpted in smooth glossy fiberglass and painted in bright saturated '
    'colors, with big friendly painted eyes and a wide happy smile. It is clearly a STATUE, a single '
    'solid sculpted piece, not a living animal: simplified rounded sculpted shapes, no real skin or '
    'scales, painted details. Now, after years abandoned in a wet indoor water park, it is faded, '
    'sun-bleached and weathered: cracked gelcoat, chipped and flaking paint showing the white '
    'fiberglass underneath, brown water stains and drip marks, patches of green algae in the crevices, '
    'white limescale crust. It stands on a sturdy round fiberglass pedestal painted with faded wave '
    'patterns, bolted down with big rusty bolts and rusty metal brackets, orange rust streaks running '
    'down. Total height about 2.3 metres including the pedestal. Cheerful in daylight, unsettling in '
    'the dark. ')

SQUALO_A = (
    'The character is an anthropomorphic friendly cartoon shark standing upright on two short sturdy '
    'legs, light blue-grey back and white belly, a rounded snout, big round friendly eyes, a big '
    'toothy grin with rounded cartoon teeth, a tall dorsal fin and its tail fin behind. It wears red '
    'lifeguard swim shorts. With its right fin-hand it gives a big thumbs up, and with its left arm it '
    'holds a red and white life ring against its hip. ')
SQUALO_B = (
    'The character is an anthropomorphic friendly cartoon shark standing upright on two short sturdy '
    'legs, deep turquoise-blue back and cream belly, a rounded snout, big round friendly eyes, a wide '
    'open happy smile with a few rounded cartoon teeth, a tall dorsal fin and its tail fin behind. It '
    'wears a little white sailor hat with a blue band and a yellow lifeguard whistle on a cord around '
    'its neck. With both fin-hands it holds up in front of its chest a wooden welcome sign shaped like '
    'a surfboard, painted with colorful waves and a sun (no text). ')
POLPO_A = (
    'The character is an anthropomorphic friendly cartoon octopus standing upright on its curled lower '
    'tentacles like legs, with a big round coral-pink head, big round friendly eyes with long lashes, '
    'rosy cheeks and a wide happy smile. Two of its upper tentacles are raised and opened wide in a '
    'big welcoming hug gesture, waving hello, the other tentacles curl on the pedestal. It wears a '
    'little white sailor hat with a blue band tilted on its head and a blue polka-dot bow tie. ')
POLPO_B = (
    'The character is an anthropomorphic friendly cartoon octopus standing upright on its curled lower '
    'tentacles like legs, with a big round lavender-purple head with lighter spots, big round friendly '
    'eyes, rosy cheeks and a wide happy smile. It wears a yellow snorkel mask pushed up on its forehead '
    'and an orange swim ring around its waist. One upper tentacle waves hello high in the air, another '
    'holds a striped beach ball, another holds a little ice cream cone, the other tentacles curl on '
    'the pedestal. ')

MOSTRO = (
    'A photorealistic monstrous shark creature, a living animal, not a statue or a toy: a huge, round, '
    'bloated barrel-shaped body leaning forward, standing on two short, thick, slightly bent legs with '
    'reptile-like three-toed feet with dark claws. The large head merges directly into the body with no '
    'neck, a rounded blunt snout with a white patch above the mouth, tiny black eyes set far apart, a '
    'very wide grin full of small sharp pointed teeth with a red mouth inside, gill slits on the sides. '
    'A tall dorsal fin on the back and a shark tail fin behind, held almost horizontal. Two short arms '
    'with long hands and long curved claws, one arm raised forward reaching. The skin is wet living '
    'shark skin, mottled grey and brown in blotches, with a paler belly and snout, glistening with '
    'water. Clumsy but menacing, like a bulldog. About 2.2 metres tall. ')
MOSTRO_A = (
    'It looks a bit goofy and almost endearing in its proportions, a creature design faithful to a '
    'storybook watercolor monster, but with real wet skin. ')
MOSTRO_B = (
    'A more horrifying version: the skin is scarred, sickly and slimy, with old wounds, barnacle '
    'clusters and torn fins, the grin is wider and the teeth are crooked and needle-like in several '
    'rows, the tiny eyes are glossy and dead, the claws longer and hooked, the posture more hunched '
    'and predatory. ')
MOSTRO_STUDIO = (
    ' Full body from head to feet, centered, seen from a three-quarter front view, standing on a plain '
    'flat neutral light grey studio background with soft even lighting, no environment. ')

MV = (
    'The same object as in the reference image, exactly the same design, materials, colors, wear, pose '
    'and proportions, full figure, on a plain flat neutral light grey background with soft even '
    'studio lighting, no environment, no cast shadows. ')

# ---------------------------------------------------------------- job
JOBS = {}


def img(name, model, prompt, refs, aspect='3:4', mv=False):
    JOBS[name] = dict(kind='img', model=model, prompt=prompt, refs=refs, aspect=aspect, mv=mv)


MODELLI = (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt'))
for m, tag in MODELLI:
    for nome, des in (('squalo_a', SQUALO_A), ('squalo_b', SQUALO_B),
                      ('polpo_a', POLPO_A), ('polpo_b', POLPO_B)):
        img(f'{nome}_{tag}', m, STATUA + des + STUDIO + VIETATO, [STATUA_MEDUSA])
    img(f'mostro_a_{tag}', m, MOSTRO + MOSTRO_A + MOSTRO_STUDIO + VIETATO, [])
    img(f'mostro_b_{tag}', m, MOSTRO + MOSTRO_B + MOSTRO_STUDIO + VIETATO, [])


def mv(name, src, extra=''):
    """Multi-view di un'immagine scelta ('@job' o '@job_n')."""
    for m, tag in MODELLI:
        img(f'mv_{name}_{tag}', m, MV + extra + VIETATO, [src], mv=True)


def modello(name, immagini, geom='2k'):
    """3D da immagini locali in OUT (la vista frontale per prima)."""
    JOBS[f'3d_{name}'] = dict(kind='3d', immagini=immagini, geom=geom)


# Riferimenti scelti guardando il primo giro (18 ottobre)
SCELTI = dict(squalo_a='@squalo_a_gpt', squalo_b='@squalo_b_gpt', polpo_a='@polpo_a_gpt',
              polpo_b='@polpo_b_gpt', mostro_a='@mostro_a_nbp', mostro_b='@mostro_b_gpt')
for _n, _src in SCELTI.items():
    mv(_n, _src, 'The back view shows the back of the character and of the pedestal. '
       if not _n.startswith('mostro') else 'The back view shows the dorsal fin and the tail. ')

# Modelli 3D: ordine delle viste deciso guardando i multi-view (frontale per prima),
# più l'immagine di riferimento di tre quarti come quarta vista.
ORDINE = dict(squalo_a_nbp=(0, 1, 2), squalo_a_gpt=(2, 1, 0), squalo_b_nbp=(0, 1, 2),
              squalo_b_gpt=(1, 2, 0), polpo_a_nbp=(0, 1, 2), polpo_a_gpt=(2, 0, 1),
              polpo_b_nbp=(0, 1, 2), polpo_b_gpt=(2, 0, 1), mostro_a_nbp=(1, 2, 0),
              mostro_a_gpt=(0, 2, 1), mostro_b_gpt=(2, 0, 1), mostro_b_nbp=(0, 2, 1))
for _k, _o in ORDINE.items():
    _n = _k.rsplit('_', 1)[0]
    modello(_k, [f'mv_{_k}_{i}.png' for i in _o] + [SCELTI[_n][1:] + '_0.png'])

# Secondo giro del mostro. Il primo A era troppo bianco e lucido (riflessi cotti nella texture) e
# con le braccia giù; il 3D del B gpt aveva una doppia bocca per colpa della quarta vista di 3/4.
MOSTRO_A2 = (
    'Its skin is matte-wet, not shiny plastic: dark slate grey and muddy olive-brown in irregular '
    'blotches and spots like a nurse shark or a catshark, only the lower belly and the snout patch '
    'are a dirty cream colour. Its right arm is raised forward toward the viewer at shoulder height, '
    'the long clawed fingers spread, the left arm hangs low. It looks goofy and almost endearing in '
    'its proportions, like a storybook watercolor monster, but with real wet skin. ')
for m, tag in MODELLI:
    img(f'mostro_a2_{tag}', m, MOSTRO + MOSTRO_A2 + MOSTRO_STUDIO + VIETATO, [])
# il B gpt rifatto con le sole tre viste del multi-view
modello('mostro_b_gpt_3v', [f'mv_mostro_b_gpt_{i}.png' for i in (2, 0, 1)])

for _src in ('mostro_a2_nbp', 'mostro_a2_gpt'):
    for m, tag in MODELLI[:1]:
        img(f'mv_{_src}', m, MV + 'The back view shows the dorsal fin and the tail. ' + VIETATO, ['@' + _src], mv=True)

modello('mostro_a2_nbp', [f'mv_mostro_a2_nbp_{i}.png' for i in (1, 2, 0)])
modello('mostro_a2_gpt', [f'mv_mostro_a2_gpt_{i}.png' for i in (1, 2, 0)])

# Versione "nuova" delle statue (vernice fresca, come nel 1995), per il confronto nuovo/rovinato:
# la vista frontale del multi-view ridipinta, poi retexture del modello sulle sue UV.
NUOVA = (
    'The same statue as in the reference image, exactly the same shape, pose, proportions, design and '
    'colors, same view and framing, on the same plain background, but brand new as on its opening day '
    'in 1995: freshly painted glossy fiberglass with clean bright saturated colors, smooth flawless '
    'gelcoat, crisp painted details, no cracks, no chipped paint, no stains, no algae, no rust: the '
    'pedestal is clean with bright painted waves and shiny new steel bolts. ')
for _n in ('squalo_a', 'squalo_b', 'polpo_a', 'polpo_b'):
    img(f'nuova_{_n}', 'nano-banana-pro', NUOVA + VIETATO, [f'@mv_{_n}_nbp_0.png'])
    JOBS[f'ritex_nuova_{_n}'] = dict(kind='ritex', da=f'3d_{_n}_nbp', stile=f'nuova_{_n}_0.png')


def run_ritex(name, j):
    body = dict(input_task_id=_read_log()[j['da']]['task_id'], ai_model='meshy-7',
                image_style_url=_data_uri(_ref_path('@' + j['stile'])), enable_original_uv=True,
                enable_pbr=True, texture_resolution='4k', target_formats=['glb'])
    tid = _create('retexture', body)
    t = meshy.wait('retexture', tid, every=10, timeout=3600)
    _log(name, 'retexture', tid, dict(j, body={k: v for k, v in body.items() if k != 'image_style_url'}), t)
    if t['status'] != 'SUCCEEDED':
        print(name, t['status'], t.get('task_error'), flush=True)
        return
    _scarica(t['model_urls']['glb'], os.path.join(OUT, f'{name}.glb'))
    print(name, 'OK glb', flush=True)


# ---------------------------------------------------------------- esecuzione
def _data_uri(p):
    mime = 'image/png' if p.endswith('.png') else 'image/jpeg'
    with open(p, 'rb') as f:
        return f'data:{mime};base64,' + base64.b64encode(f.read()).decode()


def _ref_path(r):
    if r.startswith('@'):
        r = r[1:]
        return os.path.join(OUT, r if r.endswith(('.png', '.jpg')) else r + '_0.png')
    return os.path.join(REPO, r)


def run_img(name, j):
    body = dict(ai_model=j['model'], prompt=j['prompt'])
    if j['refs']:
        body['reference_image_urls'] = [_data_uri(_ref_path(r)) for r in j['refs']]
        kind = 'image-to-image'
    else:
        kind = 'text-to-image'
    if j['mv']:
        body['generate_multi_view'] = True
    else:
        body['aspect_ratio'] = j['aspect']
    tid = _create(kind, body)
    t = meshy.wait(kind, tid, every=6, timeout=3600)
    _log(name, kind, tid, j, t)
    if t['status'] != 'SUCCEEDED':
        print(name, t['status'], t.get('task_error'), flush=True)
        return
    for i, u in enumerate(t['image_urls']):
        _scarica(u, os.path.join(OUT, f'{name}_{i}.png'))
    print(name, 'OK', len(t['image_urls']), 'immagini', flush=True)


def run_3d(name, j):
    body = dict(image_urls=[_data_uri(_ref_path('@' + f)) for f in j['immagini']],
                ai_model='meshy-7.1', should_texture=True, enable_pbr=True,
                texture_resolution='4k', should_remesh=False, target_formats=['glb'],
                image_enhancement=True, remove_lighting=True, geometry_resolution=j['geom'])
    tid = _create('multi-image-to-3d', body)
    t = meshy.wait('multi-image-to-3d', tid, every=10, timeout=3600)
    corto = {k: v for k, v in body.items() if k != 'image_urls'}
    _log(name, 'multi-image-to-3d', tid, dict(j, body=corto), t)
    if t['status'] != 'SUCCEEDED':
        print(name, t['status'], t.get('task_error'), flush=True)
        return
    _scarica(t['model_urls']['glb'], os.path.join(OUT, f'{name}.glb'))
    print(name, 'OK glb', flush=True)


def _scarica(url, path):
    for k in range(5):  # i GLB grossi a volte arrivano troncati
        try:
            return meshy.download(url, path)
        except Exception:  # noqa: BLE001
            if k == 4:
                raise
            time.sleep(5)


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


def _log(name, kind, tid, j, t):
    with _lock:
        log = _read_log()
        log[name] = dict(kind=kind, task_id=tid, status=t['status'], model=j.get('model', 'meshy-7.1'),
                         prompt=j.get('prompt'), refs=j.get('refs'), multi_view=j.get('mv'),
                         immagini=j.get('immagini'), body=j.get('body'),
                         credits=t.get('consumed_credits'))
        with open(LOG, 'w') as f:
            json.dump(log, f, indent=1, ensure_ascii=False)


def _safe(fn, n, j):
    try:
        fn(n, j)
    except Exception as e:  # noqa: BLE001
        print(n, 'ERRORE', e, flush=True)


def main(names):
    os.makedirs(OUT, exist_ok=True)
    ths = []
    for n in names:
        j = JOBS[n]
        fn = {'img': run_img, '3d': run_3d, 'ritex': run_ritex}[j['kind']]
        th = threading.Thread(target=_safe, args=(fn, n, j))
        th.start(); ths.append(th)
        time.sleep(1.5)
    for th in ths:
        th.join()


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] == '--list':
        print('\n'.join(JOBS))
    else:
        main(sys.argv[1:])

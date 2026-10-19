"""Modelli Meshy dell'infermeria (proposte d'aspetto del 19 ottobre, squadra enigma-ambiente).

Uso: python3 assets_src/infermeria/meshy_infermeria.py [nomi...]
Per ogni modello una sola forma (preview meshy-7.1 con remesh) e due texture (refine con PBR sulla
stessa preview): A "ambulatorio di bordo anni '90" e B "infermeria per bambini, pastello". Così le
proposte si confrontano sugli stessi modelli con due materiali. GLB in assets_src/infermeria/meshy/
come <nome>_A.glb e <nome>_B.glb (solo A o solo B per gli oggetti di un aspetto).
"""
import json, os, sys, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, 'meshy')

TEX_A = ('1990s company first-aid room: grey-green and beige enamel painted steel, cream vinyl, worn and '
         'chipped paint, rust at the edges, dust, grime, fluorescent-lit hospital look. ')
TEX_B = ('Children\'s infirmary of a 1990s water park: pastel pink, mint green and baby blue painted surfaces, a '
         'few small cute sea animal stickers (no text), faded, chipped paint, dust and grime. ')

MODELLI = {
    'scrivania': dict(
        prompt='1990s steel office desk, 1.4 m wide, with a pedestal of three drawers on the right, a thin top '
               'with rounded edges, modesty panel. Realistic.',
        texture='Desk top with laminate, metal drawer handles.', aspetti='AB', polycount=15000),
    'sedia': dict(
        prompt='1990s swivel office chair with five-star base on casters, padded seat and backrest, armrests. '
               'Realistic.', texture='Vinyl seat cracked, metal base.', aspetti='AB', polycount=15000),
    'schedario': dict(
        prompt='Vertical metal filing cabinet with four drawers, 1.35 m tall, 0.47 m wide, each drawer with a '
               'pull handle and a small empty label holder frame. Realistic.',
        texture='Painted sheet metal, metal handles, empty label holders.', aspetti='AB', polycount=12000),
    'lettino': dict(
        prompt='Medical examination couch, 1.9 m long, padded top with raised adjustable backrest, steel frame '
               'with legs, a roll of paper sheet at the head end. Realistic.',
        texture='Padded vinyl top, painted steel frame, white paper roll.', aspetti='AB', polycount=20000),
    'armadietto': dict(
        prompt='Wall-mounted medicine cabinet, 0.8 m wide and 0.9 m tall, two glass doors, shelves inside with '
               'medicine bottles, jars and boxes without text. Realistic.',
        texture='Painted metal cabinet, glass doors, white and brown bottles, plain boxes, no text.',
        aspetti='AB', polycount=25000),
    'paravento': dict(
        prompt='Three-panel folding hospital privacy screen on small wheels, 1.8 m tall, tubular steel frames '
               'with fabric panels, slightly folded zigzag. Realistic.',
        texture='Tubular metal frames, fabric panels.', aspetti='AB', polycount=15000),
    'lavandino': dict(
        prompt='Small ceramic wall-mounted hand wash sink with two long lever taps and a soap dispenser above, '
               'exposed pipe under it. Realistic.',
        texture='Ceramic sink with limescale, chrome taps, plastic soap dispenser.', aspetti='AB', polycount=12000),
    'carrello': dict(
        prompt='Medical trolley cart on four casters, two shelves and one drawer, tray on top with a kidney dish '
               'and a few small bottles, push handle. Realistic.',
        texture='Painted steel trolley, stainless kidney dish.', aspetti='AB', polycount=15000),
    'bombola': dict(
        prompt='Medical oxygen cylinder on a small two-wheel cart with a regulator gauge and a coiled tube. '
               'Realistic.', texture='Painted gas cylinder, brass regulator.', aspetti='A', polycount=12000),
    'giraffa_metro': dict(
        prompt='Children\'s height measuring chart shaped like a cartoon giraffe, flat wooden cutout 1.6 m tall '
               'to hang on a wall, with a ruler scale marks along the neck (marks only, no numbers). Realistic.',
        texture='Painted plywood giraffe, yellow with orange spots.', aspetti='B', polycount=8000),
}


def fai(nome):
    m = MODELLI[nome]
    fatti = [a for a in m['aspetti'] if os.path.exists(os.path.join(OUT, '%s_%s.glb' % (nome, a)))]
    if len(fatti) == len(m['aspetti']):
        return nome, 'già fatto'
    pid = meshy.create('text-to-3d', dict(mode='preview', prompt=m['prompt'], ai_model='meshy-7.1',
                                          should_remesh=True, topology='triangle',
                                          target_polycount=m['polycount'], target_formats=['glb']))
    t = meshy.wait('text-to-3d', pid)
    if t['status'] != 'SUCCEEDED':
        return nome, 'preview fallita: %s' % t.get('task_error')
    info = dict(preview=pid, prompt=m['prompt'])
    for a in m['aspetti']:
        tex = (TEX_A if a == 'A' else TEX_B) + m['texture']
        rid = meshy.create('text-to-3d', dict(mode='refine', preview_task_id=pid, enable_pbr=True,
                                              texture_prompt=tex, texture_resolution='2k',
                                              target_formats=['glb']))
        t = meshy.wait('text-to-3d', rid)
        if t['status'] != 'SUCCEEDED':
            return nome, 'refine %s fallita: %s' % (a, t.get('task_error'))
        meshy.download(t['model_urls']['glb'], os.path.join(OUT, '%s_%s.glb' % (nome, a)))
        if t.get('thumbnail_url'):
            meshy.download(t['thumbnail_url'], os.path.join(OUT, '%s_%s_anteprima.png' % (nome, a)))
        info['refine_' + a] = rid
        info['texture_' + a] = tex
    with open(os.path.join(OUT, nome + '.json'), 'w') as f:
        json.dump(info, f, indent=1)
    return nome, 'ok'


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    nomi = sys.argv[1:] or list(MODELLI)
    with cf.ThreadPoolExecutor(5) as ex:
        for nome, esito in ex.map(fai, nomi):
            print(nome, esito, flush=True)
    print(meshy.balance())

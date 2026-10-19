"""Modelli Meshy dell'infermeria (proposte d'aspetto del 19 ottobre, squadra enigma-ambiente).

Uso: python3 assets_src/infermeria/meshy_infermeria.py [nomi...]
Per ogni modello una sola forma (preview meshy-7.1 con remesh) e due texture (refine con PBR sulla
stessa preview): A "ambulatorio di bordo anni '90" e B "infermeria per bambini, pastello". Così le
proposte si confrontano sugli stessi modelli con due materiali. GLB in assets_src/infermeria/meshy/
come <nome>_A.glb e <nome>_B.glb (solo A o solo B per gli oggetti di un aspetto); <nome>_N.glb per
gli oggetti uguali nei due aspetti (texture senza tema).
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
    # --- oggetti dell'enigma veri e riempimento (richiesta del coordinatore del 19 ottobre) ---
    'schedario_vero': dict(
        prompt='Old dented steel four-drawer vertical filing cabinet, 1.35 m tall, 0.47 m wide, each drawer with '
               'a recessed pull handle and a small card label holder with a blank paper card, the second drawer '
               'from the bottom slightly open with paper folders inside. Realistic.',
        texture='Painted sheet steel with dents, scratches and rust at the edges, blank yellowed label cards.',
        aspetti='AB', polycount=15000),
    'negatoscopio': dict(
        prompt='Wall-mounted medical x-ray film viewer lightbox, 1 m wide and 0.65 m tall, thin metal frame, '
               'flat white diffuser panel, a row of spring film clips along the top edge, a rocker switch on the '
               'side, a power cable hanging down. Realistic.',
        texture='Painted metal frame, milky white plastic diffuser, chrome clips, black cable.', aspetti='AB',
        polycount=10000),
    'sportello_cassaforte': dict(
        prompt='Thick steel wall safe door, square 50 cm, front view, with two heavy cylindrical hinges on the left '
               'edge, a chrome lever handle on the right, beveled edges, bolted steel rim frame around it. Realistic.',
        texture='Dark grey-green painted steel, worn edges showing bare metal, chrome handle, grime.', aspetti='N',
        polycount=10000),
    'sedia_rotelle': dict(prompt='Old folding hospital wheelchair, chrome frame, vinyl seat. Realistic.',
                          texture='Chrome with rust, cracked black vinyl, dirty tires.', aspetti='N', polycount=20000),
    'bilancia': dict(
        prompt='Old mechanical column doctor scale with a height measuring rod and a platform, 1.5 m tall. Realistic.',
        texture='White painted steel, chipped, black rubber platform mat, chrome weights.', aspetti='N', polycount=12000),
    'asta_flebo': dict(prompt='Hospital IV drip stand pole on five casters with two hooks and an empty IV bag. Realistic.',
                       texture='Chrome pole with rust spots, clear plastic bag, dirty.', aspetti='N', polycount=8000),
    'cestino': dict(prompt='Pedal operated medical waste bin, 50 cm tall, with lid. Realistic.',
                    texture='Painted metal, dented, scratched.', aspetti='AB', polycount=6000),
    'tenda_binario': dict(
        prompt='Hospital privacy curtain hanging from a ceiling mounted straight rail, 2 m long and 2.2 m tall, '
               'fabric pulled half open with folds. Realistic.', texture='Fabric curtain, stained, aluminum rail.',
        aspetti='AB', polycount=20000),
    'lenzuolo': dict(prompt='Crumpled white hospital bedsheet lying in a heap, 1 m wide. Realistic.',
                     texture='White cotton sheet, stained, wrinkled.', aspetti='N', polycount=12000),
    'pronto_soccorso': dict(
        prompt='Wall mounted first aid box cabinet with a red cross symbol on the door, 40 cm wide. Realistic.',
        texture='White painted metal, red cross, scratched, dirty.', aspetti='N', polycount=6000),
    'asciugamani': dict(prompt='Stack of three folded towels, 40 cm wide. Realistic.',
                        texture='Faded white and light blue terry towels, stained.', aspetti='N', polycount=6000),
    'guanti': dict(prompt='Open box of disposable latex gloves with a few gloves hanging out. Realistic.',
                   texture='White cardboard box, blue gloves, no text.', aspetti='N', polycount=6000),
    'cartelle_terra': dict(
        prompt='Scattered paper medical folders and loose sheets spread on the floor, 1 m wide area, flat. Realistic.',
        texture='Manila folders, yellowed papers, footprints and grime, no readable text.', aspetti='N',
        polycount=10000),
    'vetri_rotti': dict(prompt='Scattered shards of broken glass on the floor, 60 cm area, flat. Realistic.',
                        texture='Clear glass shards with dust.', aspetti='N', polycount=8000),
    'lampada_tavolo': dict(prompt='1980s adjustable metal desk lamp with a round shade. Realistic.',
                           texture='Painted metal, chipped.', aspetti='AB', polycount=8000),
    'fonendoscopio': dict(prompt='Medical stethoscope lying coiled on a table. Realistic.',
                          texture='Black rubber tubing, chrome chest piece.', aspetti='N', polycount=6000),
    'timbri': dict(prompt='Rubber stamp holder rack with three office rubber stamps and an ink pad. Realistic.',
                   texture='Wooden handles, black ink pad, worn.', aspetti='N', polycount=6000),
    'fogli': dict(prompt='Messy stack of paper sheets and two manila folders on a desk, 35 cm wide. Realistic.',
                  texture='Yellowed paper, manila folders, coffee stains, no readable text.', aspetti='N', polycount=6000),
    'bicchiere': dict(prompt='Empty drinking glass with a dried stain at the bottom, 10 cm. Realistic.',
                      texture='Clear glass, dusty.', aspetti='N', polycount=3000),
    # B: cose da bambini
    'orsetto': dict(prompt='Worn teddy bear plush toy sitting, 35 cm. Realistic.',
                    texture='Faded light brown fur, matted, a patch on one arm, dirty.', aspetti='N', polycount=10000),
    'cubi': dict(prompt='A few wooden toy alphabet blocks scattered, with simple pictures, no letters. Realistic.',
                 texture='Faded pastel painted wood, chipped.', aspetti='N', polycount=6000),
    'trenino': dict(prompt='Colorful wooden toy train with three wagons, 50 cm long. Realistic.',
                    texture='Faded red, yellow and blue paint, chipped.', aspetti='N', polycount=8000),
    'cerotti': dict(prompt='Open box of colorful children bandages plasters, some scattered. Realistic.',
                    texture='Colorful plasters with cartoon patterns, no text.', aspetti='N', polycount=5000),
    'cavallo_dondolo': dict(prompt='Small wooden rocking horse toy, 70 cm. Realistic.',
                            texture='Faded white and pink paint, chipped, worn saddle.', aspetti='N', polycount=12000),
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
        tex = ({'A': TEX_A, 'B': TEX_B}.get(a, '')) + m['texture']
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

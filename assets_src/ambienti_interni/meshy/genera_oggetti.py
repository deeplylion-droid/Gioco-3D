"""Oggetti di scena generati con Meshy text-to-3d (preview meshy-7 + refine con PBR).
Uso: python3 genera_oggetti.py [nome ...]   (senza argomenti: tutti quelli che mancano).
Scarica <nome>.glb grezzo qui; la pulizia e la scala le fa tools/blender/ambienti1_props.py."""
import json, os, sys, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
STILE = ' Realistic, worn and dirty, abandoned 1990s cruise ship waterpark, game asset, single object, no text, no logos.'
OGGETTI = {
    'ciabatta': ('A single cheap rubber flip-flop sandal, faded blue sole, worn and dirty.', 4000),
    'braccioli': ('A pair of inflatable children swim armbands, bright orange with yellow stripes, a bit deflated and dirty.', 6000),
    'fischietto': ('A plastic lifeguard whistle, red, with a short coiled lanyard cord.', 3000),
    'radio': ('A 1990s portable transistor radio with carry handle, grey plastic, telescopic antenna, round speaker grille, scratched.', 8000),
    'sedia': ('A metal folding chair with a cracked plastic seat, rusty legs, office style.', 8000),
    'asciugamano': ('A crumpled bath towel lying on the floor, faded teal with white stripes, damp and dirty.', 6000),
    'salvagente_giocattolo': ('A kids inflatable swim ring shaped like a smiling yellow duck, bright saturated colors, slightly faded.', 8000),
    'secchio_mocio': ('A yellow plastic mop bucket on wheels with a wringer and a grey mop, dirty.', 10000),
    'estintore': ('A red fire extinguisher with black hose and wall bracket, scratched paint.', 6000),
    'radio_ricetrasmittente': ('A 1990s handheld walkie-talkie radio, black plastic, short antenna, belt clip.', 4000),
    'cassetta_pronto_soccorso': ('A wall-mounted metal first aid cabinet, white enamel with a green cross symbol only, one door slightly open, rust stains, chipped.', 8000),
    'paperella': ('A small yellow rubber duck bath toy, dirty and faded.', 3000),
    'pallone': ('An inflatable beach ball with bright red, yellow, blue and white segments, half deflated.', 4000),
    'cestino': ('A round metal mesh trash bin, rusty, with a crumpled plastic bag inside.', 8000),
}

def fai(nome):
    out = os.path.join(QUI, nome + '.glb')
    if os.path.exists(out):
        return nome, 'esiste'
    prompt, poly = OGGETTI[nome]
    pid = meshy.create('text-to-3d', dict(mode='preview', prompt=prompt + STILE, ai_model='meshy-7',
                                          topology='triangle', target_polycount=poly, should_remesh=True))
    p = meshy.wait('text-to-3d', pid)
    if p['status'] != 'SUCCEEDED':
        return nome, 'preview ' + p['status']
    rid = meshy.create('text-to-3d', dict(mode='refine', preview_task_id=pid, enable_pbr=True, texture_resolution='2k'))
    r = meshy.wait('text-to-3d', rid)
    json.dump(dict(preview=pid, refine=rid, prompt=prompt + STILE, status=r['status']),
              open(os.path.join(QUI, nome + '.json'), 'w'), indent=1)
    if r['status'] != 'SUCCEEDED':
        return nome, 'refine ' + r['status']
    meshy.download(r['model_urls']['glb'], out)
    return nome, 'ok'

if __name__ == '__main__':
    nomi = sys.argv[1:] or list(OGGETTI)
    with cf.ThreadPoolExecutor(6) as ex:
        for n, s in ex.map(fai, nomi):
            print(n, s, flush=True)

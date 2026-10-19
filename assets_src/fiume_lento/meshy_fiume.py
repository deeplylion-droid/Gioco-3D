"""Modelli Meshy del fiume lento (proposte d'aspetto del 19 ottobre, squadra enigma-ambiente).

Uso: python3 assets_src/fiume_lento/meshy_fiume.py [nomi...]
Per ogni modello: preview (meshy-7.1, remesh) + refine con PBR, GLB in assets_src/fiume_lento/meshy/.
"""
import json, os, sys, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, 'meshy')

MODELLI = {
    # --- comuni ---
    'ciambella': dict(
        prompt='Single-person lazy river inner tube from a 1990s water park: thick heavy vinyl donut ring with a '
               'molded seat bottom and two grab handles, about 1.2 m wide. Realistic.',
        texture='Faded turquoise and yellow vinyl, sun-bleached, scuffed and dirty, water stains, a peeling '
                'water park logo sticker, slightly deflated wrinkles.', polycount=20000),
    'paratia': dict(
        prompt='Large industrial water channel sluice gate: a thick riveted steel panel 3 m wide and 1.6 m tall '
               'hinged on a heavy vertical steel post with a big pivot collar and gear housing on top, like a '
               'swinging canal gate. Realistic.',
        texture='Safety yellow and black chevron stripes painted on steel, chipped, rust streaks, algae and '
                'limescale at the bottom, wet and grimy.', polycount=30000),
    'lampada_emergenza': dict(
        prompt='Industrial emergency floodlight lamp on a wall bracket: a rectangular cast metal housing with a '
               'thick glass lens and protective wire grille, tilting bracket. Realistic.',
        texture='Faded red painted metal housing, chipped, rust, dirty glass lens.', polycount=12000),
    'scaletta_banchina': dict(
        prompt='Stainless steel pool ladder with three wide steps and two curved handrails going up over the edge '
               'of a concrete quay, mounted to the side wall. Realistic.',
        texture='Dull stainless steel with limescale, rust spots at the joints, grimy anti-slip treads.',
        polycount=15000),
    'tornello_imbarco': dict(
        prompt='Water park ride boarding station podium: a small fiberglass attendant booth with a slanted '
               'control desk, big round push buttons and a dome warning light on top. Realistic.',
        texture='Faded teal and white fiberglass, sun-bleached, cracked gel coat, dirt, peeling stickers, '
                'red and green buttons.', polycount=20000),
    'transenna': dict(
        prompt='Water park queue railing section: a 2 m long galvanized steel tube barrier with two posts and '
               'two horizontal rails, posts with round floor flanges. Realistic.',
        texture='Galvanized steel tubes, faded, rust spots, limescale, a little peeling blue paint.',
        polycount=8000),
    # --- aspetto A: giungla finta ---
    'roccia_parete': dict(
        prompt='Large themed artificial rock wall panel for an indoor water park lazy river, sculpted fiberglass '
               'and concrete rock, 4 m wide and 4 m tall, layered rocky ledges and cracks, flat back. Realistic.',
        texture='Painted fake rock in faded ochre, brown and grey, with peeling paint showing white fiberglass, '
                'green algae streaks and water stains near the bottom, dirty and wet.', polycount=40000),
    'palma_finta': dict(
        prompt='Artificial plastic palm tree for an indoor water park, 4 m tall, ribbed trunk made of stacked '
               'brown plastic segments, drooping plastic fronds, set in a round concrete planter. Realistic.',
        texture='Faded plastic, the green fronds sun-bleached and dusty, some fronds torn, brown plastic trunk, '
                'grimy concrete planter.', polycount=30000),
    'totem_tiki': dict(
        prompt='Carved tiki totem pole decoration from a 1990s water park, 2.5 m tall, three stacked grinning '
               'faces with big eyes and open mouths. Realistic.',
        texture='Faded painted fiberglass imitating wood, bright orange, teal and yellow paint chipped, mold '
                'stains, cracks, grime.', polycount=25000),
    'capanna_tiki': dict(
        prompt='Small tiki hut kiosk from a 1990s water park lazy river: bamboo posts, a thatched straw roof, '
               'a small wooden counter, 2.5 m wide. Realistic.',
        texture='Faded artificial straw thatch, sun-bleached bamboo, peeling paint, mold and grime, damp.',
        polycount=30000),
    # --- aspetto B: viaggio sottomarino ---
    'pesce_vetroresina': dict(
        prompt='Large cartoon fiberglass fish decoration from a 1990s water park, 2 m long, big friendly eyes and '
               'smiling mouth, mounted on a short steel bracket. Realistic.',
        texture='Faded bright orange and white fiberglass, chipped paint, cracks, algae stains, grime, wet.',
        polycount=20000),
    'palombaro': dict(
        prompt='Vintage brass deep sea diving helmet decoration statue, 1 m tall, on a riveted base, round '
               'portholes with grilles. Realistic.',
        texture='Tarnished brass and copper with green patina, dirty glass portholes, rust on the bolts.',
        polycount=25000),
    'tartaruga': dict(
        prompt='Cartoon fiberglass sea turtle decoration from a 1990s water park, 1.8 m long, swimming pose, '
               'smiling face. Realistic.',
        texture='Faded green and yellow fiberglass, chipped paint, cracks, algae and limescale, grime.',
        polycount=20000),
}


def fai(nome):
    m = MODELLI[nome]
    glb = os.path.join(OUT, nome + '.glb')
    if os.path.exists(glb):
        return nome, 'già fatto'
    pid = meshy.create('text-to-3d', dict(mode='preview', prompt=m['prompt'], ai_model='meshy-7.1',
                                          should_remesh=True, topology='triangle',
                                          target_polycount=m['polycount'], target_formats=['glb']))
    t = meshy.wait('text-to-3d', pid)
    if t['status'] != 'SUCCEEDED':
        return nome, 'preview fallita: %s' % t.get('task_error')
    rid = meshy.create('text-to-3d', dict(mode='refine', preview_task_id=pid, enable_pbr=True,
                                          texture_prompt=m['texture'], texture_resolution='2k',
                                          target_formats=['glb']))
    t = meshy.wait('text-to-3d', rid)
    if t['status'] != 'SUCCEEDED':
        return nome, 'refine fallita: %s' % t.get('task_error')
    meshy.download(t['model_urls']['glb'], glb)
    if t.get('thumbnail_url'):
        meshy.download(t['thumbnail_url'], os.path.join(OUT, nome + '_anteprima.png'))
    with open(os.path.join(OUT, nome + '.json'), 'w') as f:
        json.dump(dict(preview=pid, refine=rid, prompt=m['prompt'], texture=m['texture']), f, indent=1)
    return nome, 'ok'


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    nomi = sys.argv[1:] or list(MODELLI)
    with cf.ThreadPoolExecutor(6) as ex:
        for nome, esito in ex.map(fai, nomi):
            print(nome, esito, flush=True)
    print(meshy.balance())

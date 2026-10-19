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
    # --- riempimento (richiesta del coordinatore del 19 ottobre: stanze piene da subito) ---
    'bocchetta': dict(
        prompt='Lazy river wall current jet nozzle: a round stainless steel grille 40 cm wide with a central '
               'nozzle, set in a square tiled wall plate. Realistic.',
        texture='Stainless steel with heavy limescale crust, green algae, rust streaks running down.', polycount=8000),
    'griglia_scolo': dict(
        prompt='Rectangular pool deck drain grate, 1 m long and 25 cm wide, slotted plastic grating in a '
               'channel frame. Realistic.', texture='Dirty white plastic grate, limescale, black grime, leaves stuck.',
        polycount=6000),
    'altoparlante': dict(
        prompt='Outdoor public address horn loudspeaker on a wall bracket with a cable hanging down. Realistic.',
        texture='Faded grey painted metal horn, rust, dirt, black cable.', polycount=8000),
    'salvagente': dict(
        prompt='Ring life buoy hanging on a short wooden post with a hook and a coiled rope. Realistic.',
        texture='Faded orange and white ring buoy, dirty, frayed rope, weathered wooden post.', polycount=10000),
    'ciabatta': dict(
        prompt='A single child flip-flop sandal lying on the ground, small. Realistic.',
        texture='Faded pink rubber flip-flop, dirty, worn.', polycount=3000),
    'paperella': dict(prompt='Classic yellow rubber duck toy, 12 cm. Realistic.',
                      texture='Faded yellow rubber, dirty, orange beak, slightly moldy.', polycount=3000),
    'secchiello': dict(
        prompt='Child beach toy bucket with a handle and a small spade lying beside it. Realistic.',
        texture='Faded blue and red plastic, scratched, dirty, sun-bleached.', polycount=5000),
    'pallone': dict(prompt='Half-deflated inflatable beach ball, crumpled, 40 cm. Realistic.',
                    texture='Faded colored panels red yellow blue white, dirty, wrinkled vinyl.', polycount=5000),
    'detriti': dict(
        prompt='Small pile of debris on a floor: crushed plastic cups, a soda can, wrappers, dead leaves and '
               'pieces of broken plastic, 60 cm wide, flat. Realistic.',
        texture='Faded dirty plastic, brown dead leaves, rusty can, grime.', polycount=10000),
    'lampada_capannone': dict(
        prompt='Industrial high-bay pendant lamp: a wide enamel reflector dome hanging from a chain, 50 cm wide. '
               'Realistic.', texture='Faded green enamel outside, white inside, rust, dust, dirty glass bulb.',
        polycount=8000),
    # A: giungla finta
    'liane': dict(
        prompt='Bundle of artificial plastic jungle vines hanging down, 2.5 m long, with leaves, attached to a '
               'small bracket at the top. Realistic.', texture='Faded green plastic leaves and brown vines, dusty, '
               'some leaves bleached and torn.', polycount=20000),
    'fiori': dict(
        prompt='Artificial tropical plant in a fiberglass rock planter: big leaves and red hibiscus flowers, '
               '1 m tall. Realistic.', texture='Faded plastic leaves and flowers, dusty, grimy planter.',
        polycount=20000),
    'maschera_tiki': dict(
        prompt='Large carved tiki mask wall decoration, 80 cm tall, angry face with big teeth. Realistic.',
        texture='Faded painted fiberglass imitating wood, orange teal and yellow, chipped, moldy.', polycount=12000),
    'corrimano_bambu': dict(
        prompt='Bamboo handrail fence section, 2 m long and 1 m tall, bamboo posts tied with rope. Realistic.',
        texture='Faded fake bamboo, sun-bleached, frayed rope ties, grime.', polycount=10000),
    'pappagallo': dict(
        prompt='Fiberglass parrot statue perched on a branch stand, 1 m tall, cartoon water park style. '
               'Realistic.', texture='Faded red blue and yellow paint, chipped, cracked, dirty.', polycount=15000),
    'scimmia': dict(
        prompt='Fiberglass cartoon monkey statue sitting and waving, 1 m tall, water park decoration. Realistic.',
        texture='Faded brown and beige paint, chipped, cracked, algae stains.', polycount=15000),
    'tettoia_paglia': dict(
        prompt='Large thatched straw roof canopy on four bamboo poles over a ride boarding area, 4 m wide and '
               '3 m long, 3 m tall. Realistic.', texture='Faded artificial straw thatch, holes, mold, grimy '
               'bamboo poles.', polycount=30000),
    'ponte_corda': dict(
        prompt='Rope suspension footbridge 5 m long with wooden plank deck and rope handrails, slight sag, '
               'jungle themed. Realistic.', texture='Weathered wooden planks, frayed ropes, grime, a few planks '
               'missing.', polycount=25000),
    # B: viaggio sottomarino
    'corallo': dict(
        prompt='Large fiberglass coral reef decoration cluster, 1.2 m tall, branching corals and sea fans. '
               'Realistic.', texture='Faded pink, orange and purple paint, chipped, limescale, algae.',
        polycount=20000),
    'ancora': dict(prompt='Old ship anchor decoration, 1.5 m tall, with a chain. Realistic.',
                   texture='Painted black iron with heavy rust and limescale.', polycount=10000),
    'forziere': dict(
        prompt='Pirate treasure chest decoration, half open, 80 cm wide, fake gold coins inside. Realistic.',
        texture='Faded fiberglass wood with brass bands, chipped gold paint, grime.', polycount=15000),
    'rete_stelle': dict(
        prompt='Fishing net hanging on a wall with several starfish and shells caught in it, 2 m wide. '
               'Realistic.', texture='Brown frayed net, faded orange starfish and white shells, dusty.',
        polycount=20000),
    'portello': dict(
        prompt='Round submarine hatch door with a big handwheel in the center, riveted steel frame, set in a '
               'flat wall panel, 1.9 m tall. Realistic.', texture='Painted steel, faded grey-green, rust, '
               'brass wheel with patina.', polycount=15000),
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

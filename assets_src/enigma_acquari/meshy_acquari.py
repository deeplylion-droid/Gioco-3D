"""Modelli Meshy dell'enigma degli acquari (proposta del 18 ottobre, squadra enigma-ambiente).

Uso: python3 assets_src/enigma_acquari/meshy_acquari.py [nomi...]
Per ogni modello: preview (meshy-7.1, remesh) + refine con PBR, GLB in assets_src/enigma_acquari/meshy/.
Il vetro e l'acqua NON li fa Meshy: si tolgono/aggiungono in Blender e in Godot.
"""
import json, os, sys, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, 'meshy')

MODELLI = {
    # Stile A: vasca rettangolare con telaio di metallo verniciato da acquapark anni '90.
    'vasca_telaio': dict(
        prompt='Empty steel frame of a large rectangular 1990s water park display aquarium on a sturdy '
               'cabinet base. Thick square steel tube frame posts and top rim, painted faded teal with '
               'yellow trim, rivets and bolts, cabinet base with a small access hatch and vent grille. '
               'The frame is open: no glass panes, no water, see-through between the posts. Realistic.',
        texture='Faded teal and yellow enamel paint on steel, chipped and peeling, rust streaks running '
                'down from bolts, limescale and grime, damp and dirty, abandoned indoor water park.',
        polycount=40000),
    # Stile B: grande cilindro di vetro con base e coperchio di acciaio, tubi e manometri.
    'cilindro_tubi': dict(
        prompt='Tall industrial water tank made of a clear glass cylinder between a heavy round riveted '
               'steel base and a round steel top cap, four thin vertical steel tie rods around the glass, '
               'pipes and a small valve coming out of the base, two round pressure gauges with dials on '
               'the base, 1990s water park machinery. Realistic.',
        texture='Faded red painted steel, chipped paint, rust, brass gauges with dirty glass dials, '
                'limescale, grime, damp and dirty, abandoned indoor water park machinery.',
        polycount=40000),
    # Stile B, secondo tentativo: il primo (cilindro_tubi) è venuto un boiler pieno, senza vetro.
    # Come per il telaio A, si chiede solo la struttura aperta: il vetro lo mettiamo noi.
    'cilindro_gabbia': dict(
        prompt='Open steel cage frame for a tall cylindrical glass water tank, 1990s water park machinery: '
               'a heavy round riveted steel base drum 40 cm tall with pipes, a small valve and two round '
               'pressure gauges on its side, a round steel top ring with a pipe elbow, and four vertical '
               'steel tie rods connecting base and top ring. Empty in the middle: no glass, no cylinder, '
               'see-through between the rods. Realistic.',
        texture='Faded red painted steel, chipped paint, rust, brass gauges with dirty glass dials, '
                'limescale, grime, damp and dirty, abandoned indoor water park machinery.',
        polycount=40000),
    # Stile A, l'acquario del miscuglio: basso e largo (il bordo a 0,8 m, perché la lancia tenuta in
    # basso non versa più su; vincolo di enigma-logica, 18 ottobre).
    'vasca_bassa': dict(
        prompt='Empty steel frame of a low wide rectangular 1990s water park display basin, 2.2 m wide, '
               '1.2 m deep, only 0.8 m tall: thick square steel tube corner posts and a sturdy top rim, a '
               'solid low base band 30 cm tall with rivets and a small vent grille, a round flanged pipe '
               'outlet in the middle of the front base band. Open top. The frame is open: no glass panes, '
               'no water, see-through between the posts above the base band. Realistic.',
        texture='Faded teal and yellow enamel paint on steel, chipped and peeling, rust streaks running '
                'down from bolts, limescale and grime, damp and dirty, abandoned indoor water park.',
        polycount=30000),
    # Stile A: il basamento sotto la vasca, perché la valvola rossa stia davvero sotto l'acquario.
    'basamento_vasca': dict(
        prompt='Low heavy rectangular steel equipment plinth, 2 m wide, 1 m deep, 0.5 m tall, flat top, '
               'riveted steel side panels with a thick bolted rim on top and a recessed kick plate at the '
               'bottom, a round flanged pipe outlet in the middle of the front panel. Realistic.',
        texture='Faded teal enamel paint on steel with a yellow trim stripe along the top rim, chipped and '
                'peeling, rust streaks from bolts and rivets, limescale and grime, damp and dirty, '
                'abandoned indoor water park.',
        polycount=25000),
    # La valvola da colpire col getto, sotto l'acquario del miscuglio.
    'valvola_rossa': dict(
        prompt='Large industrial gate valve with a big round spoked handwheel, cast iron valve body on a '
               'short thick flanged pipe with bolts, handwheel 60 cm wide. Realistic.',
        texture='Bright red glossy paint on the handwheel and valve body, chipped edges showing dark iron, '
                'light rust, wet and grimy.',
        polycount=20000),
    # Le lampade del portone (versione a gabbia).
    'lampada_gabbia': dict(
        prompt='Industrial caged bulkhead wall lamp: a round glass globe with a light bulb inside a '
               'protective metal wire cage, cast iron wall mount bracket. Realistic.',
        texture='Yellow painted cast iron, chipped paint and rust, dirty frosted glass globe, '
                'grimy metal cage.',
        polycount=15000),
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
    with cf.ThreadPoolExecutor(4) as ex:
        for nome, esito in ex.map(fai, nomi):
            print(nome, esito, flush=True)
    print(meshy.balance())

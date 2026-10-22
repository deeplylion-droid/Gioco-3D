"""Modelli Meshy dei due lettori della keycard (proposte del 19 ottobre, squadra enigma-ambiente).

Uso: python3 assets_src/tessera/meshy_tessera.py [nomi...]
Per ogni modello: preview (meshy-7.1, remesh) + refine con PBR, GLB in assets_src/tessera/meshy/.
"""
import json, os, sys, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, 'meshy')

MODELLI = {
    'lettore_1': dict(
        prompt='1990s magnetic card swipe reader mounted on a wall, rectangular beige plastic housing 20 cm tall '
               'and 9 cm wide, a vertical swipe slot channel along its right side, a small round LED window at the '
               'top, four screws, a conduit pipe going down from the bottom. Realistic.',
        texture='Yellowed beige ABS plastic, grimy and scratched, dark slot channel, clear LED window, dirty '
                'metal conduit.', polycount=8000),
    'lettore_2': dict(
        prompt='Industrial heavy-duty access control card reader in a stainless steel weatherproof wall housing '
               '18 cm tall with a small rain hood on top, a flat square black reading pad in the middle framed by '
               'a thin ring, an armored cable going down. Realistic.',
        texture='Brushed stainless steel with limescale and grime, black glossy reading pad, rusty screws.',
        polycount=8000),
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

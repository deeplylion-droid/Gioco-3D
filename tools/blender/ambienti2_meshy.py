"""Genera con Meshy (text-to-3D, preview + refine con PBR) i pochi oggetti di arredo degli ambienti tecnici.

Uso: MESHY_API_KEY=... python3 tools/blender/ambienti2_meshy.py
I GLB grezzi finiscono in assets_src/ambienti_tecnici/meshy/<nome>.glb; ripulitura e scala le fa
ambienti2_sala_pompe.py quando li importa. Se un file esiste già, non lo rigenera.
"""
import json, os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import meshy

DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets_src', 'ambienti_tecnici', 'meshy')

OGGETTI = {
    'monitor_crt': 'old 1990s CRT computer monitor, bulky beige plastic case yellowed and dirty, curved glass screen, '
                   'small buttons under the screen, realistic, worn, scratched',
    'scrivania': 'old industrial steel office desk with three drawers on the right side, chipped grey-green paint, '
                 'rust stains, dented, realistic, 1990s maintenance room',
    'sedia': 'old broken office swivel chair, torn dark vinyl seat, rusty five-star metal base with wheels, realistic, abandoned',
}


def attendi(path):
    while True:
        t = meshy._req('GET', path)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            return t
        time.sleep(10)


def genera(nome, prompt):
    out = os.path.join(DEST, nome + '.glb')
    if os.path.exists(out):
        return
    pid = meshy._req('POST', '/v2/text-to-3d', {
        'mode': 'preview', 'prompt': prompt, 'ai_model': 'meshy-7.1', 'should_remesh': True,
        'target_polycount': 20000, 'topology': 'triangle'})['result']
    t = attendi(f'/v2/text-to-3d/{pid}')
    print(nome, 'preview', t['status'], flush=True)
    rid = meshy._req('POST', '/v2/text-to-3d', {
        'mode': 'refine', 'preview_task_id': pid, 'enable_pbr': True,
        'texture_prompt': prompt})['result']
    t = attendi(f'/v2/text-to-3d/{rid}')
    print(nome, 'refine', t['status'], flush=True)
    if t['status'] == 'SUCCEEDED':
        meshy.download(t['model_urls']['glb'], out)
        with open(os.path.join(DEST, nome + '.json'), 'w') as f:
            json.dump({'prompt': prompt, 'preview_task': pid, 'refine_task': rid}, f, indent=1)


if __name__ == '__main__':
    os.makedirs(DEST, exist_ok=True)
    import threading
    th = [threading.Thread(target=genera, args=kv) for kv in OGGETTI.items()]
    [x.start() for x in th]; [x.join() for x in th]

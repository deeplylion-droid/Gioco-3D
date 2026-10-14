"""Genera le texture dei cartelloni con Meshy image-to-image (uso interno: diventano texture nel gioco).
Uso: python3 genera_poster.py <nome>   (vedi POSTER qui sotto). Salva <nome>.png e <nome>.json con il task."""
import base64, json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
CONCEPT = os.path.join(QUI, '../../../docs/concept')

def data_uri(p):
    return 'data:image/jpeg;base64,' + base64.b64encode(open(p, 'rb').read()).decode()

NO_TEXT = ('Absolutely no text, no letters, no words, no numbers, no logo, no signature anywhere in the image.')
POSTER = {
    # grande cartellone del corridoio: la mascotte come cartone animato
    'cartellone_medusa': dict(refs=['medusa_statua.jpg'], aspect='3:4', prompt=(
        'Redraw this exact mascot character as a cheerful 1990s children\'s waterpark poster illustration: '
        'flat 2D cartoon style with thick dark outlines and bright saturated colors, like a Saturday morning cartoon. '
        'A cute jellyfish girl mascot with ONE single big eye with a pink iris in the middle of her face, '
        'short wavy silver-pink hair, periwinkle-blue smooth body, a translucent lilac jellyfish bell skirt with glowing '
        'radial stripes and long wavy magenta tentacles. She smiles with a small closed mouth and waves one hand, '
        'floating happily among bubbles, stylized ocean waves, starfish and little fish, sunny yellow and turquoise '
        'background with a big rainbow arc. Full body, centered, poster composition with a simple border. ' + NO_TEXT)),
    # piccolo cartello con pittogrammi (niente scritte) per spogliatoi e stanzino
    'cartello_regole': dict(refs=[], aspect='3:4', prompt=(
        'A 1990s swimming pool safety rules sign made only of pictograms: a grid of six round icons with simple white '
        'silhouettes on blue and red circles (no running, no diving, shower before swimming, no glass bottles, '
        'lifeguard whistle, children with adult). Flat vector print style on a white plastic board with a blue border. '
        'Front view, the sign fills the whole image. ' + NO_TEXT)),
    'poster_bagnino': dict(refs=['medusa_statua.jpg'], aspect='3:4', prompt=(
        'Cheerful 1990s kids waterpark poster, flat 2D cartoon with thick outlines: the one-eyed jellyfish girl mascot '
        '(one big pink-iris eye, short wavy silver-pink hair, periwinkle skin, lilac jellyfish bell and magenta tentacles) '
        'wearing a red lifeguard cap and a whistle, giving a thumbs up next to an orange life ring and a cartoon dolphin, '
        'turquoise water and bubbles background. ' + NO_TEXT)),
}

if __name__ == '__main__':
    nome = sys.argv[1]; p = POSTER[nome]
    if p['refs']:
        body = dict(ai_model='nano-banana-pro', prompt=p['prompt'], aspect_ratio=p['aspect'],
                    reference_image_urls=[data_uri(os.path.join(CONCEPT, r)) for r in p['refs']])
        kind = 'image-to-image'
    else:
        body = dict(ai_model='nano-banana-pro', prompt=p['prompt'], aspect_ratio=p['aspect'])
        kind = 'text-to-image'
    tid = meshy.create(kind, body)
    t = meshy.wait(kind, tid)
    json.dump({k: t.get(k) for k in ('id', 'status', 'prompt', 'ai_model', 'task_error')}, open(os.path.join(QUI, nome + '.json'), 'w'), indent=1)
    if t['status'] != 'SUCCEEDED':
        sys.exit(f'{nome}: {t["status"]} {t.get("task_error")}')
    meshy.download(t['image_urls'][0], os.path.join(QUI, nome + '.png'))
    print('ok', nome)

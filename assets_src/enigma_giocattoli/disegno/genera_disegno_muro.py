"""Il disegno a pastello dei bambini sul muro ovest della parte profonda (indizio dell'enigma dei giocattoli, accordo
del 28 ottobre): Meshy image-to-image ridisegna lo schema (schema_disegno.png, posizioni giuste) come un disegno a cera
di un bambino su carta bianca, nello stile del disegno degli acquari. Immagine generata, usata solo come texture
(decal). Poi scontorna.py toglie la carta (trasparenza) e la salva in godot/assets/models/enigma_giocattoli/.
Uso: python3 genera_disegno_muro.py <nome> ["prompt in più"]"""
import base64, os, sys, time
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '..', '..', '..', 'tools'))
import meshy

PROMPT = ('Redraw this layout as a real child\'s wax crayon drawing made by a 7 year old on plain white paper, scanned '
          'flat, keeping every shape exactly where it is and the same size: a swimming pool seen from straight above, '
          'outlined in dark blue crayon, the left part coloured medium blue with crayon strokes, the middle light '
          'blue with a few wavy lines, the right end pale beige sand. The grey square is a metal trapdoor with a cross of '
          'bolts. Inside the yellow circle a yellow rubber duck, inside the red circle a solid red ball, inside the blue '
          'circle a blue whale; each circle coloured in solid with its crayon colour, with a thick pale green ring all around it, and the toy drawn on it with a dark '
          'outline. Uneven crayon strokes, colouring outside the lines, white paper all around the pool. No words, no '
          'letters, no numbers, no people.')

if __name__ == '__main__':
    nome = sys.argv[1]
    prompt = PROMPT + (' ' + sys.argv[2] if len(sys.argv) > 2 else '')
    dati = base64.b64encode(open(os.path.join(QUI, 'schema_disegno.png'), 'rb').read()).decode()
    tid = meshy._req('POST', '/v1/image-to-image', dict(ai_model='nano-banana-2', prompt=prompt, aspect_ratio='4:3',
                                                         reference_image_urls=['data:image/png;base64,' + dati]))['result']
    while True:
        t = meshy._req('GET', '/v1/image-to-image/' + tid)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            break
        time.sleep(4)
    print(t['status'], t.get('task_error'), t.get('consumed_credits'))
    meshy.download(t['image_urls'][0], os.path.join(QUI, nome + '.png'))

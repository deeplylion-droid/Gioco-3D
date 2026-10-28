"""Texture del disegno a pastello dei bambini per la parete della parte fonda (indizio dell'enigma dei giocattoli,
28 ottobre), nello stesso stile del disegno degli acquari (assets_src/enigma_acquari/disegno/genera_disegno.py):
immagine generata, usata solo come texture sul foglio. La piscina vista dall'alto, coi tre giocattoli ognuno nel suo
cerchio: la parte fonda in alto, il cerchio rosso con la palla in alto al centro, il giallo con la paperella in basso
a sinistra, il blu con la balena in basso a destra. Uso: python3 genera_disegno.py <nome> ["prompt in più"]"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
import meshy

PROMPT = ('A real child\'s wax crayon drawing on a sheet of slightly yellowed paper, scanned flat, full sheet filling '
          'the frame, portrait. Drawn clumsily by a 7 year old: a big swimming pool seen from straight above, a large '
          'rounded rectangle outlined in dark blue and coloured light blue with heavy crayon strokes and a few wavy '
          'lines for the water. Inside the pool three big round circles drawn with thick crayon: a red circle at the top '
          'in the middle with a red ball inside it, a yellow circle at the bottom left with a yellow rubber duck inside '
          'it, a blue circle at the bottom right with a blue whale inside it. Each toy sits inside its own circle of the '
          'same colour. Crayon texture, uneven strokes, colouring outside the lines, no words, no letters, no numbers, '
          'no people.')

if __name__ == '__main__':
    nome = sys.argv[1]
    prompt = PROMPT + (' ' + sys.argv[2] if len(sys.argv) > 2 else '')
    tid = meshy._req('POST', '/v1/text-to-image', dict(ai_model='nano-banana-2', prompt=prompt,
                                                        aspect_ratio='3:4'))['result']
    while True:
        t = meshy._req('GET', '/v1/text-to-image/' + tid)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            break
        time.sleep(4)
    print(t['status'], t.get('task_error'), t.get('consumed_credits'))
    meshy.download(t['image_urls'][0], os.path.join(os.path.dirname(os.path.abspath(__file__)), nome + '.png'))

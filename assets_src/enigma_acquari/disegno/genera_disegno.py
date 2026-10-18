"""Texture del disegno a pastello dei bambini (indizio dell'enigma): immagine generata, usata solo
come texture sul foglio. Uso: python3 genera_disegno.py <nome> ["prompt in più"]"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
import meshy

PROMPT = ('A real child\'s wax crayon drawing on a sheet of slightly yellowed paper, scanned flat, full '
          'sheet filling the frame. Drawn clumsily by a 7 year old: two yellow beach buckets and one blue '
          'beach bucket in a row at the top, with thick plus signs between them, a big arrow pointing down '
          'to a large rectangular aquarium tank coloured bright saturated grass green with heavy crayon '
          'strokes, a tiny smiling pink jellyfish next to it. Crayon texture, uneven strokes, colouring '
          'outside the lines, no words, no letters, no numbers.')

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

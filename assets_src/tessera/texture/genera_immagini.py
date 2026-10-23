"""Facce delle due keycard (nano-banana-2 di Meshy, 6 crediti l'una): solo uso interno come texture.
Uso: python3 genera_immagini.py [nomi...]"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
IMMAGINI = {
    'tessera_1': ('16:9', 'Flat front view of a 1990s water park staff ID card filling the whole image, credit card '
                  'proportions with rounded corners: white plastic with a turquoise and blue wave band at the top, a '
                  'small square photo of a smiling staff member with blurred face on the left, a black magnetic '
                  'stripe along the bottom, a pictogram of a water slide, no text, no letters, no numbers, worn and '
                  'scratched, slightly dirty.'),
    'tessera_2': ('16:9', 'Flat front view of an access keycard filling the whole image, credit card proportions with '
                  'rounded corners: glossy orange plastic, a gold contact chip on the left, a large white pictogram '
                  'of a key inside a circle on the right, a slot punch hole at the top edge, no text, no letters, no '
                  'numbers, worn and scratched.'),
}


def fai(nome):
    ar, prompt = IMMAGINI[nome]
    tid = meshy._req('POST', '/v1/text-to-image', dict(ai_model='nano-banana-2', prompt=prompt, aspect_ratio=ar))['result']
    while True:
        t = meshy._req('GET', '/v1/text-to-image/' + tid)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            break
        time.sleep(4)
    print(nome, t['status'])
    if t['status'] == 'SUCCEEDED':
        meshy.download(t['image_urls'][0], os.path.join(QUI, nome + '_grezza.png'))


if __name__ == '__main__':
    for n in sys.argv[1:] or list(IMMAGINI):
        fai(n)

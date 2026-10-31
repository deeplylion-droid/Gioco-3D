"""Il cartello a disegni del corridoio del fiume (scelta A+C dell'utente, 30 ottobre): verso il fiume lento, un'onda,
una ciambella e una freccia (niente scritte). Immagine generata, usata solo come texture, come i cartelli del fiume
(assets_src/fiume_lento/texture/genera_texture.py).
Uso: python3 genera_cartello.py [genera] [ritaglia]"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
QUI = os.path.dirname(os.path.abspath(__file__))
PROMPT = ('Flat front view of a square water park direction sign filling the whole image: blue background, white '
          'pictograms of three wavy water lines with a swim ring (inner tube) floating on them, and below a big bold '
          'white arrow pointing to the left, simple bold shapes, ISO style, no text, no letters, no numbers, faded '
          'and slightly dirty, scratched enamel with small rust spots at the four screw holes in the corners.')


def genera():
    import meshy
    tid = meshy._req('POST', '/v1/text-to-image', dict(ai_model='nano-banana-2', prompt=PROMPT, aspect_ratio='1:1'))['result']
    while True:
        t = meshy._req('GET', '/v1/text-to-image/' + tid)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            break
        time.sleep(4)
    print(t['status'], t.get('consumed_credits'))
    meshy.download(t['image_urls'][0], os.path.join(QUI, 'cartello_fiume_grezzo.png'))


def ritaglia(box=None):
    from PIL import Image
    im = Image.open(os.path.join(QUI, 'cartello_fiume_grezzo.png')).convert('RGB')
    if box:
        im = im.crop(box)
    im.resize((512, 512), Image.LANCZOS).save(os.path.join(QUI, 'cartello_fiume.jpg'), quality=90)


if __name__ == '__main__':
    if 'genera' in sys.argv:
        genera()
    if 'ritaglia' in sys.argv:
        ritaglia((134, 126, 900, 904))

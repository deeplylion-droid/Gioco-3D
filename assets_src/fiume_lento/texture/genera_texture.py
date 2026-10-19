"""Texture del fiume lento: il cartello d'uscita d'emergenza (immagine generata, usata solo come
texture) e il disco a strisce del bersaglio delle paratie (disegnato qui).
Uso: python3 genera_texture.py [uscita] [disco]"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
QUI = os.path.dirname(os.path.abspath(__file__))


def uscita():
    import meshy
    prompt = ('Flat front view of an illuminated emergency exit sign panel, ISO 7010 style: bright green '
              'background, white pictogram of a running man going through a doorway, with a white arrow pointing '
              'right, simple bold shapes, no text, no letters, rectangular 2:1 sign filling the whole image, '
              'slightly dirty plastic diffuser.')
    tid = meshy._req('POST', '/v1/text-to-image', dict(ai_model='nano-banana-2', prompt=prompt, aspect_ratio='16:9'))['result']
    while True:
        t = meshy._req('GET', '/v1/text-to-image/' + tid)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            break
        time.sleep(4)
    print(t['status'], t.get('consumed_credits'))
    meshy.download(t['image_urls'][0], os.path.join(QUI, 'uscita_grezza.png'))


def disco():
    # disco a spicchi rossi e bianchi (come i bersagli di sicurezza), 1024 px, con sporco
    import numpy as np
    from PIL import Image, ImageFilter
    n = 1024
    y, x = np.mgrid[0:n, 0:n] - n / 2 + 0.5
    ang = np.arctan2(y, x)
    r = np.hypot(x, y) / (n / 2)
    spicchi = (np.floor((ang + np.pi) / (np.pi / 4)) % 2).astype(bool)
    rgb = np.where(spicchi[..., None], [235, 230, 220], [205, 30, 25]).astype(np.float32)
    rgb[r > 0.93] = [40, 40, 40]          # bordo nero
    rgb[r < 0.12] = [40, 40, 40]          # mozzo
    rng = np.random.default_rng(7)
    sporco = Image.fromarray((rng.random((64, 64)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    s = np.asarray(sporco, np.float32)[..., None] / 255.0
    rgb = rgb * (0.78 + 0.22 * s) - 18 * (r[..., None] ** 3)
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(QUI, 'disco_strisce.jpg'), quality=92)


if __name__ == '__main__':
    cosa = sys.argv[1:] or ['uscita', 'disco']
    if 'disco' in cosa:
        disco()
    if 'uscita' in cosa:
        uscita()

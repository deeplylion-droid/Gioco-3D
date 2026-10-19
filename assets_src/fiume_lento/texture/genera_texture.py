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


def pittogrammi():
    # due cartelli di sicurezza a pittogrammi del fiume lento (niente testo), per i pali sulle banchine
    import meshy
    prompts = {
        'cartello_tuffi': 'Flat front view of a square water park safety sign filling the whole image: white '
                          'background, thick red circle with diagonal bar over a black pictogram of a person diving '
                          'head first, a second smaller blue panel below with a pictogram of a person sitting in an '
                          'inner tube, no text, no letters, faded, slightly dirty and scratched.',
        'cartello_bimbi': 'Flat front view of a square water park safety sign filling the whole image: blue '
                          'background with white pictograms of an adult holding the hand of a small child next to '
                          'an inner tube on water, no text, no letters, faded by the sun, scratched.',
    }
    for nome, prompt in prompts.items():
        tid = meshy._req('POST', '/v1/text-to-image', dict(ai_model='nano-banana-2', prompt=prompt, aspect_ratio='1:1'))['result']
        while True:
            t = meshy._req('GET', '/v1/text-to-image/' + tid)
            if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
                break
            time.sleep(4)
        print(nome, t['status'])
        meshy.download(t['image_urls'][0], os.path.join(QUI, nome + '_grezza.png'))


def pittogrammi_ritaglio():
    from PIL import Image
    for nome, box in {'cartello_tuffi': (112, 98, 918, 918), 'cartello_bimbi': (88, 86, 934, 934)}.items():
        Image.open(os.path.join(QUI, nome + '_grezza.png')).convert('RGB').crop(box).resize((512, 512), Image.LANCZOS) \
            .save(os.path.join(QUI, nome + '.jpg'), quality=90)


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




def linea_calcare():
    # la riga di calcare e alghe sulla parete del canale, sul pelo dell'acqua: in basso (sott'acqua)
    # verde scuro, sopra una fascia bianca di calcare che sfuma, con macchie e colature (PNG con alfa)
    import numpy as np
    from PIL import Image, ImageFilter
    w, h = 2048, 256
    rng = np.random.default_rng(11)
    def rumore(sx, sy, blur):
        im = Image.fromarray((rng.random((sy, sx)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        return np.asarray(im.filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255.0
    y = np.linspace(0.0, 1.0, h)[:, None].repeat(w, 1)       # 0 in alto, 1 in basso (il pelo a 0,7)
    n1, n2, n3 = rumore(256, 16, 3), rumore(64, 8, 6), rumore(512, 4, 2)
    pelo = 0.7 + (n2 - 0.5) * 0.12
    alghe = np.clip((y - pelo) * 8.0, 0, 1)
    calcare = np.clip(1.0 - np.abs(y - (pelo - 0.12)) / (0.14 + n1 * 0.12), 0, 1) * (0.55 + 0.45 * n1)
    colature = np.clip((n3 - 0.62) * 6.0, 0, 1) * np.clip((pelo - y) * 3.0, 0, 1) * np.clip(1.0 - (pelo - y) * 2.2, 0, 1)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    col_calc = np.array([0.86, 0.84, 0.76])
    col_alghe = np.array([0.16, 0.22, 0.1]) * (0.7 + 0.6 * n1[..., None])
    col_col = np.array([0.45, 0.33, 0.18])
    a_calc = np.clip(calcare * 0.8, 0, 1)
    a_col = colature * 0.5
    a_alg = alghe * (0.6 + 0.3 * n2)
    for c, aa in ((col_col, a_col), (col_calc, a_calc), (col_alghe, a_alg)):
        rgb = rgb * (1 - aa[..., None]) + c * aa[..., None]
        a = a + aa * (1 - a)
    out = np.dstack([rgb, a]) * 255.0
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(QUI, 'linea_calcare.png'))


if __name__ == '__main__':
    cosa = sys.argv[1:] or ['uscita', 'disco']
    if 'disco' in cosa:
        disco()
    if 'uscita' in cosa:
        uscita()
    if 'pittogrammi' in cosa:
        pittogrammi()
    if 'pittogrammi_ritaglio' in cosa:
        pittogrammi_ritaglio()
    if 'linea_calcare' in cosa:
        linea_calcare()

"""Immagini grezze per le texture dell'infermeria (nano-banana-2 di Meshy, 6 crediti l'una): solo uso
interno come texture, non si mostrano all'utente. Uso: python3 genera_immagini.py [nomi...]"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
IMMAGINI = {
    'radiografia_grezza': ('3:4', 'Veterinary X-ray radiograph film of a whole young lamb lying on its side, full skeleton '
                           'visible from head to tail: skull, spine, ribs, four legs, short tail, bluish-white bones '
                           'on a black background, soft grey body outline, dark film border, no text, no letters, '
                           'no markers, the lamb fills the film, head on the left and tail on the right.'),
    'agnello_icona': ('1:1', 'Simple flat icon: solid white silhouette of a standing lamb in side view facing left, '
                      'round fluffy body, small head with ear, four thin legs and a short tail, on a pure black '
                      'background, centered, no text, no outline, no shading.'),
    'polaroid_medico': ('1:1', 'Faded 1990s Polaroid snapshot photo taken with flash in a small first-aid room: a '
                        'middle-aged male doctor in a white coat, face turned away and blurred, standing next to a '
                        'grey four-drawer metal filing cabinet; the third drawer has a bright pink round sticker '
                        'on it. Overexposed flash, warm color cast, grainy, no text.'),
    'polaroid_medico_B': ('1:1', 'Faded 1990s Polaroid snapshot photo taken with flash in a children\'s infirmary with '
                          'pastel mint green walls: a middle-aged male doctor in a white coat, face turned away and '
                          'blurred, standing next to a pastel pink four-drawer metal filing cabinet; the third drawer '
                          'has a bright pink round sticker on it. Overexposed flash, warm color cast, grainy, no text.'),
    'decalcomanie': ('16:9', 'Set of five separate cute flat cartoon wall decal stickers for a children\'s room, pastel '
                     'colors: a smiling blue whale, a yellow starfish, an orange fish, a pink seahorse, a green sea '
                     'turtle. Simple vector shapes with thick outlines, evenly spaced, not overlapping, on a pure '
                     'white background, no text.'),
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
        meshy.download(t['image_urls'][0], os.path.join(QUI, nome + '.png'))


if __name__ == '__main__':
    for n in sys.argv[1:] or list(IMMAGINI):
        fai(n)

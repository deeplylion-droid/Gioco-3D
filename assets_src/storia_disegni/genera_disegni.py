"""I disegni del bambino con la scatola (build 0.5.0, «La storia», GDD del 15 novembre, righe «Build 2»): sei fogli a
pastello a cera, nella stessa mano dei due che ci sono già (assets_src/enigma_acquari/disegno/genera_disegno.py e
assets_src/enigma_giocattoli/disegno/genera_disegno.py): stesso modello (Meshy text-to-image, nano-banana-2, 3:4),
stesse frasi d'apertura e di chiusura del prompt. Solo disegni, niente lettere né numeri. Immagini generate, usate solo
come texture sui fogli.

Codici fissi in tutti i fogli: TU = omino stilizzato arancione; LEI = medusa rosa che sorride (come negli acquari);
SQUALO = grigio coi denti; LA SCIALUPPA = barchetta arancione su onde blu; il bambino con la scatola = omino con la testa
quadrata turchese; l'agnellino = bianco con un occhio solo. La firma (un quadratino turchese con un sorriso) è una
immagine sola, messa via codice in basso a destra su tutti gli otto fogli (firma.py).

Uso: python3 genera_disegni.py <id> [variante]   (id: D1 D2 DF D3 D4 DZ FIRMA, o «tutti»)
"""
import os, sys, time, threading
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
import meshy

QUI = os.path.dirname(os.path.abspath(__file__))
APERTURA = ('A real child\'s wax crayon drawing on a sheet of slightly yellowed paper, scanned flat, full sheet filling '
            'the frame, portrait. Drawn clumsily by a 7 year old: ')
CHIUSURA = (' Crayon texture, uneven strokes, colouring outside the lines, no words, no letters, no numbers.')
OMINO = 'a small orange stick figure person (drawn in orange crayon)'
MEDUSA = 'a pink jellyfish with a happy smiling face and wavy tentacles'
BARCA = 'a little orange boat on wavy blue water'

SCENE = {
    'D1': (f'{OMINO} at the bottom of the sheet, a big thick arrow drawn in blue crayon going from the stick figure up '
           f'towards the top of the sheet, and at the top {BARCA}. Lots of empty paper around, very simple.'),
    'D2': (f'in the lower middle an open swimming pool seen from straight above, a big rounded rectangle outlined in '
           f'dark blue and coloured light blue with heavy crayon strokes and a few wavy lines for the water, no walls, '
           f'no glass. Inside the water {MEDUSA}. {OMINO} stands at the bottom left corner of the sheet. One single '
           f'dashed orange line with ONLY ONE arrowhead: it starts at the stick figure, goes up along the left side of '
           f'the sheet, curves across above the pool far from its edge, and ends with its one arrowhead at the foot of '
           f'a simple ladder standing on the right side of the sheet, well away from the pool. The ladder goes up, and '
           f'at the top of the sheet, small, {BARCA}.'),
    'DF': (f'a lazy river drawn as a big blue ring loop seen from above. {OMINO} sits on a green swim ring floating on '
           f'the river. Behind the swim ring a grey shark fin sticks out of the water and a grey shark mouth with big '
           f'white pointy teeth. From the stick figure short blue dashes go backwards towards the shark, like a water '
           f'spray.'),
    'D3': (f'a tall water slide tower with colourful twisting tubes (red, yellow, green, blue) going round it. {OMINO} '
           f'climbs up the tower, a big arrow points up to the top, and at the very top, small, {BARCA}.'),
    'D4': (f'a long tube tunnel drawn across the sheet. {OMINO} runs along the tunnel and sprays blue water dashes '
           f'backwards. Behind him, very big, {MEDUSA} following him. At the far end of the tunnel a round door, and '
           f'beyond the round door {BARCA}.'),
    'DZ': (f'a row of seven simple stick figures standing on the ground, side by side, not touching each other. In the '
           f'middle {OMINO}, a plain stick figure exactly like a simple drawing of a grown-up, the TALLEST of all. The '
           f'other six are small children, simple stick figures: one with a square turquoise head with a smile, one '
           f'small child standing upright on two legs wearing a white curly lamb hood costume with one single big eye, '
           f'and four more children in red, green, purple and blue crayon. Above all of them a very big {MEDUSA}; each '
           f'of her long wavy tentacles comes down to one figure, and every figure raises one arm up to hold the tip of '
           f'a tentacle, like children holding their mother\'s hand; the tall orange stick figure holds one too. No '
           f'boat.'),
    'FIRMA': ('only one tiny thing in the middle of the blank sheet: a small square drawn and coloured in turquoise '
              'crayon with a simple smiling face inside it, like a little smiling box. The rest of the sheet is empty '
              'paper.'),
}


def _a_jpg(png: str) -> None:
    """I grezzi si tengono in JPG di buona qualità (regola dei concept: niente PNG grandi)."""
    from PIL import Image
    Image.open(png).convert('RGB').save(png[:-4] + '.jpg', quality=95)
    os.remove(png)


def genera(id: str, variante: str = 'v1') -> None:
    prompt = APERTURA + SCENE[id] + CHIUSURA
    tid = meshy._req('POST', '/v1/text-to-image', dict(ai_model='nano-banana-2', prompt=prompt,
                                                        aspect_ratio='3:4'))['result']
    while True:
        t = meshy._req('GET', '/v1/text-to-image/' + tid)
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            break
        time.sleep(4)
    print(id, variante, t['status'], t.get('task_error'), t.get('consumed_credits'), flush=True)
    if t['status'] == 'SUCCEEDED':
        os.makedirs(os.path.join(QUI, 'grezzi'), exist_ok=True)
        meshy.download(t['image_urls'][0], os.path.join(QUI, 'grezzi', f'{id}_{variante}.png'))
        _a_jpg(os.path.join(QUI, 'grezzi', f'{id}_{variante}.png'))


if __name__ == '__main__':
    ids = list(SCENE) if sys.argv[1] == 'tutti' else sys.argv[1].split(',')
    varianti = sys.argv[2].split(',') if len(sys.argv) > 2 else ['v1']
    fili = [threading.Thread(target=genera, args=(i, v)) for i in ids for v in varianti]
    for f in fili:
        f.start()
    for f in fili:
        f.join()

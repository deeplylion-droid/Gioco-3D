"""Il nome della medusa, JILLY JUBILEE: loghi e grafiche (texture) generati con Meshy.

Uso: python assets_src/mascotte/jilly_meshy.py <job> [...] | --list
Usa la stessa macchina di meshy_mascotte.py (log in meshy_log.json, uscite in gen/jilly/).
Le immagini servono solo come texture dei modelli 3D (targa, manifesto, insegna): all'utente si
mostrano solo i render e gli scatti dal motore.
"""
import os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault('MASCOTTE_OUT', os.path.join(QUI, 'gen', 'jilly'))
sys.path.insert(0, QUI)
import meshy_mascotte as M  # noqa: E402

M.JOBS.clear()
MEDUSA = 'docs/concept/medusa_turnaround.jpg'
NOME = ('The text reads exactly "JILLY JUBILEE" (two words, spelled J-I-L-L-Y  J-U-B-I-L-E-E), '
        'and no other text at all. ')
PIATTO = (' Flat graphic design, centered, on a plain flat white background, no mockup, no photo, '
          'no perspective, no shadows on the background, no watermark.')

# Stile A: lettering "a bolle" da acquapark anni '90, la i col puntino a forma dell'occhio di Jilly.
LOGO_A = (
    'A 1990s water park mascot logo: big puffy rounded bubble letters, glossy like inflatable pool '
    'toys, in a gradient from pink to lavender with a thick white outline and a dark purple drop '
    'shadow, small water bubbles and a few splash drops around, a wavy aqua water line under the '
    'letters. The dots of the letter i are drawn as a single big round eye with a pink iris (like '
    'the one-eyed jellyfish mascot in the reference image). Playful, colorful, toyetic, '
    'like a 1995 theme park sign. ' + NOME)
# Stile B: varietà da nave da crociera, "Jilly" in corsivo sopra "JUBILEE" in stampatello su un nastro.
LOGO_B = (
    'A 1990s cruise ship showbiz logo: the word "Jilly" in a big flowing retro brush script with a '
    'coral-pink fill and a navy blue outline, above the word "JUBILEE" in bold condensed capital '
    'letters in gold on a navy blue ribbon banner with curled ends, a few gold stars and a small '
    'stylized pink jellyfish bell with tentacles beside the script. Elegant variety show '
    'marquee style, like a 1994 cruise entertainment program. ' + NOME)
for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
    M.img(f'logo_a_{tag}', m, LOGO_A + PIATTO, [MEDUSA], aspect='16:9')
    M.img(f'logo_b_{tag}', m, LOGO_B + PIATTO, [MEDUSA], aspect='16:9')

# Manifesti dello spettacolo: Jilly com'è nel turnaround approvato, col logo scelto (A o B).
MANIFESTO = (
    'A 1990s cruise ship water park show poster, portrait format, printed offset look with halftone '
    'dots. In the middle the cartoon mascot from the first reference image, exactly the same design: '
    'a slender one-eyed jellyfish girl with periwinkle-blue skin, a single big eye with a pink iris, '
    'short wavy silver-pink hair, a translucent glowing jellyfish bell skirt and magenta tentacles, '
    'smiling and waving, on a bright underwater stage with spotlights, bubbles and confetti. At the '
    'top the logo exactly as in the second reference image. At the bottom, in simple bold capital '
    'letters, the only other text: "LIVE SHOW" and below it "EVERY DAY 11 AM & 4 PM". No other text, '
    'no small print, no logos of real companies. Flat poster, full frame, no wall, no mockup.')
for _l in ('a', 'b'):
    for m, tag in (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt')):
        M.img(f'manifesto_{_l}_{tag}', m, MANIFESTO, [MEDUSA, f'@logo_{_l}_gpt'], aspect='2:3' if tag == 'gpt' else '3:4')

if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] == '--list':
        print('\n'.join(M.JOBS))
    else:
        M.main(sys.argv[1:])

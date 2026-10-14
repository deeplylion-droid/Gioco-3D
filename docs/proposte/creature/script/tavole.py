"""Tavole delle proposte per i bambini-creature: personaggio + scena affiancati, con etichetta grande.

Rigenera le tre tavole a partire dalle immagini in ../singole/:
    /home/user/tools/blender-venv/bin/python docs/proposte/creature/script/tavole.py

Le immagini singole sono state generate con Meshy (tools/meshy.py, modello gpt-image-2-5-flare, scelte tra
quelle fatte anche con nano-banana-pro). In fondo al file ci sono i prompt usati e come è nata ogni immagine.
"""
import os
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.abspath(__file__))
CARTELLA = os.path.dirname(QUI)
SINGOLE = os.path.join(CARTELLA, 'singole')

TAVOLE = [
    # numero, sottotitolo, personaggio, scena, didascalia sinistra, didascalia destra, file di uscita
    (1, 'Ancora bambini, selvatici', 'opzione1_personaggi.jpg', 'opzione1_scena.jpg', 'Due di loro',
     "Di sfuggita: ti osserva dall'alto della torre degli scivoli", 'opzione1_ancora_bambini.jpg'),
    (2, 'Cresciuti dalla medusa', 'opzione2_personaggio.jpg', 'opzione2_scena.jpg', 'Il personaggio',
     'Di sfuggita: attraversa a quattro zampe il fondo di un corridoio', 'opzione2_cresciuti_dalla_medusa.jpg'),
    (3, 'Toccati dal mostro', 'opzione3_personaggio.jpg', 'opzione3_scena.jpg', 'Il personaggio',
     'Di sfuggita: sbircia da dietro gli armadietti', 'opzione3_toccati_dal_mostro.jpg'),
]

H = 1280      # altezza dei due pannelli
M = 44        # margini
HEAD = 330    # fascia dell'etichetta
CAP = 140     # fascia delle didascalie
BG = (14, 14, 17)


def font(nome, size):
    for p in (f'/usr/share/fonts/opentype/inter/Inter-{nome}.otf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size)


def alla_altezza(path, h):
    im = Image.open(path).convert('RGB')
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def tavola(num, sottotitolo, personaggio, scena, cap_l, cap_r, uscita):
    c = alla_altezza(os.path.join(SINGOLE, personaggio), H)
    s = alla_altezza(os.path.join(SINGOLE, scena), H)
    W = M + c.width + M + s.width + M
    im = Image.new('RGB', (W, HEAD + H + CAP + M // 2), BG)
    im.paste(c, (M, HEAD))
    im.paste(s, (M + c.width + M, HEAD))
    d = ImageDraw.Draw(im)

    def adatta(testo, max_w, size=80):
        # la didascalia più grande possibile che sta nella larghezza del pannello
        while size > 40 and d.textlength(testo, font=font('SemiBold', size)) > max_w:
            size -= 2
        return font('SemiBold', size)

    etichetta = f'Opzione {num}'
    f_big = font('ExtraBold', 210)
    d.text((M, HEAD // 2), etichetta, font=f_big, fill=(255, 255, 255), anchor='lm')
    x = M + d.textlength(etichetta, font=f_big) + 70
    d.text((x, HEAD // 2 + 8), sottotitolo, font=font('SemiBold', 112), fill=(255, 130, 175), anchor='lm')
    cy = HEAD + H + CAP // 2
    d.text((M + c.width / 2, cy), cap_l, font=adatta(cap_l, c.width - 40), fill=(200, 200, 205), anchor='mm')
    d.text((M + c.width + M + s.width / 2, cy), cap_r, font=adatta(cap_r, s.width - 40), fill=(200, 200, 205),
           anchor='mm')
    out = os.path.join(CARTELLA, uscita)
    im.save(out, quality=90, subsampling=0, optimize=True)
    print(out, im.size)


# --- Prompt usati (Meshy text-to-image / image-to-image) ------------------------------------------------
STYLE = ("Photorealistic cinematic 3D render, like a high-end Unreal Engine 5 video game, dark and moody, "
         "for a first-person mascot horror game in the spirit of Poppy Playtime, set in the abandoned indoor "
         "water park of a shipwrecked 1990s family cruise ship.")
SAFE = ("The character is fully clothed, with modest clothes that cover the body. It is creepy only because of the "
        "posture, the mask, the eyes and the silhouette: no gore, no blood, no wounds, no injuries, no violence, "
        "nothing sexual. No text, no letters, no numbers, no logos and no writing anywhere in the image.")
CONCEPT = ("Full-body character concept, the whole figure visible from head to feet with some space around it, "
           "three-quarter front view, standing on wet dark tiles in front of a plain dark grey studio backdrop "
           "with a little low fog, soft cold key light and a red emergency-light rim light from behind.")
SCENE = ("First-person view at eye level of a player standing in the abandoned indoor water park of a 1990s cruise "
         "ship at night: red emergency lights, a flickering fluorescent tube, low fog over wet reflective tiles, rust "
         "and peeling paint, a big glass dome above with a stormy sea and lightning outside, faded colorful water "
         "slides and a few bright saturated pool toys (rubber duck, beach ball, inflatable rings) scattered on the "
         "floor. Realistic and dark, like a frame from the game. The figure is glimpsed for a moment, small in the "
         "frame and partly hidden, but its silhouette is readable.")
I2I = ("Use the attached image as the reference for the location, the lighting, the colors and the art style. "
       "Create a new image of the same abandoned water park at night, seen from a different spot. Any signs and "
       "posters show only pictures of sea animals, with no writing at all.")
TWO = ("The first image is the reference for the location, the lighting, the colors and the art style. The second "
       "image is the character design: keep the same character, with the same clothes, mask or face, hair and body. "
       "Create a new image of the same abandoned water park at night. Any signs and posters show only pictures of "
       "sea animals, with no writing at all.")

D1 = ("A small, skinny feral child, about 8 years old, who has survived alone for a long time on the shipwrecked "
      "cruise ship. Very pale skin, long wet dark hair hanging in strings over the shoulders. Wears a worn-out "
      "faded 1990s swimsuit with neon geometric patterns under a far too big faded teal staff polo shirt (plain, "
      "without any logo or writing) that reaches the knees, a battered faded orange 1990s life vest buckled on "
      "top, and old mismatched pool sandals. The face is completely hidden by a homemade mask cut from a pool toy: "
      "the head of a faded yellow inflatable duck, cut open at the neck and worn over the head like a helmet, with "
      "two small dark eye holes cut out, patched with duct tape and crude stitches. Thin pale hands, one dragging "
      "a deflated swim ring. Stands perfectly still, slightly hunched, head tilted to one side, staring at the viewer.")
C1B = ("Use the attached image as the reference for the art style, the lighting and the backdrop. Keep this child "
       "exactly as it is, in front, and add a second small feral child of about 7 standing half a step behind, holding "
       "the hem of the first child's shirt: very pale skin, long wet dark hair, an oversized faded 1990s swimsuit and a "
       "worn yellow inflatable armband on one arm, an old long-sleeved faded staff shirt, barefoot. The second child's "
       "face is hidden by an old children's snorkel diving mask whose glass has been painted over with one single huge "
       "eye with a white sclera and a pink iris, like the one-eyed jellyfish mascot that raised them. Both children "
       "stand perfectly still and stare at the viewer. Both figures fully visible from head to feet.")
EDIT1 = ("Keep this image exactly the same: same two children, same poses, same masks, same lighting, same dark "
         "backdrop and wet tiles. Change only the clothes of the smaller child on the right: the swimsuit is no "
         "longer visible. The smaller child now wears the long oversized faded grey-teal long-sleeved shirt closed "
         "and buttoned, reaching below the knees, over long baggy faded 1990s board shorts with neon geometric "
         "patterns that reach the shins, still barefoot, with the yellow inflatable armband on one arm and the "
         "snorkel diving mask painted with one single huge eye with a pink iris. No writing on any clothes.")
S1 = ("First-person view at eye level from the wet floor near the empty pool, looking up at the rusty water slide "
      "tower a few meters away. On the top platform of the tower, behind the railing and under a red emergency light, "
      "the child from the second image stands perfectly still and watches the player, head tilted to one side: the "
      "cut-off yellow inflatable duck head mask with its two dark eye holes, the oversized faded teal shirt and the "
      "orange life vest are clearly readable even though the child is small in the frame and half lost in the fog.")

D2 = ("A feral teenager of about 15 who grew up wild for years on the shipwrecked cruise ship, raised by a sea "
      "monster. Tall and gaunt, with unnaturally long thin arms and legs and long bony fingers, crouching low on all "
      "fours on the wet tiles like an animal ready to run, head raised, staring at the viewer. Long tangled hair "
      "bleached almost white by chlorine. Wears loose, baggy patchwork clothes that cover the whole body, crudely "
      "stitched together from pieces of faded 1990s swimsuits, cut inflatable swim rings, water wing armbands, scraps "
      "of orange life jackets and a striped pool towel, tied with a piece of floating pool lane rope; long sleeves "
      "and long trousers. The face is painted pale lavender-blue like a doll, with one single huge round eye painted "
      "in the middle of the face, white with a bright pink iris, imitating the one-eyed jellyfish mascot that raised them.")
S2 = ("First-person view at eye level down a long, narrow service corridor of the water park, seen straight on in "
      "one-point perspective: wet tiles, rusty lockers along one wall, a flickering fluorescent tube, low fog and a red "
      "emergency light at the far end. Far away at the end of the corridor, the character from the second image is "
      "crossing from one side to the other on all fours, very fast, and has frozen for an instant in the middle of a "
      "step with its long thin limbs bent like a spider, head turned toward the player: the single huge painted eye "
      "with the pink iris catches the light. The figure is small in the frame and half lost in the red fog, glimpsed "
      "for a split second, but its silhouette and the painted eye are readable.")

D3 = ("A small child of about 9 who survived the shipwreck and has been slowly changed by the sea monster that "
      "raised them, part human and part jellyfish. Wears an oversized faded 1990s swim T-shirt with bright neon "
      "zigzag patterns (no writing) and long faded board shorts, barefoot. On the cheeks, the neck and the backs of "
      "the hands the skin turns into smooth translucent jelly, glassy and slightly see-through like a real jellyfish, "
      "with faint glowing pink lines inside: eerie and beautiful, not wounds. Tiny glowing magenta dots are sprinkled "
      "across the face and arms like bioluminescent freckles. Some locks of the wet dark hair are thin translucent "
      "magenta tentacle strands that hang down and curl slightly. Big dark eyes that reflect the light with a bright "
      "pale eyeshine, like a cat's eyes caught in a flashlight in the dark. Stands perfectly still, head lowered, "
      "staring up at the viewer, hands half hidden in the too-long sleeves.")
S3 = ("About six meters away, a row of rusty lockers stands along the wall of the pool hall, deep in shadow. From "
      "behind the last locker a small child peeks out: only half of the face and one hand are visible. The eyes "
      "shine with a bright eyeshine reflecting the light, tiny glowing magenta dots glow on the cheek and on the "
      "fingers, a thin translucent magenta tentacle-like lock of hair hangs over the face, and the sleeve of an old "
      "faded 1990s neon swim T-shirt shows. Red emergency light, wet floor, fog.")

COME = {
    'opzione1_personaggi.jpg': ['text-to-image 3:4: CONCEPT + D1 + STYLE + SAFE (un solo bambino)',
                                'image-to-image 3:4 da quella: C1B + STYLE + SAFE (aggiunge il secondo bambino)',
                                'image-to-image 3:4 da quella: EDIT1 + SAFE (secondo bambino tutto coperto)'],
    'opzione1_scena.jpg': ['image-to-image 16:9, riferimenti [docs/concept/ambiente_A_realistico.jpg, il concept con '
                           'un solo bambino]: TWO + S1 + STYLE + SAFE'],
    'opzione2_personaggio.jpg': ['text-to-image 3:4: CONCEPT + D2 + STYLE + SAFE'],
    'opzione2_scena.jpg': ['image-to-image 16:9, riferimenti [ambiente_A_realistico.jpg, opzione2_personaggio]: '
                           'TWO + S2 + STYLE + SAFE'],
    'opzione3_personaggio.jpg': ['text-to-image 3:4: CONCEPT + D3 + STYLE + SAFE'],
    'opzione3_scena.jpg': ['image-to-image 16:9, riferimento ambiente_A_realistico.jpg: I2I + SCENE + S3 + SAFE'],
}

if __name__ == '__main__':
    for t in TAVOLE:
        tavola(*t)

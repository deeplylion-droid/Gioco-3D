"""Polaroid del capitolo 1: generazione delle foto con Meshy (text-to-image e image-to-image).

Uso:
    python tools/blender/polaroid_meshy.py <job> [<job> ...]   # lancia i job in parallelo
    python tools/blender/polaroid_meshy.py --list               # elenca i job

Ogni job produce una sola immagine: $POLAROID_OUT/<job>.png (default ./polaroid_out).
I job delle foto esistono in due versioni, una per modello: P07_nbp (nano-banana-pro) e
P07_gpt (gpt-image-2-5-flare). Si guardano tutte e due e si tiene la migliore.
I riferimenti sono immagini del repository oppure '@<job>', l'uscita di un job precedente.
Si passano come data URI, ridotti a 1280 px. Ogni task (id, modello, prompt, riferimenti)
viene registrato in assets_src/polaroid/meshy_log.json, così ogni foto si può rigenerare.

Ordine: prima il cast dei bambini (cast97_*), poi la sua versione cresciuta (castdopo_*),
poi le foto P01-P10, che usano come riferimento il cast scelto (copiato in
assets_src/polaroid/riferimenti/).
"""
import base64, io, json, os, sys, threading, time

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import meshy  # noqa: E402

OUT = os.environ.get('POLAROID_OUT', os.path.join(os.getcwd(), 'polaroid_out'))
LOG = os.path.join(REPO, 'assets_src', 'polaroid', 'meshy_log.json')
_lock = threading.Lock()

C = 'docs/concept/'
STATUA, GIRO, SOTTO, SBIRCIA = (C + 'medusa_statua.jpg', C + 'medusa_turnaround.jpg',
                                C + 'medusa_sottacqua.jpg', C + 'medusa_sbircia.jpg')
AMB_A, AMB_B, AMB_C = C + 'ambiente_A_realistico.jpg', C + 'ambiente_B_colorato.jpg', C + 'ambiente_C_anni90.jpg'
RIF = 'assets_src/polaroid/riferimenti/'
CAST97, CASTDOPO = RIF + 'cast_1997.jpg', RIF + 'cast_dopo.jpg'

MODELLI = (('nano-banana-pro', 'nbp'), ('gpt-image-2-5-flare', 'gpt'))
JOBS = {}


def job(name, model, prompt, refs=(), aspect='1:1'):
    JOBS[name] = dict(model=model, prompt=' '.join(prompt.split()), refs=list(refs), aspect=aspect)


# ---------------------------------------------------------------- blocchi di prompt
VIETATO = (
    'Absolutely no text, letters, numbers, logos, captions, name labels or writing anywhere in the '
    'image: no words on signs, no words or letters on clothes. No blood, no wounds, no violence. '
    'Everyone is fully clothed.')

FOTO = (
    'An authentic amateur instant photograph taken in 1997 with a Polaroid 600 camera, square format. '
    'Direct on-camera flash that brightens the nearest subjects and falls off quickly into the '
    'background, slightly soft focus, a little motion blur, typical instant-film colors: cyan-green '
    'shadows, warm creamy faded highlights, slightly milky blacks, visible film grain, a few dust '
    'specks. The photo fills the entire square frame edge to edge: do not draw the white Polaroid '
    'border, a frame, a table or hands holding it, only the picture itself. ')

BAMBINI = [
    'the tallest girl, 11, with long straight auburn-red hair in one thick braid over her shoulder '
    'and freckles, in a teal T-shirt with a purple and yellow 1990s squiggle pattern and black '
    'knee-length shorts',
    'a boy, 10, with dark brown skin, short black hair and round black sports glasses with an elastic '
    'strap, in a long-sleeve swim shirt with yellow and black horizontal stripes and black swim shorts',
    'a boy, 9, with light brown skin and dark hair, wearing a red baseball cap backwards, in a navy '
    'blue T-shirt with white stripes on the sleeves and grey shorts',
    'a Black girl, 10, with two big round afro puffs tied with yellow hair ties, in a purple T-shirt '
    'with neon orange and turquoise color-block panels and purple shorts',
    'a boy, 9, with a blond bowl haircut and a sunburnt nose, in a lime-green T-shirt with a cartoon '
    'shark printed on the front and red swim shorts',
    'an East Asian girl, 8, with black hair in two high pigtails tied with neon pink scrunchies, in a '
    'pink-and-white striped long-sleeve swim shirt and white shorts',
    'a small boy, 7, with dark skin, a very short buzzcut and a gap-toothed smile, in an oversized '
    'white T-shirt with a small blue cartoon whale, wearing bright orange inflatable armbands',
    'the smallest girl, 6, with curly light-blonde hair, in a yellow T-shirt with a big white daisy '
    'and pink jelly sandals, hugging a small white plush lamb toy',
]

CAST97_TXT = (
    'Reference photograph of a group of eight children for a film set in 1997: a casting line-up. '
    'They stand side by side in one straight row, full body from head to toe, all facing the camera '
    'with relaxed arms and shy natural smiles, on the wet tiled deck of a cruise ship\'s indoor water '
    'park in daytime, in front of a plain pale blue painted wall. Soft even light, sharp focus, '
    'realistic photograph, every face clearly visible, authentic 1997 clothes and haircuts, '
    'barefoot or in sandals. From left to right: ' +
    '; '.join(f'{["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"][i]}, {b}'
              for i, b in enumerate(BAMBINI)) + '. ')

CASTDOPO_TXT = (
    'The same eight children as in the reference image, in the same order from left to right, in the '
    'same full-body line-up in front of the same wall, but about four years later, after years of '
    'living alone in a dark abandoned shipwrecked cruise ship. Now they are 10 to 15 years old, '
    'taller and very thin, with pale skin that never sees the sun, dark circles under the eyes, '
    'long tangled salt-stiff hair, barefoot, with wild, watchful, feral expressions. Each one still '
    'wears the same clothes and colors as in the reference, now faded, torn, too small and patched '
    'with pieces of towel and rope, and most of them wear dirty, frayed orange ship life jackets over '
    'them. Same distinctive details as before: the auburn-red braid (now very long and messy), the '
    'round sports glasses (one lens cracked, held with tape), the red cap worn backwards (faded '
    'pink), the two afro puffs (bigger and wilder), the bowl haircut grown out into a shaggy blond '
    'mop, the two pigtails with the old pink scrunchies, the orange armbands (now patched), and the '
    'smallest girl now wears her old white plush lamb, cut open and stitched into a hood over her '
    'curly hair, with the lamb\'s floppy ears and button eyes on top of her head. The blond boy holds '
    'under his arm a white cube box mask with a simple smiley face drawn in black marker. The wall is '
    'now dirty and peeling, lit by a harsh camera flash in a dark room. ')

MEDUSA_STATUA = (
    'The water park mascot statue is exactly the one in the reference image of the statue: a '
    'life-size glossy vinyl statue of a cute one-eyed jellyfish girl, with a smooth periwinkle-blue '
    'mannequin-like doll torso without any anatomical details, hands clasped on her chest, a single '
    'huge eye with a pink iris in the middle of the face and no mouth, short wavy silver-pink hair '
    'with a little loop of hair on top, and from the waist down a translucent pink-violet jellyfish '
    'bell with radial channels and long glossy magenta tentacles reaching down to a round blue '
    'pedestal painted with waves and shells. ')

MEDUSA_VIVA = (
    'The mascot is now alive, the same character as in the reference images of the jellyfish girl: '
    'a smooth pale periwinkle-blue vinyl-doll body like a mannequin, without any anatomical details, '
    'long wet wavy silver-pink hair, a single huge eye with a bright pink iris in the middle of her '
    'face and no visible mouth, and from the waist down a translucent jellyfish bell glowing pink '
    'and violet from within with luminous radial channels, trailing many long magenta tentacles. ')

STESSI97 = (
    'The children are the eight children of the first reference image, with the same faces, hair, '
    'clothes and colors: ' + '; '.join(BAMBINI) + '. ')

STESSIDOPO = (
    'The children are the same children of the first reference image, years after the shipwreck: '
    '10 to 15 years old, thin and pale, long tangled hair, barefoot, in torn faded versions of their '
    'old T-shirts and swim shirts and dirty orange life jackets, recognizable by the auburn-red braid, '
    'the round taped sports glasses, the faded backwards cap, the afro puffs, the shaggy blond mop, '
    'the pigtails with pink scrunchies. ')

# ---------------------------------------------------------------- cast
for m, tag in MODELLI:
    for k in (1, 2):
        job(f'cast97_{tag}{k}', m, CAST97_TXT + VIETATO, aspect='16:9')

# il cast cresciuto parte dal cast 1997 scelto
for m, tag in MODELLI:
    job(f'castdopo_{tag}', m, CASTDOPO_TXT + VIETATO, [CAST97], aspect='16:9')

# secondo giro: nel primo sono selvatici ma non sembrano cresciuti; GPT ha rifiutato il primo prompt
CRESCIUTI = (
    'Important: they must look clearly older than in the reference, a head taller with longer arms '
    'and legs and older faces: the tallest girl now looks 15, the smallest girl now looks 10. ')
job('castdopo_nbp2', 'nano-banana-pro', CASTDOPO_TXT + CRESCIUTI + VIETATO, [CAST97], aspect='16:9')
job('castdopo_gpt2', 'gpt-image-2-5-flare', (
    'The same eight children as in the reference image, in the same order from left to right, in the '
    'same full-body line-up, but four years later, as castaways who have lived for years on an old '
    'drifting cruise ship: now they are 10 to 15 years old, taller and thinner, a little pale, with '
    'long untidy sun-bleached hair and serious, quiet faces, barefoot. Each one wears the same '
    'clothes and colors as in the reference, now faded, worn, patched and a bit too small, and most '
    'of them wear faded orange ship life jackets. Same details as before: the auburn braid (longer), '
    'the round sports glasses mended with tape, the backwards red cap (faded), the two afro puffs, '
    'the blond bowl cut grown out, the pigtails with pink scrunchies, the orange armbands, and the '
    'smallest girl wears her old white plush lamb sewn into a hood with floppy ears. The blond boy '
    'holds a white cardboard cube mask with a simple smiley face drawn in marker. Dim room, flash '
    'photo. ' + CRESCIUTI + VIETATO), [CAST97], aspect='16:9')

# ---------------------------------------------------------------- le 10 foto
FOTO_P = {}

FOTO_P['P01'] = ([CAST97, STATUA, GIRO, AMB_B], (
    'A happy family snapshot at the entrance of the indoor water park of a 1990s family cruise ship, '
    'on the first day of the cruise. A smiling mother with permed brown hair in a floral summer dress '
    'and a father with a moustache in a bright Hawaiian shirt pose with their two children from the '
    'first reference image: the blond boy with the bowl haircut in the lime-green shark T-shirt and '
    'red swim shorts, and the smallest girl with curly light-blonde hair in the yellow daisy T-shirt, '
    'hugging her small white plush lamb. Behind them, above the colorful entrance arch, a big painted '
    'billboard shows the water park mascot as a cute smiling cartoon drawing: the one-eyed jellyfish '
    'girl of the other reference images (single huge pink eye, short wavy silver-pink hair with a '
    'little loop on top, periwinkle skin, a pink-violet jellyfish bell and magenta tentacles), drawn '
    'as a friendly cartoon, waving, on a sea-blue background with bubbles and starfish. The billboard '
    'has no words and no letters at all, only the drawing. Clean, brand-new, cheerful colors, '
    'turnstiles, potted palms, a glass dome with blue sky. '))

FOTO_P['P02'] = ([CAST97, STATUA, AMB_B], (
    'Bright daytime inside the brand-new indoor water park of a family cruise ship, under a glass dome '
    'with blue sky. The eight children of the first reference image stand in a cheerful line in front '
    'of the water park mascot statue and wave at it, some wearing colorful kids\' life vests over '
    'their T-shirts. ' + MEDUSA_STATUA + 'The statue is brand new, spotless and shiny, its bell '
    'channels softly lit, and a huge red satin ribbon bow is tied around the pedestal for the '
    'inauguration. Behind them colorful slides, palm plants, turquoise water and a few blurry '
    'parents. ' + STESSI97))

FOTO_P['P03'] = ([CAST97, STATUA, AMB_C], (
    'Group photo of a children\'s swimming class in the indoor water park of a family cruise ship, '
    'posing by the pool edge with their two lifeguard instructors. The eight children of the first '
    'reference image stand in two rows, the smaller ones kneeling in front, holding colorful foam '
    'kickboards and pool noodles, smiling; the two lifeguards, a young man with a whistle and a young '
    'woman with a sun visor, stand at the back in plain red polo shirts with no print at all. Daylight '
    'from the glass dome, turquoise water, pastel slides in the background and, far behind them, '
    'small, the mascot statue of the second reference image on its round blue pedestal. ' + STESSI97))

FOTO_P['P04'] = ([CAST97, AMB_B, AMB_A], (
    'The night of the shipwreck, in the indoor water park of the cruise ship of the reference images. '
    'The eight children of the first reference image, soaked and terrified, huddle together at the '
    'very top of the colorful children\'s play structure, right under the giant tipping bucket, '
    'wearing big orange adult life jackets over their T-shirts, clutching each other and the '
    'railings. All around and below them there is only dark churning flood water reaching the '
    'platforms, with floating toys and debris, rain and sea spray pouring through the broken glass '
    'dome, and red emergency lights glowing in the darkness. The flash lights the wet frightened '
    'faces in the foreground, everything else falls into red-black darkness. Recognizable children: '
    'the auburn-red braid, the round sports glasses, the backwards red cap, the afro puffs, the blond '
    'bowl cut, the pigtails with pink scrunchies, the orange armbands, the smallest curly-blonde girl '
    'hugging her white plush lamb. '))

FOTO_P['P05'] = ([CAST97, AMB_B, STATUA], (
    'The empty wave pool of the abandoned indoor water park of the reference images, photographed '
    'from the pool edge looking down into the deep end, some weeks after the shipwreck. The dry, '
    'cracked tiled pool floor with the faded compass-rose mosaic has become a children\'s camp: '
    'colorful inflatable mattresses and pool floats arranged in a circle, ship blankets and beach '
    'towels, pillows, a small camping lantern, rows of plain unlabeled tin cans, plastic bottles of '
    'water, toys, a rope with small T-shirts hung to dry. No adults anywhere. Two children of the '
    'first reference image sleep curled up under the blankets: the smallest curly-blonde girl hugging '
    'her white plush lamb, and the small boy with the orange armbands. Grey stormy light from the '
    'glass dome, deep shadows, red emergency lights at the edges. At the very top of the frame, on the '
    'pool rim above the camp, stands the round blue pedestal of the mascot statue of the third '
    'reference image, with her glossy magenta tentacles hanging over the edge, the rest of the statue '
    'cut off by the frame. '))

FOTO_P['P06'] = ([GIRO, AMB_A], (
    'Flash photo, close and straight on, of the old white tiled wall of a dark, wet machine tunnel '
    'under a wave pool, stained with rust streaks and salt. The wall is covered from edge to edge '
    'with hundreds of hand-drawn tally marks in groups of five (four short vertical strokes crossed '
    'by a diagonal one), made with crayons, markers and scratches in many colors, row after row, so '
    'many that they cannot be counted. On the right, a child\'s naive crayon drawing of the water park '
    'mascot of the first reference image: a one-eyed jellyfish girl with a big round single pink eye, '
    'pink scribbled hair, a striped pink and violet jellyfish bell and long wavy magenta tentacles, '
    'surrounded by many red and pink hearts, holding hands with eight tiny stick-figure children. '
    'Only tally marks, hearts and drawings: no letters, no words, no numbers. '))

FOTO_P['P07'] = ([CAST97, SOTTO, STATUA, AMB_B], (
    'Night in the abandoned indoor water park of the reference images, months after the shipwreck, '
    'flash photo from the pool edge. In the dark water of the shallow children\'s pool, the eight '
    'children of the first reference image, thinner and dirtier, in their old T-shirts and orange '
    'life jackets, sleep peacefully on inflatable mattresses and swim rings floating close together. '
    'In the middle of them, half submerged, is the mascot of the second and third reference images, '
    'now alive: her long wet silver-pink hair falls over her shoulders and chest, her smooth pale '
    'periwinkle doll-like arms are wrapped tenderly around the sleeping children, and her single huge '
    'pink eye is wide open, staring straight at the camera. Under the water her translucent '
    'jellyfish bell glows pink and violet, lighting the children from below, with magenta tentacles '
    'spreading among the floats. In the background, under a red emergency light, the round blue '
    'pedestal where her statue stood is empty, with a faded red ribbon bow lying on it. ' + MEDUSA_VIVA))

FOTO_P['P08'] = ([CASTDOPO, SBIRCIA, SOTTO, AMB_A], (
    'Years later. Night at the tiled edge of a pool in the abandoned indoor water park, red emergency '
    'lights and a harsh flash. The living mascot of the second and third reference images rises from '
    'the black water up to her waist, her long wet silver-pink hair covering her shoulders and chest, '
    'and feeds the children one at a time, like a mother bird or like puppies: she holds a small whole '
    'raw silver fish by the tail above the open mouth of a child kneeling at the edge. The children of '
    'the first reference image, now years older, kneel in a row on the wet tiles waiting for their '
    'turn with eager upturned faces. At the edge of the frame, out of focus and half in shadow, one '
    'child wears a white cube box over the head with a simple smiley face drawn in marker, another '
    'wears the old white plush lamb as a hood. The fish is whole and clean, no blood. ' + STESSIDOPO +
    MEDUSA_VIVA))

FOTO_P['P09'] = ([CASTDOPO, SOTTO, AMB_B], (
    'Night in the flooded shallow pools of the children\'s area of the abandoned indoor water park. '
    'The children of the first reference image, now years older, stand motionless in a long row in '
    'the dark water up to their chests, seen from behind, all turned toward the living mascot of the '
    'second reference image, who glows at the center a few metres in front of them. Her translucent '
    'jellyfish bell lights the water pink and violet from below and her single huge pink eye shines '
    'in the dark. Against her light the children are dark silhouettes: long tangled hair, torn '
    'T-shirts, orange life jackets; one of them has a hood with floppy lamb ears, another a white '
    'boxy cube head. Nobody looks at the camera. Underexposed and grainy, only her glow and faint red '
    'emergency lights far away. ' + MEDUSA_VIVA))

FOTO_P['P10'] = ([SOTTO], (
    'A blurry, murky underwater photograph in deep green water full of floating particles, taken far '
    'below the hull of a large cruise ship, looking up. At the top, the dark silhouette of the ship\'s '
    'keel against the faint green-grey light of the surface. Clinging under the keel there is an '
    'enormous dark shape, many times bigger than a person, with dozens of long thick tentacles hanging '
    'and spreading down into the depths, barely distinguishable from the gloom. High up near the hull, '
    'small and far away, a single soft pink glowing light like a little lantern: the glow of the '
    'jellyfish bell of the reference image. Heavy blur, soft focus, flash backscatter on the '
    'particles, strong green color cast, very low contrast. No people. '))

for p, (refs, testo) in FOTO_P.items():
    for m, tag in MODELLI:
        job(f'{p}_{tag}', m, FOTO + testo + VIETATO, refs)



# ---------------------------------------------------------------- secondo giro (dopo aver guardato il primo)
# P04: nano-banana-pro ha ricopiato la scritta "Wave Pool" dal concept B, GPT ha rifiutato il prompt.
#      Ora il riferimento è un ritaglio della struttura di gioco del concept B, senza cartelli.
STRUTTURA = (AMB_B, (380, 90, 1060, 520), [(685, 340, 830, 415), (380, 480, 1060, 520)])
P04B = (
    'A stormy night in the flooded indoor water park of a cruise ship. The eight children of the first '
    'reference image wait close together at the very top of the colorful children\'s play structure of '
    'the second reference image, right under the giant yellow bucket, wearing big orange adult life '
    'jackets over their wet T-shirts, holding on to each other and to the railings, scared and cold. '
    'Below them the whole water park is flooded with dark churning water up to the platforms, with '
    'floating toys and swim rings; rain and sea spray pour in through the broken glass dome with '
    'lightning; red emergency lights glow in the darkness. The flash lights the children\'s wet faces '
    'in the foreground, everything else falls into red-black darkness. Recognizable children: the '
    'auburn-red braid, the round sports glasses, the backwards red cap, the afro puffs, the blond bowl '
    'cut, the pigtails with pink scrunchies, the orange armbands, the smallest curly-blonde girl '
    'hugging her white plush lamb. There are no signs anywhere. ')
for m, tag in MODELLI:
    job(f'P04_{tag}2', m, FOTO + P04B + VIETATO, [CAST97, STRUTTURA])

# P07: nella versione GPT il piedistallo vuoto non si riconosce: lo chiedo in primo piano.
job('P07_gpt2', 'gpt-image-2-5-flare', FOTO + FOTO_P['P07'][1].replace(
    'In the background, under a red emergency light, the round blue pedestal where her statue stood '
    'is empty, with a faded red ribbon bow lying on it. ',
    'Behind them, on the pool deck, clearly visible and lit by a red emergency light, stands the round '
    'blue pedestal painted with waves and shells of the third reference image, completely empty: the '
    'statue is gone from it, and a faded red ribbon bow lies at its foot. ') + VIETATO,
    [CAST97, SOTTO, STATUA])

# P09: il busto della medusa veniva troppo anatomico. Ora è immersa fino alle spalle.
P09B = (
    'Night in the flooded shallow pools of the children\'s area of the abandoned indoor water park. '
    'The children of the first reference image, now years older, stand motionless in a long row in '
    'the dark water up to their chests, seen from behind, all turned toward the living mascot of the '
    'other reference images, a few metres in front of them at the center. She floats upright in the '
    'deeper water, submerged up to her shoulders: above the surface only her head, her long wet '
    'silver-pink hair spread on the water and her single huge pink eye, shining in the dark; under '
    'the surface her translucent jellyfish bell glows pink and violet and lights the water from below, '
    'with luminous magenta tentacles spreading toward the children. Against her light the children '
    'are dark silhouettes: long tangled hair, torn T-shirts, orange life jackets; one of them has a '
    'hood with floppy lamb ears, another a white boxy cube head. Nobody looks at the camera. '
    'Underexposed and grainy, only her glow and faint red emergency lights far away. ')
for m, tag in MODELLI:
    job(f'P09_{tag}2', m, FOTO + P09B + VIETATO, [CASTDOPO, SBIRCIA, SOTTO])

# P10: lo scafo deve riconoscersi come quello di una nave (elica e timone).
job('P10_gpt2', 'gpt-image-2-5-flare', FOTO + FOTO_P['P10'][1].replace(
    'At the top, the dark silhouette of the ship\'s keel against the faint green-grey light of the '
    'surface.',
    'At the top, the long dark silhouette of the bottom of a big ship\'s hull, with a huge propeller '
    'and rudder at one end, against the faint green-grey light of the surface.') + VIETATO, [SOTTO])

# ---------------------------------------------------------------- P11: la pecora che brilla (infermeria, 21 ottobre)
# Nella cassaforte dell'infermeria (GDD, "Infermeria"): una pecora vera, modificata coi geni della medusa,
# che brilla al buio nel recinto dietro l'infermeria. La foto l'ha fatta il medico, senza flash: altrimenti
# il bagliore non si vedrebbe. Il rosa è quello dell'agnellino fluorescente (variante B scelta il 18 ottobre).
FLUO_B = 'docs/proposte/agnello_fluo/b/3_vicino.jpg'
FOTO_BUIO = FOTO.replace(
    'Direct on-camera flash that brightens the nearest subjects and falls off quickly into the '
    'background, ', 'Taken in near darkness without flash, a long handheld exposure, ')
P11 = (
    'Night, a small makeshift animal pen behind the door of a ship\'s infirmary, in a dark service '
    'room of an abandoned shipwrecked cruise ship: a low fence of wooden pallets and chicken wire, a '
    'scatter of dirty straw on a wet metal floor, a dented metal water bucket. Inside the pen stands a '
    'real adult sheep with a thick dirty fleece. Its wool glows faintly from within with soft blotchy '
    'patches of pink light, like the glow of a jellyfish, brightest on its muzzle and around its eyes, '
    'the same pink glow as the plush lamb of the reference image. The sheep\'s own glow is the only '
    'real light: it softly lights the straw and the wire fence around it, everything else falls into '
    'darkness. The sheep stands still and looks toward the camera. Underexposed, heavy grain, slight '
    'motion blur, eerie and quiet. No people. ')
for m, tag in MODELLI:
    job(f'P11_{tag}', m, FOTO_BUIO + P11 + VIETATO, [FLUO_B])

# ---------------------------------------------------------------- P12-P16: le Polaroid nuove (proposta del 25 ottobre notte)
# Cinque pezzi di storia che mancavano fra le 11 (GDD, "Lore nascosta"), in ordine di tempo: l'ultima sera di festa con
# il temporale lontano (P12), quella notte qualcosa che brilla nel mare accanto allo scafo (P13), la prima notte dopo il
# naufragio la statua che si accende (P14), anni dopo i bambini che si fanno le maschere (P15) e che nuotano sott'acqua
# con lei (P16). Insieme alle altre non dicono tutto. Proposte all'utente: dove stanno e perché in
# docs/proposte/polaroid_nuove/.
FOTO_P2 = {}
FOTO_P2['P12'] = ([CAST97, GIRO, AMB_B], (
    'The last evening party of the cruise, at night, in the indoor water park of the 1990s family cruise ship of the '
    'reference images. Colorful stage lights in pink, cyan and yellow sweep over the wet tiles, with strings of party '
    'lights and balloons. The eight children of the first reference image dance and laugh in a circle around a staff '
    'member wearing a big friendly plush costume of the water park mascot: the one-eyed jellyfish girl of the other '
    'reference image, with a big soft round head, a single huge pink eye, silver-pink yarn hair with a little loop on '
    'top, periwinkle felt arms and a pink-violet felt bell skirt with soft magenta tentacles hanging down; the costume '
    'waves both hands. Behind them, through the glass dome, a black night sky over the sea, with a distant flash of '
    'lightning on the horizon. A few blurry clapping parents at the edges. Flash photo, slightly tilted, joyful. ' +
    STESSI97))
FOTO_P2['P13'] = ([SOTTO, CAST97], (
    'The same night, during a rising storm: a flash photo taken from the open deck of the cruise ship, over the wet '
    'white railing, looking down at the black sea along the side of the hull. In the foreground, out of focus, two '
    'small children\'s hands grip the railing, one of them holding the small white plush lamb of the first reference '
    'image; no faces. Far below, in the dark churning waves right next to the hull, there is a huge soft pink and '
    'violet glow under the water, as big as a lifeboat, with faint blurred streaks of long tentacles radiating from it, '
    'like a giant jellyfish rising from the depths, the same glow as in the second reference image. Rain streaks lit by '
    'the flash, spray, a row of lit portholes along the hull. Underexposed, grainy, blurry, eerie. '))
FOTO_P2['P14'] = ([STATUA, AMB_B, SOTTO], (
    'The first night after the shipwreck, in the dark flooded indoor water park of the reference images. A blurry, '
    'shaky flash photo taken from high up on the children\'s play structure, looking across the black flood water '
    'toward the mascot statue of the first reference image, standing on its round blue pedestal in the middle of the '
    'hall. ' + MEDUSA_STATUA + 'Her single huge eye glows bright pink in the darkness, and the water all around the '
    'pedestal glows pink and violet from below, where thin luminous magenta tentacles rise out of the water and coil '
    'slowly around the pedestal and up the statue\'s own tentacles. Floating toys and swim rings in the foreground water, '
    'rain dripping through the broken glass dome, faint red emergency lights. Very dark, grainy, motion blurred; the '
    'flash only lights the wet railing in the foreground. No people. '))
FOTO_P2['P15'] = ([CASTDOPO, AMB_A], (
    'Years later, inside a cramped dark service storeroom of the abandoned shipwrecked cruise ship, lit only by a small '
    'camping lantern on the floor and a red emergency light, flash photo. Two of the children of the first reference '
    'image, now older, thin and pale, sit cross-legged on the wet metal floor making masks. The boy with the shaggy '
    'blond mop glues small cracked white and turquoise swimming-pool tiles onto a big cardboard cube box mask that has '
    'a simple cute smiley face drawn on it in black marker, with a tube of glue and a pile of loose tiles beside him, '
    'some with barnacles and bits of seaweed. The smallest girl with curly blonde hair sews her old white plush lamb, '
    'cut open, into a hood, with a big needle and thick thread: its floppy ears, brass button eyes and a small sailor '
    'ribbon bow on top. Around them: rolls of tape, rope, pieces of towels. They concentrate on their work and do not '
    'look at the camera. ' + STESSIDOPO))
FOTO_P2['P16'] = ([CASTDOPO, SOTTO, AMB_B], (
    'Years later, an underwater flash photograph in the clear green-turquoise water of a deep pool of the abandoned '
    'indoor water park. The living mascot of the second reference image floats in the middle, submerged: her '
    'translucent jellyfish bell glows pink and violet and lights the water, her long silver-pink hair drifts around '
    'her head, and her single huge pink eye looks straight at the camera. Four of the children of the first reference '
    'image, now older, thin and pale, swim calmly around her underwater with their eyes wide open, holding on to her '
    'long glowing magenta tentacles like ropes, tiny bubbles rising from their noses: the auburn braid floating, the '
    'round taped sports glasses, the pigtails with pink scrunchies, the shaggy blond mop, torn faded T-shirts. Pool '
    'tiles on the floor far below, a lost swim ring floating at the surface above. Only she looks at the camera. ' +
    MEDUSA_VIVA))
for p, (refs, testo) in FOTO_P2.items():
    for m, tag in MODELLI:
        job(f'{p}_{tag}', m, FOTO + testo + VIETATO, refs)

# Secondo giro. P15: GPT ha rifiutato il prompt (forse l'ago e il peluche "tagliato"): ora cuce con ago e filo il
# peluche intero, senza tagli. P16: il busto di lei si vedeva troppo (come nel primo giro di P09): ora lo coprono i
# capelli lunghi e i tentacoli, e del corpo si vedono solo testa, spalle e braccia.
P15B = FOTO_P2['P15'][1].replace(
    'sews her old white plush lamb, cut open, into a hood, with a big needle and thick thread: its floppy ears, brass '
    'button eyes and a small sailor ribbon bow on top.',
    'is stitching a strap onto her old white plush lamb with thread, to wear it on her head like a hood: its floppy '
    'ears, brass button eyes and a small sailor ribbon bow.')
P16B = FOTO_P2['P16'][1].replace(
    'her long silver-pink hair drifts around her head,',
    'her very long silver-pink hair drifts down in front of her and completely covers her chest and body down to the '
    'bell, so that only her face, shoulders and arms are visible,')
job('P15_gpt2', 'gpt-image-2-5-flare', FOTO + P15B + VIETATO, FOTO_P2['P15'][0])
# P14: la prima versione mostrava i tentacoli che salgono sulla statua, cioè il mostro che prende la bambola, e le
# Polaroid non lo mostrano mai (docs/livello/capitolo1.md, "Le 10 Polaroid"). Ora è la mattina dopo: solo l'indizio,
# la statua bagnata fradicia con la scia di melma rosa che sale dall'acqua e i pesciolini ai suoi piedi.
P14B = (
    'The first grey morning after the shipwreck, in the flooded indoor water park of the reference images. A shaky '
    'flash photo taken from high up on the children\'s play structure, looking across the still dark flood water toward '
    'the mascot statue of the first reference image, standing on its round blue pedestal in the middle of the hall. ' +
    MEDUSA_STATUA + 'Everything is quiet and still, but the statue is dripping wet from head to toe, as if something had '
    'just climbed out of the water onto it: glossy wet streaks and a trail of shiny pink slime run from the water up the '
    'side of the pedestal to her tentacles, and a few small silver fish lie on the pedestal at her feet, like an '
    'offering. Floating toys and swim rings in the foreground water, grey light through the broken glass dome, faint red '
    'emergency lights. In the foreground, out of focus, a small child\'s hand in a wet sleeve grips the yellow railing of '
    'the play structure. ')
for m, tag in MODELLI:
    job(f'P14_{tag}2', m, FOTO + P14B + VIETATO, [STATUA, AMB_B])
for m, tag in MODELLI:
    job(f'P16_{tag}2', m, FOTO + P16B + VIETATO, FOTO_P2['P16'][0])

# ---------------------------------------------------------------- esecuzione
def _carica(r):
    """Un riferimento: percorso, '@job', oppure (percorso, ritaglio, [riquadri da cancellare]).

    I riquadri (coordinate dell'immagine intera) vengono riempiti con cv2.inpaint: servono a
    togliere le scritte dei cartelloni dai concept, che altrimenti i modelli ricopiano."""
    from PIL import Image
    if isinstance(r, tuple):
        import numpy as np, cv2
        path, (x0, y0, x1, y1), riquadri = r
        a = np.array(Image.open(_ref_path(path)).convert('RGB'))
        m = np.zeros(a.shape[:2], np.uint8)
        for bx0, by0, bx1, by1 in riquadri:
            m[by0:by1, bx0:bx1] = 255
        a = cv2.inpaint(a, m, 9, cv2.INPAINT_TELEA)[y0:y1, x0:x1]
        return Image.fromarray(a)
    return Image.open(_ref_path(r)).convert('RGB')


def _data_uri(r):
    im = _carica(r)
    im.thumbnail((1280, 1280))
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=92)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode()


def _ref_path(r):
    return os.path.join(OUT, r[1:] + '.png') if r.startswith('@') else os.path.join(REPO, r)


def _create(kind, body):
    for tentativo in range(6):
        try:
            return meshy.create(kind, body)
        except RuntimeError as e:
            if '429' in str(e) and tentativo < 5:
                time.sleep(20)
                continue
            raise


def _log(name, kind, tid, j, t):
    with _lock:
        log = json.load(open(LOG)) if os.path.exists(LOG) else []
        log.append(dict(job=name, kind=kind, task_id=tid, model=j['model'], aspect=j['aspect'],
                        refs=[r if isinstance(r, str) else list(r) for r in j['refs']], prompt=j['prompt'], status=t['status'],
                        error=t.get('task_error'), time=time.strftime('%Y-%m-%d %H:%M:%S')))
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        json.dump(log, open(LOG, 'w'), indent=1, ensure_ascii=False)


def run(name):
    j = JOBS[name]
    body = dict(ai_model=j['model'], prompt=j['prompt'], aspect_ratio=j['aspect'])
    if j['refs']:
        kind = 'image-to-image'
        body['reference_image_urls'] = [_data_uri(r) for r in j['refs']]
    else:
        kind = 'text-to-image'
    tid = _create(kind, body)
    t = meshy.wait(kind, tid, every=6, timeout=3600)
    _log(name, kind, tid, j, t)
    if t['status'] != 'SUCCEEDED':
        print(name, t['status'], t.get('task_error'), flush=True)
        return
    meshy.download(t['image_urls'][0], os.path.join(OUT, f'{name}.png'))
    print(name, 'OK', flush=True)


def _safe(name):
    try:
        run(name)
    except Exception as e:  # un job fallito non ferma gli altri
        print(name, 'ERRORE', e, flush=True)


def main(names):
    os.makedirs(OUT, exist_ok=True)
    th = []
    for n in names:
        t = threading.Thread(target=_safe, args=(n,))
        t.start()
        th.append(t)
        time.sleep(1.5)
    for t in th:
        t.join()


if __name__ == '__main__':
    if not sys.argv[1:] or sys.argv[1] == '--list':
        print('\n'.join(JOBS))
    else:
        import fnmatch
        sel = [n for pat in sys.argv[1:] for n in JOBS if fnmatch.fnmatch(n, pat)]
        main(list(dict.fromkeys(sel)))

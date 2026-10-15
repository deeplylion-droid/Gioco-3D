#!/usr/bin/env python3
"""Zaino-pompa in 3D con Meshy (regola dell'utente: si mostrano solo asset 3D veri e
screenshot dal motore; le immagini generate servono solo come input interno).

Per ogni opzione di design:
  1. immagine interna dello zaino intero (Meshy text-to-image; già fatta per le 3 opzioni);
  2. immagine interna della sola lancia (image-to-image dallo zaino, sfondo neutro);
  3. modelli 3D con texture PBR (image-to-3D) dello zaino e della lancia.
I GLB grezzi si scaricano in una cartella di lavoro; tools/godot_zaino_blender.py li
sistema (scala, orientamento, punta della lancia) e li esporta in godot/assets/models/zaino/.

Uso (dalla radice del repository, con MESHY_API_KEY impostata):
  python3 tools/godot_zaino_3d.py <cartella_di_lavoro>
I task già creati sono in docs/proposte/godot/zaino/task.json: rilanciare non spreca crediti.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshy  # noqa: E402

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASK_FILE = os.path.join(RADICE, 'docs', 'proposte', 'godot', 'zaino', 'task.json')
MODELLO_IMG = 'nano-banana-pro'

AMBIENTE = (
    "Setting: a dark abandoned indoor water park inside a 1990s family cruise ship at night, "
    "photorealistic and grim: red emergency lights, flickering cold fluorescent tubes, low fog, "
    "wet cracked tiles with reflections, rust, peeling paint, an empty wave pool and faded plastic "
    "slides in the background. Cinematic lighting, realistic horror video game concept art, "
    "Unreal Engine 5 quality."
)

OPZIONI = [
    {
        'nome': 'Irroratore di servizio',
        'riga': "Plastica da manutenzione: serbatoio traslucido ingiallito, leva della pompa, tubo rosso, lancia in ottone.",
        'zaino': (
            "A worn 1990s backpack water pump sprayer used by the maintenance staff of the ship's water park. "
            "Semi-translucent yellowed white polyethylene tank of about 15 liters with molded ribs and a visible "
            "water level inside, a big screw cap, a black side pump lever, black nylon shoulder straps with padded "
            "foam, a coiled red rubber hose and a long black lance with a brass trigger valve and an adjustable brass "
            "nozzle hooked on the side. A faded teal sticker with a simple wave logo and the word STAFF. Scratches, "
            "grime, limescale stains."
        ),
        'mani': "The right hand holds the black lance by its brass trigger valve.",
    },
    {
        'nome': "Cannone dell'animazione",
        'riga': "Giocattolone anni '90 dello staff animazione: plastica turchese, gialla e arancione, adesivi di delfini.",
        'zaino': (
            "A bulky 1990s backpack water cannon used by the entertainment staff of the ship's water park for kids' "
            "water games: chunky rounded plastic in saturated turquoise, sunshine yellow and orange, like an "
            "oversized 90s pump-action water blaster toy turned into a backpack. A clear pressurized water chamber, "
            "a ribbed purple hose and a big chunky toy-like pump-action water blaster with an orange pump grip and "
            "a yellow tip clipped to the side. Cheerful cartoon dolphin and starfish decals, now scratched, faded "
            "and dirty with grime and mold spots. The bright toy colors contrast with the grim decayed place."
        ),
        'mani': "The right hand holds the grip of the toy-like water blaster and the left hand holds its orange pump grip.",
        # il modello ha scritto una didascalia in basso a destra: la tagliamo nel montaggio
        'ritaglio_basso': 0.085,
    },
    {
        'nome': 'Pompa antincendio di bordo',
        'riga': "Metallo navale: serbatoio d'acciaio rosso ammaccato, manometro, cinghie di tela, lancia in ottone.",
        'zaino': (
            "A heavy dented metal backpack water pump in the style of a vintage firefighter backpack pump, used by "
            "the staff of the ship's water park. A cylindrical galvanized steel tank painted signal red with chipped "
            "paint and rust spots, brass fittings, a round pressure gauge with a glass face, a brass hand pump "
            "handle, worn khaki canvas webbing straps with steel buckles, a black rubber hose wrapped in cloth tape "
            "and a brass pistol-grip lance with a long nozzle. Stenciled white text STAFF and a faded lifebuoy emblem."
        ),
        'mani': "The right hand holds the brass pistol-grip lance.",
        # v1 scartata (zaino/scartate/): il serbatoio stava per terra davanti al giocatore.
        'mani_extra': ("The red tank is strapped on the player's back, so the tank itself is NOT visible in the "
                       "frame: only its black rubber hose comes over the right shoulder down to the lance."),
    },
]


def prompt_zaino(o):
    return (
        "Concept art of a piece of equipment for a first-person horror game. " + o['zaino'] + " "
        "The whole backpack is fully visible, centered and large in the frame, three-quarter front view, "
        "standing upright on the wet tiled floor, leaning on a low tiled wall, lit well enough to read every "
        "detail. " + AMBIENTE + " No people, no watermark."
    )



LANCE = [
    "ONLY the spray lance of this backpack sprayer: the long black lance with the brass trigger valve "
    "handle and the adjustable brass nozzle, with about 40 cm of the red rubber hose attached to the handle.",
    "ONLY the toy-like pump-action water blaster of this backpack, in turquoise, yellow and orange plastic, "
    "with its orange pump grip and a short stub of the purple ribbed hose.",
    "ONLY the brass pistol-grip lance of this backpack pump, with its long brass nozzle and a short piece "
    "of the black cloth-taped rubber hose.",
]


def prompt_zaino(o):
    return (
        "Concept art of a piece of equipment for a first-person horror game. " + o['zaino'] + " "
        "The whole backpack is fully visible, centered and large in the frame, three-quarter front view, "
        "standing upright on the wet tiled floor, leaning on a low tiled wall, lit well enough to read every "
        "detail. " + AMBIENTE + " No people, no watermark."
    )


def prompt_lancia(i):
    return (
        "Use the equipment of the reference image and keep exactly its design, materials and colors. New image: "
        "a clean product photo of " + LANCE[i] + " Isolated on a plain light grey studio background, soft even "
        "studio lighting, side view slightly from above, the whole object visible, centered and large. "
        "No backpack, no hands, no people, no text, no watermark."
    )


def carica():
    if os.path.exists(TASK_FILE):
        with open(TASK_FILE) as f:
            return json.load(f)
    return {}


def salva(task):
    os.makedirs(os.path.dirname(TASK_FILE), exist_ok=True)
    with open(TASK_FILE, 'w') as f:
        json.dump(task, f, indent=2)


def crea(task, chiave, tipo, corpo):
    if chiave not in task:
        task[chiave] = meshy.create(tipo, corpo)
        salva(task)
        print('creato', chiave, task[chiave], flush=True)
    return task[chiave]


def aspetta(tipo, task_id, nome):
    t = meshy.wait(tipo, task_id)
    print(nome, t['status'], flush=True)
    if t['status'] != 'SUCCEEDED':
        raise SystemExit(f'{nome} fallito: {t.get("task_error")}')
    return t


def modello_3d(task, chiave, input_task, polycount):
    return crea(task, chiave, 'image-to-3d', {
        'input_task_id': input_task, 'ai_model': 'meshy-7.1', 'should_texture': True,
        'enable_pbr': True, 'texture_resolution': '2k', 'should_remesh': True,
        'topology': 'triangle', 'target_polycount': polycount, 'origin_at': 'bottom',
        'target_formats': ['glb']})


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'zaino_3d'
    os.makedirs(out, exist_ok=True)
    task = carica()
    for i, o in enumerate(OPZIONI, 1):
        crea(task, f'zaino{i}', 'text-to-image', {
            'ai_model': MODELLO_IMG, 'prompt': prompt_zaino(o), 'aspect_ratio': '16:9'})
    for i in range(1, len(OPZIONI) + 1):
        aspetta('text-to-image', task[f'zaino{i}'], f'zaino{i}')
        crea(task, f'lancia_img{i}', 'image-to-image', {
            'ai_model': MODELLO_IMG, 'prompt': prompt_lancia(i - 1), 'input_task_id': task[f'zaino{i}'],
            'aspect_ratio': '4:3'})
        modello_3d(task, f'zaino3d{i}', task[f'zaino{i}'], 24000)
    for i in range(1, len(OPZIONI) + 1):
        aspetta('image-to-image', task[f'lancia_img{i}'], f'lancia_img{i}')
        modello_3d(task, f'lancia3d{i}', task[f'lancia_img{i}'], 10000)
    for i in range(1, len(OPZIONI) + 1):
        for k in (f'zaino3d{i}', f'lancia3d{i}'):
            t = aspetta('image-to-3d', task[k], k)
            dest = os.path.join(out, k + '.glb')
            if not os.path.exists(dest):
                meshy.download(t['model_urls']['glb'], dest)
                print('  scaricato', dest, os.path.getsize(dest) // 1024, 'KB', flush=True)


if __name__ == '__main__':
    main()

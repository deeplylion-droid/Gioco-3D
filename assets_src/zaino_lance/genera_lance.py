"""Genera con Meshy le tre proposte di lancia (A pompiere, B cannone giocattolo, C industriale),
due varianti ciascuna, e scarica i GLB texturizzati in assets_src/zaino_lance/meshy/.
Uso: python3 assets_src/zaino_lance/genera_lance.py   (serve MESHY_API_KEY)"""
import json, sys, threading
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import meshy

QUI = Path(__file__).resolve().parent / "meshy"
QUI.mkdir(exist_ok=True)

COMUNE = (" Single isolated handheld object, no hands, no person, no base, no background props. "
          "The barrel is straight and horizontal, nozzle pointing forward. Clean separate parts.")
LANCE = {
    "A": ("Professional firefighter hose nozzle held like a rifle: heavy polished brass nozzle tip, "
          "big red bale shut-off lever valve on top, black ribbed rubber pistol grip underneath, "
          "brass hose coupling at the back with a short stub of thick red reinforced fire hose. "
          "Realistic, heavy, used and scratched." + COMUNE,
          "polished worn brass, red painted lever, black rubber grip, red canvas fire hose, realistic PBR"),
    "B": ("Giant oversized 1990s toy water cannon, chunky glossy plastic in turquoise, yellow and orange, "
          "round pressure gauge on top, wide flared nozzle with fins at the front, big trigger handle and "
          "a front grip, ribbed hose port at the back. Toy-like but enormous and powerful." + COMUNE,
          "glossy turquoise, yellow and orange plastic toy, white gauge face with red needle, dolphin stickers"),
    "C": ("Chunky heavy industrial pressure water cannon for water park maintenance, compact and thick like a "
          "power tool: thick cylindrical steel body about as wide as a fist, painted yellow and black hazard "
          "stripes, a large round pressure gauge mounted on the side, a pistol grip with a big trigger underneath, "
          "a tall carry handle on top, a heavy wide steel nozzle at the front, rubber hose fitting at the back. "
          "Bulky, worn and scratched." + COMUNE,
          "worn painted steel, yellow and black hazard stripes, black rubber grip, gauge with white face"),
    # Terzo giro della C: la forma di una pistola da idropulitrice industriale, che Meshy conosce.
    "D": ("Heavy-duty industrial pressure washer spray gun with a thick short steel lance, the gun body painted with "
          "yellow and black diagonal hazard stripes, a big round pressure gauge on top of the body, a pistol grip "
          "with a large trigger, a carry handle arching over the body, a wide heavy nozzle at the front, a rubber "
          "hose fitting at the back of the grip. Worn industrial maintenance equipment." + COMUNE,
          "yellow and black hazard stripes paint, scratched steel lance, black rubber grip, white gauge face with red needle"),
}


def una(nome, variante, prompt, texture):
    tag = f"{nome}{variante}"
    try:
        pid = meshy.create("text-to-3d", {"mode": "preview", "prompt": prompt, "ai_model": "meshy-7.1",
                                          "geometry_resolution": "2k", "should_remesh": True,
                                          "topology": "triangle", "target_polycount": 60000,
                                          "target_formats": ["glb"]})
        t = meshy.wait("text-to-3d", pid)
        print(tag, "preview", t["status"], flush=True)
        if t["status"] != "SUCCEEDED":
            return
        rid = meshy.create("text-to-3d", {"mode": "refine", "preview_task_id": pid, "enable_pbr": True,
                                          "texture_prompt": texture, "target_formats": ["glb"]})
        r = meshy.wait("text-to-3d", rid)
        print(tag, "refine", r["status"], flush=True)
        if r["status"] == "SUCCEEDED":
            meshy.download(r["model_urls"]["glb"], QUI / f"lancia_{tag}.glb")
            if r.get("thumbnail_url"):
                meshy.download(r["thumbnail_url"], QUI / f"lancia_{tag}.png")
        (QUI / f"lancia_{tag}.json").write_text(json.dumps({"preview": pid, "refine": rid, "prompt": prompt}, indent=1))
    except Exception as e:
        print(tag, "ERRORE", e, flush=True)


# Senza argomenti tutte; con argomenti solo quelle indicate, per esempio: C3 C4
scelte = sys.argv[1:] or [n + v for n in LANCE for v in "12"]
fili = [threading.Thread(target=una, args=(c[0], c[1:], *LANCE[c[0]])) for c in scelte]
for f in fili:
    f.start()
for f in fili:
    f.join()
print("fatto")

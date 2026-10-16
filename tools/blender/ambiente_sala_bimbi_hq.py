"""La sala principale con l'area bimbi in alta definizione (proposta, 16 ottobre): costruisce la sala come
ambiente_sala.py, ma con la struttura di gioco, il secchio gigante e i funghi-fontana di Meshy
(bimbi_hq.py, assets_src/ambiente/bimbi_hq/). Non cambia ambiente_sala.py: lo importa e sostituisce
struttura_gioco() e il file del fungo. Serve per gli scatti "dopo" della proposta; nel gioco non va niente
finché l'utente non sceglie.

Uso (la sala della disposizione 1 è quella di lavoro/ambiente):
  PY=/home/user/tools/blender-venv/bin/python
  SALA_DIR=/home/user/wt/ambiente/tools/blender BIMBI_HQ=<repo>/assets_src/ambiente/bimbi_hq \\
    flock /home/user/tools/render.lock nice -n 10 $PY tools/blender/ambiente_sala_bimbi_hq.py --glb <cartella>
SALA_DIR: cartella di ambiente_sala.py da usare (di serie quella accanto a questo file)."""
import math, os, sys
QUI = os.path.dirname(os.path.abspath(__file__))
SALA_DIR = os.environ.get('SALA_DIR', QUI)
sys.path.insert(0, QUI)
sys.path.insert(0, SALA_DIR)
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402
import ambiente_sala as S  # noqa: E402
import ambiente_kit as K  # noqa: E402
import bimbi_hq as H  # noqa: E402

_file_oggetto = S.file_oggetto


def file_oggetto(nome):
    """Il fungo-fontana HD al posto di quello del 15 ottobre (stesse misure: alto 2 m, MISURE di ambiente_sala)."""
    if nome == 'fungo_fontana' and os.path.exists(H.file_hq(H.FUNGO_HD)):
        return H.file_hq(H.FUNGO_HD)
    return _file_oggetto(nome)


def struttura_gioco_hd(mats):
    """Come ambiente_sala.struttura_gioco: restituisce [struttura, secchio] con gli stessi nomi dei nodi
    (sala_struttura_gioco, sala_secchio_gigante con il perno sull'asse x) e le collisioni di pedane,
    scala e secchio."""
    cx, cy = H.STRUTTURA_HD['centro']
    ob = H.struttura_locale()
    ob.data.transform(Matrix.Translation((cx, cy, 0.0)))
    # collisioni: le quattro pedane (si sale davvero), la scala come rampa, lo scivolo; pali e ringhiere no
    for nome, (x0, y0, x1, y1, z) in H.PEDANE.items():
        K.collisione_scatola(f'gioco_pedana_{nome}', (cx + x0, cy + y0, z - 0.1), (cx + x1, cy + y1, z), padre=ob)
    K.collisione_punti('gioco_scala', [(cx + x, cy + y, z) for (x, y, z) in (
        (-2.25, -3.05, 0.0), (-0.95, -3.05, 0.0), (-2.25, -0.95, 0.0), (-0.95, -0.95, 0.0),
        (-2.25, -0.95, 1.24), (-0.95, -0.95, 1.24), (-2.25, -3.05, 0.05), (-0.95, -3.05, 0.05))], padre=ob)
    K.collisione_punti('gioco_scivolo', [(cx + x, cy + y, z) for (x, y, z) in (
        (0.85, 0.10, 1.55), (0.85, 1.38, 1.55), (4.25, 0.10, 0.30), (4.25, 1.38, 0.30),
        (0.85, 0.10, 1.45), (0.85, 1.38, 1.45), (4.25, 0.10, 0.20), (4.25, 1.38, 0.20))], padre=ob)
    # secchio: perno sui cuscinetti del telaio, un po' inclinato come prima
    A = H.ASSE_SECCHIO
    secchio = H.secchio_locale()
    lo, hi = H.limiti(secchio.data)
    secchio.location = (cx + A['x'], cy + A['y'], A['z'])
    secchio.rotation_euler = Euler((math.radians(-14), 0, 0))
    K.collisione_scatola('secchio', (lo.x * 0.92, lo.y, lo.z), (hi.x * 0.92, hi.y, hi.z), padre=secchio)
    secchio.children[0].hide_render = True
    return [ob, secchio]


S.file_oggetto = file_oggetto
S.struttura_gioco = struttura_gioco_hd

if __name__ == '__main__':
    S.main()

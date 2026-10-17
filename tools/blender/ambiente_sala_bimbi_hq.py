"""La sala principale con l'area bimbi in alta definizione (proposta, 16 ottobre): costruisce la sala come
ambiente_sala.py, ma con la struttura di gioco, il secchio gigante e i funghi-fontana di Meshy (bimbi_hq.py,
assets_src/ambiente/bimbi_hq/). Non cambia ambiente_sala.py: lo importa e sostituisce struttura_gioco() e il
file del fungo. Serve per gli scatti "dopo" della proposta; nel gioco non va niente finché l'utente non sceglie.

BIMBI_HQ_VERSIONE:
  fedele (di serie): la struttura di oggi con la stessa forma, gli stessi nodi e le stesse collisioni; cambia
    solo la mesh (i 4 moduli Meshy nei limiti dei pezzi di oggi) e quella del secchio (stesso perno).
  variante: la struttura disegnata da capo, con le sue collisioni (pedane, scala, scivolo) e il secchio sul
    suo telaio a portale.

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
from mathutils import Euler  # noqa: E402
import ambiente_sala as S  # noqa: E402
import ambiente_kit as K  # noqa: E402
import bimbi_hq as H  # noqa: E402

VERSIONE = os.environ.get('BIMBI_HQ_VERSIONE', 'fedele')
_file_oggetto = S.file_oggetto
_struttura_gioco = S.struttura_gioco


def file_oggetto(nome):
    """Il fungo-fontana HD al posto di quello del 15 ottobre (stesse misure: alto 2 m, MISURE di ambiente_sala)."""
    if nome == 'fungo_fontana' and os.path.exists(H.file_hq(H.FUNGO_HD)):
        return H.file_hq(H.FUNGO_HD)
    return _file_oggetto(nome)


def sostituisci_mesh(dst, src, nome):
    """Mette in dst (stesso nodo, stessa trasformazione, stesse collisioni figlie) la mesh di src."""
    vecchia = dst.data
    dst.data = src.data
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.meshes.remove(vecchia)
    dst.data.name = nome


def struttura_gioco_hd(mats):
    """Come ambiente_sala.struttura_gioco: restituisce [struttura, secchio] con gli stessi nomi dei nodi
    (sala_struttura_gioco, sala_secchio_gigante con il perno sull'asse x)."""
    if VERSIONE == 'fedele':
        ob, secchio = _struttura_gioco(mats)     # la struttura di oggi: nodi, collisioni, perno del secchio
        sostituisci_mesh(ob, H.struttura_fedele(), 'sala_struttura_gioco')
        sostituisci_mesh(secchio, H.secchio_locale(nome='secchio_gigante_hd'), 'sala_secchio_gigante')
        cx, cy = H.CENTRO_FEDELE
        secchio.location = (cx + H.PERNO_FEDELE[0], cy + H.PERNO_FEDELE[1], H.PERNO_FEDELE[2])
        return [ob, secchio]
    cx, cy = H.VARIANTE['centro']
    ob = H.struttura_variante()
    # collisioni: le quattro pedane (si sale davvero), la scala come rampa, lo scivolo; pali e ringhiere no
    for nome, (x0, y0, x1, y1, z) in H.PEDANE_VARIANTE.items():
        K.collisione_scatola(f'gioco_pedana_{nome}', (cx + x0, cy + y0, z - 0.1), (cx + x1, cy + y1, z), padre=ob)
    K.collisione_punti('gioco_scala', [(cx + x, cy + y, z) for (x, y, z) in (
        (-2.25, -3.05, 0.0), (-0.95, -3.05, 0.0), (-2.25, -0.95, 0.0), (-0.95, -0.95, 0.0),
        (-2.25, -0.95, 1.24), (-0.95, -0.95, 1.24), (-2.25, -3.05, 0.05), (-0.95, -3.05, 0.05))], padre=ob)
    K.collisione_punti('gioco_scivolo', [(cx + x, cy + y, z) for (x, y, z) in (
        (0.85, 0.10, 1.55), (0.85, 1.38, 1.55), (4.25, 0.10, 0.30), (4.25, 1.38, 0.30),
        (0.85, 0.10, 1.45), (0.85, 1.38, 1.45), (4.25, 0.10, 0.20), (4.25, 1.38, 0.20))], padre=ob)
    px, py, pz = H.PERNO_VARIANTE
    secchio = H.secchio_locale()
    lo, hi = H.limiti(secchio.data)
    secchio.location = (cx + px, cy + py, pz)
    secchio.rotation_euler = Euler((math.radians(-14), 0, 0))
    K.collisione_scatola('secchio', (lo.x * 0.92, lo.y, lo.z), (hi.x * 0.92, hi.y, hi.z), padre=secchio)
    secchio.children[0].hide_render = True
    return [ob, secchio]


S.file_oggetto = file_oggetto
S.struttura_gioco = struttura_gioco_hd

if __name__ == '__main__':
    S.main()

"""Proposte del 15 ottobre per la medusa (questionario: D6 denti, D2 easter egg dell'occhio), render Cycles con la
luce neutra della scheda (medusa_scheda.py: tre luci da studio che girano con la camera, fondo grigio uniforme con
l'ombra a terra).

  denti   file di denti interne (medusa_fauce.FILE_INTERNE): fauce aperta di fronte e di 3/4 con le stesse camere di
          docs/proposte/medusa/scheda/denti_*.jpg (puntate sul centro dei denti approvati) e confronto prima/dopo:
            docs/proposte/medusa/denti_interni/1_denti_interni.jpg
            docs/proposte/medusa/denti_interni/2_prima_dopo.jpg
  occhio  l'occhio che si chiude (medusa_palpebre.py): A due palpebre che si incontrano a meta', B una palpebra
          sola dall'alto; occhio aperto, a meta' e chiuso, di fronte e di 3/4:
            docs/proposte/medusa/occhio_chiuso/A_due_palpebre.jpg
            docs/proposte/medusa/occhio_chiuso/B_una_palpebra.jpg
            docs/proposte/medusa/occhio_chiuso/confronto_A_B.jpg

Il modello delle proposte si costruisce a parte, senza toccare build/medusa_finale.blend:
  MEDUSA_DENTI_INTERNI=1 MEDUSA_PALPEBRE=due,una MEDUSA_FINALE=<x>.blend python tools/blender/medusa_07_finale.py
  MEDUSA_FINALE=<x>.blend python tools/blender/medusa_08_dettagli.py --solo-materiali
Uso: MEDUSA_FINALE=<x>.blend flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python \
     tools/blender/medusa_proposta_denti_occhio.py [denti] [occhio] [--prova]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_scheda as SCH  # noqa: E402
import medusa_palpebre as PALP  # noqa: E402

PROVA = '--prova' in sys.argv
OUT_PNG = os.path.join(BUILD, 'render', 'proposte_15ott')
OUT_DENTI = os.path.join(PROPOSTE, 'denti_interni') if not PROVA else os.path.join(OUT_PNG, 'prova')
OUT_OCCHIO = os.path.join(PROPOSTE, 'occhio_chiuso') if not PROVA else os.path.join(OUT_PNG, 'prova')
for _d in (OUT_PNG, OUT_DENTI, OUT_OCCHIO):
    os.makedirs(_d, exist_ok=True)
SCH.OUT_PNG = OUT_PNG
FONDO = SCH.FONDO


def palpebre():
    return {o.get('variante'): o for o in bpy.data.objects if o.name.startswith('Medusa_Palpebre')}


def centro_denti_approvati():
    """Centro del riquadro dei soli denti approvati (i primi vertici di Medusa_Denti): stessa camera della scheda."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    o = bpy.data.objects['Medusa_Denti']
    me = o.evaluated_get(dg).to_mesh()
    co = coords(me)
    co = co[:int(o.get('denti_approvati', len(co)))]
    M = np.array(o.matrix_world)
    co = co @ M[:3, :3].T + M[:3, 3]
    o.evaluated_get(dg).to_mesh_clear()
    return Vector(((co.min(0) + co.max(0)) / 2).tolist())


# ---------------------------------------------------------------- denti

def denti():
    from PIL import Image
    SCH.studio('fauce_apre', 24, venatura=1.0)
    for o in palpebre().values():
        o.hide_render = True
    n = bpy.data.objects['Medusa_Denti']
    log(f'denti: {len(n.data.vertices) // 16} in tutto, {int(n.get("denti_approvati", 0)) // 16} approvati')
    c = centro_denti_approvati()
    res = (1200, 900) if not PROVA else (600, 450)
    dopo = []
    for nome, az, el in (('fronte', 0, 2), ('34', 35, 4)):
        im = SCH.scatto(f'denti_interni_{nome}', SCH.orbita(c, 1.45, az, el), c, 85, res, 0.6)
        dopo.append(im)
        p = os.path.join(OUT_DENTI, f'denti_interni_{nome}.jpg')
        im.save(p, quality=92)
        log('immagine', os.path.relpath(p, REPO))
    tavola([(dopo[0], 'di fronte'), (dopo[1], 'di 3/4')], os.path.join(OUT_DENTI, '1_denti_interni.jpg'), colonne=2,
           titolo='Medusa - piu\' file di denti dentro la bocca',
           sottotitolo='le file di prima restano uguali; dietro, file di denti sempre piu\' piccoli fino alla gola',
           larghezza=2400, sfondo=FONDO)
    prima = [Image.open(os.path.join(PROPOSTE, 'scheda', f'denti_{n}.jpg')).convert('RGB') for n in ('fronte', '34')]
    tavola([(prima[0], 'prima: di fronte'), (dopo[0], 'dopo: di fronte'), (prima[1], 'prima: di 3/4'),
            (dopo[1], 'dopo: di 3/4')], os.path.join(OUT_DENTI, '2_prima_dopo.jpg'), colonne=2,
           titolo='Denti: prima e dopo', sottotitolo='stessa luce e stesse camere', larghezza=2400, sfondo=FONDO)


# ---------------------------------------------------------------- occhio che si chiude

STATI = [('aperto', 0.0, 'aperto'), ('meta', 0.5, 'a meta\''), ('chiuso', 1.0, 'chiuso')]
VISTE = [('fronte', 0, 2, 'di fronte'), ('34', 35, 4, 'di 3/4')]
NOMI = {'due': ('A', 'due palpebre'), 'una': ('B', 'una palpebra')}


def occhio():
    arm = SCH.studio('statua', 1)
    pal = palpebre()
    e = SCH.occhio_centro(arm)
    t = e + Vector((0.0, -0.2, -0.01))                    # davanti al bulbo, poco sotto il centro
    res = (900, 760) if not PROVA else (450, 380)
    dist = 1.3

    def mostra(variante, c):
        """Solo la palpebra della variante, chiusa di c; con variante None tutte e due aperte (ci sono, ma a occhio
        aperto non si vedono)."""
        for v, o in pal.items():
            o.hide_render = variante is not None and v != variante
            PALP.imposta_chiusura(o, c if v == variante else 0.0)

    imm = {}
    for nv, az, el, _ in VISTE:
        mostra(None, 0.0)
        imm[('aperto', nv)] = SCH.scatto(f'occhio_aperto_{nv}', SCH.orbita(t, dist, az, el), t, 85, res, 0.55)
        for v in ('due', 'una'):
            if v not in pal:
                continue
            for ns, c, _ in STATI[1:]:
                mostra(v, c)
                imm[(v, ns, nv)] = SCH.scatto(f'occhio_{v}_{ns}_{nv}', SCH.orbita(t, dist, az, el), t, 85, res, 0.55)
    for v in ('due', 'una'):
        if v not in pal:
            continue
        lettera, nome = NOMI[v]
        celle = []
        for nv, _, _, ev in VISTE:
            for ns, _, es in STATI:
                im = imm[('aperto', nv)] if ns == 'aperto' else imm[(v, ns, nv)]
                celle.append((im, f'{es}, {ev}'))
        sotto = ('una scende dall\'alto e una sale dal basso, si incontrano a meta\'' if v == 'due' else
                 'scende dall\'alto e copre tutto l\'occhio, come negli occhi delle bambole')
        tavola(celle, os.path.join(OUT_OCCHIO, f'{lettera}_{nome.replace(" ", "_")}.jpg'), colonne=3,
               titolo=f'Occhio che si chiude - proposta {lettera}: {nome}',
               sottotitolo=f'pelle di vinile come il viso; {sotto}', larghezza=2700, sfondo=FONDO)
    if 'due' in pal and 'una' in pal:
        celle = [(imm[('due', 'meta', 'fronte')], 'A: a meta\''), (imm[('due', 'chiuso', 'fronte')], 'A: chiuso'),
                 (imm[('una', 'meta', 'fronte')], 'B: a meta\''), (imm[('una', 'chiuso', 'fronte')], 'B: chiuso')]
        tavola(celle, os.path.join(OUT_OCCHIO, 'confronto_A_B.jpg'), colonne=4,
               titolo='Occhio che si chiude: A due palpebre, B una palpebra', larghezza=2800, sfondo=FONDO)


if __name__ == '__main__':
    argv = [a for a in sys.argv[1:] if not a.startswith('--')]
    for nome, f in (('denti', denti), ('occhio', occhio)):
        if nome in argv:
            t0 = time.time()
            f()
            log(f'{nome}: {time.time() - t0:.0f} s')

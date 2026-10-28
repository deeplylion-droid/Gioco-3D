"""Giocattoli di gomma dell'enigma "I giocattoli al loro posto" (piscina a onde, 28 ottobre): con la stessa pipeline
degli oggetti in qualità alta (assets_src/ambiente/oggetti_hq/genera_hq.py: immagine di riferimento solo interna in
rif/, poi image-to-3d meshy-7.1). La paperella non si rifà: è paperella_gigante degli oggetti hq, la stessa del gioco.
Misura, perno e collisioni le mette prepara_giocattoli.py.
Uso: python3 assets_src/enigma_giocattoli/genera_giocattoli.py [--immagini] [nome ...]
La chiave è in MESHY_API_KEY (mai nel repository)."""
import os, sys
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '../ambiente/oggetti_hq'))
sys.path.insert(0, os.path.join(QUI, '../../tools'))
import genera_hq as g

g.QUI = QUI
GOMMA = ('Solid thick rubber vinyl squeeze toy, heavy, not inflatable, slightly faded colour, a little dirty with grime in '
         'the creases and a few scuffs.')
g.OGGETTI = {
    'palla_rossa': ('A big round red rubber playground ball, classic pebbled grip texture, one thin moulded seam line '
                    'around the middle, slightly faded red. ' + GOMMA, g.DAVANTI, 3000),
    'balena_blu': ('A big cute cartoon whale bath toy sitting upright on its flat belly: chunky rounded body, tail fin '
                   'raised at the back, small side flippers, painted black eyes, a smile, a lighter blue belly, all in '
                   'faded blue. ' + GOMMA, g.DAVANTI, 8000),
}

if __name__ == '__main__':
    if '--immagini' in sys.argv:
        sys.argv.remove('--immagini')
        g.SOLO_IMMAGINI = True
    nomi = sys.argv[1:] or list(g.OGGETTI)
    for n in nomi:
        print(*g.fai(n), flush=True)

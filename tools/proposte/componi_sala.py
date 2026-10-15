"""Compone le immagini delle proposte della sala (15 ottobre 2026) per l'utente: fascia con titolo
sopra gli screenshot di Godot (godot/tests/proposte_sala.gd) e, sulle piante, i percorsi disegnati
(tools/proposte/pianta_sopra.py). Uscita in docs/proposte/sala/.

Uso: python3 tools/proposte/componi_sala.py <cartella degli scatti> <cartella dei log di godot> [scatti]
"""
import os, subprocess, sys
from PIL import Image

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
sys.path.insert(0, QUI)
from pianta_sopra import con_fascia  # noqa: E402

USCITA = os.path.join(RADICE, 'docs', 'proposte', 'sala')
D = {'L1': ('Area bimbi · disposizione 1', "Struttura nell'angolo con la scala verso di te; lo scivolo scende nella vasca piccola"),
     'L2': ('Area bimbi · disposizione 2', 'Struttura girata con il secchio verso di te; lo scivolo scende nella vasca a scacchi'),
     'L3': ('Area bimbi · disposizione 3', 'Struttura in fondo, i funghi in fila lungo il muro, piazza libera davanti')}
TITOLI = {
    'pulsante_A_spiaggia': ('Pulsante della botola · versione A', 'Fungo rosso grosso con il lampeggiante giallo. Dalla cima della spiaggia, piscina vuota'),
    'pulsante_A_vicino': ('Pulsante della botola · versione A', 'Da vicino: il lampeggiante è giallo quando la piscina è vuota'),
    'pulsante_A_verde': ('Pulsante della botola · versione A', 'Dopo il colpo: la luce diventa verde e la botola si apre'),
    'pulsante_B_spiaggia': ('Pulsante della botola · versione B', 'Cornice a strisce gialle e nere e cartello senza scritte. Dalla cima della spiaggia'),
    'pulsante_B_vicino': ('Pulsante della botola · versione B', 'Da vicino: il cartello mostra il getto che colpisce il pulsante e la botola che si apre'),
    'soppalco_f_da_terra': ('Sala senza soppalco', 'Lo scatto f rifatto da terra (prima era dal soppalco est)'),
    'soppalco_insieme': ('Sala senza soppalco', "Vista d'insieme dall'angolo sud-est, in alto"),
    'transenne': ('Transenne intorno alla medusa', 'Cordone chiuso tutto intorno alla vasca, più un muro invisibile alto 2,5 m sulla stessa linea'),
    'torre_nord_cancello': ('Sala della torre · versione 1 (nord)', 'Cancello a sbarre in fondo alla spiaggia: dietro si vede la torre illuminata'),
    'torre_est_cancello': ('Sala della torre · versione 2 (est)', "Portone scorrevole chiuso con l'insegna della torre, dove oggi c'è la torre"),
    'torre_nord_pianta': ('Sala della torre · versione 1 (nord)', 'Pianta: la sala nuova dietro la parete nord, in asse con la piscina'),
    'torre_est_pianta': ('Sala della torre · versione 2 (est)', "Pianta: la sala nuova dietro la parete est, dall'altra parte della spiaggia"),
}


def main():
    scatti, logs = sys.argv[1], sys.argv[2]
    scelti = sys.argv[3].split(',') if len(sys.argv) > 3 else None
    os.makedirs(USCITA, exist_ok=True)
    for f in sorted(os.listdir(scatti)):
        nome, ext = os.path.splitext(f)
        if ext != '.jpg' or (scelti and nome not in scelti):
            continue
        src = os.path.join(scatti, f)
        out = os.path.join(USCITA, f)
        if nome.startswith('bimbi_'):
            k = nome.split('_')[1]
            titolo, idea = D[k]
            if nome.endswith('_pianta'):
                subprocess.run([sys.executable, os.path.join(QUI, 'pianta_sopra.py'), src, os.path.join(logs, f'proposte_sala_{nome}.log'),
                                'bimbi', out, titolo, idea + '\nVista dall\'alto, senza soffitto'], check=True)
                continue
            img = con_fascia(Image.open(src).convert('RGB'), titolo, 'Da dove arrivi (tappa 4). ' + idea)
        elif nome.endswith('_pianta'):
            titolo, sotto = TITOLI[nome]
            subprocess.run([sys.executable, os.path.join(QUI, 'pianta_sopra.py'), src, os.path.join(logs, f'proposte_sala_{nome}.log'),
                            nome.replace('_pianta', ''), out, titolo, sotto], check=True)
            continue
        else:
            titolo, sotto = TITOLI[nome]
            img = con_fascia(Image.open(src).convert('RGB'), titolo, sotto)
        img.save(out, quality=90)
        print('->', out)


if __name__ == '__main__':
    main()

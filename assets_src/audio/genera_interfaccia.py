"""Suoni dell'interfaccia (menu, cursori, pausa) dai pacchetti CC0 di Kenney (Interface Sounds),
appena ripuliti e normalizzati. Uscita: godot/audio/interfaccia/.
"""
import numpy as np

from comune import kenney, salva
from lib_audio import fade, lp, mix_into, n_of, pitch, trim_silence

CART = 'interfaccia'
FONTE = 'Kenney Interface Sounds (CC0)'


def pulito(nome, semitoni=0.0, taglio=12000):
    x = kenney(nome)
    if semitoni:
        x = pitch(x, semitoni)
    x = lp(x, taglio, 2)
    return fade(trim_silence(x, -55, 0.02), 0.0, 0.01)


def main():
    print('Interfaccia')
    salva(CART, 'ui_clic', pulito('click_001.ogg', -2), loudness=-22, corto=True, qualita=3, fonte=FONTE,
          nota='click_001')
    salva(CART, 'ui_scatto', pulito('toggle_002.ogg', -3, 9000), loudness=-23, corto=True, qualita=3, fonte=FONTE,
          nota='toggle_002')
    salva(CART, 'ui_cursore', pulito('tick_002.ogg', -4, 9000), loudness=-28, corto=True, qualita=3, fonte=FONTE,
          nota='tick_002')
    salva(CART, 'ui_apri', pulito('open_002.ogg', -5, 8000), loudness=-24, corto=True, qualita=3, fonte=FONTE,
          nota='open_002')
    salva(CART, 'ui_chiudi', pulito('close_002.ogg', -5, 8000), loudness=-24, corto=True, qualita=3, fonte=FONTE,
          nota='close_002')
    # pausa: lo scatto dell'interfaccia con un tonfo morbido sotto
    x = np.zeros(n_of(0.4))
    mix_into(x, pulito('switch_002.ogg', -6, 6000), 0)
    salva(CART, 'ui_pausa', fade(x, 0, 0.05), loudness=-24, corto=True, qualita=3, fonte=FONTE, nota='switch_002')


if __name__ == '__main__':
    main()

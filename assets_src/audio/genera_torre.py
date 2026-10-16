"""Suoni della sala della torre (dopo la tappa 8), scelti dall'utente il 16 ottobre fra le proposte
di genera_proposte.py: gli stessi suoni delle anteprime approvate (stesso seme, stessa
normalizzazione; le funzioni stanno in genera_proposte.py, con le versioni scartate).

- portone_torre_apre (motore, proposta A): la serratura che scatta (0 s), il motore che parte, il
  portone pesante che scorre liscio sui rulli da 0,7 s (giunti della rotaia, la lastra che
  rimbomba), sbatte a fine corsa a 6,4 s e il motore si spegne (8,5 s in tutto). Mono, sul portone:
  l'animazione deve seguire questi tempi (vedi PORTONE_PARTE e PORTONE_ARRIVA in audio.gd).
Uscita: godot/audio/torre/.
"""
import numpy as np

import genera_proposte as gp
from comune import salva

CART = 'torre'


def main():
    print('Sala della torre')
    # come in proposta_portone_torre_a.ogg (seme 1608)
    rng = np.random.default_rng(1608)
    salva(CART, 'portone_torre_apre', gp.portone_torre_apre_a(rng), loudness=-14, corto=True, qualita=4,
          nota='motore (A, scelto il 16 ottobre): il portone si muove da 0,7 s e sbatte a 6,4 s')


if __name__ == '__main__':
    main()

"""Palette di prova dell'acquapark (PROPOSTE: la scelta spetta all'utente).

Ogni palette dice come ricolorare le texture CC0 (ambiente_texture.py deriva) e quali
colori usare per i pezzi del kit (ambiente_kit.py). Colori in esadecimale sRGB.

Ricette:
  piastrelle: sorgente CC0 con griglia regolare; ogni piastrella prende un colore a caso da
              'colori' (coppie colore, peso) con una piccola variazione; 'fuga' è il colore delle fughe;
              'sporco' > 1 aggiunge aloni; 'uniforma' (0..1) riduce lo scarto di luminosità tra tessere.
  tinta:      tutta la texture prende il colore, conservando la luminosità (sporco, graffi).
  vernice:    ricolora solo la vernice ('colore'); ruggine o intonaco scoperto restano com'erano.
  originale:  la texture CC0 così com'è.
Opzioni comuni: 'normale' = forza della normal map (fughe più profonde); 'col_da' = usa la texture di
colore di un altro materiale; 'bagnato' (0..1) ed 'extra' = rugosità del velo d'acqua (ORM a parte).
"""

PALETTE = {
    'p1_bianco_turchese': {
        'titolo': 'Opzione 1',
        'sottotitolo': 'Piastrelle bianche e turchesi, fascia rossa',
        'materiali': {
            'parete': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                           colori=[('#e6e9e4', 6), ('#eeeeea', 3), ('#dbe2df', 2)], fuga='#8d8f88', sporco=1.0),
            'fascia': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                           colori=[('#a8221d', 6), ('#9b1d19', 3), ('#b72b22', 2)], fuga='#8d8f88', sporco=1.0),
            'zoccolo': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                            colori=[('#178f96', 6), ('#13848c', 3), ('#1e9ca0', 2)], fuga='#7f8580', sporco=1.3),
            'vasca': dict(ricetta='piastrelle', sorgente='piastrelle_turchesi',
                          colori=[('#1ea7ae', 5), ('#1898a2', 3), ('#36b6b8', 2)], fuga='#b9bfba', sporco=1.4),
            'bordo': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                          colori=[('#e8e6de', 6), ('#dedcd2', 3)], fuga='#8d8f88', sporco=1.6),
            'pavimento': dict(ricetta='tinta', sorgente='antiscivolo', colore='#a9adaa'),
            'intonaco': dict(ricetta='vernice', sorgente='intonaco_scrostato', colore='#d3cfbf'),
            'metallo': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#e2e2dc'),
            'cornice_oblo': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#e2e2dc'),
            'scivolo': dict(ricetta='tinta', sorgente='vetroresina', colore='#c23a24'),
            'scivolo_b': dict(ricetta='tinta', sorgente='vetroresina', colore='#e9e4da'),
        },
        'scivolo_sequenza': ['scivolo', 'scivolo', 'scivolo_b'],
        'cartellone': 'p1',
    },
    'p2_blu_giallo': {
        'titolo': 'Opzione 2',
        'sottotitolo': 'Mosaico blu profondo e giallo',
        'materiali': {
            'parete': dict(ricetta='piastrelle', sorgente='mosaico_blu',
                           colori=[('#0d2f6e', 4), ('#12408f', 3), ('#0a2457', 3), ('#1c55a6', 2)], fuga='#4c5867', sporco=0.9,
                           uniforma=0.6),
            'fascia': dict(ricetta='piastrelle', sorgente='mosaico_blu',
                           colori=[('#e8ad0c', 5), ('#dc9a08', 3), ('#f2c02c', 2)], fuga='#6b6450', sporco=0.9,
                           uniforma=0.85),
            'zoccolo': dict(ricetta='piastrelle', sorgente='mosaico_blu',
                            colori=[('#0a1a3a', 5), ('#0e2348', 3), ('#081631', 2)], fuga='#3d4652', sporco=1.2,
                            uniforma=0.6),
            'vasca': dict(ricetta='piastrelle', sorgente='mosaico_blu',
                          colori=[('#1450a8', 4), ('#0f3f8a', 3), ('#2063b8', 2), ('#0c2f6a', 1)], fuga='#7d8a99', sporco=1.3,
                          uniforma=0.6),
            'bordo': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                          colori=[('#e2a90f', 6), ('#d69a0b', 3)], fuga='#6b6450', sporco=1.6),
            'pavimento': dict(ricetta='tinta', sorgente='antiscivolo', colore='#5f6c7a'),
            'intonaco': dict(ricetta='vernice', sorgente='intonaco_scrostato', colore='#23406e'),
            'metallo': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#e2e2dc'),
            'cornice_oblo': dict(ricetta='originale', sorgente='ottone'),
            'scivolo': dict(ricetta='tinta', sorgente='vetroresina', colore='#e3a90e'),
            'scivolo_b': dict(ricetta='tinta', sorgente='vetroresina', colore='#1f4fa0'),
        },
        'scivolo_sequenza': ['scivolo', 'scivolo', 'scivolo_b'],
        'cartellone': 'p2',
    },
    'p3_pastelli_90': {
        'titolo': 'Opzione 3',
        'sottotitolo': "Pastelli sbiaditi anni '90",
        'materiali': {
            'parete': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                           colori=[('#97c7b8', 5), ('#a3cfc1', 3), ('#8bbcae', 2)], fuga='#a9a597', sporco=1.6),
            'fascia': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                           colori=[('#dc9ca0', 5), ('#d18f95', 3), ('#e6aaa9', 2)], fuga='#a9a597', sporco=1.6),
            'zoccolo': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                            colori=[('#5c8a86', 5), ('#527e7a', 3)], fuga='#8f8b7f', sporco=1.8),
            'vasca': dict(ricetta='piastrelle', sorgente='piastrelle_turchesi',
                          colori=[('#69aea9', 5), ('#78b9b1', 3), ('#5f9f9d', 2)], fuga='#b3b0a3', sporco=1.8),
            'bordo': dict(ricetta='piastrelle', sorgente='piastrelle_bianche',
                          colori=[('#e3d8bf', 6), ('#d8ccb2', 3)], fuga='#a9a597', sporco=1.8),
            'pavimento': dict(ricetta='tinta', sorgente='antiscivolo', colore='#c4ab95'),
            'intonaco': dict(ricetta='vernice', sorgente='intonaco_scrostato', colore='#e0d3a2'),
            'metallo': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#7fb0a9'),
            'cornice_oblo': dict(ricetta='originale', sorgente='ottone'),
            'scivolo': dict(ricetta='tinta', sorgente='vetroresina', colore='#de9aa3'),
            'scivolo_b': dict(ricetta='tinta', sorgente='vetroresina', colore='#7cbfb5'),
            'scivolo_c': dict(ricetta='tinta', sorgente='vetroresina', colore='#e8d48e'),
        },
        'scivolo_sequenza': ['scivolo', 'scivolo_b', 'scivolo_c'],
        'cartellone': 'p3',
    },
}

# Palette della SALA PRINCIPALE (vertical slice): scelta come la più vicina al concept A e allo
# storyboard. È l'Opzione 1 adattata: piastrelle bianche sporche, fascia rossa scura, vasca turchese,
# intonaco grigio-verde scrostato, scivoli multicolori sbiaditi, giochi colorati, torre arrugginita.
PALETTE['sala_a'] = {
    'titolo': 'Sala principale',
    'sottotitolo': 'Opzione 1 adattata al concept A',
    'materiali': dict(PALETTE['p1_bianco_turchese']['materiali']),
    'scivolo_sequenza': ['scivolo', 'scivolo_b', 'scivolo_c', 'scivolo_d'],
    'cartellone': 'p1',
    'cartelloni': ['p1', 'p2', 'p3'],
}
PALETTE['sala_a']['materiali'].update({
    'parete': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_bianche',
                   colori=[('#d9ddd5', 6), ('#e2e3dc', 3), ('#cdd4cf', 2)], fuga='#7f827a', sporco=1.7),
    'fascia': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_bianche',
                   colori=[('#8e2a22', 6), ('#7f241e', 3), ('#9c3326', 2)], fuga='#7f827a', sporco=1.6),
    'zoccolo': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_bianche',
                    colori=[('#1f6f73', 6), ('#1a6469', 3), ('#277a7c', 2)], fuga='#6f7570', sporco=1.9),
    'vasca': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_turchesi',
                  colori=[('#2a9ea5', 5), ('#228f98', 3), ('#3fb0b2', 2)], fuga='#aeb5b0', sporco=1.9),
    'vasca_bimbi': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_turchesi',
                        colori=[('#4fb8c0', 5), ('#62c3c6', 3), ('#3aa7b0', 2)], fuga='#b8bdb8', sporco=1.7),
    'scacchi': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_bianche', schema='scacchi',
                    colori=[('#1d4f9a', 1), ('#e4e4dc', 1)], fuga='#8a8d86', sporco=1.6),
    'bordo': dict(ricetta='piastrelle', normale=1.6, sorgente='piastrelle_bianche',
                  colori=[('#dedcd2', 6), ('#d2d0c4', 3)], fuga='#85877f', sporco=2.0),
    'pavimento': dict(ricetta='tinta', sorgente='antiscivolo', colore='#6f7773', sporco=0.8, bagnato=0.9),
    # stesse piastrelle, più o meno bagnate (assegnate piastrella per piastrella dalla sala)
    'pavimento_bagnato': dict(ricetta='tinta', sorgente='antiscivolo', colore='#6f7773', col_da='pavimento',
                              bagnato=1.0, extra=0.42, normale=0.45),
    'pavimento_asciutto': dict(ricetta='tinta', sorgente='antiscivolo', colore='#6f7773', col_da='pavimento',
                               bagnato=0.2, normale=1.15),
    'intonaco': dict(ricetta='vernice', sorgente='intonaco_scrostato', colore='#a7b3a6'),
    'intonaco_alto': dict(ricetta='vernice', sorgente='intonaco_scrostato', colore='#7d8b84'),
    'metallo': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#d9dbd4'),
    'cornice_oblo': dict(ricetta='originale', sorgente='ottone'),
    'ferro_cupola': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#3d4846'),
    'torre': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#8a3a26'),
    'scivolo': dict(ricetta='tinta', sorgente='vetroresina', colore='#a8452f', sporco=1.0),
    'scivolo_b': dict(ricetta='tinta', sorgente='vetroresina', colore='#58833d', sporco=1.0),
    'scivolo_c': dict(ricetta='tinta', sorgente='vetroresina', colore='#2f5a8e', sporco=1.0),
    'scivolo_d': dict(ricetta='tinta', sorgente='vetroresina', colore='#c49a30', sporco=1.0),
    'gioco_blu': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#2c6aa6'),
    'gioco_rosso': dict(ricetta='vernice', sorgente='metallo_verniciato', colore='#b03a2a'),
    'gioco_giallo': dict(ricetta='tinta', sorgente='vetroresina', colore='#e0ae2e'),
    'gioco_verde': dict(ricetta='tinta', sorgente='vetroresina', colore='#3f9a8c'),
    'gioco_arancio': dict(ricetta='tinta', sorgente='vetroresina', colore='#d8702a'),
    'piedistallo': dict(ricetta='piastrelle', sorgente='mosaico_blu', uniforma=0.6, normale=1.4,
                        colori=[('#16478f', 4), ('#1d5aa8', 3), ('#0f3a78', 2), ('#d9c48a', 1)], fuga='#7b8794', sporco=1.4),
})

# materiali uguali in tutte le palette (texture CC0 così come sono)
COMUNI = {
    'inox': dict(ricetta='originale', sorgente='acciaio_inox'),
    'plastica': dict(ricetta='originale', sorgente='plastica_bianca'),
}


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

# Bambini: proposte in 3D

Due "creature minori", i bambini cresciuti dalla medusa. Le forme seguono i disegni dati dall'utente; materiali e dettagli sono marittimi, come la "madre": fuori plastica, neoprene e stoffa bagnata, dentro tessuto vivo e traslucido. Sono sempre coperti del tutto.

Sono modelli 3D veri, renderizzati in Blender (Cycles), senza immagini 2D. Le scene usano l'angolo dell'acquapark del kit dell'ambiente: piastrelle, oblò, scaletta della piscina, luci rosse d'emergenza, neon, nebbia bassa, pozzanghere. Cubo e agnellino stanno nello stesso punto e hanno la stessa inquadratura.

Scelte dell'utente:
- il cubo è di piastrelle;
- gli occhi dentro il cubo sono gialli;
- l'agnellino rivelato è quello con l'occhio unico;
- il corpo del cubo andava rifatto, perché era "troppo pacioccone".

## Immagini

- `cubo_3d.jpg`: la testa a cubo con il corpo nuovo, travestita e rivelata nell'acquapark di notte, più le viste da studio (davanti, tre quarti, dietro).
- `agnello_3d.jpg`: l'agnellino travestito e rivelato con l'occhio unico nell'acquapark di notte, più le viste da studio.
- `render/cubo_travestito_acquapark.jpg`, `render/cubo_rivelato_acquapark.jpg`: il cubo a 1600x900.
- `render/agnello_travestito_acquapark.jpg`, `render/agnello_occhio_acquapark.jpg`: l'agnellino a 1600x900.
- `render/*_studio.jpg`: le viste da studio, una tavola per stato.
- `alternative/agnello_lupo_studio.jpg`: l'agnellino con la testa di lupo, tenuto come alternativa.
- `scartati/cubo_corpo_v1/`: i render del primo corpo del cubo, che non si cancellano.

## I due bambini

**Testa a cubo** (1,2 m). Ha il corpo di un bambino magro di 7-9 anni: spalle strette, braccia e gambe sottili e un po' troppo lunghe, postura un po' curva e testa inclinata, immobile. Indossa una vecchia muta da sub consumata, di neoprene satinato e bagnato. La muta ha cuciture, ginocchiere, piccoli strappi con la fodera chiara, la cerniera sulla schiena, guanti e calzari da sub e qualche filo d'alga. Al posto della testa ha un cubo di piastrelle da piscina crepate, con salsedine, alghe, cirripedi e ruggine. Sul davanti c'è la faccina a pennarello. Quando si rivela, il cubo si spacca. Da dentro esce una massa di tentacoli rosa e magenta, traslucidi e luminosi come la campana della medusa, piena di occhi gialli.

**Agnellino** (1,2 m). È un peluche cucito a mano, zuppo e macchiato di sale e di alghe, con le cuciture a croce e una toppa di asciugamano a righe. Ha i bottoni d'ottone come occhi e il fiocco rosso alla marinara con un'ancorina. Quando si rivela, il muso si spacca lungo la cucitura e dentro c'è un unico grande occhio. L'iride è quella della madre: la stessa texture della medusa, rosa a raggi, con l'anello magenta e le punte. La sclera è bianca e lucida e sfuma nella membrana rosa.

## Modelli

Tutti i modelli sono GLB a misura reale, con i piedi a terra e lo sguardo verso +Z (glTF).

- `assets_src/bambini/*.glb`: le versioni dettagliate, da 150 mila facce. Ci sono `cubo_calmo`, `cubo_rivelato`, `agnello_calmo` e `agnello_occhio`.
- `assets_src/bambini/game/*.glb`: le versioni per il gioco, con gli stessi nomi. Hanno 25 mila triangoli e texture 2K cotte dal modello di Meshy (colore, metallo/rugosità, normali), senza fessure.
  - Nell'agnellino l'occhio è un oggetto a parte (`occhio_bulbo`): spostando le sue UV in uno shader, lo sguardo può seguire il giocatore.
- `assets_src/bambini/alternative/`: l'agnellino con la testa di lupo, anche in versione gioco.
- `assets_src/bambini/scartati/cubo_corpo_v1/`: il primo corpo del cubo.
- `assets_src/bambini/tex/agnello_occhio_bulbo.png`: la texture dell'occhio dell'agnellino.
- Sono generati con Meshy (meshy-7.1, multi-view); in `meshy_log.json` ci sono prompt e task. Non hanno ancora lo scheletro.

Gli script stanno in `tools/blender/bambini_*.py`:

- `bambini_meshy.py` genera i modelli;
- `bambini_esporta.py` crea le versioni dettagliate;
- `bambini_gioco.py` crea le versioni per il gioco, con il bake;
- `bambini_occhio.py` fa l'occhio dell'agnellino;
- `bambini_scena.py` fa i render nell'acquapark;
- `bambini_render.py` fa quelli in studio;
- `bambini_tavole.py` compone le tavole.

## Domande per l'utente

1. Il nuovo corpo del cubo, magro e in muta, va bene? Lo vuoi ancora più magro o più curvo?
2. L'occhio dell'agnellino va bene così, uguale a quello della madre? Oppure lo vuoi diverso, per esempio che brilla o che segue il giocatore?
3. Quanti bambini ci sono nel capitolo 1, e dove li vede il giocatore?
4. Passo allo scheletro e alle animazioni: camminata, testa che si apre, sguardo che segue il giocatore?

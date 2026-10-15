# Bambini: proposte in 3D

Due "creature minori", i bambini cresciuti dalla medusa. Le forme seguono i disegni dati dall'utente; materiali e dettagli sono marittimi, come la "madre": fuori plastica, vinile e stoffa bagnata, dentro tessuto vivo e traslucido. Sono sempre coperti del tutto.

Sono modelli 3D veri, renderizzati in Blender (Cycles), senza immagini 2D. Le scene usano l'angolo dell'acquapark del kit dell'ambiente: piastrelle, oblò, scaletta della piscina, luci rosse d'emergenza, neon, nebbia bassa, pozzanghere.

## Immagini

- `cubo_3d.jpg`: la testa a cubo, travestita e rivelata nell'acquapark di notte, più le viste da studio (davanti, tre quarti, dietro) dei due stati.
- `agnello_3d.jpg`: l'agnellino travestito nell'acquapark di notte, più le viste da studio del travestito e del rivelato con la testa di lupo.
- `render/cubo_travestito_acquapark.jpg`: il cubo travestito sul bordo della piscina (1600x900).
- `render/cubo_rivelato_acquapark.jpg`: il cubo rivelato, con la stessa inquadratura (1600x900).
- `render/agnello_travestito_acquapark.jpg`: l'agnellino travestito, con la stessa inquadratura (1600x900).
- `render/*_studio.jpg`: le viste da studio, una tavola per stato.

Non sono ancora renderizzati, ma i modelli ci sono: l'agnellino rivelato nell'acquapark (lupo e occhio unico), la variante del cubo con gli occhi rosa e i giri completi nell'acquapark. La macchina serviva alla build: li faccio appena è libera.

## I due bambini

**Testa a cubo** (1,2 m). È una creaturina d'ombra tozza, con il corpo nero lucido e bagnato come una muta da sub e qualche alga attaccata. Al posto della testa ha un cubo di piastrelle da piscina crepate, con salsedine, alghe, piccoli cirripedi e ruggine. Sul davanti c'è la faccina disegnata a pennarello. Quando si rivela, il cubo si spacca. Da dentro esce una massa di tentacoli rosa e magenta, traslucidi e luminosi come la campana della medusa, piena di occhi gialli. Resta un pezzo della faccina.

**Agnellino** (1,2 m). È un peluche cucito a mano, zuppo e macchiato di sale e di alghe, con le cuciture a croce e una toppa di asciugamano a righe. Ha i bottoni d'ottone come occhi e il fiocco rosso alla marinara con un'ancorina. Quando si rivela, la testa d'agnello si apre e ricade come un cappuccio. Da sotto esce una testa nera da lupo con tratti da pesce degli abissi: pelle lucida, branchie, puntini luminosi, file di denti da squalo. Nella variante, il muso si spacca lungo la cucitura e dentro c'è un unico grande occhio rosa, come quello della madre.

## Modelli

Tutti i modelli sono GLB a misura reale, con i piedi a terra, lo sguardo verso +Z (glTF) e texture PBR 2K (colore, metallo/rugosità, normali).

- `assets_src/bambini/*.glb`: le versioni dettagliate, con 150 mila facce (12-15 MB): `cubo_calmo`, `cubo_rivelato`, `agnello_calmo`, `agnello_lupo`, `agnello_occhio`.
- `assets_src/bambini/game/*.glb`: le versioni leggere per il gioco, con 25 mila triangoli (8-10 MB, quasi tutto texture), con gli stessi nomi.
- Sono generati con Meshy (meshy-7.1, multi-view); in `meshy_log.json` ci sono prompt e task. Non hanno ancora lo scheletro.

Gli script stanno in `tools/blender/bambini_*.py`:

- `bambini_meshy.py` genera i modelli;
- `bambini_esporta.py` crea i GLB del repo e quelli per il gioco (`--facce 25000 --cartella game`);
- `bambini_scena.py` fa i render nell'acquapark;
- `bambini_render.py` fa quelli in studio;
- `bambini_tavole.py` compone le tavole.

## Domande per l'utente

1. Il cubo va bene di piastrelle da piscina, o lo preferisci di gommapiuma galleggiante?
2. Gli occhi della massa li vuoi gialli, come nel disegno, o rosa, come la medusa?
3. Per l'agnellino preferisci la testa di lupo, l'occhio unico, o tutte e due? Potrebbero essere due momenti diversi, oppure due bambini diversi.
4. Il corpo del cubo ti piace nero lucido e liscio, o lo vuoi più da muta, con cuciture e cerniera?
5. Quanti bambini ci sono nel capitolo 1, e dove li vede il giocatore?
6. Se ti piacciono, passo allo scheletro e alle animazioni: camminata, testa che si apre, sguardo che segue il giocatore.

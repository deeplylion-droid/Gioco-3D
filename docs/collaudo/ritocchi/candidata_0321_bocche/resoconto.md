# Ricontrollo per la 0.3.21: le bocche dell'inseguimento rifatte da ambienti-2

Squadra collaudo, 6 novembre. Il controllo è sulla prova d'insieme `lavoro/candidata-0321` 412daf44, che contiene `lavoro/ritocchi-ambienti2` 8bd37b1c. Le prove d'immagine le ho rifatte anche su 8bd37b1c da solo: gli scatti sono **identici pixel per pixel**, quindi tutto quello che segue vale anche per 8bd37b1c. Nel gioco non ho cambiato niente.

## In breve
- **Riga verde nel tubo 3: sparita.** Non c'è nella posa indicata e non c'è nemmeno entrando e scivolando dentro.
- **Colore della parete d'acqua da dentro: uguale in tutte e sei**, verde-azzurro (RGB circa 4, 21-25, 23-24). Prima era verde in alcune bocche e quasi nero in altre.
- **Piastrelle dietro la parete: ancora visibili, come prima.** Il dettaglio misurato non cambia. Nei tubi 2 e 3 le piastrelle illuminate del fondo si vedono bene, nello scolo 1 si vede la griglia. Il punto "niente piastrelle nitide dietro" quindi **non è risolto**: è da girare ad ambienti-2.
- **Dalla vasca va bene.** Il retro delle pareti non fa luce e l'acqua è come prima. Nei tre tubi c'è appena un po' più d'ombra, per le lampade verdi.
- **Paratie verdi dalla vasca: come prima.** Il 3-4% dei pixel è un po' più scuro, dove adesso cade l'ombra.
- **Prestazioni.**
  - Le ombre delle tre lampade verdi costano dal 2 al 15% del tempo del fotogramma, a seconda di dove si guarda.
  - Nel campo visivo ci sono fino a 42 luci con ombra insieme. Fra queste, al più qualcuna delle tre verdi.
- **Unione fatta a mano** in `sala_inseguimento.gd` (il cuore e `occhi_pelo`):
  - test_inseguimento_suoni 24 ok: nelle condotte il cuore si sente solo quando lei è su;
  - test_occhio_sopra_acque 106 ok;
  - le due righe stanno prima del return di is_dying/_sb1.

## Test sulla candidata (0 BUG, 0 SCRIPT ERROR)
| test | esito |
|---|---|
| test_occhio_sopra_acque | 106 ok |
| test_inseguimento_suoni | 24 ok (lei sotto l'acqua: niente cuore; sale in una vasca: il cuore parte subito; tornata sotto: tace; nelle condotte niente colpi bassi) |
| test_inseguimento | 43 ok |
| test_morbidezza_inseguimento | 72 ok |
| test_scaletta_bacino | 13 ok |

## Le bocche viste da dentro
Ho usato lo strumento di ambienti-2, `scatti_bocche_da_sotto.gd confronto`, con `PRIMA=1` e senza, sulla stessa build. Il foglio è `fogli/bocche_prima_dopo.jpg`. Dentro il tubo a 1 m, girato verso la vasca, nel riquadro sotto il pelo ho misurato il colore medio e il dettaglio (la differenza media dall'immagine sfocata: più è alto, più le piastrelle si vedono nitide).

| bocca | prima: colore (RGB), dettaglio | dopo: colore (RGB), dettaglio |
|---|---|---|
| scolo_0 | 2 6 4, 0,7 | 4 21 23, 0,6 |
| scolo_1 | 3 4 4, 0,9 | 4 21 23, 0,9 |
| scolo_2 | 7 26 14, 0,2 | 4 25 24, 0,2 |
| tubo_1 | 3 15 6, 0,8 | 3 21 23, 0,8 |
| tubo_2 | 7 14 7, 2,0 | 8 23 24, 1,8 |
| tubo_3 | 6 14 6, 1,8 | 7 21 23, 1,7 |

- Il colore adesso è lo stesso in tutte e sei.
- Il dettaglio resta quello di prima: la luce propria colora la parete, ma non la rende meno trasparente.
- Nei tubi 2 e 3 si vedono bene le piastrelle del fondo della vasca, con le macchie di luce. Nello scolo 1 si vede la griglia delle piastrelle.
- Per toglierle bisognerebbe rendere la parete più piena, non solo più chiara. È da decidere con ambienti-2 e l'utente.

Gli stessi scatti col giocatore che entra (`vista_bacino.gd bocche`), girati verso la vasca a 1,2, 1,8 e 2,4 m e al primo fotogramma sotto il pelo, mostrano la stessa cosa. In nessuno si vede la superficie da sotto.

## Dalla vasca
Ho confrontato i 13 scatti per ogni bocca, dalla vasca fino alla parete, con quelli del giro di prima su 7cb9d82b: stesse pose e stesso strumento.

| bocca | luminosità media prima, dopo | differenza media | pixel cambiati (> 8) al massimo |
|---|---|---|---|
| tubo_1 | 18,1, 16,8 | 1,57 | 5,6% |
| scolo_0 | 17,9, 17,8 | 0,24 | 0,3% |
| tubo_2 | 22,3, 20,7 | 1,80 | 3,5% |
| scolo_1 | 13,8, 13,7 | 0,17 | 0,3% |
| tubo_3 | 18,2, 16,3 | 2,13 | 6,4% |
| scolo_2 | 24,9, 24,9 | 0,00 | 0,0% |

- Negli scoli non cambia niente. Nei tubi c'è un po' più di scuro, cioè le ombre nuove delle lampade verdi.
- Il retro delle pareti non si illumina.
- L'acqua delle vasche è quella di prima (foglio `fogli/tubo_1_dalla_vasca.jpg`).

## Riga verde nel tubo 3
- **Posa ferma** (65,29, -27,92, -3,15) che guarda verso (0,98, 0,15, 0,15): la riga c'è prima e non c'è dopo (`fogli/paratie_riga_prima_dopo.jpg`, in basso).
- **Scivolando dentro**, girati verso la vasca a 1,29 e 1,35 m (`fogli/tubo_3_girati.jpg`) e a 1,32 e 1,62 m (`fogli/striscia_tubo_3_dopo.jpg`, con e senza le luci verdi): niente riga.
- A 2,67 m resta solo un piccolo riflesso verde in alto a sinistra. Si vede solo schiarendo l'immagine 6 volte, e prima c'era già, più grande. Credo sia il bordo della bocca illuminato: non è la riga.

## Paratie verdi dalla vasca
Il foglio è `fogli/paratie_riga_prima_dopo.jpg`: le paratie verdi 0, 2 e 4, di fronte e verso la bocca.
- Di fronte, la differenza media è 1,8-1,9 e il 3-4% dei pixel è un po' più scuro: è l'ombra nuova sul muro e sulla struttura.
- Verso la bocca la differenza media è 0,4-0,5.
- La luce verde e il bersaglio sono uguali a prima.

## Prestazioni delle ombre nuove
Ho usato `sonda_ombre.gd`: Vulkan su llvmpipe, 960x540, sulla stessa macchina e nelle stesse pose. Per ogni posa: 60 fotogrammi dopo 30 di assestamento, due giri alternati con le ombre delle tre lampade verdi accese e spente. Le righe complete sono in `ombre.txt`.

| posa | luci con ombra nel campo visivo | con le ombre verdi | senza | costo |
|---|---|---|---|---|
| paratia verde 0 | 30 | 943-986 ms | 850-854 ms | +11-15% |
| paratia verde 2 | 42 | 1524-1574 ms | 1483-1487 ms | +3-6% |
| paratia verde 4 | 39 | 2031-2035 ms | 1982-1997 ms | +2-3% |
| tubo 3 da dentro | 11 | 719-727 ms | 658-660 ms | +10% |
| punto peggiore della griglia (vasca C1) | 30 | 960-962 ms | 855-889 ms | +8-12% |

- Nella scena ci sono 48 luci con ombra, di cui 26 omni. Le tre verdi sono a (54,55, -18,35, -16,4), (67,0, -21,35, -25,45) e (66,95, -24,35, -3,6).
- Il conteggio "nel campo visivo" è generoso: conta ogni luce con ombra la cui sfera tocca il campo visivo. Il punto con più luci è davanti alla paratia verde 2, con 42.
- Su llvmpipe un fotogramma intero dura 0,7-2 s. Contano solo le proporzioni: le tre ombre aggiungono dal 2 al 15% del tempo di disegno.
- Sul PC dell'utente, con una scheda vera, il costo in millisecondi sarà molto più piccolo, ma va guardato col contatore F3 nella zona delle vasche.

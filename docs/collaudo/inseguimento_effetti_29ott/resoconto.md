# Collaudo dell'inseguimento con cuore, ritmo ed effetti (29 ottobre, notte)

Squadra collaudo. `lavoro/godot` **e80c72d4**: cuore e ritmo (canto-inseguimento), effetti di grafica-2 (inseguimento-effetti 5410d698), tecnica-0316, Polaroid, inglese.

**Esito:**
- Gli effetti fanno quello che devono, il cuore e il ritmo seguono lei, e nel giro non ci sono state prese.
- Da guardare:
  - 10-15 compilazioni di pipeline alla prima curva dell'inseguimento, più 1-2 sparse;
  - il cuore che, coi livelli tarati, arriva al livello del canto invece che sotto (stima dai file: va ascoltato).

## Come

`godot/tests/collaudo/sonda_effetti.gd` (estende `partita_tunnel.gd`) gioca la partita intera del tunnel col renderer vero, nella scena di prova: SB1, la scaletta, la corsa, i getti, le gallerie, l'approdo e il portello. A ogni fotogramma registra:
- ogni battito del cuore, colpo del ritmo e frase del canto quando parte, con la distanza di lei;
- i bordi scuri, la luce rosa e il tremito della camera;
- le pipeline compilate.

Un secondo giro (dal tunnel) ha l'oscillazione della camera spenta, come nelle opzioni.

## Risultati

**La partita.** 5 attraversamenti, le 2 gallerie da accovacciati, approdo, portello, schianto e nero. 8 morsi a vuoto, 6 getti, 6 respinte, **0 prese**. Lo stesso nel giro senza oscillazione.

**Cuore e ritmo** (`log/suoni.csv`):

| | Lei vicina (sotto 10 m) | Lei lontana (oltre 14 m) |
|---|---|---|
| Cuore: un battito ogni | 0,54 s (111 al minuto) | 0,73 s (82 al minuto) |
| Ritmo: un colpo ogni | 0,59 s | 1,46 s |

- **Niente giri uguali:**
  - gli intervalli del ritmo vanno da 0,15 a 2,75 s (scarto 0,53 s), con i colpi doppi;
  - quelli del cuore vanno da 0,48 a 0,83 s e cambiano piano con la distanza;
  - il canto parte ogni 3,2-4,6 s, 29 frasi.
- **Si fermano quando devono.** Cuore e ritmo suonano solo con lei che insegue (223 battiti) o si ritrae dal getto (24, più lenti). L'ultimo battito è a 168,6 s; lei smette di inseguire a 168,7 s, quando sbatte sul portello. Dopo, niente.
- **Volumi, stima dai file e dalla taratura (da ascoltare):**
  - tutti e tre hanno 0 dB di taratura;
  - il cuore va da -9 a 0 dB con la vicinanza, sul bus Interfaccia; il ritmo da -9 a 0 dB, su Effetti;
  - il canto viene dalla bocca di lei in 3D (unit_size 3 m);
  - picchi dei file: cuore -16,5 dB, ritmo -20 dB, canto -9,3 dB.

  | Lei a | Canto (picco, attenuato dalla distanza) | Cuore (picco) | Ritmo (picco) |
  |---|---|---|---|
  | 8 m | ≈ -17,8 dB | ≈ -17 dB | ≈ -20 dB |
  | 18 m | ≈ -24,9 dB | ≈ -25,5 dB | ≈ -29 dB |

  - Il ritmo sta 2-4 dB sotto il canto. Il cuore invece arriva più o meno al livello del canto.
  - Il canto è una frase lunga (media -22 dB), il cuore è un colpo corto (media -28 dB): all'orecchio il canto può restare sopra. Qui l'audio non si sente: **va ascoltato**.

**Effetti** (`log/effetti.csv.gz`):
- **Bordi scuri:**

  | Lei a | Alfa medio |
  |---|---|
  | sotto 5 m | 0,51-0,54 (massimo 0,6) |
  | 5-8 m | 0,15 |
  | 8-14 m | 0,02 (scendono piano dopo un getto) |
  | oltre 14 m | 0,005 |
  | lei ferma | 0 |
- **Luce rosa:** accesa in tutti i fotogrammi con lei che insegue, mai senza di lei. L'energia va da 11,6 (lontana) a 19 (vicina). Negli scatti, con lei a 3 m, il pavimento e l'acqua davanti sono tinti (`fogli/lei_vicina_e_lontana.jpg`). Sulle piastrelle blu il rosa si vede violetto.
- **Mirino, lancia e serbatoio:** i bordi scuri sono solo ai lati, e il mirino e la lancia col serbatoio restano chiari.
- **Tremito:** 8 episodi da 0,27 s, ognuno allo stesso istante di uno degli 8 morsi, e mai fuori. Con l'oscillazione della camera spenta, 0 fotogrammi con la camera girata, con 8 morsi.

**Compilazioni di pipeline:**

| Giro | All'avvio (prima di lei) | All'uscita di lei | A metà inseguimento |
|---|---|---|---|
| Intero | 333 | 8 | **10 a 20,4 s** (lei a 16 m, mentre si passa la prima curva e le condotte si liberano), 1 a 26,9 s, 1 a 38,1 s |
| Senza oscillazione | | | **15 a 9,1 s** (lei a 14,5 m, la stessa prima curva), 1 a 18,1 s, 1 a 28,3 s |

Le compilazioni alla prima curva vengono con la liberazione delle condotte, più probabilmente che dagli effetti. Su una GPU vera possono essere uno scatto.

**Log:** 0 righe "ERROR: BUG,", 0 SCRIPT ERROR, in tutti e due i giri.

## Non verificato

- L'audio a orecchio: qui non si sente. I livelli sono stimati dai file.
- Il tunnel nella sala intera col renderer vero: non entra in memoria. Il giro è nella scena di prova.

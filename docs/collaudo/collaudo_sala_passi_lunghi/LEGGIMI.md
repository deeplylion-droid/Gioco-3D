# Ricontrollo dei passi lunghi della sala, #147 (ambienti-1, 9 novembre)

- Base: `lavoro/sala-passi-lunghi` `4e9551c8` di ambienti-2, confrontato con `6aaa8373` (torre-fotogrammi).
- La modifica:
  - `Posa.mesh_vicine(nodo, zona)` elenca una volta per lampada le mesh il cui riquadro tocca la zona dei 9 raggi;
  - `Posa._raggio` le prende come `candidate` facoltativo;
  - solo `SalaTorre._emergenza` le passa: gli altri usi di Posa fanno la stessa strada di prima.

## Esito

**Il risultato è identico. Il tempo migliora molto, ma i passi delle prime lampade non stanno sempre sotto i 16 ms.**

Le 7 lampade sono accese e attaccate. Due casi, però, c'erano già prima di questa modifica e restano da correggere a
parte:
- dal portone, le lampade 0 e 4 entrano nel muro di torre_A;
- dopo F9, una morte o Continua, la lampada 5 entra di 1,7 cm in un tubo.

| Punto | Esito |
|---|---|
| 1. Stesso risultato per tutti gli usi di Posa | **sì** |
| 2. Le 7 lampade dagli occhi e da vicino | accese, attaccate; **due casi vecchi** (sotto) |
| 3. Passi delle lampade sotto i 16 ms | **no per le prime 1-3**: 16,5-19,6 ms; le altre 10-16 ms |
| 3. test_attesa_zone 5 volte di fila | **5 su 5 verdi**, peggior fotogramma 41-51 ms |
| 4. Ripartenze | **ok**: F9 torre, morte con cache piena e vuota, Continua |
| 5. test_posa, test_sala, test_torre, test_torre_pezzi_uguali | **verdi**: 14, 107, 95, 10 controlli |

### 1. Stesso risultato

**Tutta la sala, dopo che la torre si è costruita nel gioco vero** (`godot/tests/collaudo/posa_prima_dopo.gd`):
- il percorso è quello del gioco: acquari comparsi, enigma risolto, portone aperto;
- poi si scrive la posizione nel mondo di ogni Node3D fuori dal giocatore: 8210 nodi, al decimo di millimetro;
- confronto fra 4e9551c8 e 6aaa8373: le 7 lampade sono identiche;
- fra le due versioni cambiano 62 nodi, senza contare i nomi automatici:
  - sono solo cose che si muovono da sole: medusa, giocattoli dell'enigma, luci della sala che lampeggiano,
    interattivi, lampeggiante, gocce;
  - fra due giri dello stesso codice ne cambiano 63, delle stesse cose;
  - nella torre non cambia niente.

**Il controllo di posizionamento** (`controllo_posizionamento.gd`) su 4e9551c8:
- 0 da correggere;
- il rapporto è identico a quello di main, cambia solo la data. Non l'ho salvato.

**test_torre_pezzi_uguali** è 10 su 10 (252 raggi, 0 diversi).

**Nel codice:**
- `mesh_vicine` usa il riquadro di ogni mesh, allargato di 1 cm, contro la zona dei 4 raggi d'angolo. Il raggio di
  centro e quelli sui lati stanno dentro;
- `_raggio_mesh` poi fa gli stessi filtri di prima (visibile, non figlia della lampada). Per costruzione il risultato
  non può cambiare.

### 2. Le 7 lampade (fogli 1-3)

Lo strumento è `godot/tests/collaudo/scatti_lampade_emergenza.gd`:
- la sala della torre da sola, con l'ambiente della sala grande;
- per ogni lampada uno scatto dagli occhi (1,6 m sopra il pavimento, 2,5 m davanti);
- tre scatti a 45 cm, di taglio lungo il muro;
- 25 raggi dal retro della scatola verso il muro, per misurare il contatto.

Tutte e 7 sono accese, con la loro luce rossa. Le posizioni però dipendono da come si arriva nella torre, e questo
**c'era già con 6aaa8373**: `sonda_lampade_ripartenza.gd` dà le stesse posizioni col codice di prima e con quello
nuovo.

- **Dal portone** (il gioco di fila): la torre si costruisce nascosta.
  - `SalaPrincipale._prepara_torre` la mette con `visible = false`, e `Posa._raggio_mesh` salta le mesh non visibili;
  - le lampade quindi si appoggiano solo alla collisione e ai muri della sala;
  - lampada 0 a x 20,305 e lampada 4 a x 20,28: il retro sta **15 mm e 40 mm dentro il muro di torre_A** (x 20,24);
  - lampada 5 a x 39,92, sul muro, con il tubo orizzontale appena sopra.
- **Dopo F9, una morte o Continua**: la torre si costruisce visibile.
  - lampade 0 e 4 a x 20,32, appoggiate a torre_A a 0 mm;
  - **la lampada 5 sta a x 39,43, davanti al tubo che corre sul muro**: il tubo entra di **16,6 mm** nel fondo della
    scatola (3 raggi su 25), e fra il retro della scatola e il muro restano circa 49 cm.
- Le lampade 1, 2, 3 e 6 sono uguali nei due casi, appoggiate a 0 mm, e nessun raggio entra nella scatola.

Proposta, da decidere con ambienti-2 (non è di questa modifica):
- costruire le lampade guardando anche le mesh della torre nascosta (per esempio un'opzione di Posa che non salta le
  mesh nascoste della propria zona);
- per la lampada 5, scegliere fra tubo e muro, e spostarla dove la scatola non entra nel tubo.

### 3. Tempi (`TORRE_TEMPI=1`, test_attesa_zone 5 volte di fila)

| Giro | Lampade, fissa_al_muro + 9 raggi (ms) | Peggior fotogramma |
|---|---|---|
| 1 | 17,8 14,3 10,3 10,7 9,9 10,3 10,0 | 51 ms |
| 2 | 19,4 16,3 14,3 11,4 11,0 10,2 10,7 | 46 ms |
| 3 | 19,6 17,7 16,2 14,7 12,3 12,6 12,0 | 49 ms |
| 4 | 17,2 13,8 11,1 11,7 10,9 11,1 10,2 | 48 ms |
| 5 | 16,5 12,4 10,7 10,6 10,1 10,7 10,4 | 41 ms |

- I 9 raggi costano 4,5-7,6 ms; **fissa_al_muro da solo 5-10 ms**. Fa un raggio con `Posa._raggio` senza
  `candidate`, quindi scorre ancora tutte le 2200 mesh.
- In più c'è "contarle", 3-4,6 ms: è solo la stampa di `TORRE_TEMPI`, nel gioco non c'è.
- Per stare sempre sotto i 16 ms basterebbe dare le mesh vicine anche al raggio di fissa_al_muro, che sta nella
  stessa zona. Si possono calcolare una volta prima di fissa_al_muro, con la zona allargata alla sua portata.
- Tutti i 5 giri sono verdi: nessun fotogramma sopra 100 ms.

### 4. Ripartenze (`godot/tests/collaudo/ripartenze_lampade.gd`, 18 su 18)

I casi:
- F9 torre;
- morte in torre con la cache dei varchi piena;
- morte in torre con la cache vuotata (`SalaInseguimento._varco_cache.clear()`);
- Continua dalla torre (salvataggio su disco, checkpoint `SalaTorre/Checkpoint_portone`).

In tutti e quattro:
- la torre è costruita;
- ci sono 7 lampade e le loro luci rosse;
- le lampade stanno nelle stesse posizioni della prima costruzione;
- nessun passo lungo della torre.

Verdi anche `test_portone_torre` (20), `test_ripartenza_oltre_portone` (53), `test_partenze_prova` (72) e
`test_continua` (127).

## File

- `fogli/1_lampade_0-3_f9.jpg` e `fogli/2_lampade_4-6_f9.jpg`: le 7 lampade come dopo F9, una morte o Continua. Per
  ognuna lo scatto dagli occhi e quelli da sinistra, da destra e da sopra, a 45 cm.
- `fogli/3_lampade_0_4_5_dal_portone.jpg`: le tre lampade che cambiano, nelle posizioni del gioco dal portone.
- `log/`: le uscite dei test e delle sonde (`catena.out.txt` è il riassunto).

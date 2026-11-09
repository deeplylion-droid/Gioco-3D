# Ricontrollo della correzione b3f71a0c (enigmi, 9 novembre)

- Correzione di ambienti-2 su `lavoro/tunnel-passi-lunghi` `b3f71a0c`: `_finisci_involucri` toglie dall'elenco ogni
  compito appena aspettato (`pop_front`), così `_exit_tree` aspetta solo quelli rimasti. In più c'è il test
  `test_tunnel_involucri_uscita`.
- Rispetto a `48201c67` cambiano solo `sala_sottomarino.gd` (9 righe), il test nuovo e la sua riga nella CI.
- Righe dei log in `risultati_b3f71a0c.txt`.

## Esito: superato

### 1. Il caso del difetto: compito lento e uscita dal gioco

- Il caso è quello del primo ricontrollo (`sonda_thread_lento.gd`): un compito di 8 s, e `Game.esci` mentre la
  costruzione lo aspetta.
- **0 «Invalid Task ID»**, nessun errore, uscita con codice 0. Su `48201c67` erano 2 righe.
- Gli altri casi col compito lento sono puliti, senza errori:
  - senza uscire: la costruzione aspetta 7,6 s, poi il tunnel è pronto;
  - titolo e morte: il gioco aspetta la fine dell'attesa, poi esce e riparte. Tunnel pronto.
- `test_tunnel_involucri_uscita`: 2 controlli ok su 2.

### 2. Le altre uscite durante la costruzione

- Titolo e morte a 0 fotogrammi dalla partenza dei compiti: il tunnel riparte pronto.
- Uscita dal gioco a 0 e 3 fotogrammi: uscita 0.
- In tutti e 12 i log di questo ricontrollo non ci sono errori, avvisi, «Invalid Task ID» né «Lambda capture». Sono
  escluse le solite righe dell'audio e delle risorse ancora in memoria all'uscita.

### 3. I nodi del tunnel

- Scena di prova, a pezzi: 2844 nodi come su `48201c67`, stesso ordine, **0 proprietà diverse**. Come rumore conta solo
  quello che cambia anche fra due giri di `48201c67`: i gommoni e le ossa.
- Gioco vero, F9 Inseguimento, il tunnel a pezzi nelle condotte con la torre in sala:
  - tunnel: 2844 nodi, **0 differenze** sia con `48201c67` sia con la candidata `f2f810a2`;
  - torre: 1132 nodi, **0 differenze** con tutti e due.

## Correzione al primo ricontrollo: i tempi nel gioco vero

Nel primo ricontrollo avevo scritto «nessun passo nuovo sopra 25 ms». Era misurato con `misura_tunnel_pezzi.gd`, nella
scena del solo tunnel. Nel gioco vero, con la sala e la torre, gli stessi passi costano di più. Per esempio Posa
appoggia i coralli in 9-14 ms invece di 1-2. Misura con `TORRE_TEMPI` nel gioco vero (F9 Inseguimento):

| | Passi più lunghi della costruzione del tunnel |
|---|---|
| Candidata `f2f810a2` (3 partite) | `_luci` 313-336 ms, `_abisso_oblo` 61-92, `_pesci` 45-49, `_approdo` 38-44, `_tartaruga` 38-42, `_relitto` 34-42, `_fine` fino a 39, `_buco_anello` fino a 37, `_abisso_lampade` fino a 35 |
| `b3f71a0c` (11 partite di questo pomeriggio) | al più **25,5 ms** (`_corallo`, che c'era già); poi `_relitto_forziere` 24,0, `_relitto_staffe` 23,9, `_pezzo` 23,7 |
| `48201c67` (20 partite di stamattina, le prove del thread) | `_occupati_tratto` fino a 36,6 ms (13 volte sopra 25), `_pesce_mensola_gap` 45,6 (una volta), `_corallo` 35, `_relitto_forziere` 32, `_relitto_staffe` 32, `_pezzo` 29,5 |

- Il codice della costruzione è lo stesso in `48201c67` e in `b3f71a0c`. Le punte del mattino, quasi tutte nella seconda
  costruzione dopo un titolo o una morte, nel pomeriggio non si sono ripetute nelle stesse strade.
- Le attribuisco alla macchina più carica, ma non posso escludere altro.
- Da tenere d'occhio: `_occupati_tratto` è il passo nuovo che più spesso si avvicina al limite. Si potrebbero fare meno
  occupati per passo (`OCCUPATI_PER_PASSO`).

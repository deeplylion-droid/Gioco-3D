# Posti proposti per le statue (18 ottobre)

Scatti dal motore (Godot, preset Alto, luce vera del gioco), dagli occhi del giocatore (1,7 m), **senza
torcia** (tolta dal gioco nella v0.3.6, 19 ottobre). I primi scatti con la torcia sono in `con_torcia/`. Le statue sono montate al volo da `godot/proposte/mascotte/scatti_statue.gd` (escluso
dall'export): nel gioco non c'è niente. In ogni scatto si vede solo la statua di quel posto.
`pianta_posti.jpg`: la sala vista dall'alto con i nove posti. Per ogni posto il motore ha controllato
che il basamento poggi sul pavimento e che non tocchi niente.

| Posto | Coordinate (x, z), rotazione | Dove |
| --- | --- | --- |
| S1 `squalo_1_ingresso` | (7,2; 15,6), -70° | appena entrati dagli spogliatoi, a destra, vicino alla pila di palloni; guarda chi entra |
| S2 `squalo_2_bordo_est` | (10; 1,5), -90° | bordo est della piscina a onde, accanto alla sedia del bagnino e ai lettini; guarda la piscina |
| S3 `squalo_3_spiaggia` | (3; -16,8), 0° | contro il muro nord, in fondo alla spiaggia della piscina; guarda la piscina |
| A1 `polpo_A_1_ingresso` | (-7,5; 14,5), 55° | appena entrati, a sinistra; saluta chi entra |
| A2 `polpo_A_2_serranda` (+ `_buio`) | (-11,5; 15), -39° | davanti alla serranda del magazzino: la si vede bene uscendo al buio (tappa 7) |
| A3 `polpo_A_3_bimbi` | (-5,5; -18), -12° | all'ingresso dell'area bimbi, vicino allo scivolo giallo |
| B1 `polpo_B_1_bimbi` (+ `_buio`) | (-18,3; -8), 90° | area bimbi, contro il muro ovest accanto al fungo. Nella tappa 8 sta dietro la medusa della fossa |
| B2 `polpo_B_2_spiaggia_est` | (9,5; -15,5), -45° | angolo nord-est della spiaggia della piscina |
| B3 `polpo_B_3_solarium` | (14,5; 1), -90° | dietro i lettini sul lato est, come in un solarium |

Per rifare gli scatti: `godot/proposte/mascotte/giro2.sh <cartella>` (e `giro1.sh`, `giro3.sh`).

Senza torcia: lo squalo S1 resta colorato nella luce rossa dell'ingresso; le altre statue si leggono come
sagome scure in controluce sui muri illuminati. A1 (ingresso, a sinistra) si vede poco: piccola e scura.
Nello scatto al buio di B1 (tappa 8) il polpo è quasi nascosto dietro la medusa della fossa.

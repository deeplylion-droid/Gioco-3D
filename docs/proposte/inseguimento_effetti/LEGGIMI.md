# Effetti dell'inseguimento nel tunnel (25-26 ottobre)

Approvati dall'utente (GDD, "gli effetti quando è vicina"): leggeri, e la distanza di lei resta 8-18 m.

- **Bordi scuri**: sotto gli 8 m i bordi dello schermo si scuriscono, sempre di più fino ai 3 m (al massimo il 60% di nero agli angoli). Sotto l'HUD: mirino e serbatoio restano chiari.
- **Tremito ai morsi**: a ogni morso a vuoto la camera trema appena (al più 0,45 gradi, 0,35 s), poi torna esattamente a posto. Se nelle opzioni l'oscillazione della camera è spenta, non trema.
- **La sua luce rosa ti supera**: una luce rosa parte da lei e guarda la strada 7 m davanti al giocatore, così si posa sulle pareti e sull'acqua davanti anche senza girarsi. Senza ombre e senza toccare la lancia in mano.

Niente pipeline nuove a metà inseguimento: i bordi usano lo shader di sempre della UI, la luce si accende nel riscaldamento del tunnel. Nel video, compilazioni durante l'inseguimento con gli effetti e senza: identiche (+34/+46, già presenti prima: lei, il getto, i gommoni, da sistemare a parte).

- `inseguimento_effetti.mp4`: 20,7 s dagli occhi del giocatore, dal motore (corre con lei dietro, rallenta, si gira, lei morde, getto in faccia, si ritrae, riparte).
- `confronto_*.jpg`: a sinistra senza effetti, a destra con, nello stesso istante della stessa partita: `luce_avanti` (3 s), `bordi_avanti` (lei a 9 m), `morso` (a 5,5 m), `ritrae`.
- Codice: `godot/scripts/game/effetti_inseguimento.gd`; test `godot/tests/test_effetti_inseguimento.gd`; video `godot/tests/video_effetti_inseguimento.gd`.

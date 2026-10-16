# Tappa 7 senza backtracking: due proposte (da scegliere con l'utente)

Dopo la sala pompe non si ripassa dagli spogliatoi: si risale per una strada mai vista, dietro le quinte
dell'acquapark, e si sbuca nella sala grande al buio del blackout (solo luci rosse d'emergenza e la torcia).
Le immagini sono render dei modelli veri (Blender, Cycles), non sono ancora nel gioco.

| | A. Locale caldaie | B. Magazzino dei gonfiabili |
|---|---|---|
| Pianta | `pianta_a_caldaie.png` | `pianta_b_magazzino.png` |
| Stanza nuova | `a_caldaie_entrata.jpg`: due caldaie, vapore, tubi, scala in grata verso la porta alta | `b_magazzino_entrata.jpg`: scaffali, mucchi di gonfiabili sgonfi, serranda mezza alzata |
| Arrivo nella sala grande | `a_arrivo_sala.jpg`: porta di servizio nell'angolo sud-est, a terra; davanti la vasca della medusa vuota | `b_arrivo_sala.jpg`: serranda nell'angolo sud-ovest; la scia va lungo il muro ovest |
| Verso l'area bimbi | la scia attraversa la sala in diagonale | la scia arriva da sud-ovest, proprio dove la medusa sbuca dalla fossa rivolta verso chi arriva da quel lato |

La scia è rosa fosforescente, come chiesto nel riscontro F5. Script: `tools/blender/proposte_tappa7.py`,
`tools/blender/proposte_arrivo.py`, `tools/pianta_tappa7.py`. Modelli Meshy nuovi (caldaia, mucchio di gonfiabili,
scaffale) in `assets_src/ambienti_tecnici/meshy_hq/`.

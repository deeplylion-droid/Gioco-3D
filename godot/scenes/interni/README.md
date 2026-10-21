# Interni: inizio del capitolo 1

`interni.tscn`: corridoio del ponte inferiore (risveglio), spogliatoi con docce, corridoio lava-piedi con tornello e saracinesca, stanzino dei bagnini con lo zaino-pompa. Script: `scripts/interni/interni.gd` e `scripts/interni/saracinesca.gd`. Modelli: `assets/ambienti_interni/` (sorgenti e convenzioni in `assets_src/ambienti_interni/`). La scena si rigenera con `python3 tools/godot_interni_scena.py`.

## Da sola

Si apre e si avvia così com'è (F6 nell'editor). Crea da sé il giocatore sdraiato sul marker `Gioco/Risveglio`, fa la scena del risveglio (la camera si rialza in circa 3 secondi), l'Environment (`AmbienteHorror.crea`) e parte senza zaino.

Test: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_interni.gd` (anche in CI).
Screenshot: `tests/screenshots_interni.gd` (istruzioni in cima al file).

## Dentro la sala principale

Righe da aggiungere a `scenes/sala_principale.tscn`:

```
[ext_resource type="PackedScene" path="res://scenes/interni/interni.tscn" id="interni_1"]

[node name="Interni" parent="." instance=ExtResource("interni_1")]
position = Vector3(-9.7, 0, 40.9)
giocatore_proprio = false
```

Con questa traslazione l'uscita degli spogliatoi (`marker_uscita_sala_principale`, vano 1,2 × 2,2 m chiuso dalla saracinesca) finisce in (0; 0; 20,2), sul retro del vano sud della sala.

**Spawn del giocatore**: il nodo `Player` della sala va spostato sul risveglio, in **(4,8; 0; 39,6)**, girato verso est (+X), verso la porta tagliafuoco (inizio con il mostro-squalo, 21 ottobre):

```
[node name="Player" ...]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 4.8, 0, 39.6)
```

Poi, nella sala:

- lo zaino parte dallo stanzino: `start_with_pack = false` nello script della sala e `start_equipped = false` sul `WaterPack` del giocatore; il nodo `PostazioneBagnini` della sala non serve più (lo zaino vero è `Interni/Zaino`);
- le Polaroid P1, P2 e P3 sono negli interni (`Interni/Polaroid`, stessi `entry_id` p01-p03): togliere `Polaroid01-03` dalla sala;
- i checkpoint degli interni hanno `order` da -10 a -5, quindi vengono prima di quelli della sala (da 0 in su): non serve rinumerare;
- la scena del risveglio: dallo script della sala, `$Interni.fai_risveglio(GameState.player)` all'inizio del livello (solo se non si riparte da un checkpoint). È la scena del mostro-squalo (`Gioco/RisveglioSqualo`, `scripts/interni/risveglio_squalo.gd`);
- `Interni` non crea un WorldEnvironment quando `giocatore_proprio = false`: vale quello della sala.

## Cosa c'è dentro

| Nodo | Cosa fa |
|---|---|
| `Ambienti/Corridoio`, `Spogliatoi`, `Stanzino` | i tre glTF, tutti a IDENTITY, con le collisioni `-colonly` |
| `Acqua/VascaLavapiedi` + `AcquaLavapiedi` | `WaterTank` della vasca lava-piedi (30 litri, si aspira) con l'acqua dell'addon (`stile_1_limpida`) |
| `Meccanismi/PulsanteTornello` | `WaterButton` LATCH nel gabbiotto, dietro il vetro rotto: sblocca il tornello |
| `Meccanismi/BloccoTornello`, `PassaggioTornello` | il tornello chiuso; sbloccato, il rotore gira di 120° a ogni passaggio |
| `Meccanismi/TurbinaSaracinesca` + `PernoTurbina` | `Turbine` sulla parete ovest: fa girare la girante del modello |
| `Meccanismi/Saracinesca` | `Saracinesca` (una `PoweredDoor`) che alza il modello vero; sale piano e resta su |
| `Zaino` | `PackPickup` appeso alla rastrelliera dello stanzino, con una luce calda sopra |
| `Polaroid/Polaroid01-03` | P1 a terra vicino al risveglio, P2 nell'armadietto aperto, P3 sulla bacheca dello stanzino |
| `Gioco/Risveglio` | punto di partenza del giocatore (guarda verso ovest) |
| `Gioco/Checkpoint*` | 6 checkpoint invisibili: risveglio, ingresso spogliatoi, stanzino, lava-piedi, tornello, saracinesca |
| `Gioco/DocceDaSole` | la prima volta che si passa davanti alle docce si aprono tutte insieme (getti e vapore) per 6 secondi |
| `Gioco/ArmadiettoSbatte` | l'anta dell'armadietto con il salvagente-papera si spalanca di colpo |
| `Atmosfera/Riflessi*` | una ReflectionProbe d'interno per zona |

A runtime `interni.gd` trasforma i neon accesi del modello (`*_tubo_sfarfalla`) in nodi `Neon` (SFARFALLA) e le luci rosse in `LuceEmergenza` (alcune PULSANTE), mette alle pozze un materiale lucido e apre e chiude le docce (`apri_docce(true/false)`).

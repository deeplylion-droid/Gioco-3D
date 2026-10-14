extends Node3D
## Demo giocabile della sala principale (vertical slice): atmosfera, statua, piscina vuota
## con la pozza. Enigma della demo: fai cadere il gonfiabile incastrato nella turbina dello
## scarico, tieni il getto sulla turbina (ricaricando lo zaino dalla pozza stessa) finché la
## pozza si svuota, poi colpisci il pulsante del portello.

## La lampada sul palo vicino alla statua: si accende quando entri nella sala.
@export var statue_lamp: FlickerLight
@export var lamp_trigger: Area3D
## Il segnaposto della statua (o il modello vero, se ha un metodo pulse()).
@export var statue: Node
## Il pulsante per i bambini sul piedistallo: fa partire la sigla.
@export var jingle_button: WaterButton
@export var hatch: PoweredDoor
@export var show_controls_hint := true
## Litri nello zaino all'inizio della demo (se si parte già con lo zaino).
@export var start_water := 10.0
## Se falso si parte senza zaino: è sulla rastrelliera nello stanzino dei bagnini.
@export var start_with_pack := false

var demo_finished := false


func _ready() -> void:
	if lamp_trigger:
		lamp_trigger.body_entered.connect(_on_lamp_trigger)
	if jingle_button:
		jingle_button.pressed.connect(_on_jingle)
	if hatch:
		hatch.opened.connect(_on_hatch_opened)
	if show_controls_hint:
		_show_hint.call_deferred()
	var p := GameState.player
	if p and p.water_pack:
		p.water_pack.set_tank_amount(start_water)
		if not start_with_pack and not p.has_item(&"zaino_pompa"):
			p.water_pack.set_equipped(false, false)


func _hud() -> Hud:
	var p := GameState.player
	return p.get_node_or_null(^"HUD") as Hud if p else null


func _show_hint() -> void:
	var hud := _hud()
	if hud:
		hud.show_hint("WASD muoviti · Shift corri · Ctrl abbassati · Spazio salta · E usa · F torcia · Esc pausa", 10.0)


## Chiamato quando il giocatore prende lo zaino.
func on_pack_taken() -> void:
	var hud := _hud()
	if hud:
		hud.show_hint("Tasto destro: aspira l'acqua · Tasto sinistro: spruzza", 9.0)


func _on_lamp_trigger(body: Node3D) -> void:
	if body is Player and statue_lamp and not statue_lamp.is_on:
		statue_lamp.turn_on()


func _on_jingle() -> void:
	# La sigla (audio) arriverà più avanti: per ora pulsa solo la campana.
	if statue and statue.has_method(&"pulse"):
		statue.call(&"pulse", 6.0)


func _on_hatch_opened() -> void:
	if demo_finished:
		return
	demo_finished = true
	var hud := _hud()
	if hud:
		hud.show_banner("FINE DELLA DEMO", "Il portello porta alla camera delle onde.\nGrazie per aver giocato!", 9.0)

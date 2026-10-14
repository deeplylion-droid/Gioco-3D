extends Node3D
## Demo giocabile della sala principale (vertical slice) sull'architettura vera dell'acquapark.
## Si entra dagli spogliatoi, si prende lo zaino-pompa dalla rastrelliera dei bagnini, si
## incontra la medusa immobile sul piedistallo (la lampada si accende quando ti avvicini).
## Enigma della demo: fai cadere il gonfiabile incastrato nella turbina dello scarico, tieni il
## getto sulla turbina (ricaricando lo zaino dalla pozza stessa) finché la pozza si svuota, poi
## colpisci il pulsante del portello. Nell'area bimbi la ruota a pale riempie il secchio gigante.

## La lampada sul palo vicino alla statua: si accende quando ti avvicini.
@export var statue_lamp: FlickerLight
## La luce della lampada (in sala_luci.glb) e il punto verso cui puntarla.
@export var statue_lamp_light: NodePath
@export var statue_lamp_aim := Vector3(0, 3.5, 6.9)
@export var lamp_trigger: Area3D
## La statua (con un metodo pulse() per la sigla).
@export var statue: Node
## Il pulsante per i bambini sul piedistallo: fa partire la sigla.
@export var jingle_button: WaterButton
@export var jingle_button_mesh: NodePath
@export var hatch: Node
@export var hatch_button_mesh: NodePath
## Materiale del vetro della cupola (rivoli di pioggia, si accende coi lampi).
@export var dome_glass: Material
@export var show_controls_hint := true
## Litri nello zaino all'inizio della demo (se si parte già con lo zaino).
@export var start_water := 10.0
## Se falso si parte senza zaino: è sulla rastrelliera dei bagnini all'ingresso.
@export var start_with_pack := false

var demo_finished := false


func _ready() -> void:
	_setup_hall()
	if lamp_trigger:
		lamp_trigger.body_entered.connect(_on_lamp_trigger)
	if jingle_button:
		jingle_button.pressed.connect(_on_jingle)
		_press_with(jingle_button, jingle_button_mesh)
	var hatch_button := get_node_or_null(^"Piscina/PulsantePortello") as WaterButton
	if hatch_button:
		_press_with(hatch_button, hatch_button_mesh)
	if hatch and hatch.has_signal(&"opened"):
		hatch.connect(&"opened", _on_hatch_opened)
	if show_controls_hint:
		_show_hint.call_deferred()
	var p := GameState.player
	if p and p.water_pack:
		p.water_pack.set_tank_amount(start_water)
		if not start_with_pack and not p.has_item(&"zaino_pompa"):
			p.water_pack.set_equipped(false, false)


## Ritocchi alla sala importata: lampada della statua, vetro della cupola, luci rosse.
func _setup_hall() -> void:
	var lamp := get_node_or_null(statue_lamp_light) as SpotLight3D
	if lamp:
		lamp.look_at(statue_lamp_aim, Vector3.UP)
		lamp.spot_angle = 38.0
		lamp.spot_range = 10.0
		lamp.spot_angle_attenuation = 0.8
		lamp.light_volumetric_fog_energy = 1.6
		lamp.shadow_enabled = true
		lamp.light_size = 0.08
		lamp.set_meta(&"grafica_priorita_ombra", 0)
		var bulb := _find_surface_material(get_node_or_null(^"Sala/Architettura/amb_lampione"), "M_amb_lampadina")
		if statue_lamp:
			statue_lamp.set_targets(lamp, bulb)
	if dome_glass:
		var glass := get_node_or_null(^"Sala/Cupola/sala_cupola_vetro") as MeshInstance3D
		if glass and glass.mesh:
			for i in glass.mesh.get_surface_count():
				glass.set_surface_override_material(i, dome_glass)
	var lights := get_node_or_null(^"Sala/Luci")
	if lights:
		for l in lights.get_children():
			if l is OmniLight3D and String(l.name).begins_with("luce_emergenza"):
				(l as OmniLight3D).light_volumetric_fog_energy = 2.2
				# Le due vicine all'ingresso fanno ombre (la statua e il piedistallo).
				if String(l.name) in ["luce_emergenza_34", "luce_emergenza_35"]:
					(l as OmniLight3D).shadow_enabled = true
					l.set_meta(&"grafica_priorita_ombra", 1)
			elif l is SpotLight3D and String(l.name).begins_with("luce_neon"):
				(l as SpotLight3D).light_volumetric_fog_energy = 0.8


## Duplica il materiale [param mat_name] di una mesh importata e lo mette come override
## (così si può cambiare l'emissione di quella mesh soltanto).
static func _find_surface_material(n: Node, mat_name: String) -> StandardMaterial3D:
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return null
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m is StandardMaterial3D and m.resource_name == mat_name:
			var copy := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.emission_enabled = true
			mi.set_surface_override_material(i, copy)
			return copy
	return null


## Il tappo del pulsante del modello rientra quando il pulsante è premuto.
func _press_with(button: WaterButton, mesh_path: NodePath) -> void:
	var cap := get_node_or_null(mesh_path) as Node3D
	if cap == null:
		return
	var rest := cap.position
	var inward := cap.global_basis.z.normalized() * -0.025
	button.powered_changed.connect(func(on: bool):
		var t := create_tween()
		t.tween_property(cap, ^"position", rest + (inward if on else Vector3.ZERO), 0.12))


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

extends Node
## I gommoni del tunnel non passano dall'origine del mondo mentre si costruiscono (collaudo finale del 30 ottobre): il
## corpo (AnimatableBody3D con sync_to_physics) entrava nella scena prima della sua posa e per un passo della fisica
## stava all'origine, cioè sopra il centro della piscina della sala, all'altezza del bordo; uno per fotogramma, mentre
## il tunnel si costruisce dopo la torre. Qui: la sala, la torre e il tunnel caricati come all'apertura del portone; a ogni
## passo della fisica niente del tunnel attorno all'origine; alla fine ogni gommone al suo posto nel canale.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_gommoni_origine.gd

const SCENA := "res://scenes/sala_principale.tscn"

var level: Node3D
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(SCENA)
	for i in 1800:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == SCENA and GameState.player and is_instance_valid(GameState.player):
			level = s as Node3D
			break
	check(level != null, "la sala è aperta")
	if level == null:
		_fine()
		return
	for i in 60:
		await get_tree().physics_frame
	var spazio := level.get_world_3d().direct_space_state
	# (raggi dall'alto attorno all'origine, fra un metro sopra e un metro sotto il bordo della piscina: lì sopra la
	# piscina vuota non c'è niente; un gommone all'origine lo prendono, col fondo a 6 cm e il tubolare a 40)
	var raggi: Array[PhysicsRayQueryParameters3D] = []
	for xx in 5:
		for zz in 5:
			var da := Vector3((xx - 2) * 0.5, 1.0, (zz - 2) * 0.5)
			raggi.append(PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 2.0, Layers.WORLD))
	var visti := {}
	level.call(&"_precarica_torre")
	var chiesta := false
	var costruita := -1
	for f in 60 * 150:
		await get_tree().physics_frame
		for q in raggi:
			var h := spazio.intersect_ray(q)
			var co := h.get("collider") as Node
			if co and String(co.get_path()).contains("SalaSottomarino"):
				visti[String(co.get_path())] = f
		if not chiesta and level.get(&"_torre_pronta") != null:
			level.call(&"_carica_torre")
			chiesta = true
		var t = level.get(&"sala_torre")
		if costruita < 0 and t is Node and bool((t as Node).get(&"costruita")):
			costruita = f
		if costruita >= 0 and f > costruita + 600:
			break
	var gommoni := level.find_children("Gommone", "AnimatableBody3D", true, false)
	print("  torre costruita al fotogramma %d; %d gommoni" % [costruita, gommoni.size()])
	check(costruita >= 0 and gommoni.size() > 0, "la torre e il tunnel si costruiscono (%d gommoni)" % gommoni.size())
	check(visti.is_empty(), "mentre il tunnel si costruisce niente del tunnel passa dall'origine del mondo, sopra il centro della piscina (%s)" % [visti])
	var lontano := INF
	for g in gommoni:
		lontano = minf(lontano, (g as Node3D).global_position.length())
	check(lontano > 10.0, "i gommoni stanno nel canale, lontano dalla sala (il più vicino a %.1f m dall'origine)" % lontano)
	_fine()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _fine() -> void:
	print("\nRISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)

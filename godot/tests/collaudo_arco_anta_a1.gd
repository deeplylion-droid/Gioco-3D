extends Node
## Collaudo di ambienti-1 (25 ottobre sera): il giocatore fermo dove gira l'anta della porta nord dell'infermeria mentre si
## apre (dopo il colpo al pulsantone): l'anta non lo deve spingere né incastrare (il difetto P1 del portello). Per ogni
## punto: la scena di prova da capo, il giocatore fermo lì, il pulsantone acceso e premuto, 3,2 s; poi quanto si è
## mosso, se è dentro l'anta, se l'anta è arrivata a 180 gradi e se riesce ad andarsene.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo_arco_anta_a1.gd

const SCENA := "res://tests/scene/infermeria_gioco_prova.tscn"
## Punti dell'infermeria (x, z): l'asse dei cardini è a (-1,762, -3,122), l'anta è larga 0,876.
const PUNTI := [Vector2(-2.2, -2.75), Vector2(-1.76, -2.55), Vector2(-1.3, -2.75), Vector2(-1.2, -2.85), Vector2(-2.45, -2.6), Vector2(-1.76, -2.85)]

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for punto: Vector2 in PUNTI:
		get_tree().change_scene_to_file(SCENA)
		var p: Node3D = await _aspetta()
		var inf := get_tree().current_scene.get_node(^"Infermeria") as Node3D
		var inter := inf.get_node(^"Interruttore") as WaterButton
		var anta := inf.get(&"_anta_nord") as Node3D
		p.call(&"teleport", inf.to_global(Vector3(punto.x, 0.0, punto.y)), 0.0, 0.0)
		await _secondi(0.4)
		var prima := inf.to_local(p.global_position)
		# (COLLAUDO_SENZA_COLPO=1: la prova di controllo, senza aprire: il giocatore deve restare fermo)
		if OS.get_environment("COLLAUDO_SENZA_COLPO") != "1":
			inter.powered = true
			inter.pressed.emit()
		var max_spinta := 0.0
		var dentro_max := 0
		for i in int(3.2 * 60):
			await get_tree().physics_frame
			var ora := inf.to_local(p.global_position)
			max_spinta = maxf(max_spinta, Vector2(ora.x - prima.x, ora.z - prima.z).length())
			if _dentro_anta(p, anta):
				dentro_max += 1
		var dopo := inf.to_local(p.global_position)
		var spinta := Vector2(dopo.x - prima.x, dopo.z - prima.z).length()
		var angolo := anta.rotation_degrees.y
		var dentro := _dentro_anta(p, anta)
		# se ne va verso il centro della stanza
		var da := p.global_position
		await _cammina(p, inf.to_global(Vector3(0.0, 0.0, 0.0)), 2.0)
		var via := p.global_position.distance_to(da)
		print("punto (%.2f, %.2f): partito da (%.2f, %.2f), spostato al massimo di %.3f m, alla fine di %.3f m; anta a %.1f gradi; dentro l'anta in %d fotogrammi (alla fine %s); andandosene fa %.2f m in 2 s" % [punto.x, punto.y, prima.x, prima.z, max_spinta, spinta, angolo, dentro_max, dentro, via])
		_check(max_spinta < 0.02, "(%.2f, %.2f): l'anta non spinge il giocatore (%.3f m)" % [punto.x, punto.y, max_spinta])
		_check(dentro_max == 0, "(%.2f, %.2f): il giocatore non resta dentro l'anta (%d fotogrammi)" % [punto.x, punto.y, dentro_max])
		_check(via > 0.8, "(%.2f, %.2f): non è incastrato, se ne va (%.2f m)" % [punto.x, punto.y, via])
		print("   (anta arrivata a 180: %s)" % (absf(angolo - 180.0) < 0.5))
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _dentro_anta(p: Node3D, anta: Node3D) -> bool:
	var corpo := anta.find_child("AntaNord", true, false) as CollisionObject3D
	var forma: CollisionShape3D = null
	for c in p.get_children():
		if c is CollisionShape3D and not (c as CollisionShape3D).disabled:
			forma = c
			break
	if forma == null or corpo == null:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma.shape
	q.transform = forma.global_transform
	q.collision_mask = 0xFFFFFFFF
	q.exclude = [(p as CollisionObject3D).get_rid()]
	for r in p.get_world_3d().direct_space_state.intersect_shape(q, 16):
		if r["collider"] == corpo:
			return true
	return false


func _cammina(p: Node3D, t: Vector3, secondi: float) -> void:
	Input.action_press(&"move_forward")
	for i in int(secondi * 60.0):
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			break
		p.call(&"set_look", atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")


func _aspetta() -> Node3D:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	var p := GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	return p


func _secondi(t: float) -> void:
	for i in int(round(t * 60.0)):
		await get_tree().physics_frame


func _check(c: bool, m: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", m)
	else:
		_ko += 1
		print("  KO  ", m)

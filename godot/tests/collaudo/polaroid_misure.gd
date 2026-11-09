extends Node
## Collaudo Polaroid (0.3.24, lavoro/polaroid-fiume, il fondo a filo): per ogni Polaroid nel gioco vero, dove sta, come
## è girata (la sua y) e il fondo della foto rispetto alla superficie sotto su 7 x 7 punti (la misura di
## test_polaroid_appoggiate), in mm. Poi la torre caricata dal portone (SalaPrincipale._aggiungi_torre) e da F9: la P10 e
## la P12 nei due casi, posto e misura.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/polaroid_misure.gd

const MISURA := preload("res://tests/test_polaroid_appoggiate.gd")


func _ready() -> void:
	_run.call_deferred()


func _stampa(ph: PolaroidPhoto, dove: String) -> void:
	var m: Array = MISURA.misura(ph)
	print("MISURA %s P%02d %s in %s, y %s, sotto %s: fondo da %.2f a %.2f mm, %d punti dentro su %d" % [dove, ph.photo, ph.name,
			ph.global_position.snappedf(0.0001), ph.global_basis.y.normalized().snappedf(0.001), ph.get_parent().name,
			float(m[0]) * 1000.0, float(m[1]) * 1000.0, int(m[2]), int(m[3])])
	for r in m[4]:
		print("        ", r)


func _torre(level: Node) -> Node3D:
	var torre: Node3D = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		torre = level.get(&"sala_torre") as Node3D if is_instance_valid(level) else null
		if torre and is_instance_valid(torre) and bool(torre.get(&"costruita")):
			break
	await get_tree().create_timer(3.0).timeout
	return torre


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	GameState.reset_progress()
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	var p := GameState.player as Player
	for i in 60:
		await get_tree().physics_frame
	p.teleport(Vector3(-4.9, -5.4, 55.0))
	var ris := level.get_node_or_null(^"Risalita")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var f: Node3D = ris.get(&"fiume") as Node3D if ris else null
		if f and bool(f.get(&"costruita")) and f.can_process() and f.visible and not bool(ris.get(&"_riaccendendo")):
			break
	await get_tree().create_timer(3.0).timeout
	var foto := level.find_children("*", "PolaroidPhoto", true, false)
	foto.sort_custom(func(a, b): return int(a.get(&"photo")) < int(b.get(&"photo")))
	for n in foto:
		_stampa(n as PolaroidPhoto, "sala")
	# la torre dal portone, come nel gioco
	level.call(&"_aggiungi_torre", load(String(level.get(&"sala_torre_scena"))))
	var torre := await _torre(level)
	if torre:
		for n in torre.find_children("*", "PolaroidPhoto", true, false):
			_stampa(n as PolaroidPhoto, "portone")
	else:
		print("MISURA: la torre dal portone non c'è")
	Engine.remove_meta(&"risalita_subito")
	var vecchio := GameState.player
	MenuProva.parti(get_tree(), "torre")
	for i in 3000:
		await get_tree().process_frame
		var pl := GameState.player
		if pl and is_instance_valid(pl) and pl != vecchio and pl.is_inside_tree():
			break
	torre = await _torre(get_tree().current_scene)
	if torre:
		for n in torre.find_children("*", "PolaroidPhoto", true, false):
			_stampa(n as PolaroidPhoto, "F9")
	else:
		print("MISURA: la torre da F9 non c'è")
	print("MISURA FINITO")
	get_tree().quit()

extends Node
## Sonda: cosa compare sopra il fondo della piscina mentre la torre si carica (collaudo finale del 30 ottobre: la rete
## dell'enigma dei giocattoli scattava quando la torre finiva di caricare). Svuota la piscina coi giocattoli sul fondo,
## carica la torre come all'apertura del portone e, a ogni fotogramma, lancia raggi dall'alto (come _fondo) sui
## giocattoli e su una griglia della parte profonda: stampa ogni cosa trovata sopra il fondo, col suo percorso.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sonda_enigma_torre.gd

const SCENA := "res://scenes/sala_principale.tscn"

var level: Node3D
var enigma: EnigmaGiocattoli
var _fondo_vuoto := {}
var _visti := {}


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
	for i in 60:
		await get_tree().physics_frame
	enigma = level.get_node(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	(level.get_node(^"Piscina/Pozza") as WaterTank).fill = 0.0
	for i in 120:
		await get_tree().physics_frame
	# il fondo a torre non caricata
	for p in _punti():
		_fondo_vuoto[p] = _primo(p)
	print("giocattoli: ", [enigma.giocattolo(0).global_position, enigma.giocattolo(1).global_position, enigma.giocattolo(2).global_position])
	print("torre: precarica")
	level.call(&"_precarica_torre")
	var f0 := Engine.get_physics_frames()
	var chiesta := false
	for i in 60 * 240:
		await get_tree().physics_frame
		_guarda(Engine.get_physics_frames() - f0)
		var t = level.get(&"sala_torre")
		if not chiesta and level.get(&"_torre_pronta") != null:
			print("torre pronta al fotogramma %d: _carica_torre" % (Engine.get_physics_frames() - f0))
			level.call(&"_carica_torre")
			chiesta = true
		if t is Node and bool((t as Node).get(&"costruita")):
			print("torre costruita al fotogramma %d" % (Engine.get_physics_frames() - f0))
			for k in 120:
				await get_tree().physics_frame
				_guarda(Engine.get_physics_frames() - f0)
			break
	print("FINE")
	get_tree().quit()


func _punti() -> Array:
	var out := []
	for k in 3:
		var g := enigma.giocattolo(k).global_position
		out.append(Vector2(g.x, g.z))
	var a := enigma.area
	for xx in 13:
		for zz in 9:
			out.append(Vector2(a.position.x + xx * a.size.x / 12.0, a.position.y + zz * a.size.y / 8.0))
	return out


## Tutto quello che il raggio dall'alto trova fino al fondo (strato del mondo, giocattoli esclusi): [y, percorso].
func _primo(p: Vector2) -> Array:
	var spazio := level.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for k in 3:
		ex.append(enigma.giocattolo(k).get_rid())
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 0.5, p.y), Vector3(p.x, -2.86, p.y), Layers.WORLD, ex)
	var h := spazio.intersect_ray(q)
	if h.is_empty():
		return [-99.0, ""]
	return [(h.position as Vector3).y, str((h.collider as Node).get_path()) if h.collider is Node else str(h.collider)]


func _guarda(f: int) -> void:
	for p in _fondo_vuoto:
		var r := _primo(p)
		if absf(float(r[0]) - float(_fondo_vuoto[p][0])) > 0.02:
			var chiave := "%s %s" % [p, r[1]]
			if not _visti.has(chiave):
				_visti[chiave] = true
				var co := get_tree().root.get_node_or_null(NodePath(r[1]))
				var info := ""
				if co is Node3D:
					info = " (globale %s, strato %s, genitore %s)" % [(co as Node3D).global_position.snapped(Vector3.ONE * 0.01),
						(co as CollisionObject3D).collision_layer if co is CollisionObject3D else -1, co.get_parent().get_path()]
				print("fotogramma %d in %s: y %.3f invece di %.3f, %s%s" % [f, p, r[0], _fondo_vuoto[p][0], r[1], info])

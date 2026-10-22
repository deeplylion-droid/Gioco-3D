extends Node
## Trova (senza disegnare) il pavimento sotto le statue e le pareti degli oggetti di Jilly, come
## scatti_statue.gd, e stampa le posizioni da scrivere in scripts/environment/mascotte_sala.gd.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_posti.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const STATUE := [["squalo", 10.0, 1.5], ["polpo_A", -5.5, -18.0], ["polpo_B", -18.3, -8.0]]
const MURI := [["targa", Vector3(-3.6, 0.62, 10), Vector3(1, 0, 0)],
	["manifesto", Vector3(-17, 1.4, 13.95), Vector3(-1, 0, 0)],
	["insegna", Vector3(-17, 4.7, 5.35), Vector3(-1, 0, 0)]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := (load(LEVEL) as PackedScene).instantiate()
	for n in ["Interni", "Mascotte"]:
		var x := level.get_node_or_null(n)
		if x:
			level.remove_child(x)
			x.free()
	get_tree().root.add_child(level)
	for i in 20:
		await get_tree().physics_frame
	var spazio := (level as Node3D).get_world_3d().direct_space_state
	var p := GameState.player
	for s in STATUE:
		var q := PhysicsRayQueryParameters3D.create(Vector3(s[1], 3.0, s[2]), Vector3(s[1], -6.0, s[2]))
		q.exclude = [p.get_rid()]
		var hit := spazio.intersect_ray(q)
		print("SONDA statua ", s[0], " y=", hit.position.y if hit else "NIENTE", " su ", hit.collider.get_path() if hit else "")
	for m in MURI:
		var q := PhysicsRayQueryParameters3D.create(m[1], m[1] + (m[2] as Vector3) * 25.0)
		q.exclude = [p.get_rid()]
		var hit := spazio.intersect_ray(q)
		print("SONDA muro ", m[0], " pos=", hit.position, " normale=", hit.normal, " su ", hit.collider.get_path())
	get_tree().quit()

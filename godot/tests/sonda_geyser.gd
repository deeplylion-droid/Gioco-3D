extends Node
## Sonda del geyser V1 (GeyserMesh): per ogni fotogramma della simulazione, quali punti di lei affacciata
## (l'occhio, le dita e le punte dei tentacoli: punti_gocce) sono nascosti dall'acqua che si disegna, da
## tutte le direzioni da cui li può vedere il giocatore (GeyserMesh.nasconde).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_geyser.gd

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	var level := get_tree().current_scene
	var lei := level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	lei.call(&"_affaccia")
	for i in 10:
		await get_tree().physics_frame
	var g := lei.get_node(^"Geyser") as GeyserMesh
	var base: Vector3 = lei.punto_sbuca.global_transform * Vector3(0.0, 0.0, 1.5)
	var punti: Array[Vector3] = [lei.medusa.call(&"get_eye_position")]
	for q in lei.medusa.get(&"punti_gocce"):
		punti.append(lei.medusa.global_transform * q)
	print("BASE ", base, " copre ", g.copre, " s")
	for k in punti.size():
		print("PUNTO %d %s, a %.2f m dall'asse, %.2f m sopra la base" % [k, punti[k], Vector2(punti[k].x - base.x, punti[k].z - base.z).length(), punti[k].y - base.y])
	var pp := PackedVector3Array()
	for q in punti.slice(1):
		pp.append(q)
	g.scoppia(base, [], pp)
	g.set_process(false)
	print("GETTI sulle punte: ", g.get(&"_getti_v1").size())
	var seq := GeyserMesh.sequenza()
	for i in seq.size():
		g.set(&"_t", i / GeyserMesh.FPS)
		g.call(&"_aggiorna")
		var riga := ""
		for w in punti:
			var n := g.scoperto_da(w)
			riga += "X" if n == 0 else (str(n) if n < 10 else "+")
		var a := seq[i].get_aabb()
		print("F%02d %.2f s %s  alto %.2f m, largo %.2f x %.2f" % [i, i / 30.0, riga, a.end.y, a.size.x, a.size.z])
	get_tree().quit()

extends Node
## Sonda: dove mettere la lampada d'emergenza 5 della torre (muro est, verso ovest), lontano dal tubo (collaudo di
## ambienti-1 su 4e9551c8: si appoggiava al tubo, che le entrava 16,6 mm nel fondo, a 49 cm dal muro). Prova i posti
## vicini lungo il muro e in altezza, la appoggia come SalaTorre._emergenza (fissa_al_muro e i 9 raggi sul retro) e
## misura come test_lampade_torre_strade: distanza dal muro, cose dentro la scatola, che cosa colpiscono i raggi.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_posto_lampada5.gd

const PROVA := preload("res://tests/test_lampade_torre_strade.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as Node3D
	add_child(torre)
	for i in 10:
		await get_tree().process_frame
	var v := Vector3.LEFT
	for dy: float in [0.0, -0.5, 0.5, -1.0, 1.0]:
		for dz: float in [0.0, -0.5, 0.5, -1.0, 1.0, -1.5, 1.5, -2.0, 2.0, -2.5, 2.5, -3.0, 3.0]:
			var p := Vector3(39.92, -16.5 + dy, -15.0 + dz)
			var corpo := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.16, 0.3, 0.3)
			corpo.mesh = bx
			torre.add_child(corpo)
			corpo.global_position = p
			var a1 := v.cross(Vector3.UP).normalized()
			var a2 := v.cross(a1).normalized()
			var zona := AABB(p, Vector3.ZERO)
			for i in [-1, 1]:
				for j in [-1, 1]:
					var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
					zona = zona.expand(p + o + v * 0.3).expand(p + o - v * Posa.PORTATA * 2.0)
			var vicine := Posa.mesh_vicine(corpo, zona, torre)
			Posa.fissa_al_muro(corpo, v, 0.08, false, [], vicine)
			var p0 := corpo.global_position
			var davanti := -INF
			var colpiti := {}
			for i in [-1, 0, 1]:
				for j in [-1, 0, 1]:
					var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
					var h := Posa._raggio(corpo, p0 + o + v * 0.3, p0 + o - v * Posa.PORTATA, [], vicine)
					if not h.is_empty():
						davanti = maxf(davanti, (h.position as Vector3).dot(v))
						colpiti[String((h.collider as Node).name)] = true
			if davanti > -INF:
				corpo.global_position = p0 + v * (davanti + 0.08 - p0.dot(v))
			var m: Array = PROVA._misura(corpo)
			print("POSTO dy %+.1f dz %+.1f -> %s: dal muro %.1f mm, dentro %d, x %.4f, colpiti %s" % [dy, dz,
					corpo.global_position.snappedf(0.001), m[0] * 1000.0, m[1], corpo.global_position.x, colpiti.keys()])
			corpo.free()
	get_tree().quit()

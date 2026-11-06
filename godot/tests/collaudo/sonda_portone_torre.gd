extends Node
## Le due aperture verso il cielo dal checkpoint del portone della torre (ricontrollo del collaudo su varchi-cielo,
## 6 novembre): nel gioco vero (partenza F9 torre), dagli occhi del checkpoint, le mappe dei raggi attorno alle due
## direzioni ("." esce nel cielo, lettera: la prima del nodo colpito), il pavimento sotto (raggi verso il basso) e i nodi
## colpiti attorno. Stampa PORTONE:.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_portone_torre.gd

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const OCCHI := Vector3(21.4, 1.59, -15.0)
const DIREZIONI := [["giu", Vector3(-0.52, -0.654, -0.549)], ["su", Vector3(0.426, 0.337, 0.84)]]

var sigle := {}


func _ready() -> void:
	_run.call_deferred()


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), "torre")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	for i in 60 * 10:
		await get_tree().process_frame
	var sc := get_tree().current_scene as Node3D
	var p := GameState.player
	p.teleport(OCCHI + Vector3.DOWN * 1.5)
	for i in 30:
		await get_tree().physics_frame
	p.process_mode = Node.PROCESS_MODE_DISABLED
	print("PORTONE: corpi dalle mesh %d" % CorpiMesh.crea(sc, AABB(OCCHI, Vector3.ZERO).grow(40.0), p))
	for i in 3:
		await get_tree().physics_frame
	var spazio := get_viewport().find_world_3d().direct_space_state
	for dd in DIREZIONI:
		var d: Vector3 = (dd[1] as Vector3).normalized()
		var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
		var b := d.cross(a).normalized()
		print("PORTONE: %s, mappa ±6 gradi (righe b, colonne a): '.' cielo" % dd[0])
		var vicino := {}
		for i in range(-12, 13):
			var riga := ""
			for j in range(-12, 13):
				var dir := (d + a * tan(deg_to_rad(j * 0.5)) + b * tan(deg_to_rad(i * 0.5))).normalized()
				var r := _raggio(spazio, OCCHI, dir, p)
				if r.is_empty():
					riga += "."
				else:
					var n := _nome(sc, r.collider)
					riga += _sigla(n)
					if absf(i) <= 3 and absf(j) <= 3:
						vicino[n] = "%s a %.2f m" % [(r.position as Vector3).snapped(Vector3.ONE * 0.01), OCCHI.distance_to(r.position)]
			print("PORTONE:   " + riga)
		for n in vicino:
			print("PORTONE:   vicino al centro: %s %s" % [n, vicino[n]])
	print("PORTONE: sigle %s" % [sigle])
	# il pavimento sotto l'apertura in giù: raggi verso il basso
	print("PORTONE: pavimento (y del primo colpo dall'alto, da y 1,0), righe z da -17,4 a -15,4, colonne x da 19,2 a 21,2")
	for iz in range(0, 21):
		var z := -17.4 + iz * 0.1
		var riga := "%.1f " % z
		for ix in range(0, 21):
			var x := 19.2 + ix * 0.1
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, z), Vector3(x, -12.0, z), 0xFFFFFFFF, [p.get_rid()]))
			riga += (" %5.2f%s" % [(r.position as Vector3).y, _sigla(_nome(sc, r.collider))]) if not r.is_empty() else "    -  "
		print("PORTONE:   " + riga)
	print("PORTONE: sigle %s" % [sigle])
	print("PORTONE: finito")
	get_tree().quit()


func _raggio(spazio: PhysicsDirectSpaceState3D, a: Vector3, d: Vector3, p: Node) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, a + d * 150.0, 0xFFFFFFFF, [(p as CollisionObject3D).get_rid()])
	q.hit_back_faces = true
	return spazio.intersect_ray(q)


func _sigla(n: String) -> String:
	if not sigle.has(n):
		var c := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
		sigle[n] = c[mini(sigle.size(), c.length() - 1)]
	return sigle[n]


func _nome(radice: Node, n: Object) -> String:
	var nd := n as Node
	if nd == null:
		return "?"
	var q := nd
	# il nodo con la mesh: per i corpi dalle mesh il genitore
	if q is StaticBody3D and q.get_parent() is MeshInstance3D:
		q = q.get_parent()
	var pezzi := String(radice.get_path_to(q)).split("/")
	return "/".join(pezzi.slice(maxi(0, pezzi.size() - 3)))

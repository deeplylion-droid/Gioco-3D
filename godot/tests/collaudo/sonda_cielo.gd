extends Node
## Sonda del cielo: nel gioco vero (la sala principale con la Risalita caricata come a gioco avviato) da dove passa il
## giocatore si tirano raggi e si cerca quelli che non incontrano niente entro DISTANZA m (né collisioni né mesh: i
## corpi dalle mesh vere, CorpiMesh), cioè dove si vedrebbe il cielo dell'ambiente. Nasce dalla segnalazione
## dell'utente sulla 0.3.21 ("che è quella texture grigia sulla parete? sembra un glitch": il rettangolo in fondo alla
## scala di servizio, verso la porta di C3, negli scatti fatti con la Risalita da sola).
## Senza rendering (headless): solo fisica. Stampa CIELO: per ogni posto quanti raggi su quanti escono, e dove.
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_cielo.gd [porta_c3]

const SALA := "res://scenes/sala_principale.tscn"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const DISTANZA := 120.0

var sala: Node3D
var ris: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(SALA)
	for i in 1200:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	sala = get_tree().current_scene as Node3D
	ris = sala.get_node_or_null(^"Risalita") as Node3D
	if ris == null:
		print("CIELO: niente Risalita nella sala")
		get_tree().quit(1)
		return
	ris.call(&"carica_subito")
	for i in 3000:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and ris.get(&"fiume") != null and i > 120:
			break
	var p := GameState.player
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScala") as Node3D).global_position
	var c3 := (m.get_node(^"PortaC3") as Node3D).global_position
	var n := CorpiMesh.crea(sala, AABB(cima, Vector3.ZERO).expand(c3).grow(30.0), p)
	print("CIELO: corpi dalle mesh %d" % n)
	for i in 4:
		await get_tree().physics_frame
	# dalla cima della scala alla porta di C3, a ogni metro, gli occhi a 1,6 m; i raggi verso la porta (x di PORTA_C3,
	# z da 37,95 a 38,95, da 0,1 a 2,0 m) e poi oltre, fino a DISTANZA
	var porta_x: float = ris.to_global(Vector3(-16.15, 0, 0)).x
	var passi := int(ceil(cima.distance_to(c3)))
	var fuori_tot := 0
	for k in passi + 1:
		var occhio := cima.lerp(c3, float(k) / passi) + Vector3.UP * 1.6
		var fuori := 0
		var tirati := 0
		var dove := {}
		for zi in 6:
			for yi in 6:
				var bersaglio := ris.to_global(Vector3(-16.15, 0.1 + yi * 0.38, 37.97 + zi * 0.19))
				var dir := (bersaglio - occhio).normalized()
				tirati += 1
				var r := _raggio(occhio, occhio + dir * DISTANZA, p)
				if r.is_empty():
					fuori += 1
				else:
					var nome := _nome(r.collider as Node)
					dove[nome] = int(dove.get(nome, 0)) + 1
		fuori_tot += fuori
		print("CIELO: porta C3 da %.1f m (x %.2f): %d raggi su %d nel cielo; colpiti %s" % [occhio.distance_to(Vector3(porta_x, occhio.y, occhio.z)),
				occhio.x, fuori, tirati, str(dove)])
	print("CIELO: porta C3 totale nel cielo %d" % fuori_tot)
	print("CIELO: finito")
	get_tree().quit()


func _raggio(a: Vector3, b: Vector3, p: Node) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = 0xFFFFFFFF
	q.exclude = [(p as CollisionObject3D).get_rid()]
	q.hit_back_faces = true
	return get_viewport().find_world_3d().direct_space_state.intersect_ray(q)


func _nome(n: Node) -> String:
	if n == null:
		return "?"
	var s := String(n.name)
	var q := n.get_parent()
	for i in 3:
		if q == null or q == sala:
			break
		s = String(q.name) + "/" + s
		q = q.get_parent()
	return s

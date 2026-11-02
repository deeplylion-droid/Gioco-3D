extends Node
## Collaudo: la scaletta del bacino dell'inseguimento con l'acqua più bassa (0.3.20). Stampa le mesh vicine alla scala
## (Ladder "Scala") con la loro scatola, il pelo dell'acqua del bacino e il fondo, e prova a uscire dall'acqua: il
## giocatore vero nel bacino davanti alla scala, avanti contro di lei (si aggrappa? fin dove sale?).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_scaletta_bacino.gd

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	for i in 20:
		await get_tree().physics_frame
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	for i in 60:
		await get_tree().physics_frame
	for m in ins.find_children("acqua_bacino*", "MeshInstance3D", true, false):
		var ab := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		print("SCALETTA: acqua %s pelo %.3f" % [m.name, ab.end.y])
	for l in ins.find_children("*", "Ladder", true, false):
		var sc := l as Ladder
		var base := sc.global_position
		var n := sc.get_climb_normal()
		print("SCALETTA: logica %s base %s alta %.2f, verso chi sale %s, cima %.3f" % [ins.get_path_to(sc), base.snapped(Vector3.ONE * 0.001), sc.height, n.snapped(Vector3.ONE * 0.01), sc.get_top_y()])
		var box := AABB(base + Vector3(-1.0, -0.2, -1.0), Vector3(2.0, sc.height + 0.6, 2.0))
		for m in torre.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if not mi.is_visible_in_tree():
				continue
			var ab := mi.global_transform * mi.get_aabb()
			if ab.intersects(box) and ab.size.length() < 12.0:
				print("SCALETTA:   mesh %s da %s a %s" % [torre.get_path_to(mi), ab.position.snapped(Vector3.ONE * 0.001), ab.end.snapped(Vector3.ONE * 0.001)])
		# il bordo davanti alla scala: un raggio orizzontale a varie altezze, da chi sta nell'acqua verso la scala
		var spazio := sc.get_world_3d().direct_space_state
		for h in [0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1]:
			var da: Vector3 = base + n * 1.5 + Vector3.UP * float(h)
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(da, base - n * 0.5 + Vector3.UP * float(h)))
			print("SCALETTA:   a %.1f m sopra la base, verso la scala: %s" % [h, ("collisione a %.2f m dalla base (%s)" % [(r.position - base).dot(n), r.collider.name if r.collider else "?"]) if not r.is_empty() else "libero"])
		var p := (load(PLAYER) as PackedScene).instantiate() as Player
		add_child(p)
		for i in 5:
			await get_tree().physics_frame
		p.teleport(base + n * 1.2 + Vector3.UP * 0.1)
		for i in 30:
			await get_tree().physics_frame
		p.look_at_point(base + Vector3.UP * 1.6)
		Input.action_press(&"move_forward")
		var presa := false
		var alto := -INF
		for f in 60 * 8:
			await get_tree().physics_frame
			presa = presa or p.is_on_ladder()
			alto = maxf(alto, p.global_position.y)
		Input.action_release(&"move_forward")
		print("SCALETTA: dal bacino contro la scala: presa %s, piedi saliti da %.2f a %.2f (cima %.2f), fine %s" % [presa, base.y, alto, sc.get_top_y(), p.global_position.snapped(Vector3.ONE * 0.01)])
	print("SCALETTA: finito")
	get_tree().quit()

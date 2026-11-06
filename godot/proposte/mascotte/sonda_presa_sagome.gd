extends Node
## Sonda: lei nelle vasche delle condotte (salita, incombe e presa) contro le sagome del club dei bambini di enigmi
## (SalaInseguimento/SagomeClub: Sagoma_*, Puntello*, Mattone*, Legatura*). Per ogni vasca il giocatore sta in 9 punti
## (gli angoli, il mezzo dei muri a 0,4 m dal muro, il centro); lei girata verso di lui come nel gioco (nella vasca 3,
## mentre tiene il bordo, verso il muro). Per ogni fotogramma ogni osso, più 10 cm di pelle, contro il riquadro di ogni
## pezzo delle sagome: stampa le compenetrazioni e la distanza minima.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_presa_sagome.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const PELLE := 0.10


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 600:
		await get_tree().process_frame
		if sala.find_child("SagomeClub", true, false) and i > 60:
			break
	sala.set_physics_process(false)
	var sc := sala.find_child("SagomeClub", true, false)
	if sc == null:
		print("niente SagomeClub")
		get_tree().quit(1)
		return
	var pezzi := []
	for mi: MeshInstance3D in sc.find_children("*", "MeshInstance3D", true, false):
		pezzi.append([String(mi.name), mi.global_transform * mi.get_aabb()])
	print("pezzi delle sagome: ", pezzi.size())
	var lei := sala.lei
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for v in 3:
		var dove := "vasca_%d" % v
		var salita: String = SalaInseguimento.SALITA.get(dove, "sale_dall_acqua")
		var su := sala._posto_vasca(v)
		var r: Array = sala.dati["vasche"][v]["rett"]
		var fondo := float(sala.dati["vasche"][v]["fondo"])
		var muro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, r[1], 0.0])
		var punti := []
		for fx in [0.0, 0.5, 1.0]:
			for fy in [0.0, 0.5, 1.0]:
				punti.append(SalaInseguimento.b([lerpf(r[0] + 0.4, r[2] - 0.4, fx), lerpf(r[1] + 0.4, r[3] - 0.4, fy), fondo]))
		var minima := INF
		var dove_min := ""
		var dentro := {}
		for g: Vector3 in punti:
			lei.global_position = su
			for anim in [salita, "incombe", "presa"]:
				var a := ap.get_animation(StringName("inseguimento/" + anim))
				var t := 0.0
				while t <= a.length:
					var verso := Vector3(g.x, su.y, g.z)
					if anim == "sale_mano" and t < SalaInseguimento.MANO_LASCIA:
						verso = Vector3(muro.x, su.y, muro.z)
					lei.look_at(verso, Vector3.UP, true)
					ap.play(StringName("inseguimento/" + anim))
					ap.seek(t, true)
					ap.advance(0.0)
					for o in sk.get_bone_count():
						var w := sk.global_transform * sk.get_bone_global_pose(o).origin
						for pz in pezzi:
							var bb: AABB = pz[1]
							var d := _distanza(bb, w) - PELLE
							if d < minima:
								minima = d
								dove_min = "%s %s %.2f s, %s, giocatore a %s" % [anim, sk.get_bone_name(o), t, pz[0], g.snapped(Vector3.ONE * 0.1)]
							if d < 0.0:
								var k := "%s / %s" % [pz[0], sk.get_bone_name(o)]
								if not dentro.has(k) or d < dentro[k][0]:
									dentro[k] = [d, "%s %.2f s, giocatore a %s" % [anim, t, g.snapped(Vector3.ONE * 0.1)]]
					t += 1.0 / 30.0
		print("%s: distanza minima dalle sagome %.2f m (%s)" % [dove, minima, dove_min])
		for k in dentro:
			print("   DENTRO di %.0f cm: %s (%s)" % [-dentro[k][0] * 100.0, k, dentro[k][1]])
	get_tree().quit(0)


func _distanza(bb: AABB, p: Vector3) -> float:
	var q := Vector3(clampf(p.x, bb.position.x, bb.end.x), clampf(p.y, bb.position.y, bb.end.y), clampf(p.z, bb.position.z, bb.end.z))
	return q.distance_to(p)

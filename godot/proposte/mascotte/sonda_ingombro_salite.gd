extends Node
## Sonda: l'ingombro di lei nelle salite delle vasche dell'inseguimento (0.3.21), nel sistema della sala (coordinate
## globali di SalaInseguimento, come le mette il gioco): per ogni vasca il riquadro di tutte le ossa più 15 cm (la pelle)
## durante la salita e il primo secondo da su; per la vasca 3 anche la mano destra mentre tiene il bordo. Lei girata come
## nel gioco: nella vasca 3 verso il muro mentre tiene il bordo, poi (e nelle altre) verso il giocatore in mezzo alla vasca.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_ingombro_salite.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const PELLE := 0.15


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 10:
		await get_tree().physics_frame
	sala.set_physics_process(false)
	var lei := sala.lei
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mano_r := []
	for o in sk.get_bone_count():
		var n := sk.get_bone_name(o)
		if n.ends_with(".R") and (n.begins_with("mano") or n.begins_with("pollice") or n.begins_with("indice") or n.begins_with("medio")
				or n.begins_with("anulare") or n.begins_with("mignolo") or n.begins_with("avambraccio")):
			mano_r.append(o)
	for v in 3:
		var dove := "vasca_%d" % v
		var nome: String = SalaInseguimento.SALITA.get(dove, "sale_dall_acqua")
		var su := sala._posto_vasca(v)
		var r: Array = sala.dati["vasche"][v]["rett"]
		var centro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(sala.dati["vasche"][v]["fondo"])])
		var muro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, r[1], 0.0])
		lei.global_position = su
		var a := ap.get_animation(StringName("inseguimento/" + nome))
		var t0: float = sala._quando_radice(StringName("inseguimento/" + nome), sala._profondita(dove), true)
		var tutto := AABB()
		var mano := AABB()
		var primo := true
		var primo_m := true
		var t := t0
		while t <= a.length + 1.0:
			var tenendo := nome == "sale_mano" and t >= 0.82 and t < SalaInseguimento.MANO_LASCIA
			var guarda := Vector3(muro.x, su.y, muro.z) if nome == "sale_mano" and t < SalaInseguimento.MANO_LASCIA else Vector3(centro.x, su.y, centro.z)
			lei.look_at(guarda, Vector3.UP, true)
			if t <= a.length:
				ap.play(StringName("inseguimento/" + nome))
				ap.seek(t, true)
			else:
				ap.play(&"inseguimento/incombe")
				ap.seek(t - a.length, true)
			ap.advance(0.0)
			for o in sk.get_bone_count():
				var w := sk.global_transform * sk.get_bone_global_pose(o).origin
				# solo quello che sta sopra il pavimento vicino (non le parti sotto l'acqua o nel pozzo, a 5 m sotto)
				var bb := AABB(w - Vector3.ONE * PELLE, Vector3.ONE * PELLE * 2.0)
				tutto = bb if primo else tutto.merge(bb)
				primo = false
				if tenendo and o in mano_r:
					var bm := AABB(w - Vector3.ONE * 0.08, Vector3.ONE * 0.16)
					mano = bm if primo_m else mano.merge(bm)
					primo_m = false
			t += 1.0 / 30.0
		print("%s (%s): lei a %s; ingombro x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f" % [dove, nome, su, tutto.position.x, tutto.end.x,
			tutto.position.y, tutto.end.y, tutto.position.z, tutto.end.z])
		print("   nel sistema dei dati (inseguimento_gioco.json, assi di Blender): x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f" % [
			tutto.position.x, tutto.end.x, -tutto.end.z, -tutto.position.z, tutto.position.y, tutto.end.y])
		if not primo_m:
			print("   la mano destra sul bordo (0,82-%.2f s): x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f" % [SalaInseguimento.MANO_LASCIA,
				mano.position.x, mano.end.x, mano.position.y, mano.end.y, mano.position.z, mano.end.z])
			print("   nel sistema dei dati: x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f" % [mano.position.x, mano.end.x, -mano.end.z,
				-mano.position.z, mano.position.y, mano.end.y])
	get_tree().quit(0)

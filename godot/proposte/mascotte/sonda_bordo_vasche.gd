extends Node
## Sonda: dov'è il bordo di ogni vasca delle condotte rispetto a lei, nel suo posto e girata verso il centro della vasca
## (per le salite diverse per vasca, 0.3.21). Per ogni vasca: un raggio orizzontale da lei verso il centro della vasca a
## diverse altezze trova la parete; poi un raggio dall'alto, appena oltre la faccia della parete dalla parte di lei, trova
## la cima del bordo. Stampa il bordo nello spazio di lei (avanti, lato, su) e nello spazio del modello di Blender, per
## varie direzioni del giocatore nella vasca (lei si gira verso di lui).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_bordo_vasche.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"

var sala: SalaInseguimento


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 10:
		await get_tree().physics_frame
	sala.set_physics_process(false)
	var spazio := get_viewport().world_3d.direct_space_state
	var d := sala.dati
	for v in 3:
		var r: Array = d["vasche"][v]["rett"]
		var fondo := float(d["vasche"][v]["fondo"])
		var su := sala._posto_vasca(v)
		print("vasca_%d: lei a %s, fondo %.2f, acqua %.2f, rett %s" % [v, su, fondo, float(d["vasche"][v]["acqua"]), r])
		# il giocatore in vari punti della vasca, all'altezza del fondo
		var punti := []
		for fx in [0.2, 0.5, 0.8]:
			for fy in [0.2, 0.5, 0.8]:
				punti.append(SalaInseguimento.b([lerpf(r[0], r[2], fx), lerpf(r[1], r[3], fy), fondo]))
		for g: Vector3 in punti:
			var verso := g - su
			verso.y = 0.0
			var dir := verso.normalized()
			# la parete: il primo muro fra lei e il giocatore, all'altezza giusta
			var parete := Vector3.INF
			for h in [0.3, 0.6, 1.0, 1.5]:
				var a: Vector3 = su + Vector3.UP * (fondo - su.y + h)
				var q := PhysicsRayQueryParameters3D.create(a - dir * 1.0, a + dir * (verso.length() + 1.0))
				var hit := spazio.intersect_ray(q)
				if not hit.is_empty():
					parete = hit["position"]
					break
			if parete == Vector3.INF:
				print("  verso %s: nessuna parete" % g)
				continue
			# la cima: dall'alto, 4 cm prima della faccia della parete, dalla parte di lei... dentro lo spessore
			var cima := Vector3.INF
			for k in [0.04, 0.1, 0.16]:
				var x: Vector3 = parete + dir * k
				var q := PhysicsRayQueryParameters3D.create(Vector3(x.x, su.y + 6.0, x.z), Vector3(x.x, fondo - 1.0, x.z))
				var hit := spazio.intersect_ray(q)
				if not hit.is_empty():
					cima = hit["position"]
					break
			var basis := Basis.looking_at(-dir, Vector3.UP)     # lei: +Z verso il giocatore (look_at con use_model_front)
			var loc := basis.inverse() * (cima - su) if cima != Vector3.INF else Vector3.INF
			print("  giocatore a %s: parete a %.2f m davanti, cima del bordo %s; nello spazio di lei avanti %.2f, lato %.2f, su %.2f" % [
				g, (parete - su).dot(dir), cima, loc.z, loc.x, loc.y])
	# il profilo sotto e davanti a lei (vasca_1), verso il centro della vasca: la prima cosa che si trova scendendo
	for v in 3:
		var su := sala._posto_vasca(v)
		var r: Array = d["vasche"][v]["rett"]
		var c := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(d["vasche"][v]["fondo"])])
		var dir := (c - su) * Vector3(1, 0, 1)
		dir = dir.normalized()
		var riga := "profilo vasca_%d (avanti: quota rispetto a lei):" % v
		for i in range(-8, 14):
			var x: Vector3 = su + dir * (i * 0.25)
			var q := PhysicsRayQueryParameters3D.create(x + Vector3.UP * 6.0, x + Vector3.DOWN * 9.0)
			var hit := spazio.intersect_ray(q)
			riga += "  %.2f:%s" % [i * 0.25, ("%+.2f" % (hit["position"].y - su.y)) if not hit.is_empty() else "-"]
		print(riga)
		print("  acqua della vasca %+.2f, fondo %+.2f (rispetto a lei)" % [float(d["vasche"][v]["acqua"]) - su.y, float(d["vasche"][v]["fondo"]) - su.y])
	# le mesh che stanno sotto o intorno a lei nella vasca_1 (entro 3 m in orizzontale)
	var su1 := sala._posto_vasca(1)
	for mi: MeshInstance3D in sala.find_children("*", "MeshInstance3D", true, false):
		var bb := mi.global_transform * mi.get_aabb()
		var c := bb.get_center()
		var dxz := Vector2(c.x - su1.x, c.z - su1.z).length()
		if dxz < 3.5 and bb.size.length() < 60.0:
			print("mesh %s: centro %s, dimensioni %s, da %+.2f a %+.2f rispetto a lei" % [mi.get_path(), c, bb.size, bb.position.y - su1.y, bb.end.y - su1.y])
	get_tree().quit(0)

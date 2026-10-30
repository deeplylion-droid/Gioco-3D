extends Node
## Sonda: chi fa ombra sul muro sopra l'oblò della torre con la lampada d'emergenza del muro est (quella con l'ombra,
## SalaTorre._emergenza, x vicino a MURO_CONDOTTE_X). Costruisce la torre come nel gioco, trova la lampada più vicina
## all'oblò, prende una griglia di punti sulla faccia del muro attorno a lei e per ogni punto cerca le mesh che fanno
## ombra (cast_shadow acceso) attraversate dal segmento luce-punto (triangoli veri, anche le istanze dei MultiMesh).
## Stampa le mesh trovate col numero di punti che coprono e dove (sopra/sotto, a destra/sinistra della lampada).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_ombra_muro_oblo.gd

const RAGGIO_GRIGLIA := 2.0
const PASSO := 0.1

var _facce := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.costruzione_a_pezzi = true
	torre.visible = false
	torre.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(torre)
	await torre.costruisci_a_pezzi()
	torre.visible = true
	for i in 10:
		await get_tree().process_frame
	var o: Node3D = torre.oblo
	var lampada: OmniLight3D = null
	for l: OmniLight3D in torre.get_node(^"Luci").find_children("*", "OmniLight3D", true, false):
		if l.shadow_enabled and absf(l.global_position.x - SalaTorre.MURO_CONDOTTE_X) < 1.0 \
				and (lampada == null or l.global_position.distance_to(o.global_position) < lampada.global_position.distance_to(o.global_position)):
			lampada = l
	if lampada == null:
		print("SONDA: niente lampada con l'ombra sul muro est")
		Game.esci(1)
		return
	var lp := lampada.global_position
	print("SONDA lampada %s a %s, oblò a %s, blur %.1f" % [lampada.get_path(), lp, o.global_position, lampada.shadow_blur])
	# la faccia del muro: un raggio dalla lampada verso +x
	var q := PhysicsRayQueryParameters3D.create(lp, lp + Vector3.RIGHT * 2.0 * signf(SalaTorre.MURO_CONDOTTE_X - lp.x))
	var hit := torre.get_world_3d().direct_space_state.intersect_ray(q)
	var muro_x: float = (hit.position as Vector3).x - 0.01 if not hit.is_empty() else SalaTorre.MURO_CONDOTTE_X - 0.01
	print("SONDA faccia del muro a x %.3f (%s)" % [muro_x, hit.get("collider")])
	var geo: Array = []
	for g: GeometryInstance3D in torre.find_children("*", "GeometryInstance3D", true, false):
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not g.is_visible_in_tree():
			continue
		geo.append(g)
	var conta := {}
	var dove := {}
	var punti := 0
	var bui := 0
	var y := -RAGGIO_GRIGLIA
	while y <= RAGGIO_GRIGLIA:
		var z := -RAGGIO_GRIGLIA
		while z <= RAGGIO_GRIGLIA:
			var pt := Vector3(muro_x, lp.y + y, lp.z + z)
			punti += 1
			var chi := _bloccano(geo, lp, pt)
			if not chi.is_empty():
				bui += 1
			for g in chi:
				var k: String = str((g as Node).get_path())
				conta[k] = int(conta.get(k, 0)) + 1
				var d: Dictionary = dove.get(k, {"y0": INF, "y1": -INF, "z0": INF, "z1": -INF})
				d["y0"] = minf(d["y0"], y)
				d["y1"] = maxf(d["y1"], y)
				d["z0"] = minf(d["z0"], z)
				d["z1"] = maxf(d["z1"], z)
				dove[k] = d
			z += PASSO
		y += PASSO
	print("SONDA punti %d, in ombra %d" % [punti, bui])
	var chiavi := conta.keys()
	chiavi.sort_custom(func(a, b): return conta[a] > conta[b])
	for k in chiavi:
		var d: Dictionary = dove[k]
		var n := get_node(NodePath(k)) as GeometryInstance3D
		print("  OMBRA %d punti: %s (mesh %s, strati %d) y %.1f..%.1f z %.1f..%.1f rispetto alla lampada" % [conta[k], k,
			(n.get(&"mesh") as Resource).resource_name if n.get(&"mesh") else n.get_class(), n.layers, d["y0"], d["y1"], d["z0"], d["z1"]])
	Game.esci(0)


func _bloccano(geo: Array, da: Vector3, a: Vector3) -> Array:
	var out := []
	var seg := AABB(da, Vector3.ZERO).expand(a)
	for g: GeometryInstance3D in geo:
		if g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
				var t := g.global_transform * mm.get_instance_transform(i)
				if (t * mm.mesh.get_aabb()).intersects(seg) and _taglia(mm.mesh, t, da, a):
					out.append(g)
					break
		elif g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var t := g.global_transform
			if (t * (g as MeshInstance3D).mesh.get_aabb()).intersects(seg) and _taglia((g as MeshInstance3D).mesh, t, da, a):
				out.append(g)
	return out


## Il segmento [param da]-[param a] attraversa un triangolo di [param m] messo in [param t] (escluso l'ultimo cm vicino al muro).
func _taglia(m: Mesh, t: Transform3D, da: Vector3, a: Vector3) -> bool:
	var f: PackedVector3Array = _facce.get(m.get_instance_id(), PackedVector3Array())
	if f.is_empty():
		f = m.get_faces()
		_facce[m.get_instance_id()] = f
	var inv := t.affine_inverse()
	var la := inv * da
	var lb := inv * (a + (da - a).normalized() * 0.02)
	var dir := lb - la
	for i in range(0, f.size(), 3):
		var h = Geometry3D.segment_intersects_triangle(la, lb, f[i], f[i + 1], f[i + 2])
		if h != null:
			return true
	return false

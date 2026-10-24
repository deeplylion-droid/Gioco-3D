extends Node
## Collaudo del fiume lento (squadra collaudo): scrive in JSON, nelle coordinate della scena di prova del fiume
## (tests/scene/fiume_gioco_prova.tscn, il fiume nell'origine):
## - i marker della strada a piedi (ingresso, fine della fila, imbarco, approdo, porta);
## - l'altezza degli occhi in piedi e la posizione della camera seduti sulla ciambella rispetto al punto del tratto;
## - i tratti del fiume campionati ogni [constant PASSO] m (punto e direzione), compresi i rami sbagliati;
## - gli oggetti piccoli (riquadro sotto [constant PICCOLO] m), anche le istanze dei MultiMesh, e i MultiMesh grandi.
## Con il renderer vero (xvfb, vulkan): senza schermo i MultiMesh perdono le trasformazioni delle istanze.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- \
##        res://tests/cz/sonda_strada_fiume.gd <uscita.json>

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const PASSO := 2.0
const PICCOLO := 0.8

var level: Node
var p: Player
var fiume: FiumeLento


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var uscita: String = OS.get_cmdline_user_args()[1]
	get_tree().change_scene_to_file(SCENA)
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	for i in 6:
		await get_tree().process_frame
	level = get_tree().current_scene
	p = GameState.player
	fiume = level.get_node_or_null(^"Fiume/FiumeLento") as FiumeLento
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var out := {"marker": {}, "tratti": [], "piccoli": [], "multimesh": []}
	for m in level.get_node(^"Fiume/Marker").get_children():
		out.marker[String(m.name)] = _v((m as Node3D).global_position)
	out["occhi_in_piedi"] = p.stand_eye_height
	# seduti: la camera rispetto al punto del tratto e alla direzione
	var imbarco := level.get_node(^"Fiume/Marker/Imbarco") as Node3D
	p.teleport(imbarco.global_position, 0.0, 0.0)
	for i in 10:
		await get_tree().physics_frame
	fiume.sali(p)
	for i in 30:
		await get_tree().physics_frame
	var cam := get_viewport().get_camera_3d()
	var pt := fiume.tratto.punto(fiume.s)
	var dir := fiume.tratto.direzione(fiume.s)
	out["seduti"] = {"camera": _v(cam.global_position), "punto": _v(pt), "dir": _v(dir), "s": fiume.s,
			"ciambella": _v((fiume.get_node(^"Ciambella") as Node3D).global_position)}
	for t in fiume.find_children("*", "TrattoFiume", true, false):
		var tr := t as TrattoFiume
		var l := tr.lunghezza()
		var punti := []
		var s := 0.0
		while s <= l:
			punti.append([snappedf(s, 0.01), _v(tr.punto(s)), _v(tr.direzione(s))])
			s += PASSO
		out.tratti.append({"nome": String(tr.name), "sbagliato": tr.ramo_sbagliato, "uscita": tr.uscita,
				"prossimo": String(tr.prossimo.name) if tr.prossimo else "", "lunghezza": l, "punti": punti})
	for n in level.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var nome := String(level.get_path_to(g))
		if g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var ab := mm.mesh.get_aabb()
			var grande := ab.get_longest_axis_size() >= PICCOLO
			out.multimesh.append({"nodo": nome, "istanze": mm.instance_count, "box_mesh": [_v(ab.position), _v(ab.size)]})
			for i in mm.instance_count:
				var b: AABB = g.global_transform * mm.get_instance_transform(i) * ab
				if b.get_longest_axis_size() < PICCOLO:
					out.piccoli.append({"nodo": "%s_%d" % [nome, i], "centro": _v(b.get_center()), "box": [_v(b.position), _v(b.size)]})
				elif grande and i < 400:
					out.piccoli.append({"nodo": "%s_%d" % [nome, i], "centro": _v(b.get_center()), "box": [_v(b.position), _v(b.size)], "grande": true})
		else:
			var b2: AABB = g.global_transform * g.get_aabb()
			if b2.get_longest_axis_size() < PICCOLO and b2.size.length() > 0.001:
				out.piccoli.append({"nodo": nome, "centro": _v(b2.get_center()), "box": [_v(b2.position), _v(b2.size)]})
	# le ciambelle (anche le grandi), con il riquadro di tutte le loro mesh
	out["ciambelle"] = []
	for n in level.find_children("*", "Node3D", true, false):
		if not String(n.name).to_lower().contains("ciambella") or not (n as Node3D).is_visible_in_tree():
			continue
		var tot := AABB()
		var prima := true
		for m in n.find_children("*", "GeometryInstance3D", true, false) + ([n] if n is GeometryInstance3D else []):
			var gm := m as GeometryInstance3D
			var bb: AABB = gm.global_transform * gm.get_aabb()
			tot = bb if prima else tot.merge(bb)
			prima = false
		if not prima:
			out.ciambelle.append({"nodo": String(level.get_path_to(n)), "centro": _v(tot.get_center()), "box": [_v(tot.position), _v(tot.size)]})
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("SONDA FIUME: %d tratti, %d oggetti, %d multimesh" % [out.tratti.size(), out.piccoli.size(), out.multimesh.size()])
	get_tree().quit()


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

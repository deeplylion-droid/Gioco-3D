extends Node
## Collaudo: la scena del risveglio con lo squalo, fotogramma per fotogramma. Ogni [PASSO] fotogrammi scrive la
## pelle dello squalo deformata dallo scheletro (nel mondo), le ossa, la camera, la bava e la porta tagliafuoco;
## alla fine com'è il giocatore (torcia, comandi, checkpoint).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_squalo_scena.gd <cartella>

const PASSO := 2

var cartella := ""
var _t := 0.0


func _ready() -> void:
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var livello := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 20:
		await get_tree().physics_frame
	var p := GameState.player
	var rs := livello.get_node(^"Gioco/RisveglioSqualo")
	_stato_giocatore(p, livello, "prima")
	var finito := [false]
	rs.connect(&"finito", func(): finito[0] = true)
	livello.call(&"fai_risveglio", p, true)
	var bin := FileAccess.open(cartella + "/pelle.bin", FileAccess.WRITE)
	var fotogrammi := []
	var info := {}
	var n := 0
	while not finito[0] and _t < 25.0:
		await get_tree().process_frame
		_t += get_process_delta_time()
		n += 1
		if n % PASSO != 0:
			continue
		var sq := rs.get(&"squalo") as Node3D
		if sq == null:
			continue
		var f := {"t": snappedf(_t, 0.001), "da": bin.get_position()}
		var cam := get_viewport().get_camera_3d()
		f["camera"] = _v(cam.global_position)
		f["camera_avanti"] = _v(-cam.global_basis.z)
		f["near"] = cam.near
		var sk0: Skeleton3D = rs.get(&"_scheletro")
		if info.is_empty() and sk0:
			_scrivi_riposo(sq, sk0, info)
		if sk0:
			var buf := PackedFloat32Array()
			for bi in sk0.get_bone_count():
				var gp := sk0.global_transform * sk0.get_bone_global_pose(bi)
				for c in [gp.basis.x, gp.basis.y, gp.basis.z, gp.origin]:
					buf.append(c.x); buf.append(c.y); buf.append(c.z)
			bin.store_buffer(buf.to_byte_array())
		var sk: Skeleton3D = rs.get(&"_scheletro")
		if sk:
			var ossa := {}
			for b in sk.get_bone_count():
				ossa[sk.get_bone_name(b)] = _v(sk.global_transform * sk.get_bone_global_pose(b).origin)
			f["ossa"] = ossa
		var bava := sq.get_node_or_null(^"Bava")
		if bava:
			var bm := bava.get(&"_mesh") as ImmediateMesh
			var pts := []
			if bm and bm.get_surface_count() > 0:
				var arr := bm.surface_get_arrays(0)
				for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					pts.append(_v(v))
			f["bava"] = pts
			var capi := []
			for fl in bava.get(&"_fili"):
				capi.append([_v(bava.call(&"_mondo", bava.get(&"_testa"), fl["su"])), _v(bava.call(&"_mondo", bava.get(&"_mascella"), fl["giu"])), fl["intero"]])
			f["capi_bava"] = capi
			f["bava_forza"] = bava.get(&"_forza")
		var porta := rs.get(&"porta") as Node3D
		if porta:
			var pm := porta as MeshInstance3D
			f["porta"] = [_v(porta.global_position), snappedf(porta.global_rotation_degrees.y, 0.1)]
			if pm and pm.mesh:
				var b := pm.global_transform * pm.mesh.get_aabb()
				f["porta_box"] = _v(b.position) + _v(b.size)
		fotogrammi.append(f)
	bin.close()
	print("SCENA finita a %.2f s, %d fotogrammi" % [_t, fotogrammi.size()])
	for i in 120:
		await get_tree().process_frame
	_stato_giocatore(p, livello, "dopo")
	var out := FileAccess.open(cartella + "/scena.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"info": info, "fotogrammi": fotogrammi}))
	out.close()
	get_tree().quit()


## La pelle a riposo: per ogni mesh con la skin, i bind (osso e matrice) e per ogni superficie vertici, ossa, pesi e
## indici (file .bin), più il materiale.
func _scrivi_riposo(sq: Node, sk: Skeleton3D, info: Dictionary) -> void:
	info["ossa"] = sk.get_bone_count()
	var nomi := []
	for bi in sk.get_bone_count():
		nomi.append(sk.get_bone_name(bi))
	info["nomi_ossa"] = nomi
	info["mesh"] = []
	for mi in sq.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		var binds := []
		for i in m.skin.get_bind_count():
			var o := m.skin.get_bind_bone(i)
			if o < 0:
				o = sk.find_bone(m.skin.get_bind_name(i))
			var bp := m.skin.get_bind_pose(i)
			binds.append([o, [bp.basis.x.x, bp.basis.x.y, bp.basis.x.z, bp.basis.y.x, bp.basis.y.y, bp.basis.y.z,
					bp.basis.z.x, bp.basis.z.y, bp.basis.z.z, bp.origin.x, bp.origin.y, bp.origin.z]])
		var sup := []
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var base := cartella + "/%s_%d" % [m.name, si]
			for coppia in [["v", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)], ["i", arr[Mesh.ARRAY_INDEX]],
					["b", arr[Mesh.ARRAY_BONES]], ["w", arr[Mesh.ARRAY_WEIGHTS]]]:
				var fi := FileAccess.open(base + "_" + coppia[0] + ".bin", FileAccess.WRITE)
				var dato = coppia[1]
				if dato is PackedVector3Array:
					var pf := PackedFloat32Array()
					for v in dato:
						pf.append(v.x); pf.append(v.y); pf.append(v.z)
					fi.store_buffer(pf.to_byte_array())
				elif dato != null:
					fi.store_buffer(dato.to_byte_array())
				fi.close()
			var mat := m.mesh.surface_get_material(si)
			sup.append({"file": base.get_file(), "materiale": mat.resource_name if mat else "",
					"vertici": (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
					"ossa_per_vertice": (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(1, (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())})
		info["mesh"].append({"nome": String(m.name), "binds": binds, "superfici": sup})


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


func _stato_giocatore(p: Player, livello: Node, quando: String) -> void:
	var torcia = null
	for t in p.find_children("*", "Node3D", true, false):
		if t is Torcia:
			torcia = (t as Torcia).accesa
	var hud := p.get_node_or_null(^"HUD")
	var vis := []
	if hud:
		for c in hud.find_children("*", "Control", true, false):
			if (c as Control).is_visible_in_tree() and (c is Label or c is RichTextLabel):
				vis.append("%s=%s" % [c.name, str(c.get(&"text")).substr(0, 40)])
	print("GIOCATORE %s: comandi %s, torcia %s, posizione %s, yaw %.1f, checkpoint %s %s, hud %s" % [quando, p.input_enabled,
			torcia, p.global_position.snapped(Vector3.ONE * 0.01), rad_to_deg(p.yaw), GameState.snapshot.get("checkpoint", ""),
			GameState.snapshot.get("order", ""), vis])

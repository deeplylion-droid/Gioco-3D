extends Node
## Collaudo del manifesto rovinato della sala (manifesto_rovinato.glb) da solo: la sala intera non entra nella memoria
## della macchina per gli scatti. Il modello sta su un muro piatto messo a filo della sua faccia posteriore (nella sala
## lo mette a filo Posa.fissa_al_muro), con una luce neutra: si guardano i bordi strappati, i buchi e le parti che
## potrebbero staccarsi. Accanto, per confronto, il manifesto pulito del menu (manifesto.glb).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd \
##        -- res://tests/collaudo/scatti_manifesto.gd <cartella>


func _ready() -> void:
	_run.call_deferred()


func _aabb(n: Node) -> AABB:
	var b := AABB()
	var primo := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		b = bb if primo else b.merge(bb)
		primo = false
	return b


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = e
	add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-30, 40, 0)
	sole.light_energy = 1.4
	sole.shadow_enabled = true
	add_child(sole)
	var righe := PackedStringArray()
	var x := 0.0
	var centri := {}
	for nome in ["manifesto_rovinato", "manifesto"]:
		var m := (load("res://assets/models/mascotte/jilly/%s.glb" % nome) as PackedScene).instantiate() as Node3D
		add_child(m)
		await get_tree().process_frame
		var b := _aabb(m)
		m.position = Vector3(x, 0, 0) - Vector3(b.get_center().x, b.position.y, b.position.z)
		await get_tree().process_frame
		b = _aabb(m)
		righe.append("%s: misure %.3f x %.3f x %.3f m (spessore %.1f mm)" % [nome, b.size.x, b.size.y, b.size.z, b.size.z * 1000.0])
		# il muro dietro, a filo della faccia posteriore
		var muro := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(b.size.x + 0.8, b.size.y + 0.8, 0.1)
		muro.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.57, 0.6)
		muro.material_override = mat
		muro.position = Vector3(x, b.get_center().y, b.position.z - 0.05)
		add_child(muro)
		centri[nome] = b
		x += b.size.x + 1.5
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var b0: AABB = centri["manifesto_rovinato"]
	var c := b0.get_center()
	var viste := {
		"rovinato_davanti": [c + Vector3(0, 0, 1.6), c],
		"rovinato_bordo_sx": [c + Vector3(-b0.size.x * 0.5 - 0.35, 0.1, 0.25), c + Vector3(-b0.size.x * 0.5, 0, 0)],
		"rovinato_bordo_dx": [c + Vector3(b0.size.x * 0.5 + 0.35, -0.1, 0.25), c + Vector3(b0.size.x * 0.5, 0, 0)],
		"rovinato_alto": [c + Vector3(0.2, b0.size.y * 0.5 + 0.4, 0.3), c + Vector3(0, b0.size.y * 0.4, 0)],
		"rovinato_basso": [c + Vector3(-0.2, -b0.size.y * 0.5 - 0.3, 0.35), c + Vector3(0, -b0.size.y * 0.4, 0)],
		"pulito_davanti": [(centri["manifesto"] as AABB).get_center() + Vector3(0, 0, 1.6), (centri["manifesto"] as AABB).get_center()],
	}
	for v in viste:
		cam.global_position = viste[v][0]
		cam.look_at(viste[v][1], Vector3.UP)
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join(v + ".jpg"), 0.9)
	var fh := FileAccess.open(out.path_join("misure.txt"), FileAccess.WRITE)
	fh.store_string("\n".join(righe) + "\n")
	fh.close()
	print("\n".join(righe))
	get_tree().quit()

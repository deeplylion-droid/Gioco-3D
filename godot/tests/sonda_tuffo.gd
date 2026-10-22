extends Node
## Sonda per il tuffo: misure di lei affacciata alla fossa (scheletro, ossa, tentacoli), della fossa e del condotto.
const LEVEL := "res://scenes/sala_principale.tscn"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	var level := get_tree().current_scene
	var lei := level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	lei.call(&"_affaccia")
	for i in 10:
		await get_tree().physics_frame
	var m := lei.medusa as Node3D
	print("MEDUSA ", m.global_transform)
	print("SBUCA ", lei.punto_sbuca.global_transform, " FUGA ", lei.punto_fuga.global_position if lei.punto_fuga else Vector3.INF)
	print("PELO ", lei.call(&"_pelo"), " FOSSA ", lei.superficie_fossa.global_transform * lei.superficie_fossa.mesh.get_aabb())
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	print("SCHELETRO ", sk.get_path(), " globale ", sk.global_transform, " ossa ", sk.get_bone_count())
	var ap := m.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	print("ANIM ", ap.get_path(), " root ", ap.root_node, " corrente ", ap.current_animation, " lista ", ap.get_animation_list())
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		var tip := sk.get_bone_children(b).is_empty()
		if not n.begins_with("tentacolo") or n.ends_with("_01") or tip:
			var g := sk.global_transform * sk.get_bone_global_pose(b)
			print("OSSO %s padre %s pos %s rest_len %.3f" % [n, sk.get_bone_name(sk.get_bone_parent(b)) if sk.get_bone_parent(b) >= 0 else "-", g.origin, sk.get_bone_rest(b).origin.length() * sk.global_basis.get_scale().x])
	for n in ["colonna_2", "braccio.L", "avambraccio.L", "tentacolo_01_03", "testa"]:
		var b := sk.find_bone(n)
		var c := sk.get_bone_children(b)[0]
		var gb := sk.get_bone_global_pose(b)
		var gc := sk.get_bone_global_pose(c)
		var d := (gc.origin - gb.origin).normalized()
		print("ASSI %s verso il figlio %s: x %.2f y %.2f z %.2f, scala %s" % [n, sk.get_bone_name(c), gb.basis.x.normalized().dot(d), gb.basis.y.normalized().dot(d), gb.basis.z.normalized().dot(d), gb.basis.get_scale()])
	var mi := m.find_children("*", "MeshInstance3D", true, false)
	for x in mi:
		var mm := (x as MeshInstance3D).mesh
		if mm and mm is ArrayMesh and (mm as ArrayMesh).get_blend_shape_count() > 0:
			print("BLEND ", x.name, " ", range((mm as ArrayMesh).get_blend_shape_count()).map(func(i): return (mm as ArrayMesh).get_blend_shape_name(i)).slice(0, 4))
	print("PARENTI ", range(sk.get_bone_count()).filter(func(b): return sk.get_bone_parent(b) > b).size(), " ossa con il padre dopo di loro")
	get_tree().quit()

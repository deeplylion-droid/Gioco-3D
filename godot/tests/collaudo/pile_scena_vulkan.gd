extends Node
## Collaudo finale 0.3.21 (enigmi): le istanze dei MultiMesh delle pile del fiume come sono nella scena, col renderer
## vero (senza schermo il server di rendering finto non tiene le trasformazioni: tutte identità). Come la modalità
## "scena" di tools/salva_pile_fiume.gd, ma 60 fotogrammi dopo che il fiume è costruito, con le coordinate del fiume.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- <questo> <file>

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const FIUME := preload("res://scripts/risalita/fiume_gioco.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	var dump: String = a[1]
	get_tree().change_scene_to_file(SCENA)
	var fiume: Node3D = null
	for i in 12000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s == null:
			continue
		for f in s.find_children("*", "Node3D", true, false):
			if (f as Node).get_script() == FIUME and f.get(&"costruita") == true:
				fiume = f
		if fiume:
			break
	if fiume == null:
		print("PILE: il fiume non si è costruito")
		get_tree().quit(1)
		return
	for i in 60:
		await get_tree().process_frame
	var righe := PackedStringArray()
	var identita := 0
	var tot := 0
	for nome in ["PileCasse", "PileCartone", "PileCartoneAperte", "PileScatole", "PileScatoleColorate", "PileCasseSciolte"]:
		var mmi := fiume.get_node_or_null(NodePath(nome)) as MultiMeshInstance3D
		if mmi == null:
			righe.append("%s assente" % nome)
			continue
		var mm := mmi.multimesh
		var xf_loc := fiume.global_transform.affine_inverse() * mmi.global_transform
		righe.append("%s %d %s" % [nome, mm.instance_count, mm.mesh.resource_path if mm.mesh else "-"])
		for i in mm.instance_count:
			var t := xf_loc * mm.get_instance_transform(i)
			tot += 1
			if mm.get_instance_transform(i) == Transform3D.IDENTITY:
				identita += 1
			var o := t.origin
			var b := t.basis
			righe.append("%.5f %.5f %.5f | %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f%s" % [o.x, o.y, o.z, b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z,
					(" | " + var_to_str(mm.get_instance_color(i))) if mm.use_colors else ""])
	var f := FileAccess.open(dump, FileAccess.WRITE)
	for r in righe:
		f.store_line(r)
	f.close()
	print("PILE: scena in %s (%d righe, %d istanze, %d identità)" % [dump, righe.size(), tot, identita])
	get_tree().quit()

extends Node
## Collaudo: le pile di scatoloni del fiume scritte in un file, per vedere che quelle salvate già pronte (ritocchi dopo la
## 0.3.20) sono identiche a quelle costruite prima. Nella Risalita della scena di prova, ogni MultiMeshInstance3D Pile* del
## fiume: quante istanze, e ogni trasformazione (globale, al millimetro e al millesimo) e colore; poi anche le collisioni
## delle pile (forme sotto i corpi delle pile). Scrive <file.json> e stampa i conti e un'impronta (hash) per gruppo.
## Col renderer vero (senza schermo i MultiMesh perdono le trasformazioni):
##   xvfb-run -a -s "-screen 0 320x240x24" godot --path godot --rendering-driver vulkan --resolution 320x240 \
##     --script res://tests/run.gd -- res://tests/collaudo/pile_dump.gd <file.json>


func _ready() -> void:
	_run.call_deferred()


func _r(x: float) -> float:
	return snappedf(x, 0.001)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var uscita: String = OS.get_cmdline_user_args()[1]
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	var ris: Node = null
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		ris = sc.get_node_or_null(^"Risalita") if sc else null
		if ris and ris.get(&"fiume") != null and not bool(ris.call(&"lavori_in_corso")):
			break
	var fiu := ris.get(&"fiume") as Node3D
	var out := {}
	for m in fiu.find_children("Pile*", "MultiMeshInstance3D", true, false):
		var mmi := m as MultiMeshInstance3D
		var mm := mmi.multimesh
		var righe := []
		for i in mm.instance_count:
			var t := mmi.global_transform * mm.get_instance_transform(i)
			var b := t.basis
			var riga := [_r(t.origin.x), _r(t.origin.y), _r(t.origin.z), _r(b.x.x), _r(b.x.y), _r(b.x.z), _r(b.y.x), _r(b.y.y), _r(b.y.z), _r(b.z.x), _r(b.z.y), _r(b.z.z)]
			if mm.use_colors:
				var c := mm.get_instance_color(i)
				riga.append_array([_r(c.r), _r(c.g), _r(c.b)])
			righe.append(riga)
		var nome := String(fiu.get_path_to(mmi))
		out[nome] = righe
		print("PILE: %s: %d istanze, impronta %s" % [nome, righe.size(), JSON.stringify(righe).md5_text()])
	# le collisioni a scatola del fiume (fra queste quelle delle pile)
	var forme := []
	for c in fiu.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if not cs.shape is BoxShape3D:
			continue
		var t := cs.global_transform
		var s := cs.shape
		var dim := (s as BoxShape3D).size if s is BoxShape3D else Vector3.ZERO
		forme.append([_r(t.origin.x), _r(t.origin.y), _r(t.origin.z), _r(t.basis.x.x), _r(t.basis.x.z), _r(dim.x), _r(dim.y), _r(dim.z)])
	forme.sort()
	out["collisioni"] = forme
	print("PILE: collisioni a scatola del fiume: %d forme, impronta %s" % [forme.size(), JSON.stringify(forme).md5_text()])
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("PILE: scritto %s" % uscita)
	get_tree().quit()

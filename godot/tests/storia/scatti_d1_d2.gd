extends Node
## Scatti di D1 e D2 (i disegni del bambino con la scatola, 0.5.0) dagli occhi del giocatore, sulla strada vera:
## per ognuno il primo punto da cui si vede camminando e uno da vicino, da in piedi (occhi a 1,6 m). Con le luci del
## momento: D1 prima del risveglio (il corridoio del risveglio), D2 al blackout (dopo la leva della sala pompe).
## Una radice nuova con gli stessi nomi della sala, solo con la zona e l'atmosfera (la sala intera non entra nella
## memoria del renderer software), e accese solo le mesh entro 25 m.
## Uso (sotto il lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/storia/scatti_d1_d2.gd <cartella> D1|D2

const SALA := "res://scenes/sala_principale.tscn"
## [zona, luci, scatti: [nome, occhio, guarda] nel sistema della zona]
const SCATTI := {
	"D1": ["Interni", 0, [
		["d1_da_lontano", Vector3(13.5, 1.6, -1.3), Vector3(6.0, 1.3, -1.3)],
		["d1_vicino", Vector3(8.5, 1.6, -0.8), Vector3(8.6, 0.84, -2.6)],
	]],
	"D2": ["Tecnici", 2, [
		["d2_da_lontano", Vector3(46.9, 1.6, 1.4), Vector3(52.6, 1.2, 1.5)],
		["d2_vicino", Vector3(51.0, 1.6, 1.3), Vector3(52.6, 1.1, 1.5)],
	]],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cartella := args[1]
	var quale: String = args[2]
	var dati: Array = SCATTI[quale]
	GameState.imposta_luci(dati[1])
	var tutta := (load(SALA) as PackedScene).instantiate() as Node3D
	var lv := Node3D.new()
	lv.name = "SalaPerScatto"
	for nome in [dati[0], "Atmosfera"]:
		var n := tutta.get_node_or_null(NodePath(nome))
		if n:
			n.owner = null
			tutta.remove_child(n)
			lv.add_child(n)
	tutta.free()
	get_tree().root.add_child(lv)
	var zona := lv.get_node(NodePath(dati[0])) as Node3D
	var primo: Array = dati[2][0]
	var centro := zona.to_global(primo[1])
	for g in lv.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		var aabb := gi.global_transform * gi.get_aabb()
		if aabb.get_center().distance_to(centro) - aabb.size.length() * 0.5 > 25.0:
			gi.visible = false
	var cam := Camera3D.new()
	cam.fov = 75
	lv.add_child(cam)
	cam.make_current()
	for i in 60:
		await get_tree().process_frame
	GameState.imposta_luci(dati[1])
	for s in dati[2]:
		cam.global_position = zona.to_global(s[1])
		cam.look_at(zona.to_global(s[2]), Vector3.UP)
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [cartella, s[0]], 0.9)
		print("SCATTO: ", s[0])
	get_tree().quit()

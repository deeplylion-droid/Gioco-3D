extends Node
## Collaudo 0.3.22: la schermata di caricamento della sala col renderer vero, solo per gli scatti (a 2; 4,6 e 6,4 s) e
## le misure del video (cornice, rettangolo del video, proporzioni, posizione, testi). Poi il processo si chiude di colpo
## (OS.kill), prima che la sala entri in memoria: misura_caricamento_jilly.gd, che aspetta la sala, sul renderer
## software arriva a 12-14 GB e il sistema lo uccide.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 WxHx24" godot --path godot --rendering-driver vulkan
##   --resolution WxH --script res://tests/run.gd -- res://tests/collaudo/car_scatti.gd <cartella> [prefisso]

var cart := ""
var pre := ""


func _ready() -> void:
	_run.call_deferred()


func _rss() -> int:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f and not f.eof_reached():
		var r := f.get_line()
		if r.begins_with("VmRSS:"):
			return r.split(" ", false)[1].to_int() / 1024
	return -1


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else "/tmp/car_scatti"
	pre = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(cart)
	get_tree().change_scene_to_file("res://scenes/ui/caricamento.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var s := get_tree().current_scene
	var t0 := Time.get_ticks_msec()
	var momenti := [2.0, 4.6, 6.4]
	var k := 0
	var pos := []
	var av := []
	while k < momenti.size():
		await get_tree().process_frame
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		if dt >= momenti[k]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(cart.path_join("%scaricamento_%d.jpg" % [pre, k]), 0.9)
			var v := s.find_child("VideoJilly", true, false) as VideoStreamPlayer
			pos.append(v.stream_position if v else -1.0)
			av.append(s.get(&"avanzamento"))
			print("CS: scatto %d a %.1f s, video a %.2f s, avanzamento %.0f%%, RSS %d MB" % [k, dt, pos[-1], av[-1] * 100.0, _rss()])
			k += 1
	var v := s.find_child("VideoJilly", true, false) as VideoStreamPlayer
	var vp := get_viewport().get_visible_rect().size
	if v:
		var tex := v.get_video_texture()
		var ts := tex.get_size() if tex else Vector2.ZERO
		var r := v.get_global_rect()
		var c := (v.get_parent() as Control).get_global_rect()
		print("CS: finestra %s; video %dx%d (%.3f); cornice %s; rettangolo del video %s (%.3f); deformazione %.3f; in ciclo %s, va %s" % [
			vp, ts.x, ts.y, ts.x / maxf(ts.y, 1.0), c, r, r.size.x / maxf(r.size.y, 1.0),
			(r.size.x / maxf(r.size.y, 1.0)) / (ts.x / maxf(ts.y, 1.0)), v.loop, v.is_playing()])
	for l: Label in s.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text != "":
			var g := l.get_global_rect()
			print("CS: testo «%s» %s, righe %d/%d, fuori %s" % [l.text.replace("\n", " / ").left(90), g, l.get_visible_line_count(), l.get_line_count(),
				g.position.x < 0 or g.end.x > vp.x or g.end.y > vp.y])
	print("CS: finito, chiudo di colpo")
	OS.kill(OS.get_process_id())

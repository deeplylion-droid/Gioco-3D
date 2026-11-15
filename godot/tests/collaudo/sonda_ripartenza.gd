extends Node
## Collaudo: la presa nel tunnel e la ripartenza dal checkpoint, col giocatore vero nella scena di prova
## (sottomarino_prova.tscn). Il giocatore entra nel tunnel, si ferma a [code]S[/code] m (predefinito 30), lei gli arriva
## dietro e lo prende; poi si segue la ripartenza per 15 s: dove si riparte, se il tunnel c'è ancora, dove sta lei.
## Uso: godot [--headless] --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_ripartenza.gd
## Con GETTO=1, prima della presa, un getto vero in faccia (mirando al viso) per vedere se la respinge.

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	var level := get_tree().current_scene
	var p := GameState.player
	var ins := level.get_node("SalaInseguimento") as SalaInseguimento
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	ins.sb1_finito.connect(sott.attiva_tunnel)
	p.water_pack.set_equipped(true, false)
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	ins.sb1_finito.emit()
	await _frames(5)
	var s0 := float(OS.get_environment("S")) if OS.get_environment("S") != "" else 30.0
	var q := sott.punto(s0) - sott.destra(s0) * (sott.canale + 1.3) + Vector3.UP * (sott.piano - sott.acqua + 0.05)
	p.teleport(q)
	await _frames(30)
	print("RIPARTENZA: giocatore a s %.1f %s, checkpoint presi: %s" % [s0, str(p.global_position), GameState.snapshot.get("checkpoint", "-") if GameState.snapshot is Dictionary else "-"])
	sott._s_bersaglio = s0
	sott.insegui_da(s0 - 9.0)
	var preso := [false]
	sott.giocatore_preso.connect(func(): preso[0] = true)
	var t0 := Time.get_ticks_msec()
	var getto_fatto := false
	while not preso[0] and Time.get_ticks_msec() - t0 < 30000:
		await _frames(1)
		if OS.get_environment("GETTO") != "" and not getto_fatto and sott._s_bersaglio - sott.lei_s < (float(OS.get_environment("GAP")) if OS.get_environment("GAP") != "" else 6.0) and sott.lei_tunnel.stato == LeiTunnel.Stato.INSEGUE:
			getto_fatto = true
			var viso := sott.lei_tunnel.find_child("Viso", true, false) as Node3D
			print("RIPARTENZA: getto da gap %.1f, viso a %s" % [sott._s_bersaglio - sott.lei_s, str(viso.global_position if viso else Vector3.ZERO)])
			var r := [0]
			var ts := Time.get_ticks_msec()
			sott.lei_respinta.connect(func():
				r[0] += 1
				print("RIPARTENZA: respinta dopo %.2f s di getto, gap %.1f" % [(Time.get_ticks_msec() - ts) / 1000.0, sott._s_bersaglio - sott.lei_s]))
			Input.action_press(&"spray")
			for k in 60:
				if viso:
					p.look_at_point(viso.global_position)
				await _frames(1)
				if preso[0]:
					print("RIPARTENZA: presa durante il getto dopo %.2f s" % ((Time.get_ticks_msec() - ts) / 1000.0))
					break
			Input.action_release(&"spray")
			print("RIPARTENZA: dopo 1 s di getto respinta %d volte, stato %s, gap %.1f" % [r[0], SalaSottomarino.Lei.keys()[sott.lei_stato], sott._s_bersaglio - sott.lei_s])
	print("RIPARTENZA: preso %s dopo %.1f s (gap %.1f)" % [preso[0], (Time.get_ticks_msec() - t0) / 1000.0, sott._s_bersaglio - sott.lei_s])
	var scena0 := get_tree().current_scene
	for k in 30:
		await _frames(30)
		var sc := get_tree().current_scene
		var pg := GameState.player
		var st := sc.get_node_or_null("SalaSottomarino") if sc else null
		print("RIPARTENZA: +%.1f s scena %s (stessa %s) giocatore %s comandi %s tunnel %s lei %s" % [
				(k + 1) * 0.5, sc.name if sc else "-", sc == scena0, str(pg.global_position.snappedf(0.01)) if pg and is_instance_valid(pg) else "-",
				pg.input_enabled if pg and is_instance_valid(pg) else "-", st != null and bool(st.get(&"costruita")) if st else "niente",
				SalaSottomarino.Lei.keys()[st.lei_stato] if st else "-"])
	get_tree().quit()

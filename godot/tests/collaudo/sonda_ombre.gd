extends Node
## Collaudo dei ritocchi di ambienti-2 per la 0.3.21 (copiato da lavoro/collaudo-ritocchi; grafica-2: misura tre
## configurazioni, le ombre delle tre lampade verdi, solo quella della vasca 3 come nel gioco, nessuna): le tre lampade verdi delle paratie giuste ora fanno ombra (OmniLight
## con meta lampada_paratia_verde). Col renderer vero, la torre con l'inseguimento come nel gioco (luci della sala spente,
## paratie aperte): 1) quante luci con ombra ci sono e quante se ne vedono insieme (sfera della luce dentro il campo
## visivo della camera) in una griglia di pose sopra le vasche e i camminamenti, 8 direzioni ciascuna, e il punto
## peggiore; 2) nelle pose scelte (le vasche, le bocche, il punto peggiore) il tempo del fotogramma con le ombre delle
## lampade verdi accese e spente (media e massimo di 60 fotogrammi dopo 30 di assestamento, tempo vero e tempo di
## disegno misurato dal RenderingServer), due giri alternati. Stampa OMBRE:.
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##   --script res://tests/run.gd -- res://tests/collaudo/sonda_ombre.gd

const PLAYER := "res://scenes/player/player.tscn"
var ins: SalaInseguimento
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ombre_viste() -> Array:
	var piani := cam.get_frustum()
	var out := []
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		var li := l as Light3D
		if not li.is_visible_in_tree() or not li.shadow_enabled:
			continue
		var r := 1000.0
		if li is OmniLight3D:
			r = (li as OmniLight3D).omni_range
		elif li is SpotLight3D:
			r = (li as SpotLight3D).spot_range
		var c := li.global_position
		if c.distance_to(cam.global_position) > 60.0 + r:
			continue
		var dentro := true
		for pl in piani:
			if (pl as Plane).distance_to(c) > r:
				dentro = false
				break
		if dentro:
			out.append(li)
	return out


func _verdi() -> Array:
	var out := []
	for l in ins.find_children("*", "OmniLight3D", true, false):
		if l.get_meta(&"lampada_paratia_verde", false):
			out.append(l)
	return out


func _misura(n: int) -> Array:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _frames(30)
	var tot := 0.0
	var mx := 0.0
	var disegno := 0.0
	var t := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var t2 := Time.get_ticks_usec()
		var d := (t2 - t) / 1000.0
		t = t2
		tot += d
		mx = maxf(mx, d)
		disegno += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return [tot / n, mx, disegno / n]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _frames(30)
	ins = torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	await _frames(240)
	if ins.lei:
		ins.lei.visible = false
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	cam = Camera3D.new()
	cam.fov = p.camera.fov
	cam.near = p.camera.near
	cam.far = p.camera.far
	cam.attributes = p.camera.attributes
	add_child(cam)
	p.set_physics_process(false)
	p.global_position = Vector3(40.0, -27.0, -5.0)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	cam.make_current()
	var verdi := _verdi()
	var tutte := 0
	var omni := 0
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		if (l as Light3D).shadow_enabled and (l as Light3D).is_visible_in_tree():
			tutte += 1
			if l is OmniLight3D:
				omni += 1
	print("OMBRE: lampade verdi delle paratie con ombra: %d (%s); luci con ombra in tutta la scena: %d (omni %d)" % [verdi.size(),
			", ".join(verdi.map(func(l): return str((l as Node3D).global_position.snapped(Vector3.ONE * 0.01)))), tutte, omni])
	# 1) la griglia: sopra le vasche (occhi a 1,1 m sopra il fondo) e sui camminamenti fra le vasche
	var pose := []
	for i in (ins.dati["vasche"] as Array).size():
		var v: Dictionary = ins.dati["vasche"][i]
		var r: Array = v["rett"]
		for fx in [0.2, 0.5, 0.8]:
			for fz in [0.2, 0.5, 0.8]:
				var q := SalaInseguimento.b([lerpf(r[0], r[2], fx), lerpf(r[1], r[3], fz), float(v["fondo"]) + 1.1])
				pose.append(["vasca_%d" % i, q])
	for nome: String in ins.dati["tubi"]:
		var linea: Array = ins.dati["tubi"][nome]
		for k in [0, mini(6, linea.size() - 1)]:
			pose.append([nome, SalaInseguimento.b(linea[k]) + Vector3.UP * 0.1])
	var peggio := [-1, null, 0.0, ""]
	var per_zona := {}
	for ps in pose:
		for k in 8:
			var ang := TAU * k / 8.0
			cam.global_position = ps[1]
			cam.look_at(cam.global_position + Vector3(cos(ang), -0.1, sin(ang)), Vector3.UP)
			var viste := _ombre_viste()
			var n_verdi := 0
			for l in viste:
				if l in verdi:
					n_verdi += 1
			per_zona[ps[0]] = maxi(int(per_zona.get(ps[0], 0)), viste.size())
			if viste.size() > peggio[0]:
				peggio = [viste.size(), ps[1], ang, ps[0], n_verdi]
	print("OMBRE: luci con ombra viste insieme, al massimo per zona: %s" % per_zona)
	print("OMBRE: punto peggiore %s a %s, direzione %.0f gradi: %d luci con ombra nel campo visivo (di cui %d lampade verdi)" % [peggio[3],
			(peggio[1] as Vector3).snapped(Vector3.ONE * 0.01), rad_to_deg(peggio[2]), peggio[0], peggio[4]])
	# 2) i tempi: le pose delle vasche (dal centro verso la paratia verde), una bocca da dentro, il punto peggiore
	var misure := []
	var lp: Array = ins.luci_dati["paratie"]
	for i in lp.size():
		if lp[i][1] != "verde":
			continue
		var bers := SalaInseguimento.b(ins.luci_dati["bersagli"][i])
		var verso := SalaInseguimento.b(lp[i][2]).normalized()
		misure.append(["paratia_verde_%d" % i, bers + verso * 3.5 + Vector3.DOWN * 0.3, bers + Vector3.UP * 0.6])
	misure.append(["tubo_3_da_dentro", Vector3(65.28869, -27.92377, -3.147806), Vector3(65.28869, -27.92377, -3.147806) + Vector3(0.976734, 0.149438, 0.153816)])
	var pp: Vector3 = peggio[1]
	misure.append(["punto_peggiore", pp, pp + Vector3(cos(peggio[2]), -0.1, sin(peggio[2]))])
	for m in misure:
		cam.global_position = m[1]
		cam.look_at(m[2], Vector3.UP)
		var righe := []
		# (grafica-2, 0.3.21: tre configurazioni; "solo C3" è quella del gioco, l'ombra solo sulla verde della vasca 3)
		for giro in 2:
			for conf in ["tre", "solo C3", "nessuna"]:
				for l in verdi:
					var c3 := (l as Node3D).global_position.distance_to(Vector3(66.95, -24.35, -3.6)) < 0.5
					(l as OmniLight3D).shadow_enabled = conf == "tre" or (conf == "solo C3" and c3)
				var t := await _misura(60)
				righe.append("%s %.0f ms (max %.0f, disegno %.0f)" % ["ombre " + conf, t[0], t[1], t[2]])
		for l in verdi:
			(l as OmniLight3D).shadow_enabled = (l as Node3D).global_position.distance_to(Vector3(66.95, -24.35, -3.6)) < 0.5
		print("OMBRE: %s: %d luci con ombra nel campo visivo; %s" % [m[0], _ombre_viste().size(), "; ".join(righe)])
	print("OMBRE: finito")
	get_tree().quit()

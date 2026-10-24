extends Node
## Test della vista subacquea (difetto della camera delle onde, 15 ottobre: "ci sono un paio di pezzi del tunnel dove
## c'è acqua e ti fa la visuale sottomarina"; errori_da_non_ripetere.md: con la testa fuori dall'acqua la vista resta
## normale). In ogni acqua del gioco (la sala con le stanze della Risalita, la torre, l'inseguimento), su una griglia di
## punti di ogni acqua e dove due acque si sovrappongono:
## - con la testa 15 cm sopra il pelo la vista resta normale: l'effetto (UnderwaterEffect) non è sott'acqua e il pelo
##   che dà allo shader è sotto tutti i punti vicini alla camera da cui lo shader decide (al più 7 cm dalla camera);
## - con la testa 10 cm sotto il pelo, dove sotto c'è acqua profonda (il fondo vero, a raggi, almeno 30 cm più giù) e
##   l'acqua è profonda almeno quanto chiede l'effetto, la vista è subacquea.
## Con lo schermo (non --headless) anche uno scatto vero dello shader con due acque sovrapposte, la prima della tabella
## col pelo sopra la testa: sopra il pelo dell'acqua più vicina l'immagine resta quella senza effetto.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_vista_subacquea.gd [zone]
##      (zone: sala, torre, inseguimento, sovrapposte; senza: tutte)

const SALA := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const INSEGUIMENTO := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const SOPRA := 0.15
const SOTTO := 0.10
## Quanto lontano dalla camera stanno i punti da cui lo shader decide (camera_near 5 cm, ai bordi dello schermo un
## po' di più) più le onde dello shader (2,2 cm).
const VICINO := 0.07 + 0.022

var _ok := 0
var _ko := 0
var _cam: Camera3D
var _eff: UnderwaterEffect


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var zone: Array = OS.get_cmdline_user_args().slice(1)
	if zone.is_empty():
		zone = ["sovrapposte", "sala", "torre", "inseguimento"]
	for z in zone:
		print("== ", z)
		match z:
			"sovrapposte":
				await _sovrapposte()
			"sala":
				get_tree().change_scene_to_file(SALA)
				for i in 600:
					await get_tree().process_frame
					if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
						break
				for i in 60:
					await get_tree().process_frame
				await _zona(z)
			_:
				get_tree().change_scene_to_file(TORRE if z == "torre" else INSEGUIMENTO)
				for i in 60:
					await get_tree().process_frame
				await _zona(z)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _camera() -> void:
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = Camera3D.new()
	_cam.near = 0.05
	add_child(_cam)
	_cam.make_current()
	_eff = UnderwaterEffect.new()
	_eff.bubbles = false
	_cam.add_child(_eff)


## La decisione dell'effetto con la testa in [param p]: [sott'acqua, il pelo dato allo shader o -INF].
func _vista(p: Vector3) -> Array:
	_cam.global_position = p
	_eff._process(0.0)
	var mat: ShaderMaterial = _eff.get(&"_mat")
	var ha: bool = mat.get_shader_parameter("has_body")
	return [_eff.is_underwater, float(mat.get_shader_parameter("body_level")) if ha else -INF]


func _zona(z: String) -> void:
	_camera()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var wm := get_node("/root/WaterManager")
	var corpi: Array = wm.get_bodies().filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	print("  %d acque: %s" % [corpi.size(), ", ".join(corpi.map(func(b): return "%s (pelo %.2f, fondo %.2f)" % [b.get_parent().name + "/" + b.name, b.level, b.bottom]))])
	var spazio := get_viewport().world_3d.direct_space_state
	var sopra_ko := []
	var sotto_ko := []
	var provati_sotto := 0
	var punti := 0
	for b in corpi:
		var c: Vector3 = (b as Node3D).global_position
		var sz: Vector2 = b.size
		var pts: Array[Vector2] = []
		for i in 7:
			for j in 7:
				pts.append(Vector2(c.x + (i / 6.0 - 0.5) * (sz.x - 0.2), c.z + (j / 6.0 - 0.5) * (sz.y - 0.2)))
		# dove si sovrappone con un'altra acqua, più fitto
		for b2 in corpi:
			if b2 == b:
				continue
			var r1 := Rect2(c.x - sz.x * 0.5, c.z - sz.y * 0.5, sz.x, sz.y)
			var c2: Vector3 = (b2 as Node3D).global_position
			var r2 := Rect2(c2.x - b2.size.x * 0.5, c2.z - b2.size.y * 0.5, b2.size.x, b2.size.y)
			var r := r1.intersection(r2)
			if r.has_area():
				for i in 5:
					for j in 5:
						pts.append(r.position + r.size * Vector2((i + 0.5) / 5.0, (j + 0.5) / 5.0))
		if b.is_empty():
			continue
		for q in pts:
			var lv: float = b.get_surface_height(Vector3(q.x, b.level, q.y))
			var p := Vector3(q.x, lv + SOPRA, q.y)
			punti += 1
			var v := _vista(p)
			if v[0] or float(v[1]) > p.y - VICINO:
				sopra_ko.append("%s in %s (pelo dato allo shader %.2f)" % [b.name, p.snapped(Vector3.ONE * 0.01), v[1]])
			# sotto: solo dove c'è acqua profonda davvero (il fondo vero sotto) e l'effetto la conta
			if b.level - b.bottom < _eff.min_depth:
				continue
			var ray := PhysicsRayQueryParameters3D.create(Vector3(q.x, lv - 0.02, q.y), Vector3(q.x, lv - 3.0, q.y), Layers.WORLD)
			var hit := spazio.intersect_ray(ray)
			var fondo: float = (hit["position"] as Vector3).y if not hit.is_empty() else b.bottom
			if fondo > lv - SOTTO - 0.3:
				continue
			# (sopra il punto, fino al pelo, niente di solido: non dentro un muro o sotto una passerella)
			var su := PhysicsRayQueryParameters3D.create(Vector3(q.x, lv - SOTTO, q.y), Vector3(q.x, lv + 0.02, q.y), Layers.WORLD)
			su.hit_from_inside = true
			if not spazio.intersect_ray(su).is_empty():
				continue
			provati_sotto += 1
			v = _vista(Vector3(q.x, lv - SOTTO, q.y))
			if not v[0]:
				sotto_ko.append("%s in %s" % [b.name, Vector3(q.x, lv - SOTTO, q.y).snapped(Vector3.ONE * 0.01)])
	for s in sopra_ko.slice(0, 10):
		print("    sopra il pelo, vista subacquea: ", s)
	for s in sotto_ko.slice(0, 10):
		print("    sotto il pelo, vista normale: ", s)
	_check(sopra_ko.is_empty(), "%s: con la testa %d cm sopra il pelo la vista resta normale (%d punti, %d no)" % [z, SOPRA * 100, punti, sopra_ko.size()])
	_check(sotto_ko.is_empty() and (provati_sotto > 0 or corpi.is_empty()),
			"%s: con la testa %d cm sotto il pelo la vista è subacquea (%d punti, %d no)" % [z, SOTTO * 100, provati_sotto, sotto_ko.size()])
	_cam.queue_free()
	_cam = null


## Due acque sovrapposte: la prima della tabella (B) ha il pelo a 1 m (il suo rettangolo è più grande della sua acqua,
## come una vasca col fondo inclinato), la più vicina alla testa (A) a 0. Con la testa 15 cm sopra A la vista è
## normale (prima la dava subacquea, col pelo di B); 10 cm sotto A, subacquea. Con lo schermo, lo scatto vero del solo
## effetto (la camera vede solo lo strato del quad dell'effetto, sullo sfondo fisso): sopra il pelo resta lo sfondo.
func _sovrapposte() -> void:
	var radice := Node3D.new()
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice    # (gli schizzi vanno nella scena)
	var b := WaterBody.new()
	b.size = Vector2(10, 10)
	b.position = Vector3(3, 0, 0)
	radice.add_child(b)
	b.bottom = -0.2
	b.level = 1.0
	var a := WaterBody.new()
	a.size = Vector2(10, 10)
	radice.add_child(a)
	a.bottom = -2.0
	a.level = 0.0
	_camera()
	for i in 3:
		await get_tree().process_frame
	var p := Vector3(3, SOPRA, 0)
	var schermo := DisplayServer.get_name() != "headless"
	var fondo: Image
	var sopra: Image
	if schermo:
		# (prima di passare sott'acqua: dopo ci sarebbero le gocce sull'obiettivo e gli schizzi)
		_cam.cull_mask = 1
		# (senza il filtro dello schermo delle impostazioni grafiche: grana e vignetta cambiano a ogni fotogramma)
		var post = get_node("/root/Grafica").get(&"_post_layer")
		if post:
			post.visible = false
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.5, 0.5, 0.5)
		_cam.environment = env
		_cam.rotation = Vector3.ZERO
		_vista(p)
		# (la camera nasce nell'origine, sott'acqua: salendo avrebbe le gocce sull'obiettivo per 2 s)
		_eff.set(&"_lens_wet", 0.0)
		fondo = await _scatto(false)
		sopra = await _scatto(true)
	var v := _vista(p)
	_check(not v[0] and is_equal_approx(float(v[1]), 0.0), "sovrapposte: sopra il pelo dell'acqua più vicina la vista è normale e lo shader ha il suo pelo (%.2f)" % v[1])
	v = _vista(Vector3(3, -SOTTO, 0))
	_check(v[0], "sovrapposte: sotto il pelo la vista è subacquea")
	if schermo:
		var diff := _differenza(sopra, fondo)
		_check(diff < 0.005, "sovrapposte, scatto vero: sopra il pelo l'effetto non cambia l'immagine (scarto medio %.4f)" % diff)
		var sotto := await _scatto(true)
		diff = _differenza(sotto, fondo)
		_check(diff > 0.05, "sovrapposte, scatto vero: sotto il pelo l'effetto si vede (scarto medio %.3f)" % diff)
		if OS.has_environment("SCATTI"):
			sopra.save_png(OS.get_environment("SCATTI") + "/sopra.png")
			sotto.save_png(OS.get_environment("SCATTI") + "/sotto.png")
			fondo.save_png(OS.get_environment("SCATTI") + "/fondo.png")
	radice.queue_free()
	_cam.queue_free()
	_cam = null
	for i in 3:
		await get_tree().process_frame

func _scatto(effetto: bool) -> Image:
	_eff.process_mode = Node.PROCESS_MODE_INHERIT if effetto else Node.PROCESS_MODE_DISABLED
	_eff.visible = effetto
	_eff._process(0.0)
	for i in 4:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _differenza(a: Image, b: Image) -> float:
	var s := 0.0
	var n := 0
	for y in range(0, a.get_height(), 8):
		for x in range(0, a.get_width(), 8):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			s += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			n += 1
	return s / maxf(n, 1)

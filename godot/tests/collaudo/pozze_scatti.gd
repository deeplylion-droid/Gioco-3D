extends Node
## Collaudo 0.4.0 (candidata), fase 2: lei nella stanza delle pozze col renderer vero, nella Risalita della scena di prova
## (come pozze_giro.gd), al buio. PS:. Lei svegliata da codice con tutte le pozze piene (cinque colori), pause corte.
## 1. l'uscita dimostrativa (lontana): scatti dagli occhi;
## 2. per ogni colore, il giocatore sulla passerella davanti a una pozza di quel colore (letale spento): scatti dagli
##    occhi, di lato radente alla passerella e dall'alto, nel silenzio (prima che compaia), mentre esce, quando è su, e
##    1,5 s dopo che è tornata sotto; l'opacità del liquido (shader) in quei momenti;
## 3. il getto sulla mano (respinta) con gli scatti;
## 4. letale acceso: la presa e la scena della morte, uno scatto ogni 0,25 s.
## Le compilazioni di pipeline (Performance) da quando esce a quando è su, alla prima uscita e alle altre.
## Uso: xvfb-run ... --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/pozze_scatti.gd <cartella>

var cart := ""
var p: Player
var e: EnigmaPozze
var cam: Camera3D
var mia: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _pipeline() -> int:
	var n := 0
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE,
			Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += int(Performance.get_monitor(m))
	return n


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.88)


func _da(nome: String, da: Vector3, verso: Vector3, fov := 65.0) -> void:
	mia.global_position = da
	mia.look_at(verso, Vector3.UP if absf((verso - da).normalized().y) < 0.97 else Vector3.FORWARD)
	mia.fov = fov
	mia.make_current()
	await _frames(2)
	await _salva(nome)
	cam.make_current()


func _occhi(nome: String, verso: Vector3) -> void:
	p.look_at_point(verso)
	await _frames(2)
	await _salva(nome)


func _fase() -> String:
	return AcquaDiLei.Fase.keys()[e.lei.acqua.fase]


func _aspetta(nome: String, max_s: float) -> bool:
	var f0 := Engine.get_process_frames()
	while Engine.get_process_frames() - f0 < int(max_s * 60.0):
		await get_tree().process_frame
		if _fase() == nome:
			return true
	return false


func _opacita(t: WaterTank) -> String:
	var m: Material = null
	for c in t.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		m = mi.material_override if mi.material_override else (mi.get_active_material(0) if mi.mesh else null)
		if m is ShaderMaterial:
			break
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var out := []
		for k in ["estinzione", "opaco", "opacita", "absorption", "torbidita"]:
			var v = sm.get_shader_parameter(k)
			if v != null:
				out.append("%s=%s" % [k, v])
		return str(out)
	return "-"


func _pozza_sul_bordo(c: String) -> WaterTank:
	var m: WaterTank = null
	for t: WaterTank in e.pozze_del_colore(c):
		if m == null or t.position.z > m.position.z:
			m = t
	return m


func _uscita(tag: String, t: WaterTank, getto := false) -> void:
	var q := e.lei.uscita_di(t)
	var su := q.global_position
	var fuori := q.global_basis.z.normalized()
	var lato := fuori.cross(Vector3.UP).normalized()
	var pelo := t.get_surface_global_y()
	var cen := Vector3(t.global_position.x, pelo, t.global_position.z)
	if not await _aspetta("ARRIVA", 60.0):
		print("PS: %s: non arriva (fase %s)" % [tag, _fase()])
		return
	var punto: Node3D = e.lei.acqua.get(&"_punto")
	print("PS: %s: arriva al punto %s (voluto %s), dimostrativa %s" % [tag, punto.name if punto else "-", q.name, e.lei.acqua.get(&"_dimostrativa")])
	if punto:
		q = punto as Marker3D
		su = q.global_position
		fuori = q.global_basis.z.normalized()
		lato = fuori.cross(Vector3.UP).normalized()
		var tt := e.lei.call(&"_pozza_sotto", su) as WaterTank
		if tt:
			t = tt
			pelo = t.get_surface_global_y()
			cen = Vector3(t.global_position.x, pelo, t.global_position.z)
	print("PS: %s: in ARRIVA opacità %s" % [tag, _opacita(t)])
	await _occhi("%s_1_arriva_occhi" % tag, cen)
	await _aspetta("SILENZIO", 5.0)
	await _frames(15)
	print("PS: %s: nel silenzio opacità %s" % [tag, _opacita(t)])
	await _occhi("%s_2_silenzio_occhi" % tag, cen)
	await _da("%s_2_silenzio_alto" % tag, cen + Vector3.UP * 1.8 + fuori * 0.3, cen, 70.0)
	var pip0 := _pipeline()
	await _aspetta("ESCE", 3.0)
	await _frames(40)
	await _occhi("%s_3_esce_occhi" % tag, su)
	await _da("%s_3_esce_lato" % tag, su + fuori * 1.0 + lato * 1.6 + Vector3.UP * 0.5, su + fuori * 0.6, 70.0)
	await _aspetta("SU", 4.0)
	await _frames(20)
	print("PS: %s: compilazioni da ESCE a SU %d" % [tag, _pipeline() - pip0])
	await _occhi("%s_4_su_occhi" % tag, su + fuori * 0.8)
	await _da("%s_4_su_lato" % tag, su + fuori * 0.9 + lato * 1.8 + Vector3.UP * 0.35, su + fuori * 0.9, 70.0)
	await _da("%s_4_su_radente" % tag, su + fuori * 2.6 + Vector3.UP * 0.25, su, 60.0)
	await _da("%s_4_su_alto" % tag, cen + Vector3.UP * 2.2 + fuori * 0.6, cen + fuori * 0.6, 75.0)
	await _da("%s_4_su_pelo" % tag, cen - fuori * 0.2 + lato * 0.9 + Vector3.UP * 0.12, cen, 70.0)
	var lei: Node3D = e.lei.acqua.get(&"_lei")
	if lei:
		var testa := lei.find_child("*testa*", true, false)
		print("PS: %s: lei in %s, pelo %.3f" % [tag, lei.global_position.snappedf(0.01), pelo])
	if getto:
		var viso: Node3D = e.lei.acqua.get(&"_viso")
		Input.action_press(&"spray")
		var k := 0
		while _fase() in ["SU", "ESCE"] and k < 240:
			if viso:
				p.look_at_point(viso.global_position)
			await _frames(1)
			k += 1
			if k == 20:
				await _salva("%s_5_getto_occhi" % tag)
		Input.action_release(&"spray")
		print("PS: %s: getto per %d fotogrammi: fase %s" % [tag, k, _fase()])
	await _aspetta("CALMA", 8.0)
	await _frames(90)
	print("PS: %s: 1,5 s dopo opacità %s" % [tag, _opacita(t)])
	await _occhi("%s_6_dopo_occhi" % tag, cen)


func _run() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	p = GameState.player as Player
	cam = p.get_viewport().get_camera_3d()
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.volumetric_fog_enabled = false
	env.environment.ssil_enabled = false
	get_tree().current_scene.add_child(env)
	var ris := get_tree().current_scene.get_node(^"Risalita") as Node3D
	for nome in ["BambinoCorridoioFiume"]:
		var b := ris.find_child(nome, true, false) as Node3D
		if b:
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.visible = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	if ris.has_method(&"carica_subito"):
		ris.call(&"carica_subito")
	for i in 3600:
		await get_tree().process_frame
		e = get_tree().current_scene.find_child("EnigmaPozze", true, false) as EnigmaPozze
		if e and e.lei and i > 120 and not bool(ris.call(&"lavori_in_corso")):
			break
	mia = Camera3D.new()
	mia.near = 0.02
	add_child(mia)
	if e == null:
		print("PS: niente pozze")
		get_tree().quit(1)
		return
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	print("PS: pozze %d, lei %s, letale %s" % [e.pozze().size(), e.lei.nome_fase(), e.lei.letale])
	e.lei.letale = false
	e.lei.pausa_min = 1.5
	e.lei.pausa_max = 2.0
	e.lei.prima_attesa = 1.0
	# davanti alla pozza centrale
	var centro := e.to_global(Vector3(0.0, 0.0, e.passo * 2.5 + 0.6))
	p.teleport(centro + Vector3.UP * 0.05)
	await _frames(30)
	e.lei.call(&"_sveglia")
	# 1. la dimostrativa
	await _uscita("0_dimostrativa", _pozza_sul_bordo(WaterMix.BIANCO_LATTE))
	# 2. i cinque colori
	var k := 1
	for c in EnigmaPozze.COLORI:
		var t := _pozza_sul_bordo(c)
		var davanti := e.to_global(Vector3(t.position.x, 0.0, e.passo * 2.5 + 0.6))
		p.teleport(davanti + Vector3.UP * 0.05)
		p.look_at_point(Vector3(t.global_position.x, t.get_surface_global_y(), t.global_position.z))
		await _frames(10)
		await _uscita("%d_%s" % [k, c], t, c == WaterMix.VIOLA)
		k += 1
	# 4. la presa e la scena della morte
	e.lei.letale = true
	var t2 := _pozza_sul_bordo(WaterMix.ROSA)
	p.teleport(e.to_global(Vector3(t2.position.x, 0.0, e.passo * 2.5 + 0.6)) + Vector3.UP * 0.05)
	p.look_at_point(t2.global_position)
	if await _aspetta("PRESA", 60.0):
		for i in 16:
			await _frames(15)
			await _salva("9_morte_%02d" % i)
	print("PS: morte: causa %s, morendo %s" % [GameState.last_death_cause, GameState.is_dying])
	print("PS: finito")
	get_tree().quit()

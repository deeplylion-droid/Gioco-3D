extends Node
## Collaudo degli oblò con lei: gli scatti ravvicinati di vetro, bordo d'ottone, piastra e rivetti, con una luce bianca
## sulla camera (al buio non si vede niente), per vedere distacchi e compenetrazioni anche di 1-2 mm. Per ogni oblò
## della Risalita, o per quello della torre (OBLO_RAGGIO per il vetro): di fronte, rasente al muro dai quattro lati,
## gli angoli della piastra, il bordo e i rivetti da vicino; poi di fronte con lei al vetro.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/ravvicinati_oblo.gd <cartella> [risalita|torre]

var cartella := "user://ravvicinati_oblo"
var cam: Camera3D


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred(a[2] if a.size() > 2 else "risalita")


func _run(dove: String) -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var radice: Node3D
	if dove == "risalita":
		radice = (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	else:
		var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
		if OS.get_environment("OBLO_RAGGIO") != "":
			torre.oblo_raggio_vetro = float(OS.get_environment("OBLO_RAGGIO"))
		radice = torre
	add_child(radice)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.fov = 55.0
	add_child(cam)
	cam.make_current()
	var luce := OmniLight3D.new()
	luce.light_energy = 1.5
	luce.omni_range = 4.0
	luce.shadow_enabled = true
	cam.add_child(luce)
	for i in 30:
		await get_tree().process_frame
	for o in radice.find_children("*", "ObloLei", true, false):
		var ob := o as ObloLei
		ob.set_process(false)
		var nome: String = String(ob.name) if dove == "risalita" else "Torre_%s" % str(ob.raggio_vetro).replace(".", "_")
		var p := ob.piastra * 0.5
		var rb: float = ObloLei.RAGGIO_BORDO * ob.raggio_vetro / ObloLei.RAGGIO_VETRO
		var rr: float = ObloLei.RAGGIO_RIVETTI * ob.raggio_vetro / ObloLei.RAGGIO_VETRO
		# (con la cornice tonda sul muro: la flangia fino a 10 cm oltre il bordo, i rivetti nel mezzo)
		var rf := rb + 0.1
		if not ob.muro.is_empty():
			rr = rb + 0.05
		var s := ob.spessore_muro
		# [nome, camera, guarda] nel sistema dell'oblò (+Z verso il corridoio, la faccia del muro a z 0)
		var vedute := [
			["a_fronte", Vector3(0, 0, 1.0), Vector3(0, 0, -s)],
			["b_rasente_destra", Vector3(p + 0.6, 0, 0.1), Vector3(-p, 0, 0.0)],
			["c_rasente_sinistra", Vector3(-p - 0.6, 0, 0.1), Vector3(p, 0, 0.0)],
			["d_rasente_sopra", Vector3(0, p + 0.6, 0.1), Vector3(0, -p, 0.0)],
			["e_rasente_sotto", Vector3(0, -p - 0.6, 0.1), Vector3(0, p, 0.0)],
			["f_angolo_su_destra", Vector3(p + 0.15, p + 0.15, 0.35), Vector3(p - 0.05, p - 0.05, 0)],
			["g_angolo_giu_sinistra", Vector3(-p - 0.15, -p - 0.15, 0.35), Vector3(-p + 0.05, -p + 0.05, 0)],
			["h_bordo_sopra", Vector3(0.15, rb + 0.25, 0.3), Vector3(0, rb * 0.9, -s * 0.5)],
			["i_bordo_destra", Vector3(rb + 0.25, -0.1, 0.3), Vector3(rb * 0.9, 0, -s * 0.5)],
			["j_rivetti_sopra", Vector3(-0.1, rr, 0.3), Vector3(0, rr, 0)],
			["k_rivetti_destra", Vector3(rr, 0.1, 0.3), Vector3(rr, 0, 0)],
			["o_flangia_rasente_destra", Vector3(rf + 0.3, 0.05, 0.035), Vector3(rf - 0.08, 0, 0.003)],
			["p_flangia_rasente_sotto", Vector3(0.05, -rf - 0.3, 0.035), Vector3(0, -rf + 0.08, 0.003)],
			["q_flangia_dentro_sopra", Vector3(0, rb * 0.3, 0.12), Vector3(0, rb, 0.0)],
			["l_vetro_obliquo", Vector3(rb * 0.8, rb * 0.5, 0.45), Vector3(-ob.raggio_vetro * 0.5, 0, -s)],
		]
		for v in vedute:
			await _guarda(ob, v[1], v[2])
			await _scatto("%s_%s" % [nome, v[0]])
		ob._mostra()
		for i in 20:
			await get_tree().process_frame
		await _guarda(ob, Vector3(0, 0, 1.0), Vector3(0, 0, -s))
		await _scatto("%s_m_con_lei_fronte" % nome)
		await _guarda(ob, Vector3(rb * 0.8, rb * 0.5, 0.45), Vector3(-ob.raggio_vetro * 0.5, 0, -s))
		await _scatto("%s_n_con_lei_obliquo" % nome)
		ob.via()
	print("RAVVICINATI: finito")
	get_tree().quit()


func _guarda(ob: ObloLei, da: Vector3, verso: Vector3) -> void:
	var t := ob.global_transform
	cam.global_position = t * da
	cam.look_at(t * verso, ob.global_basis.y)
	for i in 4:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)
	print("scatto -> ", nome)

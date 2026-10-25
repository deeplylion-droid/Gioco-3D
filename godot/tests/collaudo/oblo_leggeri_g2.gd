extends Node
## Collaudo (grafica-2) degli oblò leggeri (lei pronta prima, palpebra, scurirsi fino al nero), col renderer vero.
## Per ogni oblò (i tre della Risalita e quello della torre), preparati come nel gioco (Risalita: prepara_lei e
## prepara_materiali_lei da sole; torre: costruita a pezzi e prepara_materiali), dagli occhi del giocatore:
## - la comparsa: pipeline nuove (draw, specialization, surface, mesh) e fotogramma più lungo per 90 fotogrammi, e lei
##   guardata (scatto);
## - il distacco: pipeline e fotogramma più lungo fino alla fine, uno scatto ogni 12 fotogrammi e due ravvicinati
##   dell'occhio (camera stretta sull'occhio) a metà e a 4/5;
## - dopo: l'oblò vuoto (scatto, lei e la sua luce spente) e di nuovo dopo una ripartenza (load_state).
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/oblo_leggeri_g2.gd <cartella> [torre|ObloFiume|...]

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
const POSTI_RISALITA := {
	"ObloFiume": Vector3(-5.45, -5.4, 58.3),
	"ObloPersonale": Vector3(-34.45, -5.4, 49.35),
	"ObloServizio": Vector3(-21.2, 0.0, 39.15),
}
var cartella := ""
var dove := "torre"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	if a.size() > 2:
		dove = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _info() -> Array:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH)]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	var o: ObloLei
	var posto := POSTO_TORRE
	if dove == "torre":
		for sc in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/props/polaroid.tscn"]:
			var n := (load(sc) as PackedScene).instantiate()
			n.set(&"visible", false)
			add_child(n)
		var campioni := SalaTorre.materiali_campione()
		var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
		torre.costruzione_a_pezzi = true
		torre.visible = false
		torre.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(torre)
		await torre.costruisci_a_pezzi()
		await torre.prepara_materiali(get_viewport())
		torre.visible = true
		torre.process_mode = Node.PROCESS_MODE_INHERIT
		o = torre.oblo
		campioni.clear()
	else:
		Engine.set_meta(&"risalita_subito", true)
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color.BLACK
		var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
		add_child(ris)
		o = ris.find_child(dove, true, false) as ObloLei
		posto = POSTI_RISALITA[dove]
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	o.set_process(false)
	p.teleport(posto)
	await _fotogrammi(4)
	p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
	# la preparazione delle lei della Risalita aspetta la camera: le si lascia il tempo (nel gioco succede a schermo nero)
	await _fotogrammi(150)
	var stato_prima := o.save_state()
	_scatto("%s_0_vuoto_prima" % dove)
	var base := _info()
	var r := await _misura(func(): o._mostra(), 90, base)
	print("OBLO %s COMPARSA: pipeline nuove [draw, specialization, surface, mesh] %s, fotogramma più lungo %.0f ms (medio %.0f)" % [dove, r[0], r[1], r[2]])
	_scatto("%s_1_guardata" % dove)
	var lei := o.lei
	var durata := 160
	if lei and lei.posa != "":
		durata = int(float(lei.call(&"_durata", "oblo_" + lei.posa + "_stacca")) * 60.0) + 20
	base = _info()
	o._stacca()
	var peggiore := 0.0
	var tot := [0, 0, 0, 0]
	var t := Time.get_ticks_usec()
	var cam_occhio := Camera3D.new()
	cam_occhio.fov = 16.0
	cam_occhio.near = 0.02
	add_child(cam_occhio)
	var cam_gioco := get_viewport().get_camera_3d()
	for f in durata:
		await RenderingServer.frame_post_draw
		var ora := Time.get_ticks_usec()
		peggiore = maxf(peggiore, float(ora - t) / 1000.0)
		t = ora
		var inf := _info()
		for k in 4:
			tot[k] += inf[k] - base[k]
		base = inf
		if f % 12 == 0:
			_scatto("%s_2_distacco_%03d" % [dove, f])
		if f == durata / 2 or f == durata * 4 / 5:
			var occhio := o.lei.get_eye_position() if o.lei and is_instance_valid(o.lei) and o.lei.lei else Vector3.ZERO
			if occhio != Vector3.ZERO:
				cam_occhio.look_at_from_position(cam_gioco.global_position, occhio)
				cam_occhio.make_current()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				_scatto("%s_3_occhio_%s" % [dove, "meta" if f == durata / 2 else "4quinti"])
				cam_gioco.make_current()
				t = Time.get_ticks_usec()
				base = _info()
	print("OBLO %s DISTACCO (%d fotogrammi): pipeline nuove %s, fotogramma più lungo %.0f ms" % [dove, durata, tot, peggiore])
	await _fotogrammi(60)
	var resti := []
	if o.lei and is_instance_valid(o.lei):
		for v in o.lei.find_children("*", "VisualInstance3D", true, false):
			if (v as VisualInstance3D).is_visible_in_tree():
				resti.append(String(v.name))
	print("OBLO %s DOPO: stato %s, parti di lei ancora visibili %s" % [dove, o.stato, resti])
	_scatto("%s_4_vuoto_dopo" % dove)
	o.load_state(stato_prima)
	await _fotogrammi(30)
	var resti2 := []
	if o.lei and is_instance_valid(o.lei):
		for v in o.lei.find_children("*", "VisualInstance3D", true, false):
			if (v as VisualInstance3D).is_visible_in_tree():
				resti2.append(String(v.name))
	print("OBLO %s RIPARTENZA: stato %s, parti di lei visibili %s" % [dove, o.stato, resti2])
	_scatto("%s_5_vuoto_ripartenza" % dove)
	get_tree().quit()


func _misura(azione: Callable, n: int, base: Array) -> Array:
	var tot := [0, 0, 0, 0]
	var peggiore := 0.0
	var somma := 0.0
	var t := Time.get_ticks_usec()
	azione.call()
	for i in n:
		await RenderingServer.frame_post_draw
		var ora := Time.get_ticks_usec()
		var ms := float(ora - t) / 1000.0
		t = ora
		peggiore = maxf(peggiore, ms)
		somma += ms
		var inf := _info()
		for k in 4:
			tot[k] += inf[k] - base[k]
		base = inf
	return [tot, peggiore, somma / n]


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)
	print("scatto ", nome)

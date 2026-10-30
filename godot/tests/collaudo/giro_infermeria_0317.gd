extends Node
## Collaudo della nebbia 0.3.17 nell'infermeria (che non deve cambiare) e dell'opzione "Nebbia viola" spenta e riaccesa
## (nessuna compilazione che blocca). L'infermeria della scena di prova, con l'ambiente della sala, blackout, preset alto,
## dagli occhi del giocatore: tre viste, con la nebbia piena. Con [param prima] = "0316" la nebbia usa lo shader della
## 0.3.16 (tests/collaudo/nebbia_0316.gdshader, copiato da main) con 20 passi, per il confronto.
## Poi (solo con la nebbia di adesso): l'opzione spenta (la nebbia scende), riaccesa (risale), il preset basso e di nuovo
## alto (i passi cambiano), contando le compilazioni "surface" e "draw" (devono restare 0).
## Uso (sotto il render.lock, tools/scatto_sicuro.sh): res://tests/collaudo/giro_infermeria_0317.gd <cartella> [0317|0316]

const SCENA := "res://tests/scene/infermeria_gioco_prova.tscn"
const SHADER_0316 := "res://tests/collaudo/nebbia_0316.gdshader"
## [nome, occhi, punto guardato] (coordinate dell'infermeria, il centro del pavimento nell'origine)
const VISTE := [
	["entrando_da_sud", Vector3(1.6, 1.6, 2.6), Vector3(-0.8, 1.0, -2.6)],
	["dal_centro_a_ovest", Vector3(0.6, 1.6, 0.4), Vector3(-3.0, 0.9, -0.6)],
	["verso_la_porta_nord", Vector3(1.2, 1.6, 1.6), Vector3(-2.2, 1.0, -3.2)],
]

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _frames(n: int, inf: Node) -> void:
	for i in n:
		inf.set(&"_t", 1.0)        # il lampeggiante spento in tutti gli scatti
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella := a[1]
	var nome: String = a[2] if a.size() > 2 else "0317"
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(SCENA)
	for i in 30:
		await get_tree().process_frame
	var radice := get_tree().current_scene
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	radice.add_child(env)
	Grafica.aggiorna_environment()
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var inf := radice.get_node(^"Infermeria")
	var p := radice.get_node(^"Player") as Player
	GameState.player = p
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.camera.make_current()
	var nv := Grafica.nebbia_viola
	if nome == "0316":
		var m := nv.materiali()[0] as ShaderMaterial
		m.shader = load(SHADER_0316)
		m.set_shader_parameter(&"passi", 20)
	var base := (inf as Node3D).global_position
	for v in VISTE:
		var occhi: Vector3 = base + v[1]
		p.global_position = occhi - Vector3.UP * (p.get_eye_position().y - p.global_position.y)
		p.look_at_point(base + v[2])
		p.camera.global_transform = p.get_aim_transform()
		await _frames(240, inf)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(cartella.path_join("%s_%s.jpg" % [v[0], nome]), 0.9)
		print("GIRO %s %s: nebbia %.2f, in zona %s" % [v[0], nome, nv.quanto, nv.in_zona()])
	if nome == "0316":
		get_tree().quit()
		return
	print("Opzione Nebbia viola spenta e riaccesa, preset basso e alto")
	check(nv.in_zona() and nv.quanto > 0.95, "nell'infermeria la nebbia è piena (%.2f)" % nv.quanto)
	var prima := _conta()
	Grafica.imposta("nebbia_viola", false)
	await _frames(300, inf)
	check(nv.quanto < 0.01, "spenta dalle opzioni la nebbia scende (%.2f)" % nv.quanto)
	Grafica.imposta("nebbia_viola", true)
	await _frames(300, inf)
	check(nv.quanto > 0.95, "riaccesa risale (%.2f)" % nv.quanto)
	var c := _conta()
	check(int(c[0] - prima[0]) == 0 and int(c[1] - prima[1]) == 0,
		"spegnendo e riaccendendo nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])
	var m2 := nv.materiali()[0] as ShaderMaterial
	prima = _conta()
	Grafica.applica_preset("basso")
	await _frames(120, inf)
	var passi_basso: int = m2.get_shader_parameter(&"passi")
	Grafica.applica_preset("alto")
	await _frames(120, inf)
	var passi_alto: int = m2.get_shader_parameter(&"passi")
	c = _conta()
	check(passi_basso == 16 and passi_alto == 32, "passi: basso %d, alto %d" % [passi_basso, passi_alto])
	print("  (preset basso e di nuovo alto: surface %d, draw %d, in sottofondo %d: le compilazioni del preset basso, non della nebbia)" % [c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit()

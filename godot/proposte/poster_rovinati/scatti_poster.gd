extends Node
## Scatti dei poster di Jilly rovinati (prima e dopo), dagli occhi del giocatore e da vicino per vedere come sono
## attaccati al muro. Una camera libera per scatto, con i materiali veri della scena.
## Uso (sotto render.lock, con almeno 13,5 GB liberi; tools/scatto_sicuro.sh):
##   tools/scatto_sicuro.sh res://proposte/poster_rovinati/scatti_poster.gd <cartella> <interni|sala|infermeria>

const SCENE := {
	"interni": "res://scenes/interni/interni.tscn",
	"sala": "res://scenes/sala_principale.tscn",
	"infermeria": "res://scenes/risalita/infermeria.tscn",
	"manifesto": "res://scenes/sala_principale.tscn",
}
## scena -> nome: [da dove, verso dove, campo visivo]. Gli occhi del giocatore sono a 1,6 m.
const SCATTI := {
	"interni": {
		"cartellone_giocatore": [Vector3(15.6, 1.6, -2.15), Vector3(14.6, 1.3, 0.0), 70.0],
		"cartellone_vicino": [Vector3(14.9, 1.0, -0.9), Vector3(15.1, 0.65, 0.0), 55.0],
		"cartellone_bordo": [Vector3(13.4, 1.4, -0.5), Vector3(14.2, 1.3, 0.0), 50.0],
		"bagnino_giocatore": [Vector3(12.9, 1.6, -7.7), Vector3(12.8, 1.45, -6.2), 70.0],
		"bagnino_vicino": [Vector3(13.0, 1.6, -6.75), Vector3(13.05, 1.6, -6.2), 55.0],
		"bagnino_bordo": [Vector3(13.6, 1.6, -6.55), Vector3(13.1, 1.6, -6.2), 50.0],
	},
	"sala": {
		"manifesto_giocatore": [Vector3(-17.5, 1.6, 13.4), Vector3(-20.0, 1.4, 13.95), 70.0],
		"manifesto_vicino": [Vector3(-19.0, 1.5, 13.95), Vector3(-20.0, 1.45, 13.95), 55.0],
		"manifesto_bordo": [Vector3(-19.1, 1.6, 13.0), Vector3(-19.97, 1.55, 14.0), 50.0],
	},
	# collaudo del manifesto (25 ottobre): dall'alto, dal basso e radenti dai due lati, da vicino
	"manifesto": {
		"manifesto_alto": [Vector3(-19.45, 2.35, 13.95), Vector3(-19.98, 1.85, 13.95), 50.0],
		"manifesto_radente_nord": [Vector3(-19.82, 1.4, 15.0), Vector3(-19.98, 1.4, 13.5), 45.0],
		"manifesto_basso": [Vector3(-19.4, 0.45, 13.95), Vector3(-19.98, 0.95, 13.95), 50.0],
		"manifesto_radente_sud": [Vector3(-19.82, 1.4, 12.9), Vector3(-19.98, 1.4, 14.4), 45.0],
		"manifesto_scotch": [Vector3(-19.6, 2.0, 13.6), Vector3(-19.98, 1.9, 13.72), 40.0],
		"manifesto_fronte": [Vector3(-18.6, 1.45, 13.95), Vector3(-20.0, 1.4, 13.95), 50.0],
	},
	"infermeria": {
		"infermeria_giocatore": [Vector3(1.6, 1.6, 2.7), Vector3(-3.2, 1.6, 1.45), 70.0],
		"infermeria_vicino": [Vector3(-2.2, 1.8, 1.45), Vector3(-3.2, 1.8, 1.45), 55.0],
		"infermeria_bordo": [Vector3(-2.8, 1.9, 0.6), Vector3(-3.18, 1.9, 1.2), 50.0],
	},
}

var out_dir := ""
var scena := "interni"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[1]
	if args.size() > 2:
		scena = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	# i neon che sfarfallano scelgono a caso: con lo stesso seme il prima e il dopo hanno le stesse luci
	seed(24)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var level := (load(SCENE[scena]) as PackedScene).instantiate()
	if scena == "sala" or scena == "manifesto":
		# le parti lontane dal manifesto: con tutta la sala non entra nella memoria della macchina
		for percorso in ["Risalita", "Piscina", "Polaroid", "BambiniBalconata", "Interni", "Tecnici", "Sala/TorreScivoli",
				"Gioco/BambiniBalconata", "Gioco/EnigmaAcquari", "Gioco/LeiSbuca", "Sala/Cupola", "Sala/Oggetti", "Sala/Dettagli", "Sala/AngoloPalloni",
				"Sala/AngoloScatoloni", "Vasche", "Gioco/MedusaFossa"]:
			var n := level.get_node_or_null(NodePath(percorso))
			if n:
				n.get_parent().remove_child(n)
				n.free()
	if scena == "infermeria":
		# da sola, con la luce d'ambiente di tests/scatti_infermeria_gioco.gd
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color.BLACK
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.1, 0.09, 0.1)
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.tonemap_exposure = 1.15
		e.ssao_enabled = true
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.015
		we.environment = e
		get_tree().root.add_child(we)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	for i in 60:
		await get_tree().process_frame
	var p := GameState.player
	if p:
		var hud := p.get_node_or_null(^"HUD")
		if hud:
			hud.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.current = true
	cam.near = 0.02
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.95, 0.88)
	luce.light_energy = 1.2
	luce.omni_range = 5.0
	luce.shadow_enabled = true
	luce.visible = false
	level.add_child(luce)
	var scatti: Dictionary = SCATTI[scena]
	for nome in scatti:
		var s: Array = scatti[nome]
		cam.global_position = s[0]
		cam.look_at(s[1], Vector3.UP)
		cam.fov = s[2]
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
		# lo stesso scatto con una lampadina neutra accanto alla camera, solo per vedere bene i dettagli
		# (nel gioco non c'è: lo scatto vero è quello sopra)
		luce.global_position = cam.global_position + Vector3(0, 0.3, 0)
		luce.visible = true
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(nome + "_luce.jpg"), 0.9)
		luce.visible = false
	get_tree().quit()

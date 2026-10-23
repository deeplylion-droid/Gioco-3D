extends Node
## Scatti ravvicinati di Jilly alla vasca centrale e (dopo il blackout, affacciata) alla fossa dei bimbi, per i casi del
## controllo di posizionamento con le mesh in posa (sonda_jilly_vuoto.gd misura, qui si guarda).
## Uso (sotto render.lock, con almeno 13,5 GB liberi; tools/scatto_sicuro.sh):
##   tools/scatto_sicuro.sh res://proposte/mascotte/scatti_jilly.gd <cartella> [nomi,separati,da,virgole] [senza]
## "senza": con i tentacoli come li lascia l'animazione (TentacoliControIMuri spento), per il confronto
## (pochi per volta: con tutti la memoria può superare il limite)

const LEVEL := "res://scenes/sala_principale.tscn"
## nome: [da dove, verso dove, campo visivo]
const SCATTI := {
	"vasca": [Vector3(0.0, 2.2, 14.6), Vector3(0.0, 0.6, 11.0), 60.0],
	"vasca_lato": [Vector3(2.6, 1.4, 12.6), Vector3(0.0, 0.3, 11.2), 60.0],
	"fossa": [Vector3(-17.2, 1.7, -5.0), Vector3(-13.6, 0.0, -7.4), 60.0],
	"fossa_tentacoli": [Vector3(-11.2, 1.2, -5.6), Vector3(-12.4, -0.2, -6.8), 60.0],
	"fossa_campana": [Vector3(-13.9, 1.6, -9.3), Vector3(-13.9, -0.9, -7.6), 60.0],
	"fossa_passaggio": [Vector3(-16.8, 1.0, -8.8), Vector3(-15.3, 0.3, -7.7), 60.0],
	"fossa_passaggio_nord": [Vector3(-15.6, 1.5, -10.6), Vector3(-14.4, 0.0, -7.4), 60.0],
	"fossa_terra_ovest": [Vector3(-16.9, 0.35, -8.6), Vector3(-14.9, 0.2, -6.4), 60.0],
}

var out_dir := ""
var nomi: PackedStringArray = []


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	nomi = OS.get_cmdline_user_args()[2].split(",") if OS.get_cmdline_user_args().size() > 2 else PackedStringArray(SCATTI.keys())
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


## Solo scatti della vasca centrale: si toglie anche la fossa dei bimbi; negli altri (la fossa) la vasca centrale e la
## piscina a onde (con tutta la sala non entra nella memoria).
func _solo_vasca() -> bool:
	for n in nomi:
		if not n.begins_with("vasca"):
			return false
	return true


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var level := (load(LEVEL) as PackedScene).instantiate()
	# le parti lontane dalle mie cose: con tutta la sala non entra nella memoria della macchina
	for percorso in ["Risalita", "Piscina", "Polaroid", "BambiniBalconata", "Interni", "Tecnici", "Sala/TorreScivoli", "Gioco/BambiniBalconata", "Gioco/EnigmaAcquari",
			"Sala/Cupola", "Sala/Oggetti", "Sala/Dettagli", "Sala/AngoloPalloni", "Sala/AngoloScatoloni",
			"Gioco/MedusaFossa"] + (["Gioco/LeiSbuca", "Sala/AreaBimbi", "Vasche"] if _solo_vasca() else
			["Vasca", "Sala/VascaCentrale", "Sala/Piscina"]):
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for i in 60:
		await get_tree().process_frame
	# Jilly alla fossa: dopo il blackout, affacciata (come la vede il giocatore)
	GameState.luci = GameState.Luci.BLACKOUT
	var ls := level.get_node_or_null("Gioco/LeiSbuca")
	if ls:
		ls.call(&"_affaccia")
		# ferma la logica della tappa 8 (senza il giocatore vicino la rimetterebbe via); lei resta viva (scheletro e
		# modificatori come nel gioco)
		ls.set_process(false)
		ls.set_physics_process(false)
	if OS.get_cmdline_user_args().size() > 3 and OS.get_cmdline_user_args()[3] == "senza":
		for t in level.find_children("TentacoliControIMuri", "", true, false):
			(t as SkeletonModifier3D).active = false
	for i in 20:
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
	for nome in nomi:
		var s: Array = SCATTI[nome]
		cam.global_position = s[0]
		cam.look_at(s[1], Vector3.UP)
		cam.fov = s[2]
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(nome + ("_senza" if OS.get_cmdline_user_args().size() > 3 else "") + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()

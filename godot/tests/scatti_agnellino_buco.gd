extends Node
## Scatti dell'agnellino della scala di C2 che si infila nella grata sfondata (v0.3.6), dal giocatore vero: col
## blackout si è in cima alla scala di C2, contro il lato nord, e si guarda l'agnellino che compare lì davanti;
## quando scappa si guarda il buco. Tre scatti: mentre corre, mentre si infila (piegato a metà dentro) e il buco vuoto un secondo
## dopo. La corsa vera, con i tempi, la prova tests/test_agnellino.gd.
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://tests/scatti_agnellino_buco.gd <cartella> [oltre]

const SCENA := "res://tests/scene/tappa7_gioco_agnellino.tscn"
## Nelle coordinate della scena dei tecnici, come test_agnellino.gd.
## Da dove si guarda: in cima alla scala di C2, contro il lato nord (lo si vede correre), oppure con "oltre" più
## avanti nel corridoio, girati indietro (lo si vede infilarsi: da dietro il buco basso lo copre il carrello rosso).
const PUNTO := Vector3(44.2, 9.05, 0.5)
const PUNTO_OLTRE := Vector3(44.25, 9.05, 6.6)

var p: Player
var tec: Node3D
var ag: AgnellinoScala
var cartella := "/tmp/claude-0/agnellino_buco"
var _fatti := {}
var oltre := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		cartella = args[1]
	oltre = args.size() > 2 and args[2] == "oltre"
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(SCENA)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n is LuceEmergenza and int(n.get(&"modalita")) in [1, 2]:
			n.set(&"modalita", 0)
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	tec = get_tree().current_scene.get_node("Tecnici")
	ag = tec.get_node("AgnellinoScala") as AgnellinoScala
	p.teleport(tec.to_global(PUNTO_OLTRE if oltre else PUNTO) + Vector3(0, 0.05, 0), 0.0, 0.0)
	for i in 12:
		await get_tree().physics_frame
	GameState.luci_cambiate.emit(GameState.luci)
	ag.compari()
	var sparito_a := -1
	for i in 900:
		var b := ag.bambino
		# prima lo si guarda (dalla statua scappa solo dopo averti visto), poi si guarda il buco
		var guarda := tec.to_global(Vector3(45.3, 9.4, ag.buco_z - (0.3 if not oltre else -0.1)))
		if b and is_instance_valid(b) and b.modalita in [Bambino.Modalita.STATUA, Bambino.Modalita.OSSERVA]:
			guarda = b.punto_testa()
		var d := guarda - p.get_eye_position()
		p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
		if b and is_instance_valid(b) and b.visible and b.modalita == Bambino.Modalita.SCAPPA:
			var l := tec.to_local(b.global_position)
			if l.z > 2.9 and l.x < 44.6:
				_scatta("1_corre")
			if b.rotation.x > deg_to_rad(45.0) and l.x > ag.muro_x - 0.35:
				_scatta("2_entra")
		elif ag.bambino == null or not is_instance_valid(ag.bambino) or not ag.bambino.visible:
			if _fatti.has("2_entra") and sparito_a < 0:
				sparito_a = i
		if sparito_a >= 0 and i - sparito_a == 30:
			_scatta("3_vuoto")
		if _fatti.size() >= 3:
			for k in 3:
				await get_tree().process_frame
			break
		await get_tree().physics_frame
	print("FINE ", _fatti.keys())
	get_tree().quit()


func _scatta(nome: String) -> void:
	if _fatti.has(nome):
		return
	_fatti[nome] = true
	_salva.call_deferred(nome)


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	print("salvato ", nome)

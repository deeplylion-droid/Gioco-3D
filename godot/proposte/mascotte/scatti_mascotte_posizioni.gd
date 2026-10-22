extends Node
## Scatti ravvicinati delle cose della squadra mascotte nella sala principale, per controllare che poggino o siano
## fissate (sonda_mascotte_posizioni.gd misura, qui si guarda). Una camera libera per scatto.
## Uso (sotto render.lock, con almeno 13,5 GB liberi; tools/scatto_sicuro.sh):
##   tools/scatto_sicuro.sh res://proposte/mascotte/scatti_mascotte_posizioni.gd <cartella>

const LEVEL := "res://scenes/sala_principale.tscn"
## nome: [da dove, verso dove, campo visivo]
const SCATTI := {
	"insegna_lampada_sx": [Vector3(-18.6, 5.15, 6.25), Vector3(-19.62, 5.35, 5.84), 45.0],
	"insegna_lampade": [Vector3(-16.8, 4.6, 5.35), Vector3(-19.8, 4.95, 5.35), 55.0],
	"manifesto_bordo": [Vector3(-19.1, 1.6, 13.0), Vector3(-19.97, 1.55, 14.0), 50.0],
	"manifesto": [Vector3(-17.9, 1.5, 13.95), Vector3(-20.0, 1.4, 13.95), 55.0],
	"targa": [Vector3(-4.2, 0.9, 10.6), Vector3(-3.0, 0.62, 10.0), 50.0],
	"statua_squalo_base": [Vector3(8.4, 0.6, 2.6), Vector3(10.0, 0.15, 1.5), 55.0],
	"statua_polpo_a_base": [Vector3(-4.2, 0.6, -16.6), Vector3(-5.5, 0.15, -18.0), 55.0],
	"statua_polpo_b_base": [Vector3(-16.6, 0.6, -6.8), Vector3(-18.3, 0.15, -8.0), 55.0],
}

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var level := (load(LEVEL) as PackedScene).instantiate()
	# le parti lontane dalle mie cose: con tutta la sala non entra nella memoria della macchina
	for percorso in ["Risalita", "Piscina", "Polaroid", "BambiniBalconata", "Interni", "Tecnici", "Sala/TorreScivoli", "Gioco/BambiniBalconata", "Gioco/EnigmaAcquari",
			"Gioco/LeiSbuca", "Sala/Cupola", "Sala/Oggetti", "Sala/Dettagli", "Sala/AngoloPalloni", "Sala/AngoloScatoloni",
			"Vasche", "Gioco/MedusaFossa"]:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
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
	for nome in SCATTI:
		var s: Array = SCATTI[nome]
		cam.global_position = s[0]
		cam.look_at(s[1], Vector3.UP)
		cam.fov = s[2]
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var f := out_dir.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()

extends Node
## Scatti della proposta del lettore della keycard nella sala vera (proposte/tessera_aspetto/
## lettore_aspetto.gd): accanto alla serranda del magazzino, dal lato del magazzino, al buio (blackout),
## con la serranda chiusa. Come scatti_enigma.gd toglie gli interni e, con SCATTI_TOGLI, altre parti.
## Uso, sotto il render.lock, un processo per scatto:
##   xvfb-run ... godot --path godot --rendering-driver vulkan --fixed-fps 60 --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_lettore.gd <cartella> "<variante>:<rosso|verde>:<camera>,..."
## (con tools/scatto_sicuro.sh e SCATTI_TOGLI=Sala,Piscina,Vasche,Vasca,BambiniBalconata,Polaroid per la memoria)
## Camere: lontano (arrivando dal magazzino), vicino (il lettore da mezzo metro).

const LEVEL := "res://scenes/sala_principale.tscn"
## Coordinate nel riferimento di Tecnici (come la serranda, Tecnici/Logica/SerrandaMagazzino): il lettore
## sul muro del magazzino a destra della serranda (che va da z 14,1 a 15,9), guarda verso +X.
const POS := Vector3(19.1, 10.35, 16.3)
const CAMERE := {
	"lontano": [Vector3(23.0, 10.7, 14.6), Vector3(19.1, 10.2, 15.6)],
	"vicino": [Vector3(19.65, 10.5, 16.05), Vector3(19.1, 10.35, 16.3)],
}

var level: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	level = (load(LEVEL) as PackedScene).instantiate()
	var togli := PackedStringArray(["Interni"])
	togli.append_array(OS.get_environment("SCATTI_TOGLI").split(",", false))
	for percorso in togli:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	var p: Player = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p.teleport(Vector3(0.0, 0.0, 10.0), 0.0, 0.0)
	var tec := (level.get_node(^"Tecnici") as Node3D).global_transform
	var L: GDScript = load("res://proposte/tessera_aspetto/lettore_aspetto.gd")
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.02
	cam.far = 200.0
	level.add_child(cam)
	cam.make_current()
	# più scatti nello stesso processo: "variante:stato:camera,variante:stato:camera,..."
	for scatto in a[2].split(","):
		var parti := scatto.split(":")
		var variante := parti[0]
		var verde := parti[1] == "verde"
		var camera := parti[2] if parti.size() > 2 else "lontano"
		var lettore: Node3D = L.new()
		lettore.set(&"variante", variante)
		lettore.set(&"sbloccato", verde)
		level.add_child(lettore)
		lettore.global_transform = tec * Transform3D(Basis(Vector3.UP, PI * 0.5), POS)
		var c: Array = CAMERE[camera]
		cam.global_position = tec * (c[0] as Vector3)
		cam.look_at(tec * (c[1] as Vector3), Vector3.UP)
		await _frames(30)
		await RenderingServer.frame_post_draw
		var nome := "lettore_%s_%s_%s.jpg" % [variante, "verde" if verde else "rosso", camera]
		get_viewport().get_texture().get_image().save_jpg(out.path_join(nome), 0.92)
		print("salvato ", nome)
		lettore.queue_free()
		await _frames(2)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

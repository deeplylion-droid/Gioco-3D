extends Node
## Scatti ravvicinati delle ante degli armadietti degli spogliatoi, dagli occhi del giocatore (riscontro dell'utente
## sulla v0.3.13: il pallone compenetrato con un'anta), per il collaudo: il pallone davanti all'anta aperta
## dell'armadietto est2_02 e l'anta che sbatte col salvagente-papera chiusa, a metà corsa e aperta.
## SCATTI_SOLO=nome1,nome2 fa solo quelli. PALLONE_PRIMA=1 rimette il pallone dov'era (x 10,2) per lo scatto "prima".
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_armadietti.gd <cartella>

const INTERNI := "res://scenes/interni/interni.tscn"
## [occhio, guardato, angolo dell'anta che sbatte (gradi; -1 chiusa)]
const SCATTI := {
	"pallone_anta": [Vector3(8.7, 1.6, -9.1), Vector3(10.2, 0.45, -10.3), -1.0],
	"pallone_anta_vicino": [Vector3(9.35, 1.25, -9.55), Vector3(10.15, 0.3, -10.3), -1.0],
	# dove sta adesso: a terra accanto alla fine della panca ovest
	"pallone_panca": [Vector3(6.6, 1.6, -8.2), Vector3(5.0, 0.3, -9.3), -1.0],
	"pallone_panca_vicino": [Vector3(5.9, 1.1, -8.7), Vector3(5.05, 0.2, -9.3), -1.0],
	"anta_sbatte_chiusa": [Vector3(8.9, 1.6, -4.1), Vector3(10.5, 0.9, -5.1), -1.0],
	"anta_sbatte_meta": [Vector3(8.9, 1.6, -4.1), Vector3(10.5, 0.9, -5.1), 40.0],
	"anta_sbatte_aperta": [Vector3(8.9, 1.6, -4.1), Vector3(10.5, 0.9, -5.1), 81.0],
	"anta_sbatte_aperta_vicino": [Vector3(9.6, 1.2, -4.7), Vector3(10.6, 0.5, -5.1), 81.0],
}

var cartella := "user://scatti_armadietti"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var interni := (load(INTERNI) as PackedScene).instantiate()
	add_child(interni)
	for i in 10:
		await get_tree().process_frame
	# niente giocatore davanti alla camera
	for p in interni.find_children("*", "Player", true, false):
		(p as Node3D).visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	var spog := interni.get_node("Ambienti/Spogliatoi") as Node3D
	if OS.get_environment("PALLONE_PRIMA") != "":
		var pal := spog.find_child("pallone_spogliatoi", true, false) as Node3D
		pal.global_position = Vector3(10.2, 0.0, -10.2)
	var anta := spog.find_child("armadietto_sbatte_anta", true, false) as Node3D
	var chiusa := anta.transform
	var cardine := spog.find_child("cardine_armadietto_sbatte", true, false) as Node3D
	var perno := anta.get_parent_node_3d().to_local(cardine.global_position)
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	var solo := OS.get_environment("SCATTI_SOLO").split(",", false)
	for nome in SCATTI:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var s: Array = SCATTI[nome]
		var ang: float = s[2]
		var verso := Transform3D(Basis.IDENTITY, perno)
		anta.transform = chiusa if ang < 0.0 else verso * Transform3D(Basis(Vector3.UP, -deg_to_rad(ang)), Vector3.ZERO) * verso.affine_inverse() * chiusa
		cam.look_at_from_position(s[0], s[1])
		for i in 40:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.88)
		print("scatto -> ", f)
	get_tree().quit()

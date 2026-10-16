extends Node
## Scatti delle tappe 5-6 nel livello vero, con lo stato giusto (riscontro della v0.3.1, punti 3-6).
## Serve un vero renderer: un processo alla volta, sotto il render.lock (flock /home/user/tools/render.lock ...).
## Uso:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_tappe56.gd <cartella> [scatti] [preset]
## Scatti (separati da virgole, di serie tutti):
##   portellone_spiaggia  piscina piena, dalla spiaggia verso la parte profonda (punto 3)
##   portellone_vicino    piscina piena, dal bordo sopra la parte profonda (punto 3)
##   portellone_vuota     piscina vuota e portellone aperto, dal fondo (punto 4)
##   sotto_scala          in fondo alla scala del pozzo, guardando sotto la scala (punto 5)
##   cancelli             camera delle onde, davanti al primo cancello stagno (punto 6)
##   cancelli_aperti      lo stesso punto dopo il passaggio, cancelli aperti (punto 6)
##   cupola               (v0.3.2, punto 5) la cupola dal bordo della piscina, 4 fotogrammi di fila (PNG)
##                        com'è, senza pulviscolo e senza rivoli sul vetro: per trovare i puntini che
##                        sfarfallano confrontando i fotogrammi

const LEVEL := "res://scenes/sala_principale.tscn"
const TUTTI := ["portellone_spiaggia", "portellone_vicino", "portellone_vuota", "sotto_scala", "cancelli", "cancelli_aperti", "cupola"]

var out_dir := "user://scatti_tappe56"
var scatti: Array = TUTTI
var preset := "alto"
var level: Node
var p: Player
var tec: Node3D


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		out_dir = a[1]
	if a.size() > 2 and a[2] != "" and a[2] != "tutti":
		scatti = Array(a[2].split(","))
	if a.size() > 3:
		preset = a[3]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(preset)
	# Come scatti_sala.gd: gli interni si tolgono prima del primo frame, se no il renderer software
	# supera la memoria della macchina (da qui non si vedono).
	# SCATTI_TOGLI="Sala/Dettagli,..." toglie anche altri nodi (uguali nei prima e nei dopo).
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
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
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	var hud := GameState.player.get_node_or_null(^"HUD") if GameState.player else null
	if hud:
		hud.visible = false
	p = GameState.player
	tec = level.get_node("Tecnici")
	for s in scatti:
		await call(StringName("_" + s))
	var st := FileAccess.get_file_as_string("/proc/self/status")
	for riga in st.split("\n"):
		if riga.begins_with("VmHWM"):
			print("memoria massima: ", riga)
	# Liberare il livello intero sul renderer software può restare appeso: gli scatti sono salvati.
	OS.kill(OS.get_process_id())


# --- Gli scatti ---------------------------------------------------------------------------------

func _portellone_spiaggia() -> void:
	await _foto("portellone_spiaggia", Vector3(0.0, 0.0, -11.5), Vector3(0.0, -2.2, 2.0))


func _portellone_vicino() -> void:
	await _foto("portellone_vicino", Vector3(3.2, 0.0, 6.2), Vector3(0.2, -2.2, 2.2))


func _portellone_vuota() -> void:
	await _svuota_e_apri()
	await _foto("portellone_vuota", Vector3(2.6, -2.0, 4.4), Vector3(0.0, -2.3, 2.0))


func _sotto_scala() -> void:
	await _foto("sotto_scala", tec.to_global(Vector3(2.6, 0.0, 0.9)), tec.to_global(Vector3(-0.2, 0.1, -0.2)))


func _cancelli() -> void:
	# Fermi per lo scatto: da qui si aprirebbero già (si aprono a 4,5 m).
	_cancelli_al_passaggio(false)
	await _foto("cancelli", tec.to_global(Vector3(12.5, 0.0, -0.6)), tec.to_global(Vector3(17.5, 1.3, 0.0)))


func _cancelli_aperti() -> void:
	# Si passa davanti ai cancelli: si aprono da soli e restano aperti.
	_cancelli_al_passaggio(true)
	Engine.time_scale = 4.0
	_metti(tec.to_global(Vector3(15.0, 0.0, 0.0)), tec.to_global(Vector3(25.0, 1.0, 0.0)))
	for i in 60:
		await get_tree().physics_frame
	_metti(tec.to_global(Vector3(19.5, 0.0, 0.0)), tec.to_global(Vector3(25.0, 1.0, 0.0)))
	for i in 80:
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	await _foto("cancelli_aperti", tec.to_global(Vector3(12.5, 0.0, -0.6)), tec.to_global(Vector3(17.5, 1.3, 0.0)))


func _cupola() -> void:
	var dove := Vector3(5.0, 0.0, 6.5)
	var verso := Vector3(0.0, 15.0, -5.0)
	_metti(dove, verso)
	for i in 60:
		await get_tree().process_frame
		_metti(dove, verso)
	await _fotogrammi("cupola_normale", dove, verso)
	var polvere := level.find_children("*", "Pulviscolo", true, false)
	for n in polvere:
		(n as Node3D).visible = false
	await _fotogrammi("cupola_senza_pulviscolo", dove, verso)
	for n in polvere:
		(n as Node3D).visible = true
	var vetro := level.get_node_or_null(^"Sala/Cupola/sala_cupola_vetro") as MeshInstance3D
	if vetro:
		var m := vetro.get_active_material(0) as ShaderMaterial
		if m:
			m.set_shader_parameter(&"pioggia", 0.0)
	await _fotogrammi("cupola_senza_rivoli", dove, verso)


func _fotogrammi(nome: String, dove: Vector3, verso: Vector3) -> void:
	for i in 20:
		await get_tree().process_frame
		_metti(dove, verso)
	for k in 4:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%d.png" % [nome, k]))
		await get_tree().process_frame
		_metti(dove, verso)
	print("scatto ", nome)


# --- Aiuti ----------------------------------------------------------------------------------------

func _svuota_e_apri() -> void:
	var vasca: WaterTank = level.get_node("Piscina/Pozza")
	vasca.fill = 0.0
	# Sul renderer software ogni frame costa: il tempo del gioco va 4 volte più svelto.
	Engine.time_scale = 4.0
	for i in 60:
		await get_tree().physics_frame
	var pulsante: WaterButton = level.get_node("Piscina/PulsantePortello")
	pulsante.powered = true
	level.get_node("Piscina/Portello").call(&"open")
	for i in 60:
		await get_tree().physics_frame
	Engine.time_scale = 1.0


func _cancelli_al_passaggio(si: bool) -> void:
	for c in level.find_children("*", "Paratia", true, false):
		if &"apri_al_passaggio" in c:
			c.set(&"apri_al_passaggio", si)


func _metti(dove: Vector3, verso: Vector3) -> void:
	p.velocity = Vector3.ZERO
	p.teleport(dove, p.yaw, 0.0)
	p.look_at_point(verso)


func _foto(nome: String, dove: Vector3, verso: Vector3, attesa := 60) -> void:
	_metti(dove, verso)
	for i in attesa:
		await get_tree().process_frame
		_metti(dove, verso)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join(nome + ".jpg"), 0.9)
	print("scatto ", nome)

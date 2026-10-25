extends Node
## Scatti dell'oblò con lei nel muro est della torre (ObloLei, accanto alla bocca del tubo), dagli occhi del giocatore
## (il Player vero, così lei lo guarda): da lontano dal pavimento, da vicino dalla vasca, il ravvicinato, mentre si
## stacca. La torre da sola (sala_torre.tscn, con le condotte), con l'ambiente della sala, al buio dopo la sala pompe.
## Con OBLO_RAGGIO nell'ambiente il raggio del vetro (0,6 grande, 0,22 piccolo); con OBLO_POSA la posa.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_oblo_torre.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"

var cartella := "user://scatti_oblo_torre"
## Dove sta il giocatore (i piedi): da lontano sul pavimento a ovest della vasca, da vicino nella vasca.
var POSTI := [Vector3(35.9, -20.0, -13.4), Vector3(38.0, -19.98, -13.4)]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	if OS.get_environment("OBLO_RAGGIO") != "":
		torre.oblo_raggio_vetro = float(OS.get_environment("OBLO_RAGGIO"))
	if OS.get_environment("OBLO_POSA") != "":
		torre.oblo_posa = OS.get_environment("OBLO_POSA")
	add_child(torre)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var o := torre.oblo
	o.set_process(false)
	var c := o.global_position
	var posti: Array = POSTI
	var nome := "oblo_torre_%s" % str(o.raggio_vetro).replace(".", "_")
	# da lontano, quando la scopri
	p.teleport(posti[0])
	await _fotogrammi(4)
	p.look_at_point(c + Vector3.DOWN * 0.1)
	o._mostra()
	await _fotogrammi(90)
	_scatto("%s_1_da_lontano" % nome)
	# da vicino, mentre ti guarda
	p.teleport(posti[1])
	await _fotogrammi(4)
	p.look_at_point(c + Vector3.DOWN * 0.15)
	await _fotogrammi(60)
	_scatto("%s_2_da_vicino" % nome)
	# il ravvicinato dell'oblò, un po' di traverso
	var lungo := o.global_basis.x
	p.teleport(Vector3(c.x, posti[1].y, c.z) + o.normale() * 1.15 + lungo * 0.55)
	await _fotogrammi(4)
	p.look_at_point(c)
	await _fotogrammi(40)
	_scatto("%s_4_ravvicinato" % nome)
	# mentre si stacca (1,2 s dopo)
	p.teleport(posti[1])
	await _fotogrammi(4)
	p.look_at_point(c + Vector3.DOWN * 0.15)
	await _fotogrammi(20)
	o._stacca()
	await _fotogrammi(72)
	_scatto("%s_3_si_stacca" % nome)
	get_tree().quit()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	var f := cartella.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("scatto -> ", f)

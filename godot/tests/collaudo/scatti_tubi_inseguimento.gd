extends Node
## Scatti dei tubi dell'inseguimento (correzioni della 0.3.17): il giocatore vero che scivola in un tubo, dagli occhi,
## uno scatto ogni [constant OGNI] fotogrammi guardando avanti lungo la linea; e qualche vista da fuori.
## La torre da sola (sala_torre.tscn, con le condotte), con l'ambiente della sala, al buio dopo la sala pompe.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_tubi_inseguimento.gd <cartella> \
##        <tubo|fuori> [da_indice] [prefisso]

const PLAYER := "res://scenes/player/player.tscn"
const OGNI := 15

var cartella := "user://scatti_tubi"


static func b(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


## nome: [camera, punto guardato] (coordinate di Blender)
var FUORI := {
	"fuori_piega_nord": [[42.6, 21.6, -18.0], [42.6, 17.3, -19.0]],
	"fuori_piega_sud": [[43.4, 12.8, -18.6], [42.6, 17.3, -19.0]],
	"fuori_piega_alto": [[44.5, 19.5, -15.6], [42.6, 17.2, -19.0]],
	"fuori_arrivo_vasca1": [[52.6, 12.8, -20.2], [50.2, 15.0, -21.8]],
}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var f := cartella.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("SCATTO ", f)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	var cosa := a[2] if a.size() > 2 else "ins_A_tubo_0"
	var da := int(a[3]) if a.size() > 3 else 0
	var prefisso := a[4] if a.size() > 4 else ""
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _fotogrammi(30)
	var ins := torre.inseguimento as SalaInseguimento
	# (lei compare solo dopo 20 s nella vasca 1: qui non serve)
	if ins.lei:
		ins.lei.visible = false
	if cosa == "fuori":
		var cam := Camera3D.new()
		cam.near = 0.05
		add_child(cam)
		cam.current = true
		cam.fov = 70.0
		for nome in FUORI:
			var s: Array = FUORI[nome]
			cam.look_at_from_position(b(s[0][0], s[0][1], s[0][2]), b(s[1][0], s[1][1], s[1][2]))
			await _fotogrammi(20)
			await _scatto(prefisso + nome)
		get_tree().quit()
		return
	var linea := PackedVector3Array()
	for q in ins.dati["tubi"][cosa]:
		linea.append(SalaInseguimento.b(q))
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(10)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	# i piedi sul fondo del tubo, poco dopo il punto di partenza
	p.teleport(linea[da] + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1))
	var k := 0
	var ultimo := da
	var arrivato := 0
	for f in 60 * 12:
		await get_tree().physics_frame
		# il punto della linea più vicino ai piedi, e lo sguardo 3 m più avanti
		var piedi := p.global_position
		var i_vicino := ultimo
		for i in range(ultimo, mini(ultimo + 12, linea.size())):
			if linea[i].distance_to(piedi) < linea[i_vicino].distance_to(piedi):
				i_vicino = i
		ultimo = i_vicino
		var avanti := i_vicino
		var l := 0.0
		while avanti < linea.size() - 1 and l < 3.0:
			l += linea[avanti].distance_to(linea[avanti + 1])
			avanti += 1
		var dir := linea[avanti] - linea[i_vicino]
		if i_vicino == linea.size() - 1 or ins.in_tubo(piedi) == false and f > 60:
			dir = Vector3(p.velocity.x, 0.0, p.velocity.z)
		if dir.length() > 0.1:
			p.look_at_point(p.global_position + Vector3.UP * 0.9 + dir.normalized() * 3.0 + Vector3.DOWN * 0.3)
		if f % OGNI == 0:
			await _scatto("%s%s_%03d" % [prefisso, cosa, k])
			print("  piedi %s occhi %s indice %d/%d accovacciato %s" % [piedi, p.get_viewport().get_camera_3d().global_position, i_vicino, linea.size(), p.is_crouching])
			k += 1
		if i_vicino >= linea.size() - 2:
			arrivato += 1
			if arrivato > 75:
				break
	get_tree().quit()

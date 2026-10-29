extends Node
## Ricontrollo (grafica-2) della correzione delle righe rosa fra la vasca dell'oblò della torre e il muro delle condotte
## (shadow_bias 0,03 e normal_bias 0,2 sulla luce di lei negli oblò, LeiOblo), con la camera vera del giocatore e la
## lancia. Nella stessa scena, con lei comparsa e ferma sul vetro, ogni vista si scatta due volte: "prima" coi bias di
## serie (0,1 e 1,0) e "dopo" con quelli nuovi, così il confronto è nello stesso istante.
## - torre: dalla torre verso l'oblò, e dalla sala delle condotte attorno alla cisterna (lato, altro lato, sotto,
##   lontano);
## - risalita: i tre oblò, di fronte e di sbieco vicino al vetro (luce, ombre, lei appoggiata).
## Uso (sotto il lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/oblo_bias_g2.gd <cartella> <torre|risalita>

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
const POSTI_RISALITA := {
	"ObloFiume": Vector3(-5.45, -5.4, 58.3),
	"ObloPersonale": Vector3(-34.45, -5.4, 49.35),
	"ObloServizio": Vector3(-21.2, 0.0, 39.15),
}
var cartella := ""
var dove := "torre"
var p: Player


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	if a.size() > 2:
		dove = a[2]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	var obli: Array = []
	if dove == "torre":
		for sc in ["res://scenes/creature/bambino_cubo.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/props/polaroid.tscn"]:
			var n := (load(sc) as PackedScene).instantiate()
			n.set(&"visible", false)
			add_child(n)
		var campioni := SalaTorre.materiali_campione()
		var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
		torre.costruzione_a_pezzi = true
		torre.visible = false
		torre.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(torre)
		await torre.costruisci_a_pezzi()
		await torre.prepara_materiali(get_viewport())
		torre.visible = true
		torre.process_mode = Node.PROCESS_MODE_INHERIT
		obli.append(["torre", torre.oblo, POSTO_TORRE])
		campioni.clear()
	else:
		Engine.set_meta(&"risalita_subito", true)
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color.BLACK
		var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
		add_child(ris)
		for k in POSTI_RISALITA:
			obli.append([k, ris.find_child(k, true, false) as ObloLei, POSTI_RISALITA[k]])
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for voce in obli:
		var nome: String = voce[0]
		var o: ObloLei = voce[1]
		var posto: Vector3 = voce[2]
		o.set_process(false)
		p.teleport(posto)
		await _fotogrammi(4)
		p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
		await _fotogrammi(150)
		o._mostra()
		await _fotogrammi(90)
		var luce: Light3D = o.lei.get(&"_luce")
		print("OBLO %s luce di lei: bias %.2f normal_bias %.2f" % [nome, luce.shadow_bias, luce.shadow_normal_bias])
		var viste := _viste(nome, o, posto)
		p.set_physics_process(false)
		for v in viste:
			p.teleport(v[1])
			p.look_at_point(v[2])
			for bias in [[0.1, 1.0, "prima"], [0.03, 0.2, "dopo"]]:
				luce.shadow_bias = bias[0]
				luce.shadow_normal_bias = bias[1]
				await _fotogrammi(12)
				await _scatto("%s_%s_%s" % [nome, v[0], bias[2]])
			# (la stessa vista con la luce di lei spenta: quello che resta non viene da lei)
			luce.visible = false
			await _fotogrammi(12)
			await _scatto("%s_%s_%s" % [nome, v[0], "luce_spenta"])
			luce.visible = true
		p.set_physics_process(true)
		o.lei.visible = false
	get_tree().quit()


## Le viste: [nome, dove sta il giocatore (piedi), dove guarda].
func _viste(nome: String, o: ObloLei, posto: Vector3) -> Array:
	var c := o.centro_vetro()
	var n := o.normale()            # verso chi guarda
	var lato := n.cross(Vector3.UP).normalized()
	var occhi := Vector3.UP * 1.6
	var out: Array = [["fronte", posto, c]]
	if nome == "torre":
		# la cisterna sta dietro il muro, nella sala delle condotte (verso -n)
		var dietro := c - n * 1.8
		out.append(["condotte_lato", dietro + lato * 3.6 - occhi, dietro + lato * 1.6])
		out.append(["condotte_altro_lato", dietro - lato * 3.6 - occhi, dietro - lato * 1.6])
		out.append(["condotte_sotto", dietro + lato * 3.0 + Vector3.DOWN * 4.5 - occhi, dietro + lato * 1.6 + Vector3.DOWN * 2.5])
		out.append(["condotte_lontano", c - n * 9.0 + lato * 2.0 + Vector3.UP * 1.0 - occhi, dietro])
	else:
		out.append(["sbieco", c + n * 1.2 + lato * 0.9 - occhi + Vector3.UP * 0.1, c])
		out.append(["sbieco_altro", c + n * 1.2 - lato * 0.9 - occhi + Vector3.UP * 0.1, c])
	return out


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	print("scatto ", nome)

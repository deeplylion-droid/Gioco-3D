extends Node
## Scatti degli oblò con lei dietro il vetro (ObloLei) nei tre corridoi della Risalita, dagli occhi del giocatore (il
## Player vero, così lei lo guarda): da lontano quando la scopri, da vicino mentre ti guarda, mentre si stacca; più il
## ravvicinato dell'oblò. La Risalita da sola (risalita.tscn), con l'ambiente della sala, al buio dopo la sala pompe,
## senza torcia. Per la pagina dell'utente e per il collaudo.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_oblo_lei.gd <cartella> [oblò, separati da virgole]

const PLAYER := "res://scenes/player/player.tscn"

var cartella := "user://scatti_oblo"
var solo := PackedStringArray()

## Per ogni oblò: [dove sta il giocatore da lontano (i piedi), da vicino]; guarda sempre il centro dell'oblò. Da
## lontano: a 3-4 m, dal lato opposto del corridoio (largo 2 m), così il vetro non si vede di taglio.
var POSTI := {
	"ObloFiume": [Vector3(-5.5, -5.4, 54.4), Vector3(-5.45, -5.4, 58.3)],
	"ObloPersonale": [Vector3(-34.35, -5.4, 50.45), Vector3(-34.45, -5.4, 49.35)],
	"ObloServizio": [Vector3(-24.4, 0.0, 39.0), Vector3(-21.2, 0.0, 39.15)],
}

## Mentre si stacca: gli scatti a questi punti dell'animazione del distacco (i fotogrammi su llvmpipe sono lenti e
## lunghi, quindi si aspetta la posizione dell'animazione e non un numero di fotogrammi).
const QUOTE_STACCA := {"3_si_stacca": 0.35, "3b_si_stacca": 0.6}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2 and a[2] != "":
		solo = a[2].split(",", false)
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	# (la Risalita da sola: fuori dalle sue porte non c'è niente, e il cielo dell'ambiente si vedrebbe dalle aperture;
	# nel gioco lì ci sono i corridoi bui)
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	add_child(ris)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for nome in POSTI:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var o := ris.find_child(nome, true, false) as ObloLei
		o.set_process(false)
		var c := o.global_position
		var posti: Array = POSTI[nome]
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
		# mentre si stacca
		p.teleport(posti[1])
		await _fotogrammi(4)
		p.look_at_point(c + Vector3.DOWN * 0.15)
		await _fotogrammi(20)
		var ap: AnimationPlayer = o.lei._ap if o.lei else null
		o._stacca()
		for q in QUOTE_STACCA:
			for i in 900:
				if not is_instance_valid(ap) or not String(ap.current_animation).ends_with("_stacca") \
						or ap.current_animation_position >= QUOTE_STACCA[q] * ap.current_animation_length:
					break
				await get_tree().process_frame
			_scatto("%s_%s" % [nome, q])
		await _fotogrammi(150)
	get_tree().quit()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	var f := cartella.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("scatto -> ", f)

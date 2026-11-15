extends Node
## Collaudo della lastra sotto la soglia del portone della torre: scatti a parti come scatti_portone_torre.gd di
## ambienti-1 (la Sala e la torre col guscio tolto, mesh accese entro [member raggio], ambiente della sala senza GI e
## nebbia volumetrica, luci del blackout), con la lastra di SalaPrincipale.chiudi_soglia_torre e il giocatore vero.
##  - occhi: il giocatore attraversa a piedi la soglia nei due versi in due punti della larghezza, guardando in basso,
##    uno scatto ogni 6 fotogrammi, al buio e con una lampadina tecnica sulla camera;
##  - fermo: in piedi sulla soglia, guardando i piedi;
##  - vicino: ravvicinati con la lampadina, radenti e dall'alto, al centro e ai due capi del vano.
## Con "prima" senza la lastra (per il confronto). Stampa SCATTI:.
## Versione "capi": solo i due capi del vano, dove la lastra finisce contro gli stipiti.
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##   --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/soglia_capi.gd <cartella> [prima]

const SALA := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const SALA_GD := preload("res://scripts/game/sala_principale.gd")
const PLAYER := "res://scenes/player/player.tscn"
const XS := 20.1
var raggio := 20.0
var _radice: Node3D
var _prima := {}
var cart := ""
var pre := ""
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(pre + nome + ".jpg"), 0.9)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var senza := a.has("prima")
	pre = "prima_" if senza else ""
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	_radice = Node3D.new()
	_radice.name = "SalaPerScatti"
	var tutta := (load(SALA) as PackedScene).instantiate()
	var n := tutta.get_node(^"Sala") as Node3D
	var tr := n.transform
	n.get_parent().remove_child(n)
	n.transform = tr
	_radice.add_child(n)
	tutta.free()
	var guscio := _radice.find_child("sala_torre_guscio", true, false)
	if guscio:
		guscio.free()
	var torre := (load(TORRE) as PackedScene).instantiate() as Node3D
	_radice.add_child(torre)
	var we := WorldEnvironment.new()
	we.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	we.environment.sdfgi_enabled = false
	we.environment.volumetric_fog_enabled = false
	we.environment.ssil_enabled = false
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	if OS.has_environment("MAGENTA"):
		# per la diagnosi: lo sfondo magenta pieno, la luce ambiente e i riflessi ancora dal cielo; quello che è magenta
		# negli scatti è un buco vero verso lo sfondo, le nuvole sono riflessi
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(1.0, 0.0, 1.0)
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		we.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		pre = "magenta_" + pre
	_radice.add_child(we)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	_accendi(Vector3(XS, 1.0, -15.0))
	if not senza:
		var l := SALA_GD.chiudi_soglia_torre(torre, _radice.find_child("sala_pavimento", true, false) as MeshInstance3D)
		print("SCATTI: lastra %s" % [l.global_transform * l.get_aabb()])
	for i in 60:
		await get_tree().process_frame
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	_accendi(Vector3(XS, 1.6, -15.0))
	var spazio := get_viewport().find_world_3d().direct_space_state
	for z in [-16.3, -15.0, -13.7]:
		var r := []
		for x in [19.8, 19.95, 20.05, 20.1, 20.15, 20.25, 20.4]:
			var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, z), Vector3(x, -3.0, z)))
			r.append("%.3f" % (h.position as Vector3).y if h else "-")
		print("SCATTI: collisioni a z %.1f, x 19,8 .. 20,4: %s" % [z, ", ".join(r)])
	var c := Camera3D.new()
	c.fov = 55.0
	c.near = 0.01
	c.attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	_radice.add_child(c)
	var o := OmniLight3D.new()
	o.light_energy = 1.0
	o.omni_range = 3.0
	c.add_child(o)
	c.current = true
	# i due capi del vano: le strisce fra la fine della lastra (z -16,52 / -13,48) e lo stipite
	for capo in [-17.5, -16.56, -13.44, -12.5]:
		var g := Vector3(XS, 0.0, capo)
		var dentro := 1.0 if capo < -15.0 else -1.0
		for v in [["dall_alto", Vector3(0.0, 0.45, 0.02 * dentro)], ["da_sala", Vector3(-0.5, 0.35, 0.25 * dentro)], \
				["da_torre", Vector3(0.5, 0.35, 0.25 * dentro)], ["dal_vano_radente", Vector3(0.0, 0.12, 0.6 * dentro)], \
				["occhi_da_sala", Vector3(-1.3, 1.6, 0.5 * dentro)], ["occhi_da_torre", Vector3(1.3, 1.6, 0.5 * dentro)]]:
			c.global_position = g + (v[1] as Vector3)
			c.look_at(g, Vector3.UP if v[0] != "dall_alto" else Vector3.RIGHT)
			_accendi(c.global_position)
			for luce in [false, true]:
				o.visible = luce
				await _frames(10)
				await _scatto("capo_z%.2f_%s%s" % [capo, v[0], "_luce" if luce else ""])
	print("SCATTI: finito")
	get_tree().quit()


func _accendi(da: Vector3) -> void:
	for nn in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := nn as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		g.visible = da.clamp(b.position, b.end).distance_to(da) < raggio and bool(_prima[g])

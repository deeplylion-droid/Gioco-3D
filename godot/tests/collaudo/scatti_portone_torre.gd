extends Node
## Scatti del portone della torre col gioco vero a parti (ricontrollo del collaudo su varchi-cielo, 6 novembre): la sala
## (Sala) e la torre (sala_torre.tscn, sotto la radice senza spostamenti, come SalaPrincipale._aggiungi_torre, col guscio
## provvisorio tolto), le mesh accese solo vicino alla camera, l'ambiente della sala senza GI e nebbia volumetrica e le
## luci del blackout. Le pose: dagli occhi del checkpoint del portone verso le due aperture trovate dal collaudo
## (cielo_fessure.gd), e la soglia come la vede chi entra e chi esce.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/scatti_portone_torre.gd <cartella> [prima]
##   (senza "prima" mette la lastra sotto la soglia come SalaPrincipale._completa_torre; con "prima" no)

const SALA := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const SALA_GD := preload("res://scripts/game/sala_principale.gd")
const OCCHI := Vector3(21.4, 1.59, -15.0)
const POSE := [
	["occhi_verso_giu", OCCHI, OCCHI + Vector3(-0.52, -0.654, -0.549), 70.0],
	["occhi_verso_su", OCCHI, OCCHI + Vector3(0.426, 0.337, 0.84), 70.0],
	["soglia_entrando", Vector3(17.6, 1.6, -15.0), Vector3(20.1, 0.0, -15.6), 75.0],
	["soglia_uscendo", Vector3(22.6, 1.6, -15.4), Vector3(20.1, 0.0, -15.0), 75.0],
	["soglia_vicino", Vector3(20.6, 0.5, -14.4), Vector3(20.1, 0.0, -15.6), 60.0],
	# i due checkpoint della torre dove i raggi verso l'alto non toccano niente (controllo_cielo.gd)
	["NEm3_su", Vector3(37.47, -1.41, -18.97), Vector3(37.47, -1.41, -18.97) + Vector3(0.45, 0.887, -0.099), 70.0],
	["NOm12_su", Vector3(27.05, -10.41, -21.41), Vector3(27.05, -10.41, -21.41) + Vector3(0.128, 0.904, 0.408), 70.0],
	# i cinque raggi della torre che controllo_cielo mette a parte (verso l'alto), al centro dello scatto
	["raggio_portone", Vector3(21.4, 1.6, -15.0), Vector3(21.4, 1.6, -15.0) + Vector3(0.425693, 0.3375, 0.839571), 40.0],
	["raggio_NEm3_a", Vector3(37.468, -1.4, -18.970), Vector3(37.468, -1.4, -18.970) + Vector3(0.45006, 0.8875, -0.098944), 40.0],
	["raggio_NEm3_b", Vector3(37.468, -1.4, -18.970), Vector3(37.468, -1.4, -18.970) + Vector3(0.29558, 0.620833, 0.726084), 40.0],
	["raggio_NOm12_a", Vector3(27.049, -10.4, -21.412), Vector3(27.049, -10.4, -21.412) + Vector3(0.127848, 0.904167, 0.4076), 40.0],
	["raggio_NOm12_b", Vector3(27.049, -10.4, -21.412), Vector3(27.049, -10.4, -21.412) + Vector3(0.685801, 0.3875, -0.616052), 40.0],
]

var raggio := 60.0
var _radice: Node3D
var _prima := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella: String = a[1] if a.size() > 1 else "/tmp/scatti_portone_torre"
	var senza := a.has("prima")
	DirAccess.make_dir_recursive_absolute(cartella)
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
	_radice.add_child(we)
	var cam := Camera3D.new()
	cam.near = 0.02
	_radice.add_child(cam)
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	if not senza:
		SALA_GD.chiudi_soglia_torre(torre, _radice.find_child("sala_pavimento", true, false) as MeshInstance3D)
	for i in 60:
		await get_tree().process_frame
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	cam.make_current()
	for v in POSE:
		if OS.has_environment("SOLO_RAGGI") and not String(v[0]).begins_with("raggio_"):
			continue
		cam.fov = float(v[3])
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		_accendi(cam.global_position)
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s%s.jpg" % ["prima_" if senza else "", v[0]]), 0.9)
		print("SCATTO ", v[0])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	print("FINE")
	get_tree().quit()


func _accendi(da: Vector3) -> void:
	for nn in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := nn as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		g.visible = da.clamp(b.position, b.end).distance_to(da) < raggio and bool(_prima[g])

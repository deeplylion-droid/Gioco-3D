extends Node
## Scatti dei cartelloni del muro nord della sala (sala_cartellone_n0 delfino, n1 balena, n2 polpo; quelli "sul muro in
## fondo" della richiesta dell'utente del 30 ottobre), prima e dopo averli bruciati e scarabocchiati, dagli occhi del
## giocatore (1,6 m) con le luci vere del gioco: all'arrivo nella sala e col lampione della statua acceso. Le viste
## "_vicino" da sotto ogni cartellone, col campo stretto, per vedere come sta sul muro.
## La sala intera, renderizzata, non sta nei 15 GB della macchina di prova: come in proposte/nebbia_viola/scatti_sala.gd
## si caricano solo le parti che si vedono, nella loro posizione, con l'ambiente della sala, e a ogni vista si accendono
## solo le mesh entro [constant RAGGIO] m. Le luci dei teli e quelle d'emergenza come le regola sala_principale.gd.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --script res://tests/run.gd -- res://proposte/poster_sala/scatti_muro_nord.gd <cartella> <prima|dopo>

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Vasca", "Piscina/Pozza", "Piscina/AcquaPozza", "Vasche", "Mascotte", "Scarabocchi"]
## nome: [occhi, punto guardato, campo visivo]
const CAMERE := {
	"ingresso": [Vector3(0.0, 1.6, 19.2), Vector3(-1.5, 4.6, -24.0), 62.0],
	"piscina": [Vector3(-1.5, 1.6, 2.0), Vector3(-1.5, 4.6, -24.0), 62.0],
	"ovest": [Vector3(-12.0, 1.6, -8.0), Vector3(-1.5, 4.8, -24.0), 62.0],
	"est": [Vector3(9.0, 1.6, -8.0), Vector3(-1.5, 4.8, -24.0), 62.0],
	"muro": [Vector3(-1.5, 1.6, -12.0), Vector3(-1.5, 4.8, -24.0), 70.0],
}
## Da vicino, sotto ogni cartellone (l'occhio a 1,6 m dal pavimento), per vedere il bordo sul muro.
const TECNICI := {
	"n0_delfino_vicino": [Vector3(-9.0, 1.6, -19.5), Vector3(-9.0, 5.0, -24.0), 45.0],
	"n1_balena_vicino": [Vector3(-1.5, 1.6, -19.5), Vector3(-1.5, 5.0, -24.0), 45.0],
	"n2_polpo_vicino": [Vector3(6.0, 1.6, -19.5), Vector3(6.0, 5.0, -24.0), 45.0],
	"n0_delfino_radente": [Vector3(-5.5, 1.6, -21.5), Vector3(-9.0, 5.0, -24.0), 40.0],
	"n2_polpo_radente": [Vector3(2.5, 1.6, -21.5), Vector3(6.0, 5.0, -24.0), 40.0],
}
const RAGGIO := 22.0

var _radice: Node3D
var _prima := {}
var _accese := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var dopo := a.size() > 2 and a[2] == "dopo"
	DirAccess.make_dir_recursive_absolute(out)
	# i neon che sfarfallano scelgono a caso: con lo stesso seme il prima e il dopo hanno le stesse luci
	seed(30)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	_radice = Node3D.new()
	_radice.name = "SalaPerTeli"
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	var look: LookSala = null
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			print("TELI manca ", percorso)
			continue
		var tr := n.transform
		var padre := n.get_parent() as Node3D
		if padre != tutta and padre:
			tr = padre.transform * tr
		n.get_parent().remove_child(n)
		n.transform = tr
		_radice.add_child(n)
		if n is LookSala:
			look = n
	tutta.free()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.far = 60.0
	_radice.add_child(cam)
	get_tree().root.add_child(_radice)
	cam.make_current()
	_luci_come_nel_gioco(_radice.get_node(^"Sala/Luci"))
	# (i teli accanto alla statua come nel gioco, rovinati dalla 0.3.17)
	var sp := load("res://scripts/game/sala_principale.gd") as Script
	print("TELI rovinati: %d superfici" % int(sp.call(&"metti_teli_rovinati", _radice.get_node(^"Sala/Architettura"))))
	if dopo and sp.get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "metti_cartelloni_rovinati"):
		print("TELI cartelloni nord rovinati: %d superfici" % int(sp.call(&"metti_cartelloni_rovinati", _radice.get_node(^"Sala/Architettura"))))
	# il lampione della statua, come lo prepara sala_principale.gd: spento all'arrivo, si accende avvicinandosi
	var sfarfallio := _radice.get_node_or_null(^"Vasca/Sfarfallio") as FlickerLight
	var lampione := _radice.get_node_or_null(^"Sala/Luci/luce_lampione") as Light3D
	if sfarfallio and lampione:
		sfarfallio.set_targets(lampione, null)
		sfarfallio.turn_off()
	for stato in ["arrivo", "lampione"]:
		if stato == "lampione" and sfarfallio:
			sfarfallio.turn_on(true)
		for nome in CAMERE:
			await _scatta(cam, CAMERE[nome], out.path_join("%s_%s.jpg" % [nome, stato]))
	for nome in TECNICI:
		await _scatta(cam, TECNICI[nome], out.path_join("%s.jpg" % nome))
	print("TELI pipeline: disegno %d, specializzazione %d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)])
	print("TELI memoria massima %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	get_tree().quit()


func _scatta(cam: Camera3D, c: Array, f: String) -> void:
	cam.global_position = c[0]
	cam.look_at(c[1], Vector3.UP)
	cam.fov = c[2]
	_accendi(c[0], c[1])
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(f, 0.9)
	print("TELI scatto ", f)


## Le luci della sala come le regola sala_principale.gd (_setup_hall): i faretti caldi sui teli, le emergenze.
func _luci_come_nel_gioco(lights: Node) -> void:
	for l in lights.get_children():
		if l is OmniLight3D and String(l.name).begins_with("luce_emergenza"):
			(l as OmniLight3D).light_volumetric_fog_energy = 2.2
			if String(l.name) in ["luce_emergenza_34", "luce_emergenza_35"]:
				(l as OmniLight3D).shadow_enabled = true
		elif l is SpotLight3D and String(l.name).begins_with("luce_neon"):
			(l as SpotLight3D).light_volumetric_fog_energy = 0.8
		elif l is SpotLight3D and String(l.name).begins_with("luce_cartellone"):
			var c := l as SpotLight3D
			c.light_color = Color(1.0, 0.78, 0.5)
			c.light_energy = 1.2
			c.spot_angle = 22.0
			c.spot_range = 6.0
			c.shadow_enabled = false
			c.light_volumetric_fog_energy = 0.8


func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


func _accendi(da: Vector3, a: Vector3) -> void:
	_accese.clear()
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		var vicino := (_distanza(b, da) < RAGGIO or _distanza(b, a) < RAGGIO) and bool(_prima[g])
		if vicino:
			_accese[g] = true
		g.visible = vicino


static func _distanza(b: AABB, p: Vector3) -> float:
	return p.clamp(b.position, b.end).distance_to(p)

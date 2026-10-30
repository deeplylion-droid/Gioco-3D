extends Node
## Scatti dei due teli di Jilly ai lati della statua (sala_cartellone_mascotte_0 e _1), prima e dopo averli bruciati e
## scarabocchiati (richiesta dell'utente del 30 ottobre), dagli occhi del giocatore (1,6 m) con le luci del gioco e la
## torcia accesa in mano: come le trova all'inizio (prima del risveglio) e al buio dopo il blackout. Le viste "_zoom" sono dallo stesso punto con
## la camera stretta, per vedere i buchi sulla lamiera; le "_radente" da sotto e di lato, per vedere come la carta sta
## sulla lamiera della cornice.
## La sala intera, renderizzata, non sta nei 15 GB della macchina di prova: come in proposte/nebbia_viola/scatti_sala.gd
## si caricano solo le parti che si vedono, nella loro posizione, con l'ambiente della sala, e a ogni vista si accendono
## solo le mesh entro [constant RAGGIO] m. Le luci dei teli e quelle d'emergenza come le regola sala_principale.gd.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --script res://tests/run.gd -- res://proposte/poster_sala/scatti_teli.gd <cartella> <prima|dopo>

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Vasca", "Piscina/Pozza", "Piscina/AcquaPozza", "Vasche", "Mascotte", "Scarabocchi"]
## nome: [occhi, punto guardato, campo visivo]
const CAMERE := {
	"ingresso": [Vector3(0.0, 1.6, 19.2), Vector3(0.0, 3.4, 9.8), 62.0],
	"arcobaleno": [Vector3(-3.6, 1.6, 15.6), Vector3(-5.6, 5.1, 9.8), 62.0],
	"arcobaleno_zoom": [Vector3(-3.6, 1.6, 15.6), Vector3(-5.6, 5.2, 9.8), 24.0],
	"arcobaleno_radente": [Vector3(-8.2, 1.6, 12.4), Vector3(-5.6, 5.2, 9.8), 40.0],
	"bagnina": [Vector3(3.6, 1.6, 15.6), Vector3(5.6, 5.1, 9.8), 62.0],
	"bagnina_zoom": [Vector3(3.6, 1.6, 15.6), Vector3(5.6, 5.2, 9.8), 24.0],
	"bagnina_radente": [Vector3(8.2, 1.6, 12.4), Vector3(5.6, 5.2, 9.8), 40.0],
}
const RAGGIO := 16.0

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
	# la torcia del giocatore, accesa come all'inizio del gioco (nella sala buia i teli si vedono con quella)
	cam.add_child(Torcia.new())
	get_tree().root.add_child(_radice)
	cam.make_current()
	_luci_come_nel_gioco(_radice.get_node(^"Sala/Luci"))
	if dopo:
		var sp := load("res://scripts/game/sala_principale.gd") as Script
		print("TELI rovinati: %d superfici" % int(sp.call(&"metti_teli_rovinati", _radice.get_node(^"Sala/Architettura"))))
	for stato in [GameState.Luci.PRIMA_DEL_RISVEGLIO, GameState.Luci.BLACKOUT]:
		GameState.imposta_luci(stato)
		var suffisso := "luci" if stato == GameState.Luci.PRIMA_DEL_RISVEGLIO else "buio"
		for nome in CAMERE:
			var c: Array = CAMERE[nome]
			cam.global_position = c[0]
			cam.look_at(c[1], Vector3.UP)
			cam.fov = c[2]
			_accendi(c[0], c[1])
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var f := out.path_join("%s_%s.jpg" % [nome, suffisso])
			get_viewport().get_texture().get_image().save_jpg(f, 0.9)
			print("TELI scatto ", f)
	print("TELI pipeline: disegno %d, specializzazione %d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)])
	print("TELI memoria massima %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	get_tree().quit()


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

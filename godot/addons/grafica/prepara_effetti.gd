class_name PreparaEffetti
extends Node
## Prepara gli effetti che altrimenti bloccano il gioco al primo uso (riscontro 3 della v0.3.4: "la
## prima volta che ho usato sia il risucchio d'acqua, sia lo sparo, sia che ho visto il geyser ... 1
## secondo di freeze"): il motore compila shader e pipeline la prima volta che li disegna.
## Appena entra il livello (lo schermo è ancora nero: Dissolvenza dopo la schermata di caricamento)
## per [constant FOTOGRAMMI] fotogrammi accende davanti alla camera, una volta sola:
## - le particelle e le mesh del giocatore (zaino: aspirazione, getto, schizzi, gocce, colonna
##   aspirata, vortice; EffettiZaino: schizzi e nebbia dove il getto colpisce; SlideFx) e i due getti (WaterStream: il nastro del nucleo, e la sua aspirazione);
## - una macchia di bagnato (il primo Decal prepara l'atlante dei decal), lo schizzo grande d'acqua del tuffo
##   di lei nella fossa (WaterSplash, forza 3) e lo schermo rotto del jumpscare (glitch_schermo);
## - i suoni che partono in quei momenti (caricati in memoria, senza suonarli).
## Poi rimette tutto com'era: particelle spente e vuote, mesh nascoste, getti vuoti.
## La crea GettoPotente quando si aggancia allo zaino. Con Engine.set_meta(&"prepara_effetti_spento",
## true) non fa niente (per misurare i blocchi senza: tests/misura_primo_uso.gd).

const FOTOGRAMMI := 6
const SUONI := [&"zaino_carica", &"zaino_gocce", &"zaino_risucchio_loop", &"zaino_serbatoio_loop",
		&"zaino_strattone", &"lei_esplosione", &"tuffo", &"lei_urlo", &"morso", &"stinger_morte", &"lei_scivola_sotto",
		&"piscina_svuota_loop", &"vasca_svuotata"]

## Lo zaino (WaterPack) e il suo GettoPotente.
var pack: Node
var getto: Node

var _f := 0
# [nodo, visible, global_transform, emitting (o null), da spostare davanti alla camera]
var _stati: Array = []
var _getti: Array = []
var _modi := {}
var _glitch: CanvasLayer
var _macchia: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Dopo i nodi che accendono e spengono gli effetti a ogni fotogramma: qui si decide per ultimi.
	process_priority = 2000
	if Engine.has_meta(&"prepara_effetti_spento"):
		queue_free()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(pack):
		return
	_f += 1
	if _f == 1:
		_raccogli()
		_carica_suoni()
	if _f <= FOTOGRAMMI:
		_accendi(cam)
	else:
		_rimetti()
		queue_free()


func _raccogli() -> void:
	var visti := {}
	# I getti (WaterStream): il nastro è in coordinate del mondo, si accendono davanti senza spostarli.
	for nome in [&"stream", &"suction_stream"]:
		var s = pack.get(nome)
		if s is Node3D and (s as Node3D).has_method(&"physics_step"):
			_getti.append(s)
			visti[s] = true
			_stati.append([s, (s as Node3D).visible, (s as Node3D).global_transform, null, false])
			# Il livello parte in pausa: il nastro si costruisce nel suo _process, che deve girare.
			_modi[s] = (s as Node).process_mode
			(s as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	# Tutto il giocatore: anche gli effetti che stanno fuori dallo zaino (EffettiZaino, gli schizzi
	# dell'impatto sui muri; SlideFx, gli schizzi della scivolata).
	for radice in [pack.get_parent(), pack, getto]:
		if radice == null:
			continue
		for n in (radice as Node).find_children("*", "GeometryInstance3D", true, false):
			if visti.has(n) or not (n is GPUParticles3D or n is MeshInstance3D or n is MultiMeshInstance3D):
				continue
			# La lancia e le mani si vedono già: qui solo gli effetti.
			if _sotto_camera(n) and not n is GPUParticles3D:
				continue
			visti[n] = true
			var g := n as GeometryInstance3D
			_stati.append([g, g.visible, g.global_transform, (g as GPUParticles3D).emitting if g is GPUParticles3D else null, true])

	if getto and getto.has_method(&"_costruisci_colonna"):
		getto.call(&"_costruisci_colonna", Vector3.ZERO, Vector3.UP)
	# La prima macchia di bagnato (Decal) prepara l'atlante dei decal: a mezz'aria, non si vede.
	if getto and getto.has_method(&"_macchia"):
		var cam := get_viewport().get_camera_3d()
		getto.call(&"_macchia", cam.global_transform * Vector3(0.0, 0.0, -2.0), Vector3.UP)
		var bagnato: Array = getto.get(&"_bagnato")
		if not bagnato.is_empty():
			_macchia = bagnato[bagnato.size() - 1]
	_glitch = CanvasLayer.new()
	_glitch.layer = 1
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = JumpscareGlitch.SHADER
	m.set_shader_parameter(&"forza", 1.0)
	r.material = m
	_glitch.add_child(r)
	add_child(_glitch)


func _accendi(cam: Camera3D) -> void:
	var davanti := cam.global_transform * Vector3(0.0, 0.0, -2.5)
	var i := 0
	for st in _stati:
		var g: GeometryInstance3D = st[0]
		if not is_instance_valid(g):
			continue
		g.visible = true
		if st[4]:
			g.global_position = davanti + Vector3(0.05 * (i % 5), 0.05 * (i / 5), 0.0)
			i += 1
		if g is GPUParticles3D:
			var p := g as GPUParticles3D
			if _f == 1:
				p.restart()
			p.emitting = true
	# Tre pezzetti di fila per fotogramma: tra un fotogramma e l'altro lo zaino fa il suo passo senza
	# getto e la catena si spezza; con un pezzetto solo il nastro non si disegna.
	for s in _getti:
		for k in 3:
			(s as Node3D).call(&"physics_step", 1.0 / 60.0, true, davanti, -cam.global_basis.z * 4.0 + Vector3.UP * 2.0)
	if _f == 1:
		# Lo schizzo del tuffo (si libera da solo quando finisce).
		var schizzo := WaterSplash.new()
		add_child(schizzo)
		schizzo.global_position = davanti + Vector3.DOWN * 0.8
		schizzo.play(3.0)


func _rimetti() -> void:
	for st in _stati:
		var g: GeometryInstance3D = st[0]
		if not is_instance_valid(g):
			continue
		if g is GPUParticles3D:
			var p := g as GPUParticles3D
			p.restart()
			p.emitting = bool(st[3])
		g.global_transform = st[2]
		g.visible = st[1]
	for s in _getti:
		(s as Node3D).call(&"clear")
		(s as Node).process_mode = _modi.get(s, Node.PROCESS_MODE_INHERIT)
	if is_instance_valid(_macchia) and getto:
		(getto.get(&"_bagnato") as Array).erase(_macchia)
		_macchia.queue_free()


func _carica_suoni() -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null:
		return
	for nome in SUONI:
		audio.call(&"stream_di", nome)


func _sotto_camera(n: Node) -> bool:
	var c := n.get_parent()
	while c:
		if c is Camera3D:
			return true
		c = c.get_parent()
	return false

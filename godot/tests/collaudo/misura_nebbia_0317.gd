extends Node
## Misure e scatti della nebbia viola per la 0.3.17 (riscontro dell'utente sulla 0.3.16), col renderer vero, dagli occhi
## del giocatore (1,6 m), con NebbiaViola di Grafica e le lampade della zona per l'alone:
## - "piscina": la piscina a onde della sala guardata dal bordo, piena e vuota, e il pavimento della sala alla stessa
##   distanza; la sala si carica a parti (non ci sta in memoria intera: CLAUDE.md), con LookSala e le luci dopo il
##   blackout. Misura la copertura della nebbia (1 - T, con l'uniform "misura": la nebbia toglie luce e non ne aggiunge)
##   sul fondo e sul pavimento;
## - "tunnel": il tunnel dell'inseguimento costruito come nel gioco (a pezzi), dalle banchine in alcuni punti; misura la
##   luminosità media dello schermo con e senza nebbia.
## Con [param shader] uno shader della nebbia diverso (per lo scatto di prima). Scatti in <cartella>, misure stampate
## con "MISURA".
## Uso (sotto il render.lock, tools/scatto_sicuro.sh): res://tests/collaudo/misura_nebbia_0317.gd <cartella>
##        <piscina|tunnel> [nome] [shader]

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Vasca", "Piscina/Pozza", "Piscina/AcquaPozza", "Vasche", "Mascotte", "Scarabocchi"]
const RAGGIO := 22.0
## La piscina dal bordo sud (z 5) guardando giù verso il fondo, e il pavimento della sala fuori dalla piscina (x 12) alla
## stessa distanza e con lo stesso sguardo.
const VISTE_SALA := {
	"piscina": [Vector3(2.0, 1.6, 6.4), Vector3(2.0, -2.0, 1.4)],
	"pavimento": [Vector3(13.0, 1.6, 6.4), Vector3(13.0, -0.0, 0.6)],
}
## Nel tunnel: [s, lato (-1 banchina sinistra), s guardato].
const VISTE_TUNNEL := {
	"testa": [2.0, -1.0, 14.0],
	"gommoni": [70.0, -1.0, 82.0],
	"lunga": [120.0, -1.0, 140.0],
}

var _cartella := ""
var _nome := "ora"
var _radice: Node3D
var _prima := {}
var _cam: Camera3D
var n: NebbiaViola


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1]
	var modo: String = a[2] if a.size() > 2 else "piscina"
	if a.size() > 3:
		_nome = a[3]
	DirAccess.make_dir_recursive_absolute(_cartella)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	n = Grafica.nebbia_viola
	if a.size() > 4 and a[4] != "":
		(n.get(&"_mat") as ShaderMaterial).shader = load(a[4])
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_cam.far = 80.0
	if modo == "piscina":
		await _piscina()
	else:
		await _tunnel()
	print("MISURA pipeline: disegno %d, specializzazione %d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)])
	get_tree().quit()


func _piscina() -> void:
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	_radice = Node3D.new()
	_radice.name = "SalaPerNebbia"
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	var look: LookSala = null
	for percorso in PARTI:
		var nd := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if nd == null:
			continue
		var tr := nd.transform
		var padre := nd.get_parent() as Node3D
		if padre != tutta and padre:
			tr = padre.transform * tr
		nd.get_parent().remove_child(nd)
		nd.transform = tr
		_radice.add_child(nd)
		if nd is LookSala:
			look = nd
	tutta.free()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	we.camera_attributes = look.attributi_camera if look else null
	_radice.add_child(we)
	_radice.add_child(_cam)
	get_tree().root.add_child(_radice)
	_cam.make_current()
	var z := ZonaNebbiaViola.new()
	z.quota = 0.0
	_radice.add_child(z)
	z.luci = [z.get_path_to(_radice.get_node(^"Sala")), z.get_path_to(_radice.get_node(^"LuciSala"))]
	for i in 30:
		await get_tree().process_frame
	n.zona(z, true, true)
	var pozza := _radice.find_child("Pozza", true, false)
	for stato in ["piena", "vuota"]:
		if stato == "vuota" and pozza and &"fill" in pozza:
			pozza.set(&"fill", 0.0)
			for i in 10:
				await get_tree().process_frame
		for v in VISTE_SALA:
			if v == "pavimento" and stato == "vuota":
				continue
			var c: Array = VISTE_SALA[v]
			_cam.global_position = c[0]
			_cam.look_at(c[1], Vector3.UP)
			_accendi(c[0], c[1])
			await _misura("%s_%s" % [v, stato] if v == "piscina" else v)


func _tunnel() -> void:
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	add_child(env)
	add_child(_cam)
	_cam.global_position = Vector3(0, 50, 0)
	_cam.make_current()
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	await sala.costruisci_a_pezzi()
	for i in 60:
		await get_tree().process_frame
	var z := sala.find_child("NebbiaViola", false, false)
	if z:
		n.zona(z, true, true)
	for v in VISTE_TUNNEL:
		var c: Array = VISTE_TUNNEL[v]
		var s: float = c[0]
		var p := sala.punto(s) + sala.destra(s) * (sala.canale + sala.banchina * 0.5) * float(c[1])
		var occhio := Vector3(p.x, sala.piano + 1.6, p.z)
		var g := sala.punto(float(c[2]))
		_cam.global_position = occhio
		_cam.look_at(Vector3(g.x, sala.piano + 1.2, g.z), Vector3.UP)
		await _misura(v)


## Senza nebbia, con la nebbia (com'è nel gioco) e con la nebbia che toglie soltanto (la copertura): salva i primi due e
## stampa la luminosità media di tutto lo schermo e, nella piscina, della metà bassa (il fondo o il pavimento).
func _misura(vista: String) -> void:
	var mat := n.get(&"_mat") as ShaderMaterial
	n.accesa = false
	n.quanto = 0.0
	var senza := await _scatto("%s_senza" % vista)
	n.accesa = true
	n.quanto = 1.0
	var con := await _scatto("%s_%s" % [vista, _nome])
	var strato := n.get(&"_strato") as CanvasLayer
	mat.set_shader_parameter(&"misura", true)
	strato.visible = false
	var solo := await _scatto("")
	mat.set_shader_parameter(&"misura", false)
	strato.visible = true
	var basso := Rect2i(0, senza.get_height() / 2, senza.get_width(), senza.get_height() / 2)
	var tutto := Rect2i(Vector2i.ZERO, senza.get_size())
	var l0 := _luminosita(senza, basso)
	var lt := _luminosita(solo, basso)
	print("MISURA %s %s: luminosità media senza %.1f, con %.1f (tutto lo schermo); metà bassa senza %.1f, con %.1f; copertura della nebbia nella metà bassa (1 - T) %.2f" % [
			vista, _nome, _luminosita(senza, tutto), _luminosita(con, tutto), l0, _luminosita(con, basso),
			1.0 - (lt / l0 if l0 > 0.5 else 1.0)])


func _scatto(nome: String) -> Image:
	for i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if nome != "":
		img.save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
		print("salvato ", nome)
	return img


## La luminosità media (0..255, luma) nel riquadro [param r], un pixel ogni 4.
static func _luminosita(img: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var c := img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			k += 1
	return s / maxf(k, 1) * 255.0


func _aggiunto(nd: Node) -> void:
	if nd is GeometryInstance3D and _radice and _radice.is_ancestor_of(nd) and not (nd.get_parent() is Camera3D):
		if not _prima.has(nd):
			_prima[nd] = (nd as GeometryInstance3D).visible
		(nd as GeometryInstance3D).visible = false


## Accende le mesh entro RAGGIO dalla camera o dal punto guardato (la sala intera non ci sta in memoria).
func _accendi(da: Vector3, a: Vector3) -> void:
	for nd in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := nd as GeometryInstance3D
		if g.get_parent() is Camera3D:
			continue
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		g.visible = bool(_prima[g]) and (_dist(b, da) < RAGGIO or _dist(b, a) < RAGGIO)


static func _dist(b: AABB, p: Vector3) -> float:
	return p.clamp(b.position, b.end).distance_to(p)

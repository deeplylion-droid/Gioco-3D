extends Node
## Collaudo della nebbia 0.3.17 sulla piscina a onde (riscontro dell'utente sulla 0.3.16: sul fondo "pochissimo più che
## nel resto della stanza"): dagli occhi del giocatore (1,6 m) in piedi sul bordo, da quattro punti diversi da quelli
## delle misure di grafica-2, a piscina piena e vuota, e due viste del pavimento della sala per il confronto. Ogni vista
## tre volte: senza nebbia, con la nebbia della 0.3.16 (tests/collaudo/nebbia_0316.gdshader, 20 passi) e con quella di
## adesso (32 passi, preset alto). La sala a parti come in misura_nebbia_0317.gd (non ci sta in memoria intera).
## Uso (sotto il render.lock, tools/scatto_sicuro.sh): res://tests/collaudo/giro_piscina_0317.gd <cartella>

const SALA := "res://scenes/sala_principale.tscn"
const SHADER_0316 := "res://tests/collaudo/nebbia_0316.gdshader"
const PARTI := ["Sala", "LuciSala", "Vasca", "Piscina/Pozza", "Piscina/AcquaPozza", "Vasche", "Mascotte", "Scarabocchi"]
const RAGGIO := 22.0
## [occhi, punto guardato]; la conca della piscina va da x -7 a 7 e da z -13,2 a 5.
const VISTE_PISCINA := {
	"bordo_sud_ovest": [Vector3(-4.0, 1.6, 5.5), Vector3(-1.5, -2.0, -1.5)],
	"bordo_sud_lontano": [Vector3(0.5, 1.6, 5.5), Vector3(0.0, -1.5, -11.0)],
	"bordo_est": [Vector3(7.6, 1.6, -4.0), Vector3(2.0, -2.5, -6.0)],
	"bordo_ovest_nord": [Vector3(-7.6, 1.6, -10.0), Vector3(-1.0, -2.0, -6.0)],
}
const VISTE_PAVIMENTO := {
	"pavimento_est": [Vector3(12.0, 1.6, -3.0), Vector3(12.5, 0.0, -9.0)],
	"pavimento_sud": [Vector3(-12.0, 1.6, 8.0), Vector3(-12.0, 0.0, 2.5)],
}

var _cartella := ""
var _radice: Node3D
var _prima := {}
var _cam: Camera3D
var n: NebbiaViola
var _shader_ora: Shader
var _shader_0316: Shader


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1]
	DirAccess.make_dir_recursive_absolute(_cartella)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	n = Grafica.nebbia_viola
	_shader_ora = (n.get(&"_mat") as ShaderMaterial).shader
	_shader_0316 = load(SHADER_0316)
	_cam = Camera3D.new()
	_cam.fov = 62.0   # (il FOV di serie del giocatore)
	_cam.near = 0.05
	_cam.far = 80.0
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
	for v in VISTE_PAVIMENTO:
		await _tre(v, VISTE_PAVIMENTO[v])
	var pozza := _radice.find_child("Pozza", true, false)
	for stato in ["piena", "vuota"]:
		if stato == "vuota" and pozza and &"fill" in pozza:
			pozza.set(&"fill", 0.0)
			for i in 300:
				await get_tree().process_frame
		for v in VISTE_PISCINA:
			await _tre("%s_%s" % [v, stato], VISTE_PISCINA[v])
	get_tree().quit()


## La vista [param c] senza nebbia, con quella della 0.3.16 e con quella di adesso.
func _tre(nome: String, c: Array) -> void:
	_cam.global_position = c[0]
	_cam.look_at(c[1], Vector3.UP)
	_accendi(c[0], c[1])
	var mat := n.get(&"_mat") as ShaderMaterial
	n.accesa = false
	n.quanto = 0.0
	var senza := await _scatto("%s_a_senza" % nome)
	n.accesa = true
	n.quanto = 1.0
	mat.shader = _shader_0316
	mat.set_shader_parameter(&"passi", 20)
	var vecchia := await _scatto("%s_b_0316" % nome)
	mat.shader = _shader_ora
	mat.set_shader_parameter(&"passi", 32)
	var ora := await _scatto("%s_c_0317" % nome)
	var basso := Rect2i(0, senza.get_height() / 2, senza.get_width(), senza.get_height() / 2)
	print("GIRO %s, metà bassa: senza %.1f, 0.3.16 %.1f, 0.3.17 %.1f" % [nome, _lum(senza, basso), _lum(vecchia, basso), _lum(ora, basso)])


func _scatto(nome: String) -> Image:
	for i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	print("salvato ", nome)
	return img


static func _lum(img: Image, r: Rect2i) -> float:
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

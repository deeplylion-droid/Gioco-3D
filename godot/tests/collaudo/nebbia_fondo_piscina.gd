extends Node
## grafica-2, dopo il ricontrollo di enigmi (strumento suo, collaudo_nebbia_0317.gd di fb24f1e4): la piscina vuota da
## dentro con lo strato fitto sul fondo dove si sta. Ogni punto: senza nebbia, 0.3.16, 0.3.17 com'era (strato alla quota
## della sala) e adesso (strato ai piedi del giocatore, messo a terra sotto la camera, come in gioco).
## Prima era: Ricontrollo della nebbia viola 0.3.17 (lavoro/nebbia-0317): gli stessi punti con la nebbia di adesso, con quella
## della 0.3.16 (lo shader di 446069c3, letto dal file dato, e 20 passi) e senza nebbia, col renderer vero.
## - "piscina": la piscina a onde caricata a parti come in misura_nebbia_0317.gd (la sala intera non ci sta in memoria),
##   piena e vuota: dal bordo sud guardando il fondo, dal bordo sud guardando attraverso la piscina, dal bordo est, da
##   dentro la piscina vuota (in piedi sul fondo) e il pavimento della sala alla stessa distanza;
## - "infermeria": l'infermeria del gioco da sola, con la sua zona di nebbia, dai punti del giro dagli occhi del giocatore
##   di scatti_infermeria_gioco.gd, con le lampade che sfarfallano ferme e la nebbia senza vento (i due scatti
##   differiscono solo per la nebbia). Per ogni punto stampa quanti pixel cambiano fra adesso e la 0.3.16.
## Stampa "MISURA" con la luminosità media dello schermo e della metà bassa. Scatti in <cartella>.
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --script res://tests/run.gd -- res://tests/collaudo/collaudo_nebbia_0317.gd <cartella> <piscina|infermeria> \
##        <shader della 0.3.16 (percorso assoluto)> [solo_vuota | punti dell'infermeria separati da virgole]
## (con i punti dell'infermeria anche gli scambi di passi: lo shader nuovo a 20 e quello della 0.3.16 a 32)
## (la sala a parti è lenta col renderer software: piena e vuota insieme passano i 40 minuti; "solo_vuota" fa la seconda)

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Vasca", "Piscina/Pozza", "Piscina/AcquaPozza", "Vasche", "Mascotte", "Scarabocchi"]
const RAGGIO := 22.0
## [occhio, punto guardato, solo con la piscina vuota]
const VISTE_SALA := {
	"bordo_sud_fondo": [Vector3(2.0, 1.6, 6.4), Vector3(2.0, -2.0, 1.4), false],
	"bordo_sud_attraverso": [Vector3(1.0, 1.6, 6.3), Vector3(-1.0, -0.3, -6.0), false],
	"bordo_est": [Vector3(7.6, 1.6, 0.5), Vector3(-4.0, -1.6, -0.5), false],
	"dentro_fondo": [Vector3(1.5, -0.6, 2.5), Vector3(-5.0, -1.2, -1.0), true],
	"dentro_verso_bordo": [Vector3(-2.0, -0.6, -1.0), Vector3(3.0, 0.2, 5.0), true],
	"dentro_fondo_3m": [Vector3(-1.0, -0.6, 0.0), Vector3(1.2, -2.2, 2.0), true],
	"pavimento": [Vector3(13.0, 1.6, 6.4), Vector3(13.0, 0.0, 0.6), false],
}
const VISTE_INFERMERIA := {
	"ingresso": [Vector3(1.6, 1.6, 2.7), Vector3(-0.5, 1.0, -2.5)],
	"lettino": [Vector3(1.2, 1.6, 0.6), Vector3(2.75, 0.7, 2.1)],
	"lavandino": [Vector3(-0.6, 1.6, 1.0), Vector3(-0.6, 0.6, 3.2)],
	"porta_nord": [Vector3(-1.0, 1.6, -0.5), Vector3(-2.2, 1.0, -3.2)],
	"porta_sud": [Vector3(0.9, 1.6, 1.3), Vector3(1.7, 1.0, 3.2)],
	"pavimento": [Vector3(1.0, 1.6, 2.0), Vector3(-1.0, 0.0, -1.5)],
}

var _cartella := ""
var _radice: Node3D
var _prima := {}
var _cam: Camera3D
var n: NebbiaViola
var _shader_ora: Shader
var _shader_0316: Shader
var _passi_ora := 32
var _giocatore: Player
var _zona_prova: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1]
	var modo: String = a[2]
	DirAccess.make_dir_recursive_absolute(_cartella)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	n = Grafica.nebbia_viola
	var mat := n.get(&"_mat") as ShaderMaterial
	_shader_ora = mat.shader
	_passi_ora = int(mat.get_shader_parameter(&"passi"))
	_shader_0316 = Shader.new()
	_shader_0316.code = FileAccess.get_file_as_string(a[3])
	print("passi di adesso (alto): %d" % _passi_ora)
	# (la nebbia senza vento: i due scatti differiscono solo per lo strato)
	mat.set_shader_parameter(&"vento", Vector3.ZERO)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_cam.far = 80.0
	if modo == "piscina":
		await _piscina()
	else:
		await _infermeria()
	print("FINE ", modo)
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
	_giocatore = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_radice.add_child(_giocatore)
	_giocatore.set_physics_process(false)
	_giocatore.visible = false
	GameState.player = _giocatore
	_cam.make_current()
	var z := ZonaNebbiaViola.new()
	z.quota = 0.0
	_radice.add_child(z)
	z.luci = [z.get_path_to(_radice.get_node(^"Sala")), z.get_path_to(_radice.get_node(^"LuciSala"))]
	for i in 30:
		await get_tree().process_frame
	n.zona(z, true, true)
	_zona_prova = z
	# (le lampade che sfarfallano ferme, come nell'infermeria: gli scatti differiscono solo per la nebbia)
	for l in _radice.find_children("*", "Node3D", true, false):
		if l is LuceEmergenza and int(l.get(&"modalita")) in [1, 2]:
			l.set(&"modalita", 0)
		if &"sfarfalla" in l:
			l.set(&"sfarfalla", false)
	var pozza := _radice.find_child("Pozza", true, false)
	var stati := ["vuota"] if OS.get_cmdline_user_args().size() > 4 and OS.get_cmdline_user_args()[4] == "solo_vuota" else ["piena", "vuota"]
	for stato in stati:
		if stato == "vuota" and pozza and &"fill" in pozza:
			pozza.set(&"fill", 0.0)
			for i in 300:
				await get_tree().process_frame
		for v in VISTE_SALA:
			var c: Array = VISTE_SALA[v]
			if bool(c[2]) and stato == "piena":
				continue
			# (sesto argomento: solo queste viste, separate da virgole; la memoria cresce vista dopo vista)
			if OS.get_cmdline_user_args().size() > 5 and not v in OS.get_cmdline_user_args()[5].split(","):
				continue
			_cam.global_position = c[0]
			_cam.look_at(c[1], Vector3.UP)
			_accendi(c[0], c[1])
			_piedi = await _piedi_sotto(c[0])
			# (gli occhi a 1,6 m sopra il fondo dove si sta, come in gioco: il fondo è in pendenza)
			if v.begins_with("dentro"):
				_cam.global_position.y = _piedi + 1.6
				_cam.look_at(c[1], Vector3.UP)
			_giocatore.global_position = Vector3(c[0].x, _piedi, c[0].z)
			_cam.make_current()
			await _tre("%s_%s" % [v, stato] if v != "pavimento" else v)


func _infermeria() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	get_tree().root.add_child(_cam)
	_cam.make_current()
	for i in 30:
		await get_tree().process_frame
	var z := f.find_child("NebbiaViola", true, false)
	print("zona della nebbia dell'infermeria: %s" % z)
	if z:
		n.zona(z, true, true)
	# (per un confronto pulito fra 0.3.16 e 0.3.17: le lampade che sfarfallano ferme e la nebbia senza vento, così i
	# due scatti differiscono solo per la nebbia)
	for l in f.find_children("*", "Node3D", true, false):
		if l is LuceEmergenza and int(l.get(&"modalita")) in [1, 2]:
			l.set(&"modalita", 0)
		if &"sfarfalla" in l:
			l.set(&"sfarfalla", false)    # (il negatoscopio)
	(n.get(&"_mat") as ShaderMaterial).set_shader_parameter(&"vento", Vector3.ZERO)
	var solo: String = OS.get_cmdline_user_args()[4] if OS.get_cmdline_user_args().size() > 4 else ""
	for v in VISTE_INFERMERIA:
		if solo != "" and not v in solo.split(","):
			continue
		var c: Array = VISTE_INFERMERIA[v]
		_cam.global_position = f.to_global(c[0])
		_cam.look_at(f.to_global(c[1]), Vector3.UP)
		await _tre(v)
		if solo != "":
			await _passi_scambiati(v)


## Lo stesso punto senza nebbia, con quella di adesso e con quella della 0.3.16: salva i tre scatti e stampa le
## luminosità e i pixel che cambiano fra adesso e la 0.3.16.
var _piedi := 0.0


## Dove poggerebbero i piedi sotto l'occhio [param occhio] (un raggio in giù), al più 1,6 m sotto l'occhio.
func _piedi_sotto(occhio: Vector3) -> float:
	await get_tree().physics_frame
	var q := PhysicsRayQueryParameters3D.create(occhio, occhio + Vector3.DOWN * 4.0)
	q.exclude = [_giocatore.get_rid()]
	var r := _cam.get_world_3d().direct_space_state.intersect_ray(q)
	return float(r.position.y) if r else occhio.y - 1.6


## Quanto la nebbia toglie: con "misura" lo shader non aggiunge luce e il colore viola è nascosto, lo schermo è
## quello senza nebbia × T. Media di 1 - T nella metà bassa e nel riquadro centrale (dove la scena non è nera).
func _copertura(_senza: Image) -> Array:
	var mat := n.get(&"_mat") as ShaderMaterial
	var strato := n.get(&"_strato") as CanvasLayer
	# (a scena ferma: le lampade che sfarfallano sono uguali nei due scatti)
	mat.set_shader_parameter(&"misura", true)
	strato.visible = false
	var img := await _fermo()
	# (senza nebbia: densità a zero; il quad lo riaccende NebbiaViola a ogni fotogramma)
	mat.set_shader_parameter(&"densita", 0.0)
	mat.set_shader_parameter(&"strato", 0.0)
	var senza := await _fermo()
	mat.set_shader_parameter(&"densita", 0.08)
	mat.set_shader_parameter(&"strato", 0.8)
	mat.set_shader_parameter(&"misura", false)
	strato.visible = true
	var w := img.get_width()
	var h := img.get_height()
	return [_cop(img, senza, Rect2i(0, h / 2, w, h / 2)), _cop(img, senza, Rect2i(w / 4, h / 4, w / 2, h / 2))]


## La nebbia piena quando è accesa (il giocatore messo sotto la camera può risultare fuori dalla zona di prova).
func _piena() -> void:
	if n.accesa:
		if _zona_prova and not n.in_zona():
			n.zona(_zona_prova, true, true)
		n.quanto = 1.0


func _fermo() -> Image:
	for i in 8:
		_piena()
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


static func _cop(m: Image, s: Image, r: Rect2i) -> float:
	var somma := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var a := s.get_pixel(x, y).get_luminance()
			if a < 10.0 / 255.0:
				continue
			somma += clampf(1.0 - m.get_pixel(x, y).get_luminance() / a, 0.0, 1.0)
			k += 1
	return somma / maxf(k, 1)


func _metti_fondo(y: float) -> void:
	n.set(&"_fondo", y)
	n.set(&"_fondo_obiettivo", y)


func _tre(vista: String) -> void:
	var mat := n.get(&"_mat") as ShaderMaterial
	n.accesa = false
	n.quanto = 0.0
	var senza := await _scatto("%s_senza" % vista)
	n.accesa = true
	n.quanto = 1.0
	_metti_fondo(0.0)
	var com_era := await _scatto("%s_0317_com_era" % vista)
	var cop_era := await _copertura(senza)
	_metti_fondo(_piedi)
	var cop_ora := await _copertura(senza)
	var ora := await _scatto("%s_0317" % vista)
	print("QUANTO %s: %.2f, zone %s" % [vista, n.quanto, n.in_zona()])
	print("COPERTURA %s (quanta luce toglie la nebbia, 0..1; metà bassa / centro): com'era %.2f / %.2f, adesso %.2f / %.2f" % [
			vista, cop_era[0], cop_era[1], cop_ora[0], cop_ora[1]])
	mat.shader = _shader_0316
	mat.set_shader_parameter(&"passi", 20)
	var prima := await _scatto("%s_0316" % vista)
	mat.shader = _shader_ora
	mat.set_shader_parameter(&"passi", _passi_ora)
	var basso := Rect2i(0, senza.get_height() / 2, senza.get_width(), senza.get_height() / 2)
	var tutto := Rect2i(Vector2i.ZERO, senza.get_size())
	var tutto0 := Rect2i(Vector2i.ZERO, senza.get_size())
	var basso0 := Rect2i(0, senza.get_height() / 2, senza.get_width(), senza.get_height() / 2)
	print("FONDO %s: piedi a %.2f, uniforme fondo %.2f; luminosità (tutto / metà bassa) 0.3.17 com'era %.1f / %.1f, adesso %.1f / %.1f; pixel diversi %d" % [
			vista, _piedi, float(mat.get_shader_parameter(&"fondo")), _luminosita(com_era, tutto0), _luminosita(com_era, basso0),
			_luminosita(ora, tutto0), _luminosita(ora, basso0), _diversi(com_era, ora)])
	print("MISURA %s: luminosità (tutto / metà bassa) senza %.1f / %.1f, 0.3.16 %.1f / %.1f, 0.3.17 %.1f / %.1f; pixel diversi fra 0.3.16 e 0.3.17 (>=6/255) %d su %d" % [
			vista, _luminosita(senza, tutto), _luminosita(senza, basso), _luminosita(prima, tutto), _luminosita(prima, basso),
			_luminosita(ora, tutto), _luminosita(ora, basso), _diversi(prima, ora), (senza.get_width() / 2) * (senza.get_height() / 2)])


## Lo shader nuovo con 20 passi e quello della 0.3.16 con 32: se la differenza fra le versioni viene dai passi o dalla
## formula. Stampa i pixel diversi rispetto ai due scatti normali.
func _passi_scambiati(vista: String) -> void:
	var mat := n.get(&"_mat") as ShaderMaterial
	mat.set_shader_parameter(&"passi", 20)
	var ora20 := await _scatto("%s_0317_20passi" % vista)
	mat.shader = _shader_0316
	mat.set_shader_parameter(&"passi", 32)
	var prima32 := await _scatto("%s_0316_32passi" % vista)
	mat.shader = _shader_ora
	mat.set_shader_parameter(&"passi", _passi_ora)
	var ora := Image.load_from_file(_cartella.path_join("%s_0317.jpg" % vista))
	var prima := Image.load_from_file(_cartella.path_join("%s_0316.jpg" % vista))
	print("MISURA passi %s: 0.3.17 a 20 passi contro 0.3.16 a 20: %d pixel diversi; 0.3.16 a 32 passi contro 0.3.17 a 32: %d" % [
			vista, _diversi(ora20, prima), _diversi(prima32, ora)])


func _scatto(nome: String) -> Image:
	for i in 25:
		_piena()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(_cartella.path_join(nome + ".jpg"), 0.9)
	return img


static func _luminosita(img: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var c := img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			k += 1
	return s / maxf(k, 1) * 255.0


## Quanti pixel (uno ogni 2 per lato) cambiano di almeno 6/255 in un canale.
static func _diversi(a: Image, b: Image) -> int:
	var k := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) >= 6.0 / 255.0:
				k += 1
	return k


func _aggiunto(nd: Node) -> void:
	if nd is GeometryInstance3D and _radice and _radice.is_ancestor_of(nd) and not (nd.get_parent() is Camera3D):
		if not _prima.has(nd):
			_prima[nd] = (nd as GeometryInstance3D).visible
		(nd as GeometryInstance3D).visible = false


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

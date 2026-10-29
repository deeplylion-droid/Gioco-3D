class_name NebbiaViola
extends Node
## La nebbia viola di NotHuman (dell'utente) nel gioco: nelle zone dove c'è (ZonaNebbiaViola: l'infermeria, la sala
## principale, il tunnel dell'inseguimento; scelta dell'utente del 29 ottobre) compare piano entrando e svanisce
## uscendo ("farla apparire gradualmente quando entri negli ambienti dove ci sarà"). Una sola per tutto il gioco, la
## crea Grafica ([member Grafica.nebbia_viola]). Due passaggi, come nell'originale (assets_src/nebbia_viola):
## - la nebbia: un quad a schermo intero (nebbia_viola.gdshader) disegnato dopo tutto il resto, prima del tone mapping;
##   il vertex shader lo mette davanti alla camera attiva, quindi può stare dove vuole nel mondo;
## - il colore: uno shader sullo schermo in un CanvasLayer (colore_viola.gdshader), dopo il tone mapping.
## I valori sono quelli della B, uguali in tutte le zone. [member quanto] sale e scende in [constant DURATA] secondi
## (densità e colore insieme: niente scatti sulla soglia); dopo un salto della camera (checkpoint, caricamento) la
## zona nuova vale subito. A [member quanto] 0 il quad e il colore sono nascosti: non si disegnano e non costano.
## L'alone: fino a 4 lampade, in ogni momento le più vicine davanti alla camera fra quelle della zona, prima le luci
## del gruppo [constant GRUPPO_ALONE] (la luce rosa di lei nell'inseguimento); quando cambiano si dissolvono.

const NEBBIA := preload("res://addons/grafica/nebbia_viola/nebbia_viola.gdshader")
const COLORE := preload("res://addons/grafica/nebbia_viola/colore_viola.gdshader")
## Le luci che, se accese e davanti alla camera, fanno l'alone prima delle lampade (la luce rosa di lei).
const GRUPPO_ALONE := &"nebbia_viola_alone"
## La B (scelta dell'utente del 29 ottobre: "ridotta di più", fino a 4,5 m, si dirada da 1,8 m).
const FORZA := 1.2
const LONTANO := 4.5
const OLTRE := 1.8
const CALA := 0.8
## La forza dell'alone di ogni lampada (come negli scatti).
const ALONE := 0.18
## I secondi per passare da spenta a piena (entrando) e viceversa (uscendo, o cambiando l'opzione).
const DURATA := 3.0
## Oltre questo spostamento della camera in un fotogramma è un salto (checkpoint): la zona nuova vale subito.
const SALTO := 3.0
## Le lampade per l'alone: entro questa distanza, davanti alla camera; ogni quanto si scelgono; in quanto si
## dissolvono quando cambiano; ogni quanto si rileggono quelle della zona (le zone costruite a pezzi le aggiungono).
const RAGGIO_LUCI := 16.0
const OGNI_SCELTA := 0.2
const CAMBIO_LUCE := 0.5
const OGNI_ELENCO := 3.0
## I passi lungo il raggio per la qualità della nebbia di Grafica (0 semplice, 1 volumetrica, 2 alta).
const PASSI := [10, 20, 20]

## L'opzione "Nebbia viola" (Grafica): spenta, la nebbia scende piano e non si disegna più.
var accesa := true
## Quanta nebbia adesso (0..1).
var quanto := 0.0:
	set(v):
		quanto = clampf(v, 0.0, 1.0)
		if _mat:
			_mat.set_shader_parameter(&"quanto", quanto)
			colore_mat.set_shader_parameter(&"quanto", quanto)
			_quad.visible = quanto > 0.0
			_strato.visible = quanto > 0.0

var colore_mat: ShaderMaterial
var _mat: ShaderMaterial
var _quad: MeshInstance3D
var _strato: CanvasLayer
## Le zone in cui è il giocatore adesso (a pezzi possono sovrapporsi): la nebbia c'è se ce n'è almeno una.
var _zone: Array[Node] = []
var _ultima_pos := Vector3.INF
var _fotogramma_salto := -100
## Le 4 luci dell'alone: [luce, peso 0..1].
var _slot: Array = [[null, 0.0], [null, 0.0], [null, 0.0], [null, 0.0]]
var _scelte: Array[Light3D] = []
var _luci_zona: Array[Light3D] = []
var _t_scelta := 0.0
var _t_elenco := 0.0


func _ready() -> void:
	name = "NebbiaViola"
	_mat = ShaderMaterial.new()
	_mat.shader = NEBBIA
	# (dopo tutto il trasparente della scena: l'acqua e le particelle dietro restano nella nebbia)
	_mat.render_priority = Material.RENDER_PRIORITY_MAX
	_mat.set_shader_parameter(&"rumore_tex", _rumore())
	_mat.set_shader_parameter(&"forza", FORZA)
	_mat.set_shader_parameter(&"lontano", LONTANO)
	_mat.set_shader_parameter(&"oltre", OLTRE)
	_mat.set_shader_parameter(&"cala", CALA)
	_quad = MeshInstance3D.new()
	_quad.name = "Nebbia"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_quad)
	_strato = CanvasLayer.new()
	_strato.name = "ColoreViola"
	_strato.layer = 0
	add_child(_strato)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colore_mat = ShaderMaterial.new()
	colore_mat.shader = COLORE
	r.material = colore_mat
	_strato.add_child(r)
	imposta_luci([])
	quanto = 0.0


## I materiali 3D (per il riscaldamento degli shader; il colore sullo schermo è 2D: lo disegna [method riscalda]).
func materiali() -> Array[Material]:
	return [_mat]


## La qualità (0..2, come la nebbia di Grafica): i passi lungo il raggio.
func imposta_qualita(q: int) -> void:
	_mat.set_shader_parameter(&"passi", PASSI[clampi(q, 0, PASSI.size() - 1)])


## Il giocatore entra in una zona ([param zona]) o ne esce. Subito dopo un salto della camera, o con [param subito]:
## senza dissolvenza, così ripartendo da un checkpoint nella zona la nebbia è già lì.
func zona(z: Node, dentro: bool, subito := false) -> void:
	if dentro and not _zone.has(z):
		_zone.append(z)
		_t_elenco = 0.0
		if &"quota" in z:
			_mat.set_shader_parameter(&"quota", float(z.get(&"quota")))
	elif not dentro:
		_zone.erase(z)
		_t_elenco = 0.0
	if subito or Engine.get_process_frames() - _fotogramma_salto < 10:
		quanto = _obiettivo()


## Vero se il giocatore è in una zona con la nebbia (anche con l'opzione spenta).
func in_zona() -> bool:
	return not _zone.is_empty()


func _obiettivo() -> float:
	return 1.0 if accesa and not _zone.is_empty() else 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var pos := cam.global_position
		if _ultima_pos != Vector3.INF and pos.distance_to(_ultima_pos) > SALTO:
			_fotogramma_salto = Engine.get_process_frames()
			quanto = _obiettivo()
		_ultima_pos = pos
	quanto = move_toward(quanto, _obiettivo(), delta / DURATA)
	if quanto > 0.0 and cam:
		_aggiorna_luci(cam, delta)


## L'alone: ogni [constant OGNI_SCELTA] s le luci giuste; ogni fotogramma i pesi verso quelle (le vecchie si spengono
## in [constant CAMBIO_LUCE] s, le nuove prendono il loro posto e si accendono) e le posizioni (lei si muove).
func _aggiorna_luci(cam: Camera3D, delta: float) -> void:
	_t_elenco -= delta
	if _t_elenco <= 0.0:
		_t_elenco = OGNI_ELENCO
		_luci_zona.clear()
		for z in _zone:
			var radici: Array = z.call(&"radici_luci") if z.has_method(&"radici_luci") else [z]
			for da in radici:
				for l in (da as Node).find_children("*", "Light3D", true, false):
					if not (l is DirectionalLight3D) and not _luci_zona.has(l):
						_luci_zona.append(l as Light3D)
	_t_scelta -= delta
	if _t_scelta <= 0.0:
		_t_scelta = OGNI_SCELTA
		_scelte = _scegli(cam)
	var pos := PackedVector3Array()
	var col := PackedVector3Array()
	for s in _slot:
		var l: Light3D = s[0] if is_instance_valid(s[0]) else null
		if l == null:
			s[0] = null
			s[1] = 0.0
		elif _scelte.has(l):
			s[1] = minf(s[1] + delta / CAMBIO_LUCE, 1.0)
		else:
			s[1] = maxf(s[1] - delta / CAMBIO_LUCE, 0.0)
			if s[1] <= 0.0:
				s[0] = null
	for l in _scelte:
		if _slot.any(func(s): return s[0] == l):
			continue
		for s in _slot:
			if s[0] == null:
				s[0] = l
				s[1] = 0.0
				break
	for s in _slot:
		var l: Light3D = s[0]
		if l == null:
			pos.append(Vector3.ZERO)
			col.append(Vector3.ZERO)
			continue
		# (le lampade che sfarfallano: l'alone segue la luce accesa o spenta)
		var acceso := 1.0 if l.is_visible_in_tree() and l.light_energy > 0.05 else 0.0
		var c := l.light_color
		pos.append(l.global_position)
		col.append(Vector3(c.r, c.g, c.b) * ALONE * float(s[1]) * acceso)
	_mat.set_shader_parameter(&"luci_pos", pos)
	_mat.set_shader_parameter(&"luci_col", col)
	_mat.set_shader_parameter(&"n_luci", 4)


## Le luci per l'alone adesso, fino a 4: prima quelle del gruppo [constant GRUPPO_ALONE], poi le lampade della zona
## più vicine davanti alla camera (quelle già nell'alone valgono un po' più vicine: non saltano di continuo).
func _scegli(cam: Camera3D) -> Array[Light3D]:
	var out: Array[Light3D] = []
	var occhio := cam.global_position
	var avanti := -cam.global_basis.z
	for n in get_tree().get_nodes_in_group(GRUPPO_ALONE):
		var l := n as Light3D
		if l and l.is_visible_in_tree() and l.light_energy > 0.0 and not cam.is_position_behind(l.global_position) \
				and l.global_position.distance_to(occhio) < RAGGIO_LUCI and out.size() < 4:
			out.append(l)
	var lampade: Array = []
	for l in _luci_zona:
		if not is_instance_valid(l) or out.has(l) or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		var d := l.global_position - occhio
		var dist := d.length()
		if dist > RAGGIO_LUCI or d.normalized().dot(avanti) < 0.3:
			continue
		if _slot.any(func(s): return s[0] == l):
			dist *= 0.8
		lampade.append([dist, l])
	lampade.sort_custom(func(a, b): return a[0] < b[0])
	for x in lampade:
		if out.size() >= 4:
			break
		out.append(x[1])
	return out


## Le lampade a mano, per le prove fuori dal gioco: [posizione, colore, forza] (fino a 4). Nel gioco le sceglie da sé.
func imposta_luci(luci: Array) -> void:
	var pos := PackedVector3Array()
	var col := PackedVector3Array()
	for l in luci.slice(0, 4):
		pos.append(l[0])
		var c: Color = l[1]
		col.append(Vector3(c.r, c.g, c.b) * float(l[2]))
	while pos.size() < 4:
		pos.append(Vector3.ZERO)
		col.append(Vector3.ZERO)
	_mat.set_shader_parameter(&"luci_pos", pos)
	_mat.set_shader_parameter(&"luci_col", col)
	_mat.set_shader_parameter(&"n_luci", 4)


## Disegna una volta la nebbia e il colore in [param sv] (il riscaldamento degli shader: le loro pipeline, sullo
## stesso formato dello schermo, prima di entrare in una zona). Aspetta [param fotogrammi] fotogrammi.
func riscalda(sv: SubViewport, fotogrammi := 2) -> void:
	var q := MeshInstance3D.new()
	q.mesh = _quad.mesh
	q.material_override = _mat.duplicate()
	(q.material_override as ShaderMaterial).set_shader_parameter(&"quanto", 1.0)
	q.extra_cull_margin = 16384.0
	sv.add_child(q)
	var c := CanvasLayer.new()
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.material = colore_mat
	c.add_child(r)
	sv.add_child(c)
	for i in fotogrammi:
		await RenderingServer.frame_post_draw
	q.queue_free()
	c.queue_free()


## Il rumore della nebbia: 256 x 256 valori a caso, e nel verde gli stessi spostati di (37, 17), come nell'originale.
static func _rumore() -> ImageTexture:
	var n := 256
	var r := PackedByteArray()
	r.resize(n * n)
	var s := 1234567
	for i in r.size():
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		r[i] = s >> 24
	var d := PackedByteArray()
	d.resize(n * n * 4)
	for y in n:
		for x in n:
			var i := (y * n + x) * 4
			d[i] = r[y * n + x]
			d[i + 1] = r[((y - 17 + n) % n) * n + ((x - 37 + n) % n)]
			d[i + 3] = 255
	return ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, d))

class_name ObloLei
extends Node3D
## Un oblò grosso nel muro con dietro una vasca allagata, e lei che ti guarda attaccata al vetro (richiesta
## dell'utente del 24 ottobre sera, GDD "Jilly dietro gli oblò": "attraverso dei grossi oblò da cui proviene la sua
## luce luminescente, si possa vedere Jilly che ci osserva attaccata al vetro, durante il percorso"). Un pezzo solo,
## lo stesso nei tre corridoi della Risalita e nella torre.
##
## Il nodo sta al centro dell'oblò, sulla faccia del muro dalla parte di chi guarda; +Z è la normale verso il
## corridoio, la vasca sta verso -Z. Il muro intorno lo fa chi mette l'oblò, con un buco quadrato di
## [constant PIASTRA] metri al centro (vedi [method buco]); l'oblò ci mette la piastra d'acciaio rivettata, a filo
## delle due facce del muro, col bordo d'ottone e il vetro, e dietro la vasca: una cisterna dello scafo piena d'acqua
## torbida e scura (pareti di lamiera, tre veli d'acqua sempre più scuri verso il fondo, niente luce sua: la luce
## rosa è quella di lei).
##
## Lei (LeiOblo di mascotte: la posa, l'occhio che segue, la luce rosa con le ombre, il distacco, i tentacoli fuori dal
## vetro e dalla vasca con le [method forme]) compare una volta sola; il modello c'è solo mentre si vede:
## - solo al buio dopo la sala pompe ([member GameState.luci] BLACKOUT) e col giocatore nella [member zona];
## - quando il vetro non si vede (fuori dal cono di [member angolo_fuori] gradi o dietro un muro): mai sotto gli occhi;
## - resta finché il giocatore non l'ha vista bene (il vetro entro [member angolo_vista] gradi per
##   [member tempo_vista] secondi), poi si stacca piano e sparisce nel buio dell'acqua quando lui guarda via per
##   [member tempo_via] secondi, o quando si avvicina sotto [member vicino] metri (anche prima di averla vista).
##   "Dovrebbe restare finché non la vedi bene o ti avvicini";
## - se il giocatore se ne va senza averla vista, lei se ne va quando non la vede (e torna la volta dopo);
## - sparita, l'oblò resta vuoto: lo stato si salva coi checkpoint (gruppo "persist").

signal comparsa
signal vista
signal staccata
signal finita

enum Stato {ATTESA, PRONTA, VISTA, VIA, FINITA}

## Lato della piastra quadrata (e del buco nel muro), raggio del vetro, del bordo d'ottone e dei rivetti.
const PIASTRA := 1.9
const RAGGIO_VETRO := 0.6
const RAGGIO_BORDO := 0.7
const RAGGIO_RIVETTI := 0.82
const RIVETTI := 24
## Di quanto la faccia della vasca resta dietro il retro del muro (così non si sovrappone alla sua faccia).
const STACCO_VASCA := 0.02
## Lo spessore delle forme della vasca per i tentacoli (fuori dall'interno).
const FORMA := 0.3

## La posa di lei: "schiacciata", "sbircia" o "capovolta" (le fa mascotte).
@export var posa := "schiacciata"
## Per "sbircia": da che lato del vetro, visto dal corridoio (1 a destra, -1 a sinistra).
@export var lato_sbircia := 1.0
## Dove deve stare il giocatore perché lei compaia (nel mondo). Vuota: entro [member raggio] dal vetro.
@export var zona := AABB()
@export var raggio := 10.0
## Lo spessore del muro (la piastra lo riempie, il vetro sta a filo del retro, dalla parte dell'acqua).
@export var spessore_muro := 0.2
## La vasca dietro: larga (lungo il muro), profonda (dietro il muro), quanto scende sotto il centro e quanto sale.
@export var vasca_larga := 3.2
@export var vasca_fonda := 2.7
@export var vasca_sotto := 5.2
@export var vasca_sopra := 1.8
## Di quanto il centro della vasca è spostato di lato rispetto all'oblò (lungo il muro, +X del nodo).
@export var vasca_spostata := 0.0
## Sotto questa distanza dal vetro lei si stacca.
@export var vicino := 1.6
## Il vetro "si vede" entro questo angolo dal centro della vista, fino a [member vista_max] metri.
@export var angolo_vista := 22.0
@export var vista_max := 12.0
## Lei compare solo col vetro oltre questo angolo dal centro della vista (o dietro un muro).
@export var angolo_fuori := 40.0
@export var tempo_vista := 1.2
## Dopo averla vista: il vetro oltre [member angolo_via] gradi per [member tempo_via] secondi e lei va via.
@export var angolo_via := 35.0
@export var tempo_via := 0.35
## Falso: niente lei (per esempio prima del blackout lo decide chi mette l'oblò con [member pronto]).
@export var attivo := true

var stato := Stato.ATTESA
## La lei che sta dietro il vetro, se c'è.
var lei: LeiOblo
var _t_vista := 0.0
var _t_via := 0.0
var _corpo: StaticBody3D


func _ready() -> void:
	add_to_group(&"persist")
	_costruisci()


## Il buco quadrato da lasciare nel muro (nel sistema del nodo, sul piano del muro): [centro, mezzo lato].
static func buco() -> Array:
	return [Vector2.ZERO, Vector2.ONE * PIASTRA * 0.5]


## Il centro del vetro dalla parte dell'acqua e la normale verso chi guarda, nel mondo.
func centro_vetro() -> Vector3:
	return global_transform * Vector3(0, 0, -spessore_muro)


func normale() -> Vector3:
	return global_basis.z.normalized()


## Le forme della vasca per i tentacoli di lei (MorbidezzaLei.aggiungi_scatola): [trasformazione nel mondo, mezze
## misure]. Le cinque pareti, spesse [constant FORMA], e il muro col vetro.
func forme() -> Array:
	var out := []
	var l := vasca_larga * 0.5
	var sx := vasca_spostata
	var z0 := -spessore_muro - STACCO_VASCA
	var z1 := z0 - vasca_fonda
	var y0 := -vasca_sotto
	var y1 := vasca_sopra
	var f := FORMA
	var scatole := [
		[Vector3(sx, (y0 + y1) * 0.5, z1 - f * 0.5), Vector3(l + f, (y1 - y0) * 0.5 + f, f * 0.5)],          # fondo
		[Vector3(sx - l - f * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(f * 0.5, (y1 - y0) * 0.5 + f, (z0 - z1) * 0.5)],
		[Vector3(sx + l + f * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(f * 0.5, (y1 - y0) * 0.5 + f, (z0 - z1) * 0.5)],
		[Vector3(sx, y0 - f * 0.5, (z0 + z1) * 0.5), Vector3(l, f * 0.5, (z0 - z1) * 0.5)],                     # sotto
		[Vector3(sx, y1 + f * 0.5, (z0 + z1) * 0.5), Vector3(l, f * 0.5, (z0 - z1) * 0.5)],                     # sopra
		[Vector3(sx, (y0 + y1) * 0.5, z0 * 0.5), Vector3(l + f, (y1 - y0) * 0.5 + f, -z0 * 0.5)],               # muro e vetro
	]
	for s in scatole:
		out.append([global_transform * Transform3D(Basis.IDENTITY, s[0]), s[1] as Vector3])
	return out


# --- come è fatto ------------------------------------------------------------------------------------------------

func _costruisci() -> void:
	var acciaio := _mat_lamiera(Color(0.42, 0.45, 0.46), 1.2)
	# la piastra rivettata, a filo delle due facce del muro, col buco tondo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_piastra(st, RAGGIO_BORDO - 0.02)
	for k in RIVETTI:
		var a := TAU * float(k) / RIVETTI
		_rivetto(st, Vector3(cos(a) * RAGGIO_RIVETTI, sin(a) * RAGGIO_RIVETTI, 0.0), 0.016)
	# e i rivetti lungo i lati (la piastra è chiodata al muro)
	for k in 7:
		var u := -PIASTRA * 0.5 + 0.08 + (PIASTRA - 0.16) * float(k) / 6.0
		for v in [-PIASTRA * 0.5 + 0.08, PIASTRA * 0.5 - 0.08]:
			_rivetto(st, Vector3(u, v, 0.0), 0.014)
			if k > 0 and k < 6:
				_rivetto(st, Vector3(v, u, 0.0), 0.014)
	st.generate_normals()
	var piastra := MeshInstance3D.new()
	piastra.name = "struttura_piastra_oblo"
	piastra.mesh = st.commit()
	piastra.material_override = acciaio
	add_child(piastra)
	# il bordo d'ottone: un anello nel buco, con la faccia davanti 1 cm fuori dal muro
	var bordo := MeshInstance3D.new()
	bordo.name = "BordoOttone"
	var tm := TorusMesh.new()
	tm.inner_radius = RAGGIO_VETRO
	tm.outer_radius = RAGGIO_BORDO
	tm.rings = 48
	tm.ring_segments = 12
	bordo.mesh = tm
	bordo.rotation_degrees.x = 90.0
	bordo.position.z = 0.01 - (RAGGIO_BORDO - RAGGIO_VETRO) * 0.5
	bordo.material_override = _mat_ottone()
	add_child(bordo)
	# il vetro, a filo del retro del muro (dalla parte dell'acqua), un po' dentro la piastra tutto intorno
	var vetro := MeshInstance3D.new()
	vetro.name = "Vetro"
	var cm := CylinderMesh.new()
	cm.top_radius = RAGGIO_BORDO - 0.02
	cm.bottom_radius = RAGGIO_BORDO - 0.02
	cm.height = 0.03
	cm.radial_segments = 48
	cm.rings = 1
	vetro.mesh = cm
	vetro.rotation_degrees.x = 90.0
	vetro.position.z = -spessore_muro + 0.015
	vetro.material_override = _mat_vetro()
	vetro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # la luce rosa di lei passa
	add_child(vetro)
	# il corpo: piastra e vetro chiudono il buco del muro
	_corpo = StaticBody3D.new()
	_corpo.name = "Corpo"
	_corpo.collision_layer = Layers.WORLD
	add_child(_corpo)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(PIASTRA, PIASTRA, spessore_muro)
	cs.shape = bs
	cs.position.z = -spessore_muro * 0.5
	_corpo.add_child(cs)
	_vasca()


## La piastra quadrata col buco tondo di raggio [param r]: le due facce (davanti a z 0, dietro a -spessore), il
## bordo del buco e i quattro lati.
func _piastra(st: SurfaceTool, r: float) -> void:
	var n := 48
	var h := PIASTRA * 0.5
	var dz := Vector3(0, 0, -spessore_muro)
	for k in n:
		var a0 := TAU * float(k) / n
		var a1 := TAU * float(k + 1) / n
		var c0 := Vector3(cos(a0), sin(a0), 0.0) * r
		var c1 := Vector3(cos(a1), sin(a1), 0.0) * r
		var q0 := _sul_quadrato(a0, h)
		var q1 := _sul_quadrato(a1, h)
		_quad(st, c0, q0, q1, c1, Vector3.BACK)                      # davanti
		_quad(st, c0 + dz, q0 + dz, q1 + dz, c1 + dz, Vector3.FORWARD)  # dietro
		_quad(st, c0, c1, c1 + dz, c0 + dz, -(c0 + c1))                 # il bordo del buco, verso il centro
	var ang := [Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)]
	for k in 4:
		var a: Vector3 = ang[k]
		var b: Vector3 = ang[(k + 1) % 4]
		_quad(st, a, b, b + dz, a + dz, a + b)                          # i lati, dentro il muro


## Il punto del bordo del quadrato di mezzo lato [param h] nella direzione [param a].
static func _sul_quadrato(a: float, h: float) -> Vector3:
	var d := Vector2(cos(a), sin(a))
	var m := maxf(absf(d.x), absf(d.y))
	return Vector3(d.x / m * h, d.y / m * h, 0.0)


## Un triangolo che si vede da [param verso] (Godot: davanti in senso orario).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, verso: Vector3) -> void:
	st.add_vertex(a)
	if (b - a).cross(c - a).dot(verso) > 0.0:
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(b)
		st.add_vertex(c)


## Un rivetto: una cupoletta di raggio [param r] sulla faccia davanti, che sporge di 0,6 r.
func _rivetto(st: SurfaceTool, c: Vector3, r: float) -> void:
	var seg := 8
	var su := r * 0.6
	for k in seg:
		var a0 := TAU * float(k) / seg
		var a1 := TAU * float(k + 1) / seg
		var p0 := c + Vector3(cos(a0), sin(a0), 0.0) * r
		var p1 := c + Vector3(cos(a1), sin(a1), 0.0) * r
		var m0 := c + Vector3(cos(a0), sin(a0), 0.0) * r * 0.6 + Vector3(0, 0, su * 0.8)
		var m1 := c + Vector3(cos(a1), sin(a1), 0.0) * r * 0.6 + Vector3(0, 0, su * 0.8)
		var cima := c + Vector3(0, 0, su)
		_quad(st, p0, p1, m1, m0, (p0 + p1) * 0.5 - c + Vector3(0, 0, r * 0.3))
		_tri(st, m0, m1, cima, Vector3.BACK)


## La vasca dietro il muro: l'interno di una cisterna di lamiera (sei facce che guardano dentro, quella davanti col
## buco della piastra) e tre veli d'acqua torbida paralleli al vetro, sempre più scuri verso il fondo.
func _vasca() -> void:
	var l := vasca_larga * 0.5
	var xa := vasca_spostata - l
	var xb := vasca_spostata + l
	var z0 := -spessore_muro - STACCO_VASCA
	var z1 := z0 - vasca_fonda
	var y0 := -vasca_sotto
	var y1 := vasca_sopra
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(xa, y0, z1), Vector3(xb, y0, z1), Vector3(xb, y1, z1), Vector3(xa, y1, z1),
			Vector3(xa, y0, z0), Vector3(xb, y0, z0), Vector3(xb, y1, z0), Vector3(xa, y1, z0)]
	# (ogni faccia si vede da dentro)
	var centro := Vector3(vasca_spostata, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	for f in [[0, 3, 2, 1], [0, 4, 7, 3], [1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2]]:
		var q: Array = [p[f[0]], p[f[1]], p[f[2]], p[f[3]]]
		_quad(st, q[0], q[1], q[2], q[3], centro - (q[0] + q[2]) * 0.5)
	# davanti, intorno al buco della piastra (si guarda da -Z)
	var h := PIASTRA * 0.5
	for r in [[xa, -h, y0, y1], [h, xb, y0, y1], [-h, h, y0, -h], [-h, h, h, y1]]:
		_quad(st, Vector3(r[0], r[2], z0), Vector3(r[1], r[2], z0), Vector3(r[1], r[3], z0), Vector3(r[0], r[3], z0), Vector3.FORWARD)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "struttura_vasca_oblo"
	mi.mesh = st.commit()
	mi.material_override = _mat_lamiera(Color(0.16, 0.2, 0.2), 1.6)
	add_child(mi)
	# l'acqua torbida: veli che si vedono dal vetro (una "superficie d'acqua" per i controlli)
	var acqua := Node3D.new()
	acqua.name = "AcquaTorbida"
	add_child(acqua)
	var veli := [0.45, 1.05, 1.75]
	for k in veli.size():
		var v := MeshInstance3D.new()
		v.name = "Velo%d" % k
		var qm := QuadMesh.new()
		qm.size = Vector2(vasca_larga - 0.02, vasca_sotto + vasca_sopra - 0.02)
		v.mesh = qm
		v.position = Vector3(vasca_spostata, (y0 + y1) * 0.5, z0 - float(veli[k]))
		v.material_override = _mat_velo(0.22 + 0.08 * k)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		acqua.add_child(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, verso: Vector3) -> void:
	_tri(st, a, b, c, verso)
	_tri(st, a, c, d, verso)


static var _materiali := {}


static func _mat_lamiera(tinta: Color, metri: float) -> StandardMaterial3D:
	var chiave := "lamiera_%s_%s" % [tinta.to_html(), metri]
	if not _materiali.has(chiave):
		const T := "res://assets/ambienti_tecnici/texture/"
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(T + "MetalPlates013_Color.jpg")
		m.albedo_color = tinta
		m.normal_enabled = true
		m.normal_texture = load(T + "MetalPlates013_NormalGL.jpg")
		m.roughness_texture = load(T + "MetalPlates013_Metalness-MetalPlates013_Roughness.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic_texture = m.roughness_texture
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.metallic = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / metri
		_materiali[chiave] = m
	return _materiali[chiave]


static func _mat_ottone() -> StandardMaterial3D:
	if not _materiali.has("ottone"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.42, 0.2)
		m.metallic = 0.85
		m.roughness = 0.35
		_materiali["ottone"] = m
	return _materiali["ottone"]


static func _mat_vetro() -> StandardMaterial3D:
	if not _materiali.has("vetro"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.6, 0.6, 0.16)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiali["vetro"] = m
	return _materiali["vetro"]


static func _mat_velo(alfa: float) -> StandardMaterial3D:
	var chiave := "velo_%s" % alfa
	if not _materiali.has(chiave):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.03, 0.09, 0.09, alfa)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_materiali[chiave] = m
	return _materiali[chiave]


## I materiali dell'oblò (per il riscaldamento: si compilano prima, dove si costruisce la sala).
static func materiali() -> Array:
	return [_mat_lamiera(Color(0.42, 0.45, 0.46), 1.2), _mat_lamiera(Color(0.16, 0.2, 0.2), 1.6), _mat_ottone(),
			_mat_vetro(), _mat_velo(0.22), _mat_velo(0.3), _mat_velo(0.38)]


# --- lei -----------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if stato == Stato.FINITA or stato == Stato.VIA:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p) or p.camera == null:
		return
	var cam := p.camera
	var dentro := _dentro(p.global_position)
	var d := cam.global_position.distance_to(_davanti())
	var ang := _angolo(cam)
	var libera := _vista_libera(cam)
	match stato:
		Stato.ATTESA:
			if attivo and dentro and GameState.luci == GameState.Luci.BLACKOUT and (ang > angolo_fuori or not libera):
				_mostra()
		Stato.PRONTA:
			if libera and ang < angolo_vista and d < vista_max:
				_t_vista += delta
			else:
				_t_vista = maxf(0.0, _t_vista - delta * 0.5)
			if d < vicino:
				_stacca()
			elif _t_vista >= tempo_vista:
				stato = Stato.VISTA
				vista.emit()
			elif not dentro and (ang > angolo_fuori or not libera):
				# se n'è andato senza vederla: via senza farsi vedere, e la volta dopo ricompare
				_togli_lei()
				stato = Stato.ATTESA
		Stato.VISTA:
			if d < vicino:
				_stacca()
				return
			if ang > angolo_via or not libera:
				_t_via += delta
				if _t_via >= tempo_via:
					_stacca()
			else:
				_t_via = 0.0


func _dentro(pos: Vector3) -> bool:
	if zona.size != Vector3.ZERO:
		return zona.has_point(pos)
	return pos.distance_to(global_position) < raggio


## Il punto davanti al vetro, dalla parte di chi guarda (dove si misura se lo si vede).
func _davanti() -> Vector3:
	return global_transform * Vector3(0, 0, 0.05)


## L'angolo (gradi) fra dove guarda la camera e il vetro; 180 se la camera sta dietro il muro.
func _angolo(cam: Camera3D) -> float:
	var v := _davanti() - cam.global_position
	if v.dot(normale()) > -0.05:
		return 180.0
	return rad_to_deg((-cam.global_basis.z).angle_to(v))


## Vero se fra la camera e il vetro non c'è niente.
func _vista_libera(cam: Camera3D) -> bool:
	var spazio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, _davanti(), Layers.WORLD)
	var p := GameState.player
	if p:
		q.exclude = [p.get_rid()]
	return spazio.intersect_ray(q).is_empty()


func _mostra() -> void:
	if lei == null:
		lei = LeiOblo.new()
		lei.name = "Lei"
		lei.lato_sbircia = 1 if lato_sbircia >= 0.0 else -1
		add_child(lei)
		lei.sparita.connect(_sparita)
		lei.aggiungi_forme(forme())
	lei.mostra(centro_vetro(), normale(), posa)
	_t_vista = 0.0
	_t_via = 0.0
	stato = Stato.PRONTA
	comparsa.emit()


## Lei va via adesso, col suo distacco lento, se è dietro il vetro (per chi la vuole altrove: nella torre prima che
## parta l'inseguimento); poi l'oblò resta vuoto. Se non è ancora comparsa, non compare più.
func via() -> void:
	if stato == Stato.PRONTA or stato == Stato.VISTA:
		_stacca()
	elif stato == Stato.ATTESA:
		stato = Stato.FINITA


func _stacca() -> void:
	stato = Stato.VIA
	staccata.emit()
	if lei:
		lei.stacca()
	else:
		_sparita()


func _sparita() -> void:
	_togli_lei()
	stato = Stato.FINITA
	finita.emit()


func _togli_lei() -> void:
	if lei and is_instance_valid(lei):
		lei.queue_free()
	lei = null


func save_state() -> Dictionary:
	return {"finito": stato == Stato.FINITA}


func load_state(s: Dictionary) -> void:
	if bool(s.get("finito", false)):
		_togli_lei()
		stato = Stato.FINITA
	elif stato != Stato.ATTESA:
		# ripartendo da prima che sparisse: di nuovo in attesa, senza lei
		_togli_lei()
		stato = Stato.ATTESA

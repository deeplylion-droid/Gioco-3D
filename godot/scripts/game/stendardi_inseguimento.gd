class_name StendardiInseguimento
extends Node3D
## Gli stendardi dei bambini nella sala delle condotte (nota dell'utente del 6 novembre: «Lascia le vasche uguali ma
## aggiungi degli stendardi giganti appesi nel vuoto dietro, nella distanza ... come s'è fossero lenzuoli appesi e
## colorati dai bambini»): lenzuoli vecchi del club dei bambini della nave, colorati a pastello (niente immagini fatte
## con l'IA), fermati con le mollette a un bastone che pende da due corde legate alle travi del soffitto.
## La geometria e le posizioni vengono da assets_src/stendardi/stendardi.py (stendardi.glb, coordinate della sala come
## le altre GLB dell'inseguimento), le texture da assets_src/stendardi/teli.py. Lontani e in alto: niente collisioni.

const DIR := "res://assets/ambiente/inseguimento/stendardi/"
const GLB := DIR + "stendardi.glb"
## Un filo di luce propria dei segni a pastello (i «pastelli fosforescenti» già approvati per il disegno guida dei
## giocattoli, che sta a 0,12): solo i disegni, la stoffa no. 0 = nessuna: con le lampade appese della sala accanto
## si vedono già (scatti del 6 novembre; a 0,12 la differenza quasi non si vede). Si cambia prima che la sala si
## costruisca: i materiali sono condivisi.
static var luce := 0.0

static var _materiali := {}


## I file che la sala carica nel thread prima di costruirsi (SalaInseguimento.risorse).
static func risorse() -> Array:
	var out: Array = [GLB]
	for k in range(1, 5):
		out.append(DIR + "stendardo_%d.png" % k)
		if luce > 0.0:
			out.append(DIR + "stendardo_%d_luce.png" % k)
	return out


## Il materiale di un lenzuolo: la stoffa con gli strappi nell'alfa (tagliati netti: niente trasparenze da ordinare),
## visibile dai due lati (il retro è la stessa stoffa, girata), opaca e ruvida come il cotone.
static func materiale(nome: String) -> StandardMaterial3D:
	if _materiali.has(nome):
		return _materiali[nome]
	var m := StandardMaterial3D.new()
	m.resource_name = nome
	m.albedo_texture = load(DIR + nome + ".png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if luce > 0.0:
		m.emission_enabled = true
		m.emission_texture = load(DIR + nome + "_luce.png")
		m.emission_energy_multiplier = luce
	_materiali[nome] = m
	return m


## Per il riscaldamento degli shader (SalaTorre.materiali_campione): un lenzuolo, con gli stessi interruttori.
static func campione() -> Material:
	return materiale("stendardo_1")


static func _semplice(colore: Color, ruvido: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = ruvido
	return m


var _glb: Node3D
var _corda: StandardMaterial3D
var _bastone: StandardMaterial3D
var _molletta: StandardMaterial3D
var _ferro: StandardMaterial3D


## La costruzione a pezzi (SalaInseguimento._passi): un passo prepara (la GLB, già caricata dal thread, istanziata con
## tutto nascosto, e i materiali semplici), poi un passo per stendardo, che mette i materiali e lo mostra. In un passo
## solo poteva fare un fotogramma lungo (CI del 6 novembre, test_attesa_zone: 150 ms).
static func passi(sala: Node3D) -> Array:
	var s := StendardiInseguimento.new()
	var out: Array = [func(): sala.add_child(s); s._prepara()]
	for k in range(1, 5):
		out.append(func(): s._stendardo(k))
	return out


func _ready() -> void:
	name = "Stendardi"


func _prepara() -> void:
	var scena := load(GLB) as PackedScene
	if scena == null:
		return
	_glb = scena.instantiate() as Node3D
	for n in _glb.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = false
	add_child(_glb)
	_corda = _semplice(Color(0.5, 0.45, 0.36), 1.0)
	_bastone = _semplice(Color(0.78, 0.38, 0.12), 0.6)
	_molletta = _semplice(Color(0.28, 0.5, 0.78), 0.55)
	# (il ferro del golfare e della molla: stesse superfici nella mesh della corda e della molletta)
	_ferro = _semplice(Color(0.45, 0.45, 0.47), 0.4)
	_ferro.metallic = 0.8


## Lo stendardo [k] (1-4): il lenzuolo, la piega, il bastone, le corde e le mollette.
func _stendardo(k: int) -> void:
	if _glb == null:
		return
	var st := "stendardo_%d" % k
	for n in _glb.find_children(st + "*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nome := String(mi.name)
		if nome != st and not nome.begins_with(st + "_"):
			continue
		if nome == st:
			mi.material_override = materiale(nome)
			mi.add_to_group(&"stendardo")
		elif nome.ends_with("_risvolto"):
			# la stoffa ripiegata sopra il bastone: lo stesso lenzuolo
			mi.material_override = materiale(st)
		elif "_corda_" in nome or "_nodo_" in nome:
			_per_superficie(mi, _corda, _ferro, "M_golfare")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif "_bastone" in nome:
			mi.material_override = _bastone
		elif "_molletta" in nome:
			_per_superficie(mi, _molletta, _ferro, "M_molla")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = true


## Una mesh fatta di più pezzi: il materiale [base] dappertutto, tranne la superficie col materiale [nome_ferro] della GLB.
static func _per_superficie(mi: MeshInstance3D, base: Material, ferro: Material, nome_ferro: String) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		var e_ferro := m != null and String(m.resource_name).begins_with(nome_ferro)
		mi.set_surface_override_material(i, ferro if e_ferro else base)

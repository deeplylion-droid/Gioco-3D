class_name MaterialiInterni
extends RefCounted
## Materiali degli interni: sostituisce i materiali importati dai glTF (stessi nomi dei materiali
## di Blender) con gli shader che non fanno vedere la ripetizione delle texture:
## shaders/interni/parete.gdshader (vernice intera, scrostata solo in punti precisi) e
## shaders/interni/piastrelle.gdshader (variazione per piastrella, fughe in rilievo, chiazze bagnate).
## Mette anche i decal (macchie, colature di ruggine, crepe) nei punti scelti.

const TEX := "res://assets/ambienti_interni/texture/"
const SHT := "res://assets/ambienti_interni/shader_tex/"
const PARETE := preload("res://shaders/interni/parete.gdshader")
const PIASTRELLE := preload("res://shaders/interni/piastrelle.gdshader")

## nome del materiale importato -> [shader, parametri]
const PARETI := {
	"lamiera_crema": {"colore": Color(0.55, 0.52, 0.44), "scrostata": "lamiera_crema", "scrostatura": 0.22, "lucido": 0.42},
	"lamiera_petrolio": {"colore": Color(0.13, 0.24, 0.23), "scrostata": "lamiera_petrolio", "scrostatura": 0.3, "lucido": 0.4, "fascia": 0.6},
	"soffitto_lamiera": {"colore": Color(0.40, 0.39, 0.36), "scrostata": "soffitto_lamiera", "scrostatura": 0.3, "lucido": 0.55, "tubi": 99.0},
}
const PIASTRELLE_MAT := {
	"piastrelle_pavimento": {"per_lato": 8.0, "bagnato": 0.5, "alt": "piastrelle_pavimento"},
	"piastrelle_doccia": {"per_lato": 0.0, "bagnato": 0.35, "alt": "piastrelle_doccia"},
	"piastrelle_verdi": {"per_lato": 0.0, "bagnato": 0.2, "alt": "piastrelle_verdi"},
}

static var _cache := {}


static func applica(radice: Node) -> int:
	var n := 0
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var m := m3.mesh.surface_get_material(i)
			if m == null:
				continue
			var nuovo := materiale(m.resource_name)
			if nuovo:
				m3.set_surface_override_material(i, nuovo)
				n += 1
	return n


static func materiale(nome: String) -> Material:
	if _cache.has(nome):
		return _cache[nome]
	var sm: ShaderMaterial = null
	if PARETI.has(nome):
		var d: Dictionary = PARETI[nome]
		sm = ShaderMaterial.new()
		sm.shader = PARETE
		sm.set_shader_parameter("colore_vernice", d["colore"])
		sm.set_shader_parameter("lucidita_vernice", d["lucido"])
		sm.set_shader_parameter("scrostatura", d["scrostatura"])
		sm.set_shader_parameter("fascia_bassa", d.get("fascia", 0.45))
		sm.set_shader_parameter("quota_tubi", d.get("tubi", 2.25))
		sm.set_shader_parameter("scrostata_albedo", load(TEX + d["scrostata"] + "_col.jpg"))
		sm.set_shader_parameter("scrostata_normal", load(TEX + d["scrostata"] + "_nrm.jpg"))
		sm.set_shader_parameter("scrostata_rough", load(TEX + d["scrostata"] + "_met-" + d["scrostata"] + "_rgh.jpg"))
		sm.set_shader_parameter("lamiera_normal", load(SHT + "lamiera_nrm.jpg"))
		sm.set_shader_parameter("colature", load(SHT + "colature.png"))
		sm.set_shader_parameter("rumore", load(SHT + "rumore.png"))
	elif PIASTRELLE_MAT.has(nome):
		var d: Dictionary = PIASTRELLE_MAT[nome]
		sm = ShaderMaterial.new()
		sm.shader = PIASTRELLE
		sm.set_shader_parameter("albedo_tex", load(TEX + nome + "_col.jpg"))
		sm.set_shader_parameter("normal_tex", load(TEX + nome + "_nrm.jpg"))
		sm.set_shader_parameter("rough_tex", load(TEX + nome + "_met-" + nome + "_rgh.jpg"))
		sm.set_shader_parameter("altezza_tex", load(SHT + d["alt"] + "_alt.png"))
		sm.set_shader_parameter("rumore", load(SHT + "rumore.png"))
		sm.set_shader_parameter("piastrelle_per_lato", d["per_lato"])
		sm.set_shader_parameter("bagnato", d["bagnato"])
	_cache[nome] = sm
	return sm


## Quante colature di ruggine si sono chieste dall'inizio della scena (si mette una su due).
static var ruggine_contate := 0


## Decal in coordinate locali della scena degli interni (come i glTF). normale = verso la stanza.
static func decal(radice: Node3D, tipo: String, pos: Vector3, normale: Vector3, w: float, h: float, alfa := 0.85, rot := 0.0) -> Decal:
	if tipo == "ruggine":
		# una colatura di ruggine su due (muri più calmi, proposta texture_muri del 23 ottobre); il conto riparte con
		# ogni scena (metti_decal, tecnici._decal)
		ruggine_contate += 1
		if ruggine_contate % 2 == 0:
			return null
	var d := Decal.new()
	d.texture_albedo = load(SHT + "decal_" + tipo + ".png")
	d.size = Vector3(w, 0.3, h)
	d.albedo_mix = alfa
	d.cull_mask = 1
	radice.add_child(d)
	d.position = pos
	# il decal proietta lungo il suo -Y: Y del decal = normale della superficie
	d.basis = _base(normale, rot)
	return d


static func _base(su: Vector3, rot: float) -> Basis:
	# Y del decal = normale della superficie; per le pareti la X resta orizzontale
	var y := su.normalized()
	var ref := Vector3.UP if absf(y.y) < 0.9 else Vector3(0, 0, -1)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z).rotated(y, rot)


## I decal del pezzo campione: corridoio, zona del tornello e stanzino (posizioni scelte a mano).
static func metti_decal(radice: Node3D) -> void:
	ruggine_contate = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# colature di ruggine sotto i tubi del corridoio (parete nord, z = -2,6)
	for x in [2.1, 5.3, 9.7, 12.4, 16.2, 19.9]:
		decal(radice, "ruggine", Vector3(x + rng.randf_range(-0.4, 0.4), 1.75, -2.58), Vector3(0, 0, 1), 0.6, 1.3, 0.8)
	# e sulla parete sud (z = 0), lontano dal cartellone
	for x in [3.4, 8.1, 11.2, 19.4]:
		decal(radice, "ruggine", Vector3(x, 1.8, -0.02), Vector3(0, 0, -1), 0.5, 1.1, 0.7)
	# crepe e macchie basse
	for x in [4.6, 10.6, 18.2]:
		decal(radice, "crepa", Vector3(x, 0.45, -2.58), Vector3(0, 0, 1), 0.9, 0.9, 0.9, rng.randf_range(0, TAU))
	for p in [Vector3(6.0, 0.0, -1.5), Vector3(15.3, 0.0, -1.0), Vector3(20.1, 0.0, -2.1)]:
		decal(radice, "macchia", p, Vector3.UP, 1.4, 1.4, 0.6, rng.randf_range(0, TAU))
	# macchie d'acqua sul soffitto del corridoio
	for x in [7.0, 13.6, 18.8]:
		decal(radice, "macchia", Vector3(x, 2.68, -1.3), Vector3.DOWN, 1.6, 1.6, 0.7, rng.randf_range(0, TAU))
	# corridoio lava-piedi e gabbiotto
	for z in [-12.2, -15.0, -18.6]:
		decal(radice, "ruggine", Vector3(8.62, 1.9, z), Vector3(1, 0, 0), 0.5, 1.0, 0.6)
	decal(radice, "crepa", Vector3(10.78, 0.6, -17.8), Vector3(-1, 0, 0), 0.8, 0.8, 0.9, 1.2)
	decal(radice, "macchia", Vector3(9.6, 2.68, -17.0), Vector3.DOWN, 1.4, 1.4, 0.7)
	# stanzino
	decal(radice, "ruggine", Vector3(15.18, 1.6, -7.0), Vector3(-1, 0, 0), 0.5, 1.2, 0.6)
	decal(radice, "macchia", Vector3(13.0, 2.58, -9.4), Vector3.DOWN, 1.5, 1.5, 0.75)
	decal(radice, "crepa", Vector3(11.9, 0.5, -10.58), Vector3(0, 0, 1), 0.7, 0.7, 0.9, 2.0)

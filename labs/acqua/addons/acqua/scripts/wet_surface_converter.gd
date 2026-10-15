class_name WetSurfaceConverter
extends Node
## Rende "bagnabili" i modelli gia' fatti (per esempio i GLB della sala): all'avvio sostituisce i
## materiali StandardMaterial3D delle mesh scelte con wet_surface.gdshader, tenendo le stesse
## texture (colore, normal map, ORM), i colori dei vertici e le UV. Cosi' quelle superfici
## ricevono caustiche sott'acqua, banda bagnata sopra il pelo dell'acqua, pozzanghere con i cerchi
## delle gocce e zone umide.
##
## Uso: aggiungi il nodo nella scena, metti in `roots` i nodi da cui partire (per esempio le
## istanze dei GLB) e scegli quali mesh convertire con `name_filter` (parti del nome, vuoto = tutte).
## I materiali trasparenti o con alpha scissor (grigliati, vetri) restano com'erano.

const WET_SHADER := preload("res://addons/acqua/shaders/wet_surface.gdshader")

## Nodi da cui cercare le MeshInstance3D (ricorsivo).
@export var roots: Array[NodePath] = []
## Converte solo le mesh il cui nome (o quello del materiale) contiene una di queste parole
## (senza distinzione tra maiuscole e minuscole). Vuoto = tutte.
@export var name_filter: PackedStringArray = []
## Esclude le mesh il cui nome contiene una di queste parole.
@export var exclude_filter: PackedStringArray = ["vetro", "glass", "griglia", "grata", "neon", "luce", "insegna"]
@export_group("Bagnato")
## Umidita' generale (0..1).
@export_range(0.0, 1.0) var base_wetness := 0.25
## Quantita' di pozzanghere sui piani orizzontali (0..1).
@export_range(0.0, 1.0) var puddle_amount := 0.0
## Scala del rumore delle pozzanghere (piu' piccolo = pozze piu' grandi).
@export var puddle_scale := 0.07
@export_range(0.0, 1.0) var wet_darkening := 0.45
@export_range(0.0, 3.0) var drop_ring_strength := 1.0
@export_group("Acqua")
@export var receive_caustics := true
@export_range(0.0, 3.0) var caustics_strength := 1.0
@export_group("")
## Converte all'avvio (altrimenti chiamare convert_now()).
@export var convert_on_ready := true

var converted := 0
var _cache := {}


func _ready() -> void:
	if convert_on_ready:
		convert_now.call_deferred()


func convert_now() -> void:
	for np in roots:
		var root := get_node_or_null(np)
		if root:
			_walk(root)
	print_verbose("WetSurfaceConverter: %d superfici convertite" % converted)


## Converte le mesh sotto un nodo qualsiasi (in alternativa a `roots`).
func convert_root(root: Node) -> void:
	_walk(root)


func _walk(n: Node) -> void:
	var mi := n as MeshInstance3D
	if mi and mi.mesh:
		_convert_mesh(mi)
	for c in n.get_children():
		_walk(c)


func _matches(text: String, words: PackedStringArray) -> bool:
	var t := text.to_lower()
	for w in words:
		if w != "" and t.contains(w.to_lower()):
			return true
	return false


func _convert_mesh(mi: MeshInstance3D) -> void:
	if _matches(mi.name, exclude_filter):
		return
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_surface_override_material(i)
		if src == null:
			src = mi.mesh.surface_get_material(i)
		var sm := src as BaseMaterial3D
		if sm == null:
			continue
		var label := String(mi.name) + " " + sm.resource_name
		if not name_filter.is_empty() and not _matches(label, name_filter):
			continue
		if _matches(sm.resource_name, exclude_filter):
			continue
		if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var wet := _wet_material_for(sm)
		if wet:
			mi.set_surface_override_material(i, wet)
			converted += 1


## Materiale bagnabile equivalente a uno StandardMaterial3D (condiviso tra le mesh uguali).
func _wet_material_for(sm: BaseMaterial3D) -> ShaderMaterial:
	if _cache.has(sm):
		return _cache[sm]
	var m := ShaderMaterial.new()
	m.shader = WET_SHADER
	m.set_shader_parameter("use_triplanar", false)
	m.set_shader_parameter("uv_scale", 1.0)
	m.set_shader_parameter("uv1_scale", Vector2(sm.uv1_scale.x, sm.uv1_scale.y))
	m.set_shader_parameter("uv1_offset", Vector2(sm.uv1_offset.x, sm.uv1_offset.y))
	m.set_shader_parameter("albedo_tint", Color(sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b))
	m.set_shader_parameter("albedo_tex", sm.albedo_texture if sm.albedo_texture else _white())
	m.set_shader_parameter("use_vertex_color", sm.vertex_color_use_as_albedo)
	if sm.normal_enabled and sm.normal_texture:
		m.set_shader_parameter("normal_tex", sm.normal_texture)
		m.set_shader_parameter("normal_strength", sm.normal_scale)
	else:
		m.set_shader_parameter("normal_strength", 0.0)
	# ORM: nei glTF occlusione, rugosita' e metallo stanno nella stessa texture (R, G, B)
	var orm: Texture2D = null
	if sm is ORMMaterial3D:
		orm = (sm as ORMMaterial3D).orm_texture
	elif sm.roughness_texture:
		orm = sm.roughness_texture
	if orm:
		m.set_shader_parameter("orh_tex", orm)
		m.set_shader_parameter("orm_mode", true)
		m.set_shader_parameter("ao_strength", 1.0 if sm.ao_enabled else 0.0)
		m.set_shader_parameter("roughness_scale", sm.roughness)
		m.set_shader_parameter("metallic", sm.metallic)
	else:
		m.set_shader_parameter("orh_tex", _white())
		m.set_shader_parameter("orm_mode", true)
		m.set_shader_parameter("ao_strength", 0.0)
		m.set_shader_parameter("roughness_scale", sm.roughness)
		m.set_shader_parameter("metallic", sm.metallic)
	m.set_shader_parameter("base_wetness", base_wetness)
	m.set_shader_parameter("puddle_amount", puddle_amount)
	m.set_shader_parameter("puddle_scale", puddle_scale)
	m.set_shader_parameter("wet_darkening", wet_darkening)
	m.set_shader_parameter("drop_ring_strength", drop_ring_strength)
	m.set_shader_parameter("receive_caustics", receive_caustics)
	m.set_shader_parameter("caustics_strength", caustics_strength)
	m.resource_name = sm.resource_name + "_bagnato"
	_cache[sm] = m
	return m


static var _white_tex: ImageTexture


static func _white() -> Texture2D:
	if _white_tex == null:
		var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

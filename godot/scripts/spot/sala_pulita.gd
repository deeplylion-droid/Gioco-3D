extends Node3D
## La sala principale "da nuova", per lo spot VHS della crociera (GDD, "Lo spot della crociera Jubilee"):
## la stessa sala del gioco, anni prima, accesa e pulita, di giorno. Solo per lo spot: il gioco non la usa.
## - materiali: le texture con lo sporco si scambiano con quelle pulite di res://assets/spot/texture/
##   (tools/blender/spot_texture_pulite.py), niente sporco nei colori dei vertici, niente colature, calcare,
##   pozzanghere, piastrelle mancanti e schegge della cupola;
## - luci: tutti i neon e le plafoniere accesi e nessuno guasto, le rosse d'emergenza spente, il sole dalla cupola
##   (la luce direzionale della sala, che nel gioco è la luna);
## - acqua: la piscina a onde piena (acqua_onde_spot.gdshader), la vasca di Jilly limpida.

const TEXTURE_PULITE := "res://assets/spot/texture/"
const SHADER_ONDE := preload("res://shaders/spot/acqua_onde_spot.gdshader")
## Le parti della sala che sono sporco o rovina: nella nave nuova non ci sono.
const ROVINE: Array[String] = ["sala_colature", "sala_piastrelle_mancanti", "sala_pozzanghere", "sala_schegge_cupola",
		"sala_vasca_centrale_calcare", "sala_vasca_offerte"]
const GLB_SALA := ["architettura", "cupola", "piscina", "vasca_centrale", "area_bimbi", "interattivi", "torre_scivoli",
		"oggetti", "monumento"]

@export var percorso_sala := NodePath("Sala")
@export var piscina_onde: NodePath = ^"Piscina/AcquaOnde"
@export_group("Sole")
## Direzione del sole (gradi): alto da sud-ovest, così entra dalla cupola e cade sulla piscina.
@export var sole_rotazione := Vector3(-58.0, -150.0, 0.0)
@export var sole_energia := 2.2
@export var sole_colore := Color(1.0, 0.96, 0.88)

var _materiali := {}
var _texture := {}


func _ready() -> void:
	var sala := get_node(percorso_sala)
	_pulisci(sala)
	var onde := get_node_or_null(piscina_onde)
	if onde and "material" in onde and onde.get(&"material") is ShaderMaterial:
		(onde.get(&"material") as ShaderMaterial).shader = SHADER_ONDE
	# Dopo le luci della sala (look_sala.gd regola tutto in differita, dopo il suo _ready).
	_accendi.call_deferred.call_deferred()


func _pulisci(radice: Node) -> void:
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if _rovina(mi):
			mi.visible = false
			continue
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m == null:
				continue
			if not _materiali.has(m):
				_materiali[m] = _pulito(m)
			mi.set_surface_override_material(i, _materiali[m])


func _rovina(n: Node) -> bool:
	var p := n
	while p != null and p != self:
		if String(p.name) in ROVINE:
			return true
		p = p.get_parent()
	return false


func _pulito(m: BaseMaterial3D) -> BaseMaterial3D:
	var n := m.duplicate() as BaseMaterial3D
	n.vertex_color_use_as_albedo = false   # lo sporco dei colori dei vertici (in basso sui muri, nelle vasche)
	for prop in [&"albedo_texture", &"normal_texture", &"roughness_texture", &"metallic_texture", &"ao_texture"]:
		var t := n.get(prop) as Texture2D
		if t:
			n.set(prop, _texture_pulita(t))
	# i neon spenti (guasti) della sala tornano accesi
	if String(m.resource_name).contains("neon_spento"):
		n.emission_enabled = true
		n.emission = Color(0.85, 1.0, 0.95)
		n.emission_energy_multiplier = 3.0
	return n


## La texture pulita con lo stesso nome (senza il prefisso del GLB), se c'è.
func _texture_pulita(t: Texture2D) -> Texture2D:
	var file := t.resource_path.get_file()
	if file == "":
		return t
	if _texture.has(file):
		return _texture[file]
	var resto := file
	for g in GLB_SALA:
		if file.begins_with("sala_%s_" % g):
			resto = file.substr(("sala_%s_" % g).length())
			break
	var nuova := t
	if ResourceLoader.exists(TEXTURE_PULITE + resto):
		nuova = load(TEXTURE_PULITE + resto) as Texture2D
	_texture[file] = nuova
	return nuova


func _accendi() -> void:
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		var luce := l as Light3D
		var nome := String(luce.name)
		if nome.begins_with("luce_emergenza"):
			luce.visible = false
		elif luce is DirectionalLight3D:
			var d := luce as DirectionalLight3D
			d.rotation_degrees = sole_rotazione
			d.light_color = sole_colore
			d.light_energy = sole_energia
			d.light_angular_distance = 0.5
			d.shadow_enabled = true
			d.shadow_opacity = 1.0
	# le lampade rosse d'emergenza (vetri) spente: di giorno non servono
	for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m and m.emission_enabled and m.emission.r > 0.6 and m.emission.g < 0.3 and m.emission.b < 0.3:
				var spenta := m.duplicate() as BaseMaterial3D
				spenta.emission_enabled = false
				mi.set_surface_override_material(i, spenta)

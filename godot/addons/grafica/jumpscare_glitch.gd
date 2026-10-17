class_name JumpscareGlitch
extends CanvasLayer
## Il jumpscare quando ti prende lei (riscontro 3 della v0.3.2, scelta dell'utente del 17 ottobre:
## versione A, "glitch forte", con l'urlo al massimo). Lo aggiunge la DeathSequence quando la causa
## è &"medusa": lei resta com'è (camera tirata verso la fauce, lampo rosso al morso a 1 s, nero da
## 1,1 a 2 s) e sopra si aggiungono:
## - 10 raffiche di glitch sullo schermo (glitch_schermo.gdshader: righe spostate, blocchi, RGB
##   separati, righe di scansione, neve, colori invertiti), con un fondo di disturbo che cresce;
## - la camera che a ogni raffica salta in una posa a caso, più un tremito (process_priority alto:
##   si applica dopo la camera della DeathSequence);
## - lei che salta a scatti di qualche centimetro, come un video che perde fotogrammi;
## - l'urlo lei_urlo, inceppato negli stessi istanti delle raffiche
##   (assets_src/audio/proposte_jumpscare/genera_urlo.py, GLITCH).

## Istanti delle raffiche (s dall'inizio): gli stessi dell'urlo.
const GLITCH := [0.14, 0.33, 0.52, 0.66, 0.8, 1.0, 1.12, 1.31, 1.5, 1.68]
const DURATA_RAFFICA := 0.09
const SHADER := preload("res://addons/grafica/glitch_schermo.gdshader")

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _lei: Node3D
var _urlo: Node
var _scatto_cam := Transform3D.IDENTITY
var _scatto_t := -1.0
var _salto_lei := Vector3.ZERO


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_rng.seed = 316
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	r.material = _mat
	add_child(r)
	_lei = get_tree().get_first_node_in_group(&"medusa_che_prende") as Node3D
	var audio := get_node_or_null(^"/root/Audio")
	if audio:
		_urlo = audio.call(&"suona", &"lei_urlo")


func _exit_tree() -> void:
	_spegni()


func _spegni() -> void:
	if is_instance_valid(_urlo) and _urlo.has_method(&"stop") and _t < 2.0:
		_urlo.call(&"stop")
	_urlo = null
	_rimetti_lei()
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	# Finita (o saltata) la sequenza di morte, il jumpscare si spegne subito: niente scosse sulla
	# camera dopo la ripartenza, niente urlo, lei al suo posto.
	var seq := get_parent()
	if not GameState.is_dying or (seq and bool(seq.get(&"_done"))):
		_spegni()
		return
	_t += delta
	var forza := _forza_glitch()
	_mat.set_shader_parameter(&"forza", forza)
	# Il seme cambia a ogni fotogramma durante le raffiche, più piano fuori.
	_mat.set_shader_parameter(&"seme", floorf(_t * (60.0 if forza > 0.3 else 12.0)))
	_scuoti()
	_glitch_lei(forza)


## Quanto è rotto lo schermo adesso (0..1).
func _forza_glitch() -> float:
	var f := 0.12 + 0.18 * smoothstep(0.0, 1.0, _t)
	for g in GLITCH:
		var d: float = _t - g
		if d >= 0.0 and d < DURATA_RAFFICA:
			f = maxf(f, 1.0 - d / DURATA_RAFFICA * 0.5)
	return f


## Scosse a scatti: a ogni raffica la camera salta in una posa a caso e ci resta un attimo.
func _scuoti() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or _t > 2.2:
		return
	for g in GLITCH:
		if _t >= g and _scatto_t < g:
			_scatto_t = _t
			_scatto_cam = Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.09, 0.09),
					_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.16, 0.16))),
					Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.04), 0.0))
			break
	var k := 1.0 - clampf((_t - _scatto_t) / 0.12, 0.0, 1.0)
	var ampiezza := 0.012 + 0.01 * smoothstep(0.0, 1.0, _t)
	var pos := _scatto_cam.origin * k
	var rot := _scatto_cam.basis.get_euler() * k
	pos += Vector3(sin(_t * 61.0) + sin(_t * 97.0) * 0.5, sin(_t * 53.0 + 1.3) + sin(_t * 89.0) * 0.5, 0.0) * ampiezza
	rot += Vector3(sin(_t * 71.0), sin(_t * 67.0 + 0.7), sin(_t * 43.0)) * ampiezza * 0.6
	var cam := p.camera
	var b := cam.global_basis
	cam.global_transform = Transform3D(b * Basis.from_euler(rot), cam.global_position + b * pos)


## Lei salta a scatti di qualche centimetro durante le raffiche (dopo che si è girata verso di te).
func _glitch_lei(forza: float) -> void:
	_rimetti_lei()
	if _lei == null or not is_instance_valid(_lei):
		return
	if _t > 0.22 and forza > 0.6 and _rng.randf() < 0.7:
		_salto_lei = Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.05, 0.05))
		_lei.global_position += _salto_lei


func _rimetti_lei() -> void:
	if _lei and is_instance_valid(_lei) and _salto_lei != Vector3.ZERO:
		_lei.global_position -= _salto_lei
	_salto_lei = Vector3.ZERO

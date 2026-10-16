extends CanvasLayer
## PROPOSTA (riscontro 3 della v0.3.2, non usata dal gioco): il jumpscare quando ti prende lei, più
## movimentato (scosse, effetto glitch) e rumoroso (urlo distorto alla FNAF). Si aggiunge sopra la
## DeathSequence (che resta com'è: camera tirata verso la fauce, lampo rosso al morso a 1 s, nero da
## 1,1 a 2 s) e ci mette sopra:
## - lo schermo che si rompe (shader glitch_schermo.gdshader: righe spostate, blocchi, RGB separati,
##   righe di scansione, neve, inversione dei colori);
## - le scosse della camera (applicate dopo quelle della DeathSequence: process_priority alto);
## - lei che "salta" a scatti di qualche centimetro, come un video che perde fotogrammi;
## - l'urlo (assets_src/audio/proposte_jumpscare/genera_urlo.py).
## Versioni:
##   A "glitch forte": 10 raffiche di glitch sullo schermo, sull'urlo e su di lei; scosse a scatti.
##   B "scossa": glitch leggero sempre, con 3 raffiche forti (attacco, morso, nero); tremito che
##     cresce e due colpi secchi; l'urlo è una voce unica senza inceppamenti.

## Istanti delle raffiche nella versione A: gli stessi dell'urlo A (GLITCH in genera_urlo.py).
const GLITCH_A := [0.14, 0.33, 0.52, 0.66, 0.8, 1.0, 1.12, 1.31, 1.5, 1.68]
const GLITCH_B := [0.08, 1.0, 1.55]
const URLO := {"A": "res://proposte/medusa/urlo_a.ogg", "B": "res://proposte/medusa/urlo_b.ogg"}

var versione := "A"
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _lei: Node3D
var _lei_da := Transform3D.IDENTITY
var _scatto_cam := Transform3D.IDENTITY
var _scatto_t := -1.0
var _salto_lei := Vector3.ZERO


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_rng.seed = 316 if versione == "A" else 3162
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://proposte/medusa/glitch_schermo.gdshader")
	r.material = _mat
	add_child(r)
	_lei = get_tree().get_first_node_in_group(&"medusa_che_prende") as Node3D
	var urlo := AudioStreamPlayer.new()
	urlo.stream = load(URLO[versione])
	urlo.bus = &"Interfaccia"
	add_child(urlo)
	urlo.play()


func _process(delta: float) -> void:
	_t += delta
	var forza := _forza_glitch()
	_mat.set_shader_parameter(&"forza", forza)
	# Il seme cambia a ogni fotogramma durante le raffiche, più piano fuori.
	_mat.set_shader_parameter(&"seme", floorf(_t * (60.0 if forza > 0.3 else 12.0)))
	_scuoti()
	_glitch_lei(forza)
	if _t > 3.0:
		set_process(false)


## Quanto è rotto lo schermo adesso (0..1).
func _forza_glitch() -> float:
	var f := 0.0
	var lista: Array = GLITCH_A if versione == "A" else GLITCH_B
	var durata := 0.09 if versione == "A" else 0.16
	for g in lista:
		var d: float = _t - g
		if d >= 0.0 and d < durata:
			f = maxf(f, 1.0 - d / durata * 0.5)
	if versione == "A":
		# Fra una raffica e l'altra resta un fondo di disturbo che cresce fino al morso.
		f = maxf(f, 0.12 + 0.18 * smoothstep(0.0, 1.0, _t))
	else:
		f = maxf(f, 0.04 + 0.16 * smoothstep(0.2, 1.2, _t))
	return f


func _scuoti() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or _t > 2.2:
		return
	var cam := p.camera
	var ampiezza := 0.0
	var rot := Vector3.ZERO
	var pos := Vector3.ZERO
	if versione == "A":
		# Scosse a scatti: a ogni raffica la camera salta in una posa a caso e ci resta un attimo.
		for g in GLITCH_A:
			if absf(_t - g) < 0.5 / 60.0 or (_t >= g and _scatto_t < g):
				_scatto_t = _t
				_scatto_cam = Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.09, 0.09),
						_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.16, 0.16))),
						Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.04), 0.0))
				break
		var k := 1.0 - clampf((_t - _scatto_t) / 0.12, 0.0, 1.0)
		ampiezza = 0.012 + 0.01 * smoothstep(0.0, 1.0, _t)
		pos = _scatto_cam.origin * k
		rot = _scatto_cam.basis.get_euler() * k
	else:
		# Tremito che cresce, rollio, e due colpi secchi: all'attacco e al morso.
		ampiezza = 0.008 + 0.03 * smoothstep(0.1, 1.0, _t)
		for g in [0.08, 1.0]:
			var d: float = _t - g
			if d >= 0.0 and d < 0.25:
				var e := exp(-d * 18.0)
				rot += Vector3(-0.12 * e, 0.0, 0.1 * sin(d * 70.0) * e)
				pos += Vector3(0.0, -0.06 * e, 0.0)
		rot.z += sin(_t * 9.0) * 0.025 * smoothstep(0.1, 1.0, _t)
	pos += Vector3(sin(_t * 61.0) + sin(_t * 97.0) * 0.5, sin(_t * 53.0 + 1.3) + sin(_t * 89.0) * 0.5, 0.0) * ampiezza
	rot += Vector3(sin(_t * 71.0), sin(_t * 67.0 + 0.7), sin(_t * 43.0)) * ampiezza * 0.6
	var b := cam.global_basis
	cam.global_transform = Transform3D(b * Basis.from_euler(rot), cam.global_position + b * pos)


## Lei salta a scatti di qualche centimetro durante le raffiche (versione A sempre, B solo nelle tre
## raffiche forti): sembra un video che perde fotogrammi.
func _glitch_lei(forza: float) -> void:
	if _lei == null or not is_instance_valid(_lei):
		return
	_lei.global_position -= _salto_lei
	_salto_lei = Vector3.ZERO
	if _t > 0.22 and forza > 0.6 and _rng.randf() < (0.7 if versione == "A" else 0.5):
		_salto_lei = Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.05, 0.05))
		_lei.global_position += _salto_lei

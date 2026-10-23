class_name OcchioIpnotico
extends ColorRect
## Il finale dello spot (inquadrature 8-9): muove i parametri di shaders/spot/occhio_ipnotico.gdshader. Il montaggio fa
## salire [member progresso] da 0 a 1 (circa 5 s, dal 38° al 43° secondo); da solo fa il resto: il battito che accelera
## da [member bpm_inizio] a [member bpm_fine], i fotogrammi saltati, il lampo in negativo, lo scatto in avanti e il nero.
## Sopra una camera: un ColorRect a tutto schermo in un CanvasLayer (dallo_schermo acceso), con [member camera] e
## [member bersaglio] (l'occhio) per tenere la pupilla al centro dell'effetto. Su un video: [member centro] a mano.

## Emesso quando i fotogrammi si fermano e quando ripartono: il montaggio ferma anche l'animazione dell'occhio.
signal fermo(acceso: bool)

@export_range(0.0, 1.0) var progresso := 0.0
@export var bpm_inizio := 72.0
@export var bpm_fine := 200.0
@export var camera: Camera3D
@export var bersaglio: Node3D
## L'occhio vero di Jilly (la MeshInstance del bulbo): con [member usa_pupilla] la pupilla si allarga a ogni colpo,
## con l'instance uniform "pupilla" dello shader dell'occhio di mascotte (1 = com'è, da 0,5 a 2,0).
@export var occhio: GeometryInstance3D
@export var usa_pupilla := false
## Con l'instance uniform "vene" del materiale dell'occhio (0-1, il bulbo venato di mascotte): le vene vere al posto di
## quelle disegnate dallo shader.
@export var usa_vene := false
@export var centro := Vector2(0.5, 0.5)
## Quando arrivano i lampi in negativo e lo scatto in avanti (in progresso): i lampi sempre più fitti, e più lunghi
## (1, 1, 2, 2, 3 fotogrammi).
@export var lampi := PackedFloat32Array([0.55, 0.7, 0.8, 0.86, 0.9])
@export var scatto_da := 0.93
@export var seme := 20261022

var _fase := 0.0
var _tempo := 0.0
var _fermo := 0
var _negativo := 0
var _lampo := 0
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial


func _ready() -> void:
	_rng.seed = seme
	_mat = material as ShaderMaterial


func _process(delta: float) -> void:
	if _mat == null:
		return
	var p := clampf(progresso, 0.0, 1.0)
	# i fotogrammi saltati: ogni tanto l'effetto (e il montaggio, col segnale) si ferma 2-5 fotogrammi, poi riparte avanti;
	# sempre più spesso verso la fine
	# (nello scatto finale niente salti né lampi: lo scatto e poi il nero, puliti)
	if _fermo > 0 and p >= scatto_da:
		_fermo = 0
		_negativo = 0
		fermo.emit(false)
	if _fermo > 0:
		_fermo -= 1
		if _fermo == 0:
			_tempo += delta * 4.0
			fermo.emit(false)
		return
	if p > 0.2 and p < scatto_da and _rng.randf() < 0.008 + 0.12 * p * p:
		_fermo = _rng.randi_range(2, 2 + roundi(3.0 * p))
		fermo.emit(true)
	# il battito che accelera: due colpi (lub-dub) per battito
	var bpm := lerpf(bpm_inizio, bpm_fine, p * p)
	_fase = fmod(_fase + delta * bpm / 60.0, 1.0)
	var colpo := exp(-_fase * 14.0) + 0.6 * exp(-absf(_fase - 0.28) * 18.0) * float(_fase > 0.22)
	colpo = clampf(colpo, 0.0, 1.0)
	# la spirale gira più forte a ogni colpo
	_tempo += delta * (1.0 + 3.0 * colpo * p)
	if occhio and usa_pupilla:
		occhio.set_instance_shader_parameter(&"pupilla", minf(2.0, 1.0 + 0.8 * colpo * (0.4 + 0.6 * p)))
	if occhio and usa_vene:
		occhio.set_instance_shader_parameter(&"vene", smoothstep(0.12, 0.75, p) * (0.85 + 0.15 * colpo))
	_mat.set_shader_parameter(&"tempo", _tempo)
	_mat.set_shader_parameter(&"battito", colpo)
	_mat.set_shader_parameter(&"intensita", p)
	_mat.set_shader_parameter(&"vene_finte", 0.0 if (occhio and usa_vene) else 1.0)
	# i lampi in negativo: quelli fissi di [member lampi] (sempre più fitti e lunghi), più qualcuno a caso verso la fine
	if p >= scatto_da:
		_negativo = 0
	elif _negativo > 0:
		_negativo -= 1
	else:
		while _lampo < lampi.size() and p >= lampi[_lampo]:
			_negativo = 1 + _lampo / 2
			_lampo += 1
		if _negativo == 0 and p > 0.6 and p < scatto_da - 0.01 and _rng.randf() < 0.05 * (p - 0.6) / 0.3:
			_negativo = _rng.randi_range(1, 2)
	_mat.set_shader_parameter(&"negativo", 1.0 if _negativo > 0 else 0.0)
	# lo scatto in avanti, poi il nero
	var av := clampf((p - scatto_da) / (0.99 - scatto_da), 0.0, 1.0)
	_mat.set_shader_parameter(&"avanti", av)
	_mat.set_shader_parameter(&"nero", 1.0 if p >= 0.995 else 0.0)
	if camera and bersaglio and not camera.is_position_behind(bersaglio.global_position):
		var s := camera.get_viewport().get_visible_rect().size
		centro = camera.unproject_position(bersaglio.global_position) / s
	_mat.set_shader_parameter(&"centro", centro)

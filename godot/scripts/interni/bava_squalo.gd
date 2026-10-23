class_name BavaSqualo
extends Node3D
## La bava del mostro-squalo all'inizio (scelta dell'utente del 23 ottobre: "sì alla bava"). Pochi fili, verso gli
## angoli della bocca e fra i denti di lato (mai al centro davanti alla gola: sembravano le sbarre di una gabbia,
## riscontro del coordinatore), tra il labbro di sopra (osso "testa") e quello di sotto (osso "mascella"), un poco
## sfalsati e storti: pendono come una catenella (la loro lunghezza è più del tratto tra le labbra), si tendono
## quando la bocca si apre di scatto, si spezzano e i due pezzi pendono e oscillano; nei morsi, quando la bocca si
## richiude, si riattaccano. In più una colata dal labbro di sotto lungo il mento, che si allunga, lascia cadere una
## goccia e ricomincia: le gocce cadono dalla sua punta. Spessore irregolare, qualche bolla.
## I fili sono nastri sottili girati verso la camera (ImmediateMesh), rifatti a ogni fotogramma; senza fisica.
## La mette risveglio_squalo.gd (prepara()); attivo = false la spegne piano.

## I fili, nello spazio del modello in Blender (x di lato, -y avanti, z su: "bocca" a (0,14; -1,02; 1,50)):
## [x sopra, x sotto, quanto più indietro sotto, lunghezza del filo (m)].
const FILI := [[-0.03, 0.0, 0.02, 0.12], [0.31, 0.28, 0.015, 0.15], [0.23, 0.25, -0.01, 0.09]]
## La colata dal labbro di sotto: x, quanto può allungarsi (m).
const COLATA := [0.1, 0.15]
const SPESSORE := 0.0026
const SEGMENTI := 12

var attivo := true
var _sk: Skeleton3D
var _testa := -1
var _mascella := -1
var _mento := -1
var _fili: Array[Dictionary] = []
var _colata := {}
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _gocce: GPUParticles3D
var _forza := 1.0          # 1 acceso, scende a 0 quando attivo = false
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func prepara(scheletro: Skeleton3D) -> void:
	_sk = scheletro
	_testa = _sk.find_bone("testa")
	_mascella = _sk.find_bone("mascella")
	_mento = _sk.find_bone("mento_punta")
	if _testa < 0 or _mascella < 0:
		push_warning("BavaSqualo: mancano gli ossi testa o mascella")
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/creature/bava_squalo.gdshader")
	_mi.mesh = _mesh
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.top_level = true
	add_child(_mi)
	_rng.seed = 2310
	for f in FILI:
		var su := _locale(_testa, _bordo(f[0], 1.505, 0.0))
		var giu := _locale(_mascella, _bordo(f[1], 1.495, f[2]))
		_fili.append({"su": su, "giu": giu, "lungo": float(f[3]), "intero": true, "rotto_t": 0.0,
			"fase": _rng.randf() * TAU, "bolla": _rng.randf_range(0.25, 0.75), "lato": _rng.randf_range(-1.0, 1.0)})
	_colata = {"da": _locale(_mascella, _bordo(COLATA[0], 1.47, -0.03)), "max": float(COLATA[1]), "l": 0.02,
		"fase": _rng.randf() * TAU}
	_crea_gocce()


## Un punto sul bordo della bocca (spazio del modello di Blender): il bordo gira indietro verso gli angoli; un poco
## dentro le labbra, più [param indietro].
func _bordo(x: float, z: float, indietro: float) -> Vector3:
	return Vector3(x, -1.02 + 0.55 * absf(x - 0.14) + 0.03 + indietro, z)


## Un punto del modello di Blender (posa di riposo) nello spazio dell'osso a riposo (glTF: x, z, -y).
func _locale(osso: int, blender: Vector3) -> Vector3:
	var p := Vector3(blender.x, blender.z, -blender.y)
	return _sk.get_bone_global_rest(osso).affine_inverse() * p


func _mondo(osso: int, locale: Vector3) -> Vector3:
	return _sk.global_transform * (_sk.get_bone_global_pose(osso) * locale)


func _crea_gocce() -> void:
	if _mento < 0:
		return
	_gocce = GPUParticles3D.new()
	_gocce.amount = 6
	_gocce.lifetime = 0.7
	_gocce.explosiveness = 0.0
	_gocce.randomness = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 8.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, -9.8, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.006
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	_gocce.process_material = pm
	var goccia := SphereMesh.new()
	goccia.radius = 0.004
	goccia.height = 0.016          # allungata: cade
	goccia.radial_segments = 6
	goccia.rings = 3
	var mg := StandardMaterial3D.new()
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mg.albedo_color = Color(0.86, 0.88, 0.8, 0.6)
	mg.roughness = 0.05
	mg.metallic_specular = 0.9
	goccia.material = mg
	_gocce.draw_pass_1 = goccia
	_gocce.local_coords = false
	_gocce.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gocce)


func _process(delta: float) -> void:
	if _sk == null or _testa < 0:
		return
	_t += delta
	_forza = move_toward(_forza, 1.0 if attivo else 0.0, delta * 1.5)
	var cam := get_viewport().get_camera_3d()
	var occhio := cam.global_position if cam else Vector3.ZERO
	_mesh.clear_surfaces()
	if _forza <= 0.0:
		if _gocce:
			_gocce.emitting = false
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var centro := _sk.global_transform * _sk.get_bone_global_pose(_testa).origin
	for f in _fili:
		var a := _mondo(_testa, f["su"])
		var b := _mondo(_mascella, f["giu"])
		var d := a.distance_to(b)
		var lungo: float = f["lungo"]
		if f["intero"] and d > lungo * 1.18:
			# tirato troppo (la bocca si apre di scatto): si spezza
			f["intero"] = false
			f["rotto_t"] = 0.0
		elif not f["intero"]:
			f["rotto_t"] += delta
			# la bocca si richiude (un morso): il filo si riattacca
			if d < lungo * 0.55 and f["rotto_t"] > 0.25:
				f["intero"] = true
		# pende di lato e in avanti, non verso la gola: verso l'esterno della bocca e verso il basso
		var fuori := (a.lerp(b, 0.5) - centro) * Vector3(1, 0, 1)
		var giu_fuori := (Vector3.DOWN + fuori.normalized() * 0.6 + Vector3(f["lato"], 0, 0) * 0.2).normalized()
		if f["intero"]:
			# una catenella: lunga più del tratto tra le labbra, la parte in più pende; tesa solo vicino alla rottura
			var molle := sqrt(maxf(lungo * lungo - d * d, 0.0)) * 0.5
			var pende := maxf(molle, 0.006) * (1.0 + 0.08 * sin(_t * 3.1 + f["fase"]))
			var tiro := clampf((d - lungo * 0.8) / (lungo * 0.38), 0.0, 1.0)
			_nastro(a, b, giu_fuori, pende, SPESSORE * _forza, 0.8 * tiro, f["fase"], f["bolla"], occhio)
		else:
			# i due pezzi pendono dalle labbra e oscillano, si accorciano mentre gocciolano
			var t: float = f["rotto_t"]
			var l := lungo * 0.35 * clampf(1.0 - (t - 0.6) / 1.2, 0.0, 1.0)
			if l > 0.006:
				var oscilla := sin(t * 7.0 + f["fase"]) * 0.45 * exp(-t * 1.4)
				var dir := (Vector3.DOWN + giu_fuori * 0.3 + Vector3(oscilla, 0, oscilla * 0.5)).normalized()
				_nastro(a, a + dir * l, giu_fuori, l * 0.15, SPESSORE * 0.9 * _forza, 0.5, f["fase"], 0.8, occhio)
				var dir2 := (Vector3.DOWN + giu_fuori * 0.5 - Vector3(oscilla, 0, 0) * 0.6).normalized()
				_nastro(b, b + dir2 * l * 0.6, giu_fuori, l * 0.1, SPESSORE * 0.8 * _forza, 0.5, f["fase"] + 1.0, 0.8, occhio)
	# la colata dal labbro di sotto lungo il mento: si allunga piano, poi la goccia si stacca e ricomincia
	var da := _mondo(_mascella, _colata["da"])
	_colata["l"] = float(_colata["l"]) + delta * 0.06 * (1.0 + 0.5 * sin(_t * 1.7))
	if float(_colata["l"]) > float(_colata["max"]):
		_colata["l"] = 0.03
		if _gocce and attivo:
			_gocce.restart()
	var lc: float = _colata["l"]
	var dondola := sin(_t * 2.3 + float(_colata["fase"])) * 0.12
	var punta := da + (Vector3.DOWN + Vector3(dondola, 0, 0) + (da - centro).normalized() * 0.25).normalized() * lc
	_nastro(da, punta, Vector3.FORWARD, 0.004, SPESSORE * 1.1 * _forza, 0.35, float(_colata["fase"]), 0.85, occhio)
	if _gocce:
		_gocce.emitting = attivo
		_gocce.global_position = punta
	_mesh.surface_end()


## Un nastro da a a b che pende di [param pende] m nel mezzo verso [param verso], largo [param largo] (mezza
## larghezza) ai capi, dove si attacca, più sottile nel mezzo di [param collo] (0..1), con lo spessore che cambia
## lungo il filo e una bolla a [param bolla]; girato verso l'occhio. uv: x lungo, y di traverso.
func _nastro(a: Vector3, b: Vector3, verso: Vector3, pende: float, largo: float, collo: float, fase: float,
		bolla: float, occhio: Vector3) -> void:
	var tang := (b - a).normalized()
	var v := (verso - tang * verso.dot(tang))
	v = v.normalized() if v.length() > 1e-4 else Vector3.DOWN
	var prima_s := Vector3.ZERO
	var prima_d := Vector3.ZERO
	var prima_u := 0.0
	for k in SEGMENTI + 1:
		var u := float(k) / SEGMENTI
		var p := a.lerp(b, u) + v * pende * 4.0 * u * (1.0 - u)
		var lato := tang.cross(occhio - p).normalized()
		# più spesso dove si attacca, sottile in mezzo quando è tirato; irregolare, e una bolla
		var w := largo * (1.0 + 0.6 * pow(absf(u * 2.0 - 1.0), 4.0)) * (1.0 - collo * sin(PI * u))
		w *= 0.75 + 0.35 * sin(u * 11.0 + fase) * sin(u * 5.0 + fase * 1.7)
		w *= 1.0 + 1.3 * exp(-pow((u - bolla) / 0.05, 2.0))
		var s := p + lato * w
		var dd := p - lato * w
		if k > 0:
			for q in [[prima_s, prima_u, 0.0], [prima_d, prima_u, 1.0], [s, u, 0.0],
					[s, u, 0.0], [prima_d, prima_u, 1.0], [dd, u, 1.0]]:
				_mesh.surface_set_color(Color(1, 1, 1, _forza))
				_mesh.surface_set_uv(Vector2(q[1], q[2]))
				_mesh.surface_add_vertex(q[0])
		prima_s = s
		prima_d = dd
		prima_u = u

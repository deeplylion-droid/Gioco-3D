class_name BavaSqualo
extends Node3D
## La bava del mostro-squalo all'inizio (scelta dell'utente del 23 ottobre: "sì alla bava"): fili di saliva tra
## il labbro di sopra (osso "testa") e quello di sotto (osso "mascella") che si allungano quando la bocca si
## apre, si assottigliano e si spezzano; i pezzi rotti pendono e gocciolano, e nei morsi, quando la bocca si
## richiude, i fili si riattaccano. In più qualche goccia che cade dal mento (osso "mento_punta").
## I fili sono nastri sottili girati verso la camera (ImmediateMesh), rifatti a ogni fotogramma; senza fisica.
## La mette risveglio_squalo.gd (prepara()); attivo = false la spegne piano.

## I punti dei fili sul bordo della bocca chiusa, nello spazio del modello in Blender (x di lato, -y avanti, z su:
## mostro_rig.G, "bocca" a (0,14; -1,02; 1,50)): x lungo la bocca, quanto più lunghi possono diventare (m).
const FILI := [[0.0, 0.17], [0.07, 0.24], [0.14, 0.2], [0.2, 0.27], [0.29, 0.19]]
const SPESSORE := 0.006
const SEGMENTI := 10

var attivo := true
var _sk: Skeleton3D
var _testa := -1
var _mascella := -1
var _mento := -1
var _fili: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _gocce: GPUParticles3D
var _forza := 1.0          # 1 acceso, scende a 0 quando attivo = false


func prepara(scheletro: Skeleton3D) -> void:
	_sk = scheletro
	_testa = _sk.find_bone("testa")
	_mascella = _sk.find_bone("mascella")
	_mento = _sk.find_bone("mento_punta")
	if _testa < 0 or _mascella < 0:
		push_warning("BavaSqualo: mancano gli ossi testa o mascella")
		return
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.86, 0.88, 0.8, 0.5)
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	_mi.mesh = _mesh
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.top_level = true
	add_child(_mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2310
	for f in FILI:
		var x: float = f[0]
		# il bordo della bocca gira indietro verso gli angoli; i fili un poco dentro le labbra
		var y := -1.02 + 0.55 * absf(x - 0.14) + 0.03
		var su := _locale(_testa, Vector3(x, y, 1.505))
		var giu := _locale(_mascella, Vector3(x, y, 1.495))
		_fili.append({"su": su, "giu": giu, "max": float(f[1]), "intero": true, "rotto_t": 0.0,
			"fase": rng.randf() * TAU, "resto": 0.0})
	_crea_gocce()


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
	_gocce.amount = 8
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
	pm.emission_sphere_radius = 0.04
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	_gocce.process_material = pm
	var goccia := SphereMesh.new()
	goccia.radius = 0.005
	goccia.height = 0.022          # allungata: cade
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
	_forza = move_toward(_forza, 1.0 if attivo else 0.0, delta * 1.5)
	if _gocce:
		_gocce.emitting = attivo
		_gocce.global_position = _sk.global_transform * _sk.get_bone_global_pose(_mento).origin
	var cam := get_viewport().get_camera_3d()
	var occhio := cam.global_position if cam else Vector3.ZERO
	_mesh.clear_surfaces()
	if _forza <= 0.0:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var vuoto := true
	for f in _fili:
		var a := _mondo(_testa, f["su"])
		var b := _mondo(_mascella, f["giu"])
		var d := a.distance_to(b)
		var lmax: float = f["max"]
		if f["intero"] and d > lmax:
			# si spezza: dal labbro di sopra resta un pezzo che pende, sotto cade sul labbro
			f["intero"] = false
			f["rotto_t"] = 0.0
			f["resto"] = clampf(d * 0.35, 0.03, 0.08)
		elif not f["intero"]:
			f["rotto_t"] += delta
			# la bocca si richiude (un morso, sotto i 12 gradi circa): il filo si riattacca
			if d < 0.075:
				f["intero"] = true
		if f["intero"]:
			# il filo: pende in mezzo (meno quando è tirato) e si assottiglia prima di spezzarsi
			var tiro := clampf(d / lmax, 0.0, 1.0)
			var pende := (0.012 + 0.03 * (1.0 - tiro)) * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.004 + f["fase"]))
			_nastro(a, b, pende, SPESSORE * _forza, 0.75 * tiro, occhio)
			vuoto = false
		else:
			# il pezzo rotto pende dal labbro di sopra, si allunga un poco e si accorcia mentre gocciola
			var t: float = f["rotto_t"]
			var l: float = f["resto"] * (1.0 + 0.5 * minf(t / 0.3, 1.0)) * clampf(1.0 - (t - 0.4) / 0.8, 0.0, 1.0)
			if l > 0.005:
				var giu := a + Vector3.DOWN * l + (b - a).normalized() * l * 0.2
				_nastro(a, giu, 0.004, SPESSORE * 0.8 * _forza, 0.6, occhio)
				vuoto = false
	if vuoto:
		# una superficie vuota non si può chiudere: un triangolo degenere
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


## Un nastro da a a b che pende di [param pende] m nel mezzo, largo [param largo], più sottile nel mezzo di
## [param collo] (0..1), girato verso l'occhio.
func _nastro(a: Vector3, b: Vector3, pende: float, largo: float, collo: float, occhio: Vector3) -> void:
	var prima_s := Vector3.ZERO
	var prima_d := Vector3.ZERO
	for k in SEGMENTI + 1:
		var u := float(k) / SEGMENTI
		var p := a.lerp(b, u) + Vector3.DOWN * pende * sin(PI * u)
		var tang := (b - a).normalized()
		var lato := tang.cross(occhio - p).normalized()
		var w := largo * (1.0 - collo * sin(PI * u))
		var s := p + lato * w
		var dd := p - lato * w
		if k > 0:
			for v in [prima_s, prima_d, s, s, prima_d, dd]:
				_mesh.surface_set_color(Color(1, 1, 1, 0.55 + 0.3 * (1.0 - sin(PI * u))))
				_mesh.surface_add_vertex(v)
		prima_s = s
		prima_d = dd

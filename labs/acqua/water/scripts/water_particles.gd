class_name WaterParticles
extends RefCounted
## Fabbrica di sistemi di particelle d'acqua (GPUParticles3D) con i materiali condivisi:
## gocce allungate nel verso del moto e sbuffi di spruzzo nebulizzato.
## La quantita' si scala con la qualita' (WaterManager.quality).

const DROPLET_SHADER := preload("res://water/shaders/water_droplet.gdshader")
const MIST_SHADER := preload("res://water/shaders/water_mist.gdshader")

static var _droplet_mat: ShaderMaterial
static var _mist_mat: ShaderMaterial


static func quality_scale() -> float:
	var wm = Engine.get_main_loop().root.get_node_or_null("WaterManager") if Engine.get_main_loop() else null
	if wm == null:
		return 1.0
	return [0.35, 0.65, 1.0][wm.quality]


static func droplet_material() -> ShaderMaterial:
	if _droplet_mat == null:
		_droplet_mat = ShaderMaterial.new()
		_droplet_mat.shader = DROPLET_SHADER
	return _droplet_mat


static func mist_material() -> ShaderMaterial:
	if _mist_mat == null:
		_mist_mat = ShaderMaterial.new()
		_mist_mat.shader = MIST_SHADER
	return _mist_mat


## Gocce: quad allungato (larghezza, lunghezza in m) allineato alla velocita'.
static func make_droplets(amount: int, lifetime: float, drop_size := Vector2(0.018, 0.05)) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = maxi(1, int(amount * quality_scale()))
	gp.lifetime = lifetime
	gp.local_coords = false
	gp.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_align_y = true
	pm.gravity = Vector3(0, -9.8, 0)
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.75, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	gp.process_material = pm
	var qm := QuadMesh.new()
	qm.size = drop_size
	qm.material = droplet_material()
	gp.draw_pass_1 = qm
	return gp


## Spruzzo nebulizzato: sprite morbidi che si allargano e svaniscono.
static func make_mist(amount: int, lifetime: float, size := 0.5) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = maxi(1, int(amount * quality_scale()))
	gp.lifetime = lifetime
	gp.local_coords = false
	gp.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.15, Color(1, 1, 1, 1.0))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	gp.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = mist_material()
	gp.draw_pass_1 = qm
	return gp

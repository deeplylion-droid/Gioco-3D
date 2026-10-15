class_name WaterSplash
extends Node3D
## Schizzo una tantum nel punto in cui un oggetto entra in acqua: corona di gocce, colonna
## centrale e sbuffo nebulizzato. Si libera da solo alla fine. La usa WaterBody.splash().

var strength := 1.0
var _parts: Array[GPUParticles3D] = []


func play(s: float) -> void:
	strength = clampf(s, 0.05, 3.0)
	var k := strength
	# corona: gocce che partono di lato e in alto
	var crown := WaterParticles.make_droplets(int(40 + 70 * k), 0.9 + 0.3 * k)
	var pm: ParticleProcessMaterial = crown.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.06 + 0.1 * k
	pm.emission_ring_inner_radius = 0.03 * k
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 1.2 + 1.2 * k
	pm.initial_velocity_max = 2.4 + 2.2 * k
	pm.radial_velocity_min = 0.4 * k
	pm.radial_velocity_max = 1.2 * k
	_add(crown)
	# colonna centrale (il "rimbalzo" dell'acqua)
	if k > 0.35:
		var col := WaterParticles.make_droplets(int(20 + 40 * k), 1.0 + 0.3 * k, Vector2(0.024, 0.07))
		var pc: ParticleProcessMaterial = col.process_material
		pc.direction = Vector3.UP
		pc.spread = 9.0
		pc.initial_velocity_min = 2.0 + 1.5 * k
		pc.initial_velocity_max = 3.4 + 2.6 * k
		pc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pc.emission_sphere_radius = 0.04
		col.preprocess = 0.0
		_add(col)
	# sbuffo
	var mist := WaterParticles.make_mist(int(6 + 10 * k), 1.4 + 0.6 * k, 0.35 + 0.25 * k)
	var pmm: ParticleProcessMaterial = mist.process_material
	pmm.direction = Vector3.UP
	pmm.spread = 70.0
	pmm.initial_velocity_min = 0.3 * k
	pmm.initial_velocity_max = 1.0 + 0.8 * k
	pmm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmm.emission_sphere_radius = 0.1 * k
	_add(mist)
	var life := 0.0
	for p in _parts:
		life = maxf(life, p.lifetime)
	get_tree().create_timer(life + 0.5).timeout.connect(queue_free)


func _add(p: GPUParticles3D) -> void:
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = true
	add_child(p)
	_parts.append(p)

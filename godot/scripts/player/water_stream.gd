class_name WaterStream
extends MeshInstance3D
## Getto d'acqua continuo. L'acqua è una catena di "pezzetti" che escono dall'ugello a ogni
## tick di fisica e volano ognuno sulla propria parabola (come particelle): così il getto si
## piega quando si gira lo sguardo, il fronte avanza quando si comincia a spruzzare e la coda
## si stacca e cade quando si smette. La catena si disegna come un nastro rivolto alla camera
## (shader water_stream.gdshader, che lo illumina come un cilindro).
## Lo comanda WaterPack: physics_step() a ogni tick, il disegno avviene in _process().

## Un pezzetto ha colpito qualcosa (per lo schizzo e i suoni).
signal impact(point: Vector3, normal: Vector3)

@export var gravity := 9.8
## Secondi di volo massimi: poi l'acqua si sfalda e sparisce.
@export var max_age := 1.1
## Raggio del getto all'uscita (m) e quanto si allarga al secondo di volo.
@export var radius_start := 0.0075
@export var radius_growth := 0.03
## Livelli che fermano il getto (come quelli del gioco).
@export_flags_3d_physics var collision_mask := 45
## Suddivisioni fra due pezzetti (curva Catmull-Rom): più alto = più liscio.
@export_range(1, 6) var subdivisions := 3
## Quanta strada fa l'acqua prima di sfaldarsi del tutto (frazione di max_age).
@export_range(0.3, 1.0) var breakup_start := 0.62

## Il nodo da cui esce l'acqua: si usa la sua posizione di ogni frame (con l'ondeggiamento).
var muzzle: Node3D
var exclude: Array[RID] = []
var emitting := false

# Pezzetti: dal più vecchio (indice 0) al più nuovo.
var _pos := PackedVector3Array()
var _prev := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _birth := PackedFloat32Array()
## 0 = in volo, 1 = ha colpito in questo tick (ultimo disegno), 2 = da togliere.
var _state := PackedByteArray()
## 1 = non è collegato al pezzetto più vecchio (il getto era stato interrotto).
var _break := PackedByteArray()
var _time := 0.0
var _was_emitting := false
var _mesh := ArrayMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	if material_override == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/water_stream.gdshader")
		material_override = m


func is_active() -> bool:
	return emitting or not _pos.is_empty()


## Un tick di fisica: muove l'acqua in volo, controlla gli urti e, se [param emit], fa uscire
## un nuovo pezzetto da [param origin] con velocità [param velocity].
func physics_step(delta: float, emit: bool, origin: Vector3, velocity: Vector3) -> void:
	_time += delta
	emitting = emit
	var g := Vector3(0.0, -gravity, 0.0)
	var space := get_world_3d().direct_space_state
	var catchers := get_tree().get_nodes_in_group(&"water_catchers")
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = collision_mask
	q.collide_with_areas = true
	q.exclude = exclude
	for i in _pos.size():
		if _state[i] != 0:
			_state[i] = 2
			continue
		var a := _pos[i]
		var v := _vel[i] + g * delta
		var b := a + v * delta
		_prev[i] = a
		_vel[i] = v
		_age[i] += delta
		if _age[i] >= max_age:
			_pos[i] = b
			_state[i] = 2
			continue
		q.from = a
		q.to = b
		var hit := space.intersect_ray(q)
		var best := 2.0
		var hit_n := Vector3.UP
		if not hit.is_empty():
			best = a.distance_to(hit.position) / maxf(a.distance_to(b), 0.0001)
			hit_n = hit.normal
		for c in catchers:
			var f: float = c.surface_hit_fraction(a, b)
			if f >= 0.0 and f < best:
				best = f
				hit_n = Vector3.UP
		if best <= 1.0:
			b = a.lerp(b, best)
			_state[i] = 1
			impact.emit(b, hit_n)
		_pos[i] = b
	_remove_dead()
	if emit:
		# Il nuovo pezzetto parte già spostato di un tick, così si interpola senza scatti.
		var v1 := velocity + g * delta
		_pos.append(origin + velocity * delta + 0.5 * g * delta * delta)
		_prev.append(origin)
		_vel.append(v1)
		_age.append(delta)
		_birth.append(_time)
		_state.append(0)
		_break.append(1 if not _was_emitting else 0)
	_was_emitting = emit


func _remove_dead() -> void:
	var i := 0
	while i < _pos.size():
		if _state[i] == 2:
			# Il pezzetto più nuovo resta senza il vecchio: la catena si spezza lì.
			if i + 1 < _pos.size():
				_break[i + 1] = 1
			_pos.remove_at(i)
			_prev.remove_at(i)
			_vel.remove_at(i)
			_age.remove_at(i)
			_birth.remove_at(i)
			_state.remove_at(i)
			_break.remove_at(i)
		else:
			i += 1


## Toglie tutta l'acqua in volo (per esempio dopo un teletrasporto).
func clear() -> void:
	_pos.clear()
	_prev.clear()
	_vel.clear()
	_age.clear()
	_birth.clear()
	_state.clear()
	_break.clear()
	_mesh.clear_surfaces()


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if _pos.is_empty() and not emitting:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var arrays := RibbonArrays.new()
	# Catene dal più nuovo al più vecchio.
	var pts := PackedVector3Array()
	var ages := PackedFloat32Array()
	var births := PackedFloat32Array()
	var i := _pos.size() - 1
	var first_chain := true
	while i >= 0 or (first_chain and emitting):
		pts.clear()
		ages.clear()
		births.clear()
		if first_chain and emitting and muzzle and (i < 0 or _break[i] == 0 or _age[i] <= dt * 1.5):
			pts.append(muzzle.global_position)
			ages.append(0.0)
			births.append(_time + f * dt)
		first_chain = false
		while i >= 0:
			pts.append(_prev[i].lerp(_pos[i], f))
			ages.append(_age[i] - dt + f * dt)
			births.append(_birth[i])
			var brk := _break[i] == 1
			i -= 1
			if brk:
				break
		if pts.size() >= 2:
			_add_chain(arrays, pts, ages, births, cam.global_position)
	if arrays.count() > 0:
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays.to_arrays())


func _add_chain(arrays: RibbonArrays, pts: PackedVector3Array, ages: PackedFloat32Array,
		births: PackedFloat32Array, cam: Vector3) -> void:
	# Curva liscia (Catmull-Rom) fra i pezzetti.
	var n := pts.size()
	var sp := PackedVector3Array()
	var sa := PackedFloat32Array()
	var sb := PackedFloat32Array()
	for k in n - 1:
		var p0 := pts[maxi(k - 1, 0)]
		var p1 := pts[k]
		var p2 := pts[k + 1]
		var p3 := pts[mini(k + 2, n - 1)]
		var steps := subdivisions if k > 0 else 1
		for s in steps:
			var t := float(s) / float(steps)
			sp.append(_catmull(p0, p1, p2, p3, t))
			sa.append(lerpf(ages[k], ages[k + 1], t))
			sb.append(lerpf(births[k], births[k + 1], t))
	sp.append(pts[n - 1])
	sa.append(ages[n - 1])
	sb.append(births[n - 1])
	var m := sp.size()
	var radii := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	var lengths := PackedFloat32Array()
	radii.resize(m)
	alphas.resize(m)
	lengths.resize(m)
	var head_age := sa[m - 1]
	var tail_age := sa[0]
	for k in m:
		var age := sa[k]
		radii[k] = radius_start + radius_growth * age
		# Sparisce sfaldandosi verso la fine del volo e alle due estremità staccate.
		var life := 1.0 - smoothstep(breakup_start * max_age, max_age, age)
		var to_head := clampf((head_age - age) / 0.05, 0.0, 1.0)
		var to_tail := 1.0 if tail_age <= 0.001 else clampf((age - tail_age) / 0.05, 0.0, 1.0)
		alphas[k] = life * lerpf(0.35, 1.0, to_head) * lerpf(0.35, 1.0, to_tail)
		lengths[k] = sb[k] * 15.0
	arrays.add_ribbon(sp, radii, alphas, lengths, cam)


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

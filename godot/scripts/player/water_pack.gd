class_name WaterPack
extends Node3D
## Zaino-pompa "Z1": una vera pompa con serbatoio.
##  - Tasto destro ("suck"): ASPIRA l'acqua puntando una superficie d'acqua o una vasca vicina
##    (raggio limitato, [member suck_range]); il livello di quella vasca scende davvero.
##  - Tasto sinistro ("spray"): SPRUZZA, solo se nel serbatoio c'è acqua.
##  - Nell'acqua che scorre (FlowingWater, per esempio negli scivoli) il serbatoio si ricarica.
## Il getto: particelle GPU per la grafica e una parabola di raggi per trovare cosa colpisce.
##  - WaterHitbox colpiti: ricevono i litri (turbine, pulsanti, nemici).
##  - Corpi rigidi: vengono spinti.
##  - Nodi del gruppo "water_catchers" (le vasche): l'acqua che ci cade dentro le riempie
##    (i litri si conservano), e il getto si ferma sulla loro superficie.
##  - In aria, puntando in basso, il getto spinge verso l'alto (con limiti).
## L'aspetto dello zaino e dell'indicatore del serbatoio è ancora da decidere: qui c'è un
## segnaposto (la lancia grigia e una barretta nell'HUD).

signal spray_started
signal spray_stopped
signal suck_started
signal suck_stopped
## Il getto ha colpito qualcosa in questo tick (per suoni ed effetti).
signal jet_hit(collider: Object, point: Vector3, normal: Vector3)
signal tank_changed(amount: float, capacity: float)
## Si è provato a spruzzare (o si sta spruzzando) con il serbatoio vuoto.
signal tank_empty
## Si sta aspirando con il serbatoio pieno.
signal tank_full

@export_group("Nodi")
## Il modello della lancia (figlio della camera): viene orientato verso il punto di convergenza.
@export var view_model: Node3D
## Punta della lancia: da qui esce l'acqua (-Z).
@export var muzzle: Node3D
@export var jet_particles: GPUParticles3D
@export var splash_particles: GPUParticles3D
@export var suction_particles: GPUParticles3D

@export_group("Getto")
## Litri al secondo che escono dalla lancia.
@export var flow_rate := 6.0
## Velocità dell'acqua all'uscita della lancia (m/s).
@export var jet_speed := 15.0
@export var jet_gravity := 9.8
## Tempo massimo di volo dell'acqua (s): insieme alla velocità decide la gittata.
@export var jet_max_time := 1.1
## Numero di raggi lungo la parabola.
@export_range(4, 48) var jet_segments := 18
## Secondi per arrivare al getto pieno dopo aver premuto.
@export var spin_up_time := 0.12
## Distanza a cui il getto incrocia il mirino (m).
@export var converge_distance := 6.0
## Impulso dato ai corpi rigidi per ogni litro (N·s).
@export var push_impulse := 4.0
## Livelli colpiti dal getto: mondo, nemici, oggetti, bersagli_acqua.
@export_flags_3d_physics var jet_collision_mask := 45
## Quanta velocità del giocatore passa all'acqua appena uscita (0..1).
@export_range(0.0, 1.0) var inherit_player_velocity := 0.8

@export_group("Aspirazione")
@export var suck_enabled := true
## Litri al secondo aspirati.
@export var suck_rate := 10.0
## Distanza massima da cui si aspira (m), misurata dagli occhi.
@export var suck_range := 3.5
## Livelli che bloccano l'aspirazione: mondo, nemici, oggetti.
@export_flags_3d_physics var suck_collision_mask := 13

@export_group("Spinta verso l'alto")
@export var boost_enabled := true
## Accelerazione verso l'alto con la lancia puntata dritta in basso (m/s²).
@export var boost_acceleration := 16.0
## Quanto bisogna puntare in basso: 0 = orizzontale, 1 = dritto in basso.
@export_range(0.0, 1.0) var boost_min_down := 0.55
## Velocità verso l'alto massima data dalla spinta (m/s).
@export var boost_max_up_speed := 2.5
## Secondi di spinta per ogni salto: si ricaricano toccando terra.
@export var boost_air_time := 0.35

@export_group("Serbatoio")
## Se falso l'acqua non finisce mai (utile per provare le meccaniche).
@export var tank_enabled := true
## Capienza del serbatoio (litri).
@export var tank_capacity := 20.0
## Acqua all'inizio del livello (litri).
@export var tank_start_amount := 20.0

## Litri nel serbatoio.
var tank_amount := 0.0
var is_spraying := false
var is_sucking := false
## Rampa del getto: 0..1.
var flow := 0.0
var has_hit := false
var hit_point := Vector3.ZERO
var hit_normal := Vector3.UP
var hit_collider: Object = null
## Secondi di volo dell'acqua fino al punto d'impatto.
var hit_time := 0.0
var boost_left := 0.0
## Da dove si sta aspirando (un nodo del gruppo "water_sources") e il punto puntato.
var suck_source = null
var suck_point := Vector3.ZERO
var player: Player

var _front_time := 0.0
## Litri usciti dalla lancia ma non ancora arrivati al bersaglio.
var _in_flight := 0.0
var _v0 := Vector3.ZERO
var _muzzle_local := Transform3D.IDENTITY
var _jet_material: ShaderMaterial
var _suction_material: ShaderMaterial
var _full_notified := false


func setup(p: Player) -> void:
	player = p
	tank_amount = clampf(tank_start_amount, 0.0, tank_capacity)
	boost_left = boost_air_time
	if view_model:
		view_model.basis = Basis.looking_at(Vector3(0.0, 0.0, -converge_distance) - view_model.position, Vector3.UP)
	if muzzle:
		_muzzle_local = p.camera.global_transform.affine_inverse() * muzzle.global_transform
	if jet_particles:
		jet_particles.emitting = false
		_jet_material = jet_particles.process_material as ShaderMaterial
	for fx in [splash_particles, suction_particles]:
		var particles := fx as GPUParticles3D
		if particles:
			particles.top_level = true
			particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			particles.emitting = false
	if suction_particles:
		_suction_material = suction_particles.process_material as ShaderMaterial
	_apply_jet_parameters()


## Aggiorna le particelle dopo aver cambiato velocità, gravità o gittata del getto.
func _apply_jet_parameters() -> void:
	if _jet_material:
		_jet_material.set_shader_parameter(&"speed", jet_speed)
		_jet_material.set_shader_parameter(&"gravity", Vector3(0.0, -jet_gravity, 0.0))
		_jet_material.set_shader_parameter(&"max_age", jet_max_time)
	if jet_particles:
		jet_particles.lifetime = jet_max_time + 0.05


## Trasformazione della punta della lancia, calcolata dallo sguardo "logico" del giocatore.
func get_muzzle_transform() -> Transform3D:
	return player.get_aim_transform() * _muzzle_local


func has_water() -> bool:
	return not tank_enabled or tank_amount > 0.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var can_act := player.input_enabled and not player.is_on_ladder()
	var want_suck := suck_enabled and can_act and Input.is_action_pressed("suck")
	var want_spray := can_act and Input.is_action_pressed("spray") and not want_suck
	if want_spray and not has_water():
		if is_spraying or Input.is_action_just_pressed("spray"):
			tank_empty.emit()
		want_spray = false
	_update_spray_state(want_spray)
	flow = move_toward(flow, 1.0 if is_spraying else 0.0, delta / maxf(spin_up_time, 0.001))
	if player.is_on_floor() or player.is_on_ladder():
		boost_left = boost_air_time
	if is_spraying:
		_front_time += delta
		var m := get_muzzle_transform()
		var dir := -m.basis.z
		_v0 = dir * jet_speed
		_trace(player.get_eye_position(), m.origin, _v0)
		var liters := flow_rate * flow * delta
		if tank_enabled:
			liters = minf(liters, tank_amount)
			_set_amount(tank_amount - liters)
		# L'acqua arriva quando il fronte del getto raggiunge il bersaglio: nel frattempo
		# resta "in volo" e poi arriva tutta (i litri si conservano).
		_in_flight += liters
		if has_hit and _front_time >= hit_time:
			_deliver(_in_flight)
			_in_flight = 0.0
		_apply_boost(dir, delta)
	else:
		has_hit = false
		hit_collider = null
	_update_suction(want_suck, delta)
	_refill_from_flowing_water(delta)
	_update_visuals()


func _update_spray_state(want: bool) -> void:
	if want and not is_spraying:
		is_spraying = true
		_front_time = 0.0
		spray_started.emit()
	elif not want and is_spraying:
		is_spraying = false
		# L'acqua ancora in volo cade dove stava andando.
		if has_hit:
			_deliver(_in_flight)
		_in_flight = 0.0
		spray_stopped.emit()


# --- Getto ----------------------------------------------------------------------------------

func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, mask: int, areas: bool) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, mask, [player.get_rid()])
	q.collide_with_areas = areas
	return space.intersect_ray(q)


## Segue la parabola dell'acqua e trova il primo impatto.
func _trace(eye: Vector3, start: Vector3, v0: Vector3) -> void:
	has_hit = false
	hit_collider = null
	var space := player.get_world_3d().direct_space_state
	# Dagli occhi alla punta della lancia: niente getto attraverso i muri.
	var first := _ray(space, eye, start, jet_collision_mask, true)
	if not first.is_empty():
		_set_hit(first.position, first.normal, first.collider, 0.0)
		return
	var g := Vector3(0.0, -jet_gravity, 0.0)
	var dt := jet_max_time / float(jet_segments)
	var catchers := get_tree().get_nodes_in_group(&"water_catchers")
	var prev := start
	for i in range(1, jet_segments + 1):
		var t := dt * i
		var p := start + v0 * t + 0.5 * g * t * t
		var best := 2.0
		var r := _ray(space, prev, p, jet_collision_mask, true)
		if not r.is_empty():
			best = prev.distance_to(r.position) / maxf(prev.distance_to(p), 0.0001)
		var surface_catcher: Node = null
		for c in catchers:
			var f: float = c.surface_hit_fraction(prev, p)
			if f >= 0.0 and f < best:
				best = f
				surface_catcher = c
		if best <= 1.0:
			var time := t - dt + dt * best
			if surface_catcher:
				_set_hit(prev.lerp(p, best), Vector3.UP, surface_catcher, time)
			else:
				_set_hit(r.position, r.normal, r.collider, time)
			return
		prev = p
	hit_time = jet_max_time


func _set_hit(point: Vector3, normal: Vector3, collider: Object, time: float) -> void:
	has_hit = true
	hit_point = point
	hit_normal = normal if normal.length_squared() > 0.0001 else Vector3.UP
	hit_collider = collider
	hit_time = time


func _deliver(liters: float) -> void:
	if liters <= 0.0:
		return
	var dir := (_v0 + Vector3(0.0, -jet_gravity, 0.0) * hit_time).normalized()
	jet_hit.emit(hit_collider, hit_point, hit_normal)
	if hit_collider is WaterHitbox:
		(hit_collider as WaterHitbox).receive_water(liters, hit_point, dir)
	elif hit_collider is RigidBody3D:
		var body := hit_collider as RigidBody3D
		body.apply_impulse(dir * push_impulse * liters, hit_point - body.global_position)
	for c in get_tree().get_nodes_in_group(&"water_catchers"):
		if c.catches_point(hit_point):
			c.receive_water(liters, hit_point, dir)


func _apply_boost(dir: Vector3, delta: float) -> void:
	if not boost_enabled or player.is_on_floor() or player.is_on_ladder():
		return
	var down := -dir.y
	if down < boost_min_down or boost_left <= 0.0:
		return
	var vy := player.velocity.y
	if vy < boost_max_up_speed:
		boost_left -= delta
		player.velocity.y = minf(vy + boost_acceleration * down * flow * delta, boost_max_up_speed)


# --- Aspirazione ---------------------------------------------------------------------------

func _update_suction(want: bool, delta: float) -> void:
	var source = null
	if want:
		if tank_enabled and tank_amount >= tank_capacity - 0.001:
			if not _full_notified:
				_full_notified = true
				tank_full.emit()
		else:
			source = find_suction_source()
	if source and not is_sucking:
		is_sucking = true
		suck_started.emit()
	elif source == null and is_sucking:
		is_sucking = false
		suck_stopped.emit()
	suck_source = source
	if source == null:
		return
	var room := tank_capacity - tank_amount if tank_enabled else suck_rate * delta
	var got: float = source.take_water(minf(suck_rate * delta, room))
	if tank_enabled and got > 0.0:
		_set_amount(tank_amount + got)


## Cerca da dove aspirare lungo lo sguardo: la superficie di una vasca o di un volume
## d'acqua, oppure la vasca stessa (muri e fondo), entro suck_range e senza muri in mezzo.
func find_suction_source():
	var aim := player.get_aim_transform()
	var from := aim.origin
	var to := from - aim.basis.z * suck_range
	var space := player.get_world_3d().direct_space_state
	var best := 1.0
	var best_source = null
	var best_point := to
	var hit := _ray(space, from, to, suck_collision_mask, false)
	if not hit.is_empty():
		best = from.distance_to(hit.position) / maxf(suck_range, 0.0001)
		best_point = hit.position
		best_source = _source_owning(hit.collider as Node)
	for s in get_tree().get_nodes_in_group(&"water_sources"):
		var f: float = s.suction_hit_fraction(from, to)
		if f >= 0.0 and f <= best:
			best = f
			best_source = s
			best_point = from.lerp(to, f)
	if best_source and best_source.can_give_water():
		suck_point = best_point
		if best_source.has_method(&"suction_visual_point"):
			suck_point = best_source.suction_visual_point(best_point)
		return best_source
	return null


func _source_owning(node: Node) -> Node:
	var n := node
	for i in 4:
		if n == null:
			return null
		if n.is_in_group(&"water_sources"):
			return n
		n = n.get_parent()
	return null


func _refill_from_flowing_water(delta: float) -> void:
	if not tank_enabled or tank_amount >= tank_capacity:
		return
	var rate := 0.0
	for area in player.sensor.get_overlapping_areas():
		var fw := area as FlowingWater
		if fw and fw.get_surface_height() > player.global_position.y + 0.02:
			rate = maxf(rate, fw.refill_rate)
	if rate > 0.0:
		refill(rate * delta)


# --- Serbatoio -----------------------------------------------------------------------------

## Aggiunge acqua al serbatoio (litri).
func refill(liters: float) -> void:
	_set_amount(tank_amount + liters)


func set_tank_amount(liters: float) -> void:
	_set_amount(liters)


func _set_amount(liters: float) -> void:
	var v := clampf(liters, 0.0, tank_capacity)
	if is_equal_approx(v, tank_amount):
		return
	if v < tank_amount:
		_full_notified = false
	tank_amount = v
	tank_changed.emit(tank_amount, tank_capacity)


# --- Grafica -------------------------------------------------------------------------------

func _update_visuals() -> void:
	if jet_particles:
		jet_particles.emitting = is_spraying
		if _jet_material:
			_jet_material.set_shader_parameter(&"max_age", hit_time if has_hit else jet_max_time)
			_jet_material.set_shader_parameter(&"inherit_velocity", player.velocity * inherit_player_velocity)
	if splash_particles:
		var show := is_spraying and has_hit and _front_time >= hit_time
		splash_particles.emitting = show
		if show:
			splash_particles.global_transform = Transform3D(_basis_from_normal(hit_normal), hit_point + hit_normal * 0.03)
	if suction_particles:
		suction_particles.emitting = is_sucking
		if is_sucking:
			suction_particles.global_position = suck_point
			if _suction_material and muzzle:
				_suction_material.set_shader_parameter(&"target", muzzle.global_position)


static func _basis_from_normal(n: Vector3) -> Basis:
	var y := n.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

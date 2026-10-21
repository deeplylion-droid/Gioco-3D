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
## Il colore dell'acqua nel serbatoio è cambiato (vedi WaterMix): lo seguono la finestrella
## della lancia e il getto.
signal water_mix_changed(mix: Dictionary)
## Si è provato a spruzzare (o si sta spruzzando) con il serbatoio vuoto.
signal tank_empty
## Si sta aspirando con il serbatoio pieno.
signal tank_full
## Si è premuto per spruzzare e la pressione sta salendo ([member spray_delay] prima del getto).
signal spray_charge_started

@export_group("Nodi")
## Il modello della lancia (figlio della camera): viene orientato verso il punto di convergenza.
@export var view_model: Node3D
## Punta della lancia: da qui esce l'acqua (-Z).
@export var muzzle: Node3D
@export var jet_particles: GPUParticles3D
@export var splash_particles: GPUParticles3D
@export var suction_particles: GPUParticles3D
## Lancia 3D con le mani (una scena LanceRig con un nodo "Muzzle" sulla punta). Se c'è,
## sostituisce la lancia grigia di prova. L'aspetto dello zaino lo sceglie l'utente.
@export var lance_scene: PackedScene
## Dove sta la punta della lancia 3D rispetto alla camera.
@export var lance_offset := Vector3(0.16, -0.25, -0.92)
## Distanza sotto cui la lancia si ritrae (per non entrare nei muri).
@export var lance_pullback_distance := 1.05
## Schizzi e gocce aspirate fatti da questo script. Con l'addon acqua (EffettiZaino) li fa
## l'addon, quindi qui restano spenti.
@export var legacy_fx := false

@export_group("Movimento dell'oggetto in mano")
## Ondeggiamento col passo (m).
@export var hold_bob := Vector2(0.012, 0.01)
## Quanto l'oggetto resta indietro quando giri lo sguardo.
@export var hold_sway := 0.35
## Rinculo quando spruzzi (m all'indietro) e vibrazione (m).
@export var spray_kick := 0.014
@export var spray_shake := 0.0022
## Vibrazione quando aspiri (m).
@export var suck_shake := 0.0016

## Se falso il giocatore parte senza zaino: niente getto né aspirazione, niente pistola in mano
## finché non lo raccoglie (PackPickup).
@export var start_equipped := true

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
## Attimo di carica prima del getto (s): la pressione sale, poi parte il colpo (0 = subito).
@export var spray_delay := 0.0
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
## Dopo un salto dallo scivolo (sala della torre) la spinta dura di più e tiene su: allunga il salto.
@export var slide_boost_time := 0.8
## Dopo un salto dallo scivolo la spinta non fa salire: frena la caduta fino a questa velocità
## verticale (m/s, negativa = si scende piano, come planando).
@export var slide_boost_max_up_speed := -1.0
## Accelerazione della spinta dopo un salto dallo scivolo (m/s², con la lancia dritta in basso).
@export var slide_boost_acceleration := 19.0
## Spinta in avanti, nel verso del volo, mentre si spinge dopo un salto dallo scivolo (m/s²).
@export var slide_boost_forward := 1.5
## Litri al secondo in più consumati dalla spinta dopo un salto dallo scivolo.
@export var slide_boost_extra_flow := 7.0

@export_group("Serbatoio")
enum TankIndicator { HUD_BAR, LANCE, NONE }
## Se falso l'acqua non finisce mai (utile per provare le meccaniche).
@export var tank_enabled := true
## Come si vede quanta acqua c'è (scelta di design, da decidere con l'utente):
## barra nell'HUD, tubetto di vetro sulla lancia, oppure niente.
@export var tank_indicator := TankIndicator.HUD_BAR
## Capienza del serbatoio (litri).
@export var tank_capacity := 20.0
## Acqua all'inizio del livello (litri).
@export var tank_start_amount := 20.0

## Litri nel serbatoio.
var tank_amount := 0.0
## Il colore dell'acqua nel serbatoio (WaterMix): si mescola per litri aspirando.
var water_mix := {}
var _charge_t := 0.0
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
## Vero nei passi in cui la spinta sta tenendo su il giocatore (dopo un salto dallo scivolo).
var boosting := false
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
var _vm_base := Vector3.ZERO
var _vm_basis := Basis.IDENTITY
var _pullback := 0.0
var _sway := Vector2.ZERO
var _last_look := Vector2.ZERO
var _kick := 0.0
var _equip_t := 1.0
var lance_rig: Node3D
## Vero quando il giocatore ha lo zaino addosso.
var equipped := true
## Il getto continuo (nastro d'acqua) e il filo d'acqua dell'aspirazione.
var stream: WaterStream
var suction_stream: SuctionStream
var _last_impact_time := -1.0
var _last_impact_point := Vector3.ZERO
var _last_impact_normal := Vector3.UP
var _clock := 0.0
## Materiale dell'acqua da cui si sta aspirando (per gli anelli sulla superficie).
var _suck_mat: ShaderMaterial


func setup(p: Player) -> void:
	player = p
	tank_amount = clampf(tank_start_amount, 0.0, tank_capacity)
	boost_left = boost_air_time
	if view_model and lance_scene:
		_use_lance_scene()
	if view_model:
		_vm_base = view_model.position
		view_model.basis = Basis.looking_at(Vector3(0.0, 0.0, -converge_distance) - view_model.position, Vector3.UP)
		_vm_basis = view_model.basis
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
	# Le particelle restano come goccioline fini intorno al getto continuo.
	if _jet_material:
		_jet_material.set_shader_parameter(&"base_size", 0.011)
		_jet_material.set_shader_parameter(&"size_growth", 0.028)
		_jet_material.set_shader_parameter(&"stretch", 0.018)
		_jet_material.set_shader_parameter(&"spread_degrees", 2.2)
		_jet_material.set_shader_parameter(&"color", Color(0.82, 0.92, 1.0, 0.55))
	if jet_particles:
		jet_particles.amount = 220
	stream = WaterStream.new()
	stream.name = "Getto"
	stream.gravity = jet_gravity
	stream.max_age = jet_max_time
	stream.collision_mask = jet_collision_mask
	stream.exclude = [p.get_rid()]
	add_child(stream)
	stream.impact.connect(_on_stream_impact)
	suction_stream = SuctionStream.new()
	suction_stream.name = "Aspirazione"
	add_child(suction_stream)
	_update_stream_muzzle()
	_apply_jet_parameters()
	set_equipped(start_equipped, false)


func _update_stream_muzzle() -> void:
	if stream:
		stream.muzzle = muzzle
	if suction_stream:
		suction_stream.muzzle = muzzle


func _on_stream_impact(point: Vector3, normal: Vector3) -> void:
	_last_impact_time = _clock
	_last_impact_point = point
	_last_impact_normal = normal


## Mette o toglie lo zaino. Con [param animate] la pistola sale dal basso.
func set_equipped(on: bool, animate := true) -> void:
	equipped = on
	if view_model:
		view_model.visible = on
	if on and animate:
		_equip_t = 0.0
	if not on:
		_update_spray_state(false)
		is_sucking = false


## Cambia la lancia 3D (per esempio per provare le opzioni di design).
func set_lance(scene: PackedScene) -> void:
	if jet_particles and lance_rig:
		jet_particles.reparent(view_model, false)
	if lance_rig:
		lance_rig.queue_free()
		lance_rig = null
	lance_scene = scene
	if scene:
		_use_lance_scene()
		_vm_base = view_model.position
		view_model.basis = Basis.looking_at(Vector3(0.0, 0.0, -converge_distance) - view_model.position, Vector3.UP)
		_vm_basis = view_model.basis
		_muzzle_local = player.camera.global_transform.affine_inverse() * muzzle.global_transform
	_update_stream_muzzle()


func _use_lance_scene() -> void:
	lance_rig = lance_scene.instantiate() as Node3D
	var new_muzzle := lance_rig.get_node_or_null(^"Muzzle") as Node3D
	if new_muzzle == null:
		push_warning("La scena della lancia non ha un nodo Muzzle")
		lance_rig.free()
		lance_rig = null
		return
	for c in view_model.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = false
	view_model.add_child(lance_rig)
	var off = lance_rig.get(&"view_offset")
	view_model.position = off if off is Vector3 else lance_offset
	if jet_particles:
		jet_particles.reparent(new_muzzle, false)
	muzzle = new_muzzle


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


func _process(delta: float) -> void:
	if player == null or view_model == null:
		return
	# La lancia si ritrae se davanti c'è un muro troppo vicino.
	var aim := player.get_aim_transform()
	var q := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin - aim.basis.z * lance_pullback_distance,
			Layers.WORLD | Layers.PROPS | Layers.ENEMIES, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target := 0.0
	if not hit.is_empty():
		target = lance_pullback_distance - aim.origin.distance_to(hit.position)
	_pullback = lerpf(_pullback, target, 1.0 - exp(-12.0 * delta))
	# Resta un po' indietro quando giri lo sguardo, poi torna al centro.
	var look := Vector2(player.yaw, player.pitch)
	var d := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y)
	_last_look = look
	_sway = (_sway + d * hold_sway).limit_length(0.06)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	# Rinculo e vibrazione quando spruzza o aspira.
	_kick = lerpf(_kick, 1.0 if is_spraying else 0.0, 1.0 - exp(-(18.0 if is_spraying else 7.0) * delta))
	var shake := spray_shake * flow if is_spraying else (suck_shake if is_sucking else 0.0)
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake
	var bob := player.get_step_bob()
	# Comparsa quando si prende lo zaino: sale dal basso.
	_equip_t = minf(1.0, _equip_t + delta / 0.6)
	var raise := 1.0 - _ease_out(_equip_t)
	var offset := Vector3(bob.x * hold_bob.x - _sway.x * 0.25, bob.y * hold_bob.y + _sway.y * 0.25 - raise * 0.35, 0.0)
	offset += Vector3(0.0, -0.25 * _pullback, _pullback + _kick * spray_kick) + jitter
	view_model.position = _vm_base + offset
	var tilt := Basis.from_euler(Vector3(_kick * 0.02 - raise * 0.6 + _sway.y * 0.6, _sway.x * 0.8, -_sway.x * 0.5))
	view_model.basis = _vm_basis * tilt


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var can_act := equipped and player.input_enabled and not player.is_on_ladder()
	var want_suck := suck_enabled and can_act and Input.is_action_pressed("suck")
	var want_spray := can_act and Input.is_action_pressed("spray") and not want_suck
	# Carica: tenendo premuto, il getto parte dopo spray_delay secondi.
	if want_spray and not is_spraying and spray_delay > 0.0 and has_water():
		if _charge_t == 0.0:
			spray_charge_started.emit()
		_charge_t += delta
		if _charge_t < spray_delay:
			want_spray = false
	elif not want_spray:
		_charge_t = 0.0
	if want_spray and not has_water():
		if is_spraying or Input.is_action_just_pressed("spray"):
			tank_empty.emit()
		want_spray = false
	_update_spray_state(want_spray)
	flow = move_toward(flow, 1.0 if is_spraying else 0.0, delta / maxf(spin_up_time, 0.001))
	if player.is_on_floor() or player.is_on_ladder():
		boost_left = boost_air_time
	elif player.is_sliding:
		boost_left = slide_boost_time
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
		boosting = false
		_apply_boost(dir, delta)
	else:
		boosting = false
		has_hit = false
		hit_collider = null
	_update_suction(want_suck, delta)
	_refill_from_flowing_water(delta)
	_clock += delta
	if stream and muzzle:
		var inherit := player.velocity * inherit_player_velocity
		stream.physics_step(delta, is_spraying and flow > 0.05, muzzle.global_position, _v0 * maxf(flow, 0.6) + inherit)
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
			if c is WaterTank:
				(c as WaterTank).receive_water(liters, hit_point, dir, water_mix)
			else:
				c.receive_water(liters, hit_point, dir)


func _apply_boost(dir: Vector3, delta: float) -> void:
	if not boost_enabled or player.is_on_floor() or player.is_on_ladder() or player.is_sliding:
		return
	var down := -dir.y
	if down < boost_min_down or boost_left <= 0.0:
		return
	var vy := player.velocity.y
	if player.slide_launched:
		# In volo dallo scivolo: la spinta tiene su e porta avanti, e beve molta acqua.
		boost_left -= delta
		if vy < slide_boost_max_up_speed:
			player.velocity.y = minf(vy + slide_boost_acceleration * down * flow * delta, slide_boost_max_up_speed)
		var hv := Vector3(player.velocity.x, 0.0, player.velocity.z)
		if hv.length() > 0.1:
			player.velocity += hv.normalized() * slide_boost_forward * flow * delta
		if tank_enabled:
			_set_amount(maxf(tank_amount - slide_boost_extra_flow * flow * delta, 0.0))
		boosting = true
		return
	if vy < boost_max_up_speed:
		boost_left -= delta
		player.velocity.y = minf(vy + boost_acceleration * down * flow * delta, boost_max_up_speed)


# --- Aspirazione ---------------------------------------------------------------------------

func _update_suction(want: bool, delta: float) -> void:
	var source = null
	if want:
		source = find_suction_source()
		# Aspirando un colore (gli acquari dell'enigma) lo zaino butta via da solo l'acqua chiara che
		# aveva (scelta B dell'utente, 18 ottobre): restano solo i colori già dentro.
		if source and tank_enabled and &"fill_pigment" in source and String(source.get(&"fill_pigment")) != "":
			scarta_acqua_chiara()
		if tank_enabled and tank_amount >= tank_capacity - 0.001:
			source = null
			if not _full_notified:
				_full_notified = true
				tank_full.emit()
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
	var source_mix: Dictionary = source.mix if &"mix" in source else {}
	var got: float = source.take_water(minf(suck_rate * delta, room))
	if tank_enabled and got > 0.0:
		_add_water(got, source_mix)


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
	_add_water(liters, {})


## Mette il serbatoio a [param liters] litri: l'acqua in più è chiara.
func set_tank_amount(liters: float) -> void:
	if liters > tank_amount:
		_add_water(liters - tank_amount, {})
	else:
		_set_amount(liters)


## Butta via la parte chiara dell'acqua nel serbatoio: restano solo i colori (vedi WaterMix).
func scarta_acqua_chiara() -> void:
	var k := WaterMix.intensita(water_mix)
	if tank_amount <= 0.001 or k >= 0.9999:
		return
	var m := WaterMix.solo_colori(water_mix)
	_set_amount(tank_amount * k)
	set_water_mix(m)


## Cambia il colore dell'acqua nel serbatoio (vedi WaterMix).
func set_water_mix(m: Dictionary) -> void:
	var v := {} if tank_amount <= 0.001 else m.duplicate()
	if v == water_mix:
		return
	water_mix = v
	water_mix_changed.emit(water_mix)


## Aggiunge [param liters] litri d'acqua del colore [param m]: si mescola per litri.
func _add_water(liters: float, m: Dictionary) -> void:
	var v := clampf(tank_amount + liters, 0.0, tank_capacity)
	if v <= tank_amount:
		return
	var mixed := WaterMix.mescola(water_mix, tank_amount, m, v - tank_amount)
	_set_amount(v)
	set_water_mix(mixed)


func _set_amount(liters: float) -> void:
	var v := clampf(liters, 0.0, tank_capacity)
	if is_equal_approx(v, tank_amount):
		return
	if v < tank_amount:
		_full_notified = false
	tank_amount = v
	tank_changed.emit(tank_amount, tank_capacity)
	if tank_amount <= 0.001:
		set_water_mix({})


# --- Grafica -------------------------------------------------------------------------------

func _update_visuals() -> void:
	if jet_particles:
		jet_particles.emitting = is_spraying
		if _jet_material:
			_jet_material.set_shader_parameter(&"max_age", hit_time if has_hit else jet_max_time)
			_jet_material.set_shader_parameter(&"inherit_velocity", player.velocity * inherit_player_velocity)
	if splash_particles:
		# Lo schizzo sta dove arriva davvero il getto continuo.
		var show := legacy_fx and _last_impact_time >= 0.0 and _clock - _last_impact_time < 0.08
		splash_particles.emitting = show
		if show:
			splash_particles.global_transform = Transform3D(_basis_from_normal(_last_impact_normal), _last_impact_point + _last_impact_normal * 0.03)
	if suction_stream:
		suction_stream.active = is_sucking
		if is_sucking:
			suction_stream.source_point = suck_point
	# Anelli sulla superficie da cui si aspira (se il suo shader li sa fare).
	var mat: ShaderMaterial = null
	if is_sucking and suck_source and &"water_material" in suck_source:
		mat = suck_source.get(&"water_material") as ShaderMaterial
	if _suck_mat and _suck_mat != mat:
		_suck_mat.set_shader_parameter(&"suck_point", Vector4(0.0, -1000.0, 0.0, 0.0))
	_suck_mat = mat
	if _suck_mat:
		_suck_mat.set_shader_parameter(&"suck_point", Vector4(suck_point.x, suck_point.y, suck_point.z, 1.0))
	if suction_particles:
		suction_particles.emitting = is_sucking and legacy_fx
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

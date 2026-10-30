class_name Player
extends CharacterBody3D
## Controller in prima persona.
## Sguardo col mouse, camminata/corsa/accovacciato (con controllo del soffitto), salto,
## accelerazioni morbide, head bob leggero, segnali dei passi con la superficie, scale a pioli.
## Gradini: si sale (e si scende) da soli su quelli bassi, fino a [member step_height], con la
## camera che segue morbida. Il corpo è un cilindro smussato sopra e sotto (vedi [method
## _body_points]): sul bordo di una vasca o di un gradino resta fermo anche con mezzo piede fuori,
## invece di scivolare giù come una capsula, e sulle rampe e sotto gli architravi passa come lei.
## Tutti i valori di "feeling" sono esportati: si tarano con l'utente.
##
## Scivoli (sala della torre): sui corpi del gruppo "scivolo" non si cammina, si scivola giù
## seguendo la pendenza, come su un acquascivolo bagnato (vedi [method _move_on_slide]). A fine pezzo
## si vola via con la velocità che si ha; in aria la spinta del getto allunga il salto (WaterPack).
##
## La camera (Head) non è interpolata dalla fisica: ogni frame segue la posizione interpolata
## del corpo e ruota subito col mouse, così il movimento è fluido anche oltre i 60 Hz.

## Un passo. [param surface]: materiale del pavimento (meta "superficie" del collider, per
## esempio &"metallo"; &"acqua" se si cammina nell'acqua, &"scala" sulle scale a pioli).
## [param wet]: pavimento bagnato. [param intensity]: circa 0,3 accovacciato, 1 camminando, 1,5 correndo.
signal footstep(surface: StringName, wet: bool, intensity: float)
## Atterraggio dopo una caduta; [param fall_speed] in m/s.
signal landed(surface: StringName, wet: bool, fall_speed: float)
signal jumped
signal crouch_changed(is_crouching: bool)
signal ladder_changed(is_on_ladder: bool)
## Si comincia a scivolare su uno scivolo, o si smette (alla fine del pezzo, o fermandosi).
signal slide_changed(is_sliding: bool)
signal item_added(item_id: StringName, item_name: String, total: int)
## L'oggetto interattivo guardato è cambiato (null = nessuno).
signal interaction_target_changed(target: Interactable)

const SURFACE_DEFAULT := &"generico"
const SURFACE_WATER := &"acqua"
## Da quanta acqua sopra i piedi si va a guado (m), nei WaterVolume con velocita_guado.
const GUADO_DA := 0.2
const SURFACE_LADDER := &"scala"
const SURFACE_SLIDE := &"scivolo"
## Gruppo dei corpi su cui si scivola (li mette chi costruisce la sala della torre).
const SLIDE_GROUP := &"scivolo"
## Le superfici dello scivolo più ripide di così (gradi) sono sponde, non fondo.
const SLIDE_MAX_ANGLE := 75.0
## Si comincia a scivolare solo appoggiandosi su una parte dello scivolo meno ripida di così (gradi).
const SLIDE_START_ANGLE := 60.0
## Quanto si resta attaccati al fondo dello scivolo quando si stacca un poco (m).
const SLIDE_SNAP := 0.18
## Quanto avanzare ancora se, appena salito, il corpo è in bilico sullo spigolo del gradino (m).
const STEP_FOOTING := 0.05
## Il corpo: raggio, raggio del fondo (e della cima) piatto, pendenza degli smussi in gradi
## (meno di floor_max_angle: appoggiati allo spigolo di un bordo si sta in piedi) e lati.
const BODY_RADIUS := 0.35
const BODY_FLAT_RADIUS := 0.12
const BODY_BEVEL_DEG := 38.0
const BODY_SIDES := 16

@export_group("Sguardo")
## Gradi di rotazione per pixel di movimento del mouse.
@export_range(0.01, 0.6, 0.005) var mouse_sensitivity := 0.12
@export var invert_y := false
@export_range(45.0, 89.9) var max_pitch_degrees := 88.0

@export_group("Movimento")
@export var walk_speed := 3.4
@export var run_speed := 5.8
@export var crouch_speed := 1.7
## Quanto in fretta raggiunge la velocità voluta a terra (1/s): più alto = più scattante.
@export var ground_acceleration := 9.0
## Quanto in fretta si ferma a terra (1/s).
@export var ground_deceleration := 11.0
## Controllo in aria (1/s).
@export var air_control := 1.8
@export var gravity_multiplier := 1.0
## Altezza del salto (m).
@export var jump_height := 1.0
## Si può ancora saltare per questi secondi dopo aver lasciato un bordo.
@export var coyote_time := 0.12
## Un salto premuto poco prima di toccare terra parte all'atterraggio.
@export var jump_buffer_time := 0.12
@export var can_jump_while_crouched := false
## Forza con cui si spingono gli oggetti fisici camminandoci contro (N).
@export var push_force := 40.0
## Sotto questa quota si muore (caduto fuori dal livello).
@export var fall_death_height := -60.0
## Gradini: quelli alti fino a tanto (m) si salgono da soli camminando, senza saltare.
@export var step_height := 0.32
## Quanto in fretta la camera recupera il dislivello di un gradino (più alto = più secco).
@export var step_camera_speed := 13.0

@export_group("Scivoli")
## Attrito dell'acqua sullo scivolo: la velocità cala così per secondo (esponenziale, 1/s).
@export var slide_friction := 0.06
## Accelerazione di lato per sterzare (m/s²).
@export var slide_steer := 10.0
## Frenata tirando indietro (m/s²); non si scende mai sotto [member slide_min_speed].
@export var slide_brake := 1.2
@export var slide_min_speed := 3.0
@export var slide_max_speed := 20.0
## Spinta all'ingresso, se si arriva piano (m/s nella direzione della pendenza).
@export var slide_entry_speed := 2.0
## Controllo in aria dopo un salto dallo scivolo (m/s²): la velocità resta, si corregge appena.
@export var slide_air_steer := 2.2
## Inclinazione massima della camera in curva (gradi) e quanto conta la curva.
@export var slide_tilt_max := 9.0
@export var slide_tilt_per_turn := 0.6

@export_group("Accovacciato")
## Vero: Ctrl accende/spegne. Falso: bisogna tenerlo premuto.
@export var crouch_toggle := false
@export var stand_height := 1.75
@export var crouch_height := 1.05
@export var stand_eye_height := 1.6
@export var crouch_eye_height := 0.92
## Velocità con cui la camera sale e scende (1/s).
@export var crouch_camera_speed := 9.0

@export_group("Head bob e passi")
@export var head_bob_enabled := true
## Oscillazione verticale massima (m).
@export var head_bob_vertical := 0.035
## Oscillazione laterale massima (m).
@export var head_bob_horizontal := 0.022
@export var step_length_walk := 0.75
@export var step_length_run := 1.05
@export var step_length_crouch := 0.55
## Abbassamento massimo della camera all'atterraggio (m).
@export var land_dip_max := 0.08

@export_group("Scale a pioli")
@export var ladder_climb_speed := 2.4
## Distanza tra un "passo" e l'altro sulla scala (m).
@export var ladder_step_distance := 0.45
## Distanza a cui si sta dalla scala (dal suo piano) mentre ci si arrampica: tiene il giocatore
## davanti ai pioli anche quando dietro la scala non c'è un muro (la scala del pozzo nella camera).
@export var ladder_hold_distance := 0.42

## Rotazione orizzontale e verticale dello sguardo (radianti).
var yaw := 0.0
var pitch := 0.0
var is_crouching := false
var ladder: Ladder = null
## item_id -> quantità.
var inventory: Dictionary = {}
## Falso durante pause, filmati, test...
var input_enabled := true
## Vero mentre si scivola su uno scivolo.
var is_sliding := false
## Se vero si sta accovacciati anche senza il tasto (nei tubi chiusi dell'inseguimento, alti 1,6 m: lo
## mette SalaInseguimento).
var accovacciato_forzato := false
## Il fondo dello scivolo sotto di te (normale), finché scivoli.
var slide_normal := Vector3.UP
## Vero dopo un salto dallo scivolo, fino a quando si tocca terra: la velocità resta quella.
var slide_launched := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _eye_height := 1.6
var _eye_prev := 1.6
var _step_phase := 0.0
var _phase_prev := 0.0
var _bob_weight := 0.0
## Moltiplicatore della sensibilità del mouse scelto nelle opzioni.
var _sensitivity_scale := 1.0
var _bob_prev := 0.0
var _land_offset := 0.0
var _land_prev := 0.0
var _land_vel := 0.0
# Gradini: la camera resta indietro del dislivello appena fatto e lo recupera piano piano.
var _step_offset := 0.0
# La velocità voluta dal comando nell'ultimo passo a terra (per i gradini presi di sbieco).
var _step_target := Vector3.ZERO
var _step_prev := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _ladder_travel := 0.0
var _crouch_toggled := false
var _ladder_cooldown := 0.0
# Presa la scala dall'alto (camminando verso di lei dal bordo): finché si tiene il tasto, avanti
# vuol dire giù (se no si scavalcherebbe subito di nuovo il bordo).
var _ladder_from_top := false
var _body_height := 1.75
var _roll := 0.0
var _roll_prev := 0.0
var _slide_heading := 0.0
var _air_time := 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var sensor: Area3D = $Sensor
@onready var water_pack: WaterPack = get_node_or_null("WaterPack")
@onready var interactor: Interactor = get_node_or_null("Interactor")


func _ready() -> void:
	add_to_group(&"player")
	# lo strato delle zone che si preparano fuori vista (SalaTorre.STRATO_PREPARA) non si vede
	camera.cull_mask &= ~SalaTorre.STRATO_PREPARA
	# I muri invisibili (per esempio il cordone intorno alla vasca della medusa) fermano il giocatore ma
	# non il getto: stanno su un livello loro, che il getto non guarda.
	collision_mask |= Layers.BARRIERS
	collision_shape.shape = ConvexPolygonShape3D.new()
	_apply_height(stand_height)
	# Si scende dai gradini restando attaccati a terra (fino alla stessa altezza di quelli in salita).
	floor_snap_length = maxf(floor_snap_length, step_height + 0.02)
	yaw = rotation.y
	rotation = Vector3(0.0, yaw, 0.0)
	_eye_height = stand_eye_height
	_eye_prev = _eye_height
	head.top_level = true
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if water_pack:
		water_pack.setup(self)
	if interactor:
		interactor.setup(self)
	add_child(SlideFx.new(self))
	_update_head(1.0)
	GameState.register_player(self)
	# Sensibilità, asse Y invertito e oscillazione della camera dalla scheda Controlli delle
	# opzioni (addon grafica, salvati in settings.cfg).
	_read_controls()
	var g := get_node_or_null(^"/root/Grafica")
	if g and g.has_signal(&"impostazione_cambiata"):
		g.connect(&"impostazione_cambiata", _on_setting_changed)


func _on_setting_changed(_key: String, _value: Variant) -> void:
	_read_controls()


func _read_controls() -> void:
	var g := get_node_or_null(^"/root/Grafica")
	if g == null or not g.has_method(&"valore"):
		return
	var sens: Variant = g.call(&"valore", "sensibilita_mouse")
	if sens != null:
		_sensitivity_scale = float(sens)
	var inv: Variant = g.call(&"valore", "inverti_y")
	if inv != null:
		invert_y = bool(inv)
	var bob: Variant = g.call(&"valore", "oscillazione_camera")
	if bob != null:
		head_bob_enabled = bool(bob)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var d := motion.screen_relative * deg_to_rad(mouse_sensitivity * _sensitivity_scale)
		yaw = wrapf(yaw - d.x, -PI, PI)
		pitch += d.y if invert_y else -d.y
		pitch = clampf(pitch, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))


# --- Sguardo e camera -------------------------------------------------------------------

## Posizione degli occhi (senza head bob), per raggi e getto.
func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * _eye_height


func get_aim_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


## Trasformazione dello sguardo "logico" (stato fisico attuale, senza head bob).
func get_aim_transform() -> Transform3D:
	return Transform3D(get_aim_basis(), get_eye_position())


func get_aim_direction() -> Vector3:
	return -get_aim_basis().z


func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = wrapf(new_yaw, -PI, PI)
	pitch = clampf(new_pitch, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))


## Gira lo sguardo verso un punto del mondo (test, filmati).
func look_at_point(target: Vector3) -> void:
	var d := target - get_eye_position()
	set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


## Sposta il giocatore senza interpolazione (respawn, test).
func teleport(pos: Vector3, new_yaw := yaw, new_pitch := 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_stop_sliding(false)
	slide_launched = false
	_roll = 0.0
	_roll_prev = 0.0
	set_look(new_yaw, new_pitch)
	rotation = Vector3(0.0, yaw, 0.0)
	_leave_ladder()
	_step_offset = 0.0
	_step_prev = 0.0
	reset_physics_interpolation()
	_update_head(1.0)


func _process(_delta: float) -> void:
	_update_head(Engine.get_physics_interpolation_fraction())


## Ondeggiamento del passo attuale (x laterale, y verticale), per l'oggetto in mano.
func get_step_bob() -> Vector2:
	if not head_bob_enabled:
		return Vector2.ZERO
	var w := _bob_weight
	return Vector2(sin(PI * _step_phase) * w, -(0.5 + 0.5 * cos(TAU * _step_phase)) * w)


func _update_head(fraction: float) -> void:
	var origin := get_global_transform_interpolated().origin if is_inside_tree() else global_position
	var eye := lerpf(_eye_prev, _eye_height, fraction)
	var land := lerpf(_land_prev, _land_offset, fraction) + lerpf(_step_prev, _step_offset, fraction)
	var phase := lerpf(_phase_prev, _step_phase, fraction)
	var w := lerpf(_bob_prev, _bob_weight, fraction) if head_bob_enabled else 0.0
	var bob_v := -head_bob_vertical * w * (0.5 + 0.5 * cos(TAU * phase))
	var bob_h := head_bob_horizontal * w * sin(PI * phase)
	var side := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var pos := origin + Vector3.UP * (eye + land + bob_v) + side * bob_h
	var roll := lerpf(_roll_prev, _roll, fraction)
	head.global_transform = Transform3D(get_aim_basis() * Basis(Vector3.BACK, roll), pos)


# --- Movimento ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_eye_prev = _eye_height
	_phase_prev = _step_phase
	_bob_prev = _bob_weight
	_land_prev = _land_offset
	_step_prev = _step_offset
	_roll_prev = _roll
	rotation = Vector3(0.0, yaw, 0.0)
	_update_crouch(delta)
	_update_ladder()
	_attraversa_scala(delta)
	var pre_vy := velocity.y
	var pre_floor := is_on_floor() and ladder == null
	var pre_transform := global_transform
	if ladder:
		_move_on_ladder(delta)
	elif is_sliding:
		_move_on_slide(delta)
	else:
		_move_on_ground(delta)
	var wish_velocity := velocity
	move_and_slide()
	_update_slide(delta, pre_vy)
	if pre_floor and ladder == null and wish_velocity.y <= 0.01 and not is_sliding:
		_step_up_after_move(pre_transform, wish_velocity, delta)
	_push_rigid_bodies(delta)
	_follow_step_down(pre_floor, pre_transform.origin)
	_after_move(delta, pre_vy)
	if global_position.y < fall_death_height:
		GameState.kill_player(&"caduta")


func _move_input() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _move_on_ground(delta: float) -> void:
	var on_floor := is_on_floor()
	var g := _gravity * gravity_multiplier
	if not on_floor:
		velocity.y -= g * delta
	# Salto con coyote time e buffer.
	_coyote = coyote_time if on_floor else _coyote - delta
	if input_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta
	if _jump_buffer > 0.0 and _coyote > 0.0 and (can_jump_while_crouched or not is_crouching) and not in_acqua_senza_salto():
		velocity.y = sqrt(2.0 * g * jump_height)
		_jump_buffer = 0.0
		_coyote = 0.0
		jumped.emit()
	# Movimento orizzontale con accelerazioni morbide (esponenziali).
	var input := _move_input()
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var target := wish * _max_speed(input)
	_step_target = target
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if on_floor:
		rate = ground_acceleration if target.length_squared() >= hv.length_squared() - 0.01 else ground_deceleration
	elif slide_launched:
		# In volo dallo scivolo: la velocità resta, il comando la corregge appena (senza frenare).
		var speed := hv.length()
		hv += wish * slide_air_steer * delta
		if hv.length() > speed and speed > 0.1:
			hv = hv.normalized() * speed
		velocity.x = hv.x
		velocity.z = hv.z
		return
	else:
		rate = air_control if input != Vector2.ZERO else 0.1
	hv = hv.lerp(target, 1.0 - exp(-rate * delta))
	velocity.x = hv.x
	velocity.z = hv.z


func _max_speed(input: Vector2) -> float:
	var v := walk_speed
	if is_crouching:
		v = crouch_speed
	elif input_enabled and Input.is_action_pressed("sprint") and input.y <= 0.0 and input.length() > 0.1:
		v = run_speed
	# a guado (l'acqua del canale del tunnel sottomarino, al ginocchio) si va piano, anche di corsa
	for area in sensor.get_overlapping_areas():
		var wv := area as WaterVolume
		if wv and wv.velocita_guado > 0.0 and wv.get_surface_height() > global_position.y + GUADO_DA:
			v = minf(v, wv.velocita_guado_accovacciato if is_crouching and wv.velocita_guado_accovacciato > 0.0 else wv.velocita_guado)
	return v


## Gradini. Dopo il passo normale, se si è sbattuto contro qualcosa di basso (camminando a
## terra), si riprova il passo come farebbe il corpo un gradino più su: su, avanti strisciando
## sui muri, giù. Se così si va più avanti e sotto c'è un pavimento alto al massimo
## [member step_height], si tiene quello: il corpo sale sul gradino e la camera lo segue morbida.
## Se appena salito il corpo è in bilico sullo spigolo, avanza ancora un poco verso il gradino.
## Niente gradini su oggetti che si muovono (palloni, casse): quelli si spingono.
func _step_up_after_move(from: Transform3D, wish_velocity: Vector3, delta: float) -> void:
	# Il gradino: la cosa ripida contro cui si è sbattuto più in basso, sotto step_height.
	var into := Vector3.ZERO
	var lowest := INF
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var y := (c.get_position() - from.origin).dot(up_direction)
		if n.angle_to(up_direction) <= floor_max_angle or c.get_collider() is RigidBody3D:
			continue
		if y > step_height + 0.02 or y >= lowest:
			continue
		var flat := n - up_direction * n.dot(up_direction)
		if flat.length() < 0.1:
			continue
		lowest = y
		into = -flat.normalized()
	if into == Vector3.ZERO:
		return
	var motion := Vector3(wish_velocity.x, 0.0, wish_velocity.z) * delta
	# Arrivando di sbieco, dopo il primo contatto la velocità striscia lungo il gradino e verso il gradino quasi non
	# va (collaudo del 25 ottobre: dall'acqua del canale non si saliva il gradino a due scalini): il passo si prova
	# nella direzione del comando, se va più verso il gradino.
	if _step_target.dot(into) * delta > motion.dot(into):
		motion = _step_target * delta
	if motion.length() < 0.0005:
		return
	var hit := KinematicCollision3D.new()
	var t := from
	var up := up_direction * (step_height + 0.03)
	if test_move(t, up, hit, safe_margin):
		up = hit.get_travel()
	t.origin += up
	# Avanti come move_and_slide(): al massimo due strisciate contro i muri.
	var m := motion
	for k in 2:
		if not test_move(t, m, hit, safe_margin):
			t.origin += m
			break
		t.origin += hit.get_travel()
		m = hit.get_remainder().slide(hit.get_normal())
		m -= up_direction * m.dot(up_direction)
		if m.length() < 0.0005:
			break
	var moved := t.origin - from.origin
	moved -= up_direction * moved.dot(up_direction)
	var normal_move := global_position - from.origin
	normal_move -= up_direction * normal_move.dot(up_direction)
	# (conta quanto si va verso il gradino: di sbieco il passo normale striscia lungo il gradino e va lontano quasi
	# quanto quello più su)
	if moved.dot(into) <= normal_move.dot(into) + 0.002:
		return  # anche più su non si passa: è un muro
	var depth := up.length()
	var down := _step_floor(t, depth, from)
	if down < 0.0:
		# In bilico sullo spigolo: un poco più avanti verso il gradino.
		var nudge := into * STEP_FOOTING
		if test_move(t, nudge, hit, safe_margin):
			nudge = hit.get_travel()
		t.origin += nudge
		down = _step_floor(t, depth, from)
		if down < 0.0:
			return
	var rise := depth - down
	if rise < 0.004 or rise > step_height:
		return
	global_position = t.origin - up_direction * down
	# Il passo non è finito contro il gradino: niente velocità persa.
	velocity = Vector3(wish_velocity.x, velocity.y, wish_velocity.z)
	_step_offset -= rise


## Quanto si scende da [param t] prima di appoggiare su un pavimento vero (in piano, non un
## oggetto mobile, non più alto di step_height sopra i piedi in [param from]), entro
## [param depth]; -1 se non c'è.
func _step_floor(t: Transform3D, depth: float, from: Transform3D) -> float:
	var hit := KinematicCollision3D.new()
	if not test_move(t, -up_direction * (depth + 0.02), hit, safe_margin):
		return -1.0
	if hit.get_normal().angle_to(up_direction) > floor_max_angle or hit.get_collider() is RigidBody3D:
		return -1.0
	if (hit.get_position() - from.origin).dot(up_direction) > step_height + 0.01:
		return -1.0
	return -hit.get_travel().dot(up_direction)


## Scendendo da un gradino il pavimento (floor snap) tira giù il corpo di colpo: la camera ci
## arriva piano. Una rampa (al massimo floor_max_angle) non conta.
func _follow_step_down(pre_floor: bool, pre_pos: Vector3) -> void:
	if not pre_floor or not is_on_floor() or ladder:
		return
	var d := global_position - pre_pos
	var drop := -d.dot(up_direction)
	var flat := (d + up_direction * drop).length()
	if drop > flat * tan(floor_max_angle) + 0.03:
		_step_offset += drop


func is_running() -> bool:
	return not is_crouching and Vector2(velocity.x, velocity.z).length() > walk_speed * 1.15


func _push_rigid_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body == null:
			continue
		var dir := -c.get_normal()
		dir.y = 0.0
		if dir.length_squared() < 0.0001:
			continue
		body.apply_impulse(dir.normalized() * push_force * delta, c.get_position() - body.global_position)


func _after_move(delta: float, pre_vy: float) -> void:
	# Appena arrivati su uno scivolo il passo l'ha ancora preso per pavimento: non conta.
	var on_floor := is_on_floor() and not is_sliding
	if on_floor or ladder:
		slide_launched = false
	_air_time = 0.0 if on_floor or is_sliding or ladder else _air_time + delta
	if not is_sliding:
		_roll *= exp(-4.0 * delta)
	# Atterraggio: segnale e piccola molla sulla camera.
	if on_floor and not _was_on_floor and ladder == null:
		var fall := -pre_vy
		if fall > 1.0:
			var s := get_surface_under_feet()
			landed.emit(s[0], s[1], fall)
			_land_vel -= minf((fall - 1.0) * 0.25, land_dip_max * 29.8)
	_was_on_floor = on_floor
	var k := 120.0
	_land_vel += (-k * _land_offset - 2.0 * sqrt(k) * _land_vel) * delta
	_land_offset += _land_vel * delta
	# La camera recupera il gradino: esponenziale, più un minimo perché arrivi davvero a zero.
	_step_offset *= exp(-step_camera_speed * delta)
	_step_offset = clampf(move_toward(_step_offset, 0.0, 0.15 * delta), -step_height * 1.5, step_height * 1.5)
	# Passi e head bob in base alla distanza percorsa.
	var hs := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if on_floor and ladder == null and hs > 0.2:
		var step_len := step_length_walk
		if is_crouching:
			step_len = step_length_crouch
		elif is_running():
			step_len = step_length_run
		var before := _step_phase
		_step_phase += hs * delta / step_len
		if floori(_step_phase) != floori(before):
			var s := get_surface_under_feet()
			footstep.emit(s[0], s[1], clampf(hs / walk_speed, 0.2, 1.6))
		_bob_weight = move_toward(_bob_weight, clampf(hs / walk_speed, 0.0, 1.4), delta * 4.0)
	else:
		_bob_weight = move_toward(_bob_weight, 0.0, delta * 4.0)


## Superficie sotto i piedi: [nome, bagnata].
func get_surface_under_feet() -> Array:
	var wet := false
	for area in sensor.get_overlapping_areas():
		if area is WaterVolume and (area as WaterVolume).get_surface_height() > global_position.y + 0.05:
			return [SURFACE_WATER, true]
		if area.is_in_group(&"zona_bagnata"):
			wet = true
	var surface := SURFACE_DEFAULT
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.25,
			global_position + Vector3.DOWN * 0.35, Layers.WORLD | Layers.PROPS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider:
		var c: Object = hit.collider
		surface = c.get_meta(&"superficie", SURFACE_DEFAULT)
		if bool(c.get_meta(&"bagnato", false)) or (c is Node and (c as Node).is_in_group(&"bagnato")):
			wet = true
	return [surface, wet]


## Vero se il giocatore è nell'acqua almeno fino a [param depth] metri.
func is_in_water(depth := 0.2) -> bool:
	for area in sensor.get_overlapping_areas():
		if area is WaterVolume and (area as WaterVolume).get_surface_height() > global_position.y + depth:
			return true
	return false


# --- Scivoli -------------------------------------------------------------------------------

## Velocità lungo lo scivolo (m/s), 0 se non si scivola.
func get_slide_speed() -> float:
	return velocity.length() if is_sliding else 0.0


## Sullo scivolo: la gravità tira lungo la pendenza, l'acqua frena pochissimo. Di lato si sterza;
## tirando indietro si rallenta un poco, ma non sotto slide_min_speed (fermi non si sta).
func _move_on_slide(delta: float) -> void:
	var n := slide_normal
	var v := velocity
	var g := Vector3.DOWN * _gravity * gravity_multiplier
	v += (g - n * g.dot(n)) * delta
	if v.dot(n) < 0.0:
		v -= n * v.dot(n)
	v *= exp(-slide_friction * delta)
	var speed := v.length()
	var dir := v / speed if speed > 0.01 else (g - n * g.dot(n)).normalized()
	var input := _move_input()
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	wish -= n * wish.dot(n)
	var side := wish - dir * wish.dot(dir)
	v += side * slide_steer * delta
	var back := -wish.dot(dir)
	if back > 0.3 and speed > slide_min_speed:
		v -= dir * minf(slide_brake * back * delta, speed - slide_min_speed)
	if v.length() > slide_max_speed:
		v = v.normalized() * slide_max_speed
	# Una spinta piccola contro il fondo: così ogni passo lo tocca e se ne legge la normale.
	velocity = v - n * 0.4


## Dopo il passo: si comincia a scivolare toccando uno scivolo, si resta attaccati al fondo
## anche quando si stacca appena, e si vola via quando il pezzo finisce.
func _update_slide(delta: float, pre_vy: float) -> void:
	if ladder:
		_stop_sliding(false)
		return
	var n := _slide_contact()
	if n == Vector3.ZERO and is_sliding:
		var hit := KinematicCollision3D.new()
		if test_move(global_transform, -slide_normal * SLIDE_SNAP, hit, safe_margin) \
				and _is_slide_surface(hit.get_collider(), hit.get_normal()):
			global_position += hit.get_travel()
			n = hit.get_normal()
	if n == Vector3.ZERO:
		if is_sliding:
			# Fine del pezzo: si vola con la velocità che si ha (senza la spinta contro il fondo).
			velocity += slide_normal * 0.4
			_stop_sliding(true)
		return
	if not is_sliding:
		# Si comincia solo appoggiandosi sul fondo (non sfiorando una sponda o il bordo di un pezzo).
		if n.angle_to(Vector3.UP) > deg_to_rad(SLIDE_START_ANGLE):
			return
		var hv := Vector3(velocity.x, 0.0, velocity.z)
		var nh := Vector3(n.x, 0.0, n.z)
		if hv.length() > 1.0 and nh.length() > 0.3 and nh.normalized().dot(hv.normalized()) < -0.6:
			return  # lo spigolo dell'inizio di un pezzo, preso di fronte
		var fall := -pre_vy
		is_sliding = true
		slide_launched = false
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var downhill := (Vector3.DOWN - n * Vector3.DOWN.dot(n)).normalized()
		velocity -= n * velocity.dot(n)
		if velocity.dot(downhill) < slide_entry_speed:
			velocity += downhill * (slide_entry_speed - velocity.dot(downhill))
		_slide_heading = _heading(velocity)
		if fall > 1.0 and _air_time > 0.15:
			landed.emit(SURFACE_SLIDE, true, fall)
			_land_vel -= minf((fall - 1.0) * 0.25, land_dip_max * 29.8)
		slide_changed.emit(true)
	slide_normal = n
	velocity -= n * minf(velocity.dot(n), 0.0)
	# La camera si inclina verso l'interno della curva.
	var h := _heading(velocity)
	var turn := wrapf(h - _slide_heading, -PI, PI) / maxf(delta, 0.0001)
	_slide_heading = h
	var target := clampf(turn * slide_tilt_per_turn, -1.0, 1.0) * deg_to_rad(slide_tilt_max)
	_roll = lerpf(_roll, target, 1.0 - exp(-5.0 * delta))


func _stop_sliding(launched: bool) -> void:
	if not is_sliding:
		return
	is_sliding = false
	slide_launched = launched
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	slide_normal = Vector3.UP
	slide_changed.emit(false)


## La normale del fondo dello scivolo toccato nell'ultimo passo (il più in piano), o ZERO; anche
## quello su cui si sta in piedi.
func _slide_contact() -> Vector3:
	var best := Vector3.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var nn := c.get_normal()
		if _is_slide_surface(c.get_collider(), nn) and nn.y > best.y:
			best = nn
	if best == Vector3.ZERO and is_on_floor():
		# Camminando su una pendenza dolce il pavimento non risulta tra gli urti del passo.
		var hit := KinematicCollision3D.new()
		if test_move(global_transform, Vector3.DOWN * 0.08, hit, safe_margin) \
				and _is_slide_surface(hit.get_collider(), hit.get_normal()):
			best = hit.get_normal()
	return best


func _is_slide_surface(collider: Object, normal: Vector3) -> bool:
	return collider is Node and (collider as Node).is_in_group(SLIDE_GROUP) \
			and normal.angle_to(Vector3.UP) <= deg_to_rad(SLIDE_MAX_ANGLE)


static func _heading(v: Vector3) -> float:
	return atan2(-v.x, -v.z) if Vector2(v.x, v.z).length_squared() > 0.01 else 0.0


# --- Accovacciato ---------------------------------------------------------------------------

func _update_crouch(delta: float) -> void:
	var wants := false
	if input_enabled:
		if crouch_toggle:
			if Input.is_action_just_pressed("crouch"):
				_crouch_toggled = not _crouch_toggled
			wants = _crouch_toggled
		else:
			wants = Input.is_action_pressed("crouch")
	if ladder:
		wants = false
	if accovacciato_forzato:
		wants = true
	if wants and not is_crouching:
		_set_crouching(true)
	elif not wants and is_crouching and can_stand_up():
		_set_crouching(false)
	var target := crouch_eye_height if is_crouching else stand_eye_height
	_eye_height = lerpf(_eye_height, target, 1.0 - exp(-crouch_camera_speed * delta))


## Vero se sopra la testa c'è spazio per alzarsi.
func can_stand_up() -> bool:
	return not test_move(global_transform, Vector3.UP * (stand_height - _body_height + 0.02))


func _set_crouching(value: bool) -> void:
	is_crouching = value
	_apply_height(crouch_height if value else stand_height)
	if not value:
		_crouch_toggled = false
	crouch_changed.emit(value)


func _apply_height(h: float) -> void:
	_body_height = h
	(collision_shape.shape as ConvexPolygonShape3D).points = _body_points(h)
	collision_shape.position = Vector3(0.0, h * 0.5, 0.0)


## Il corpo alto [param h], centrato: un cilindro con il fondo e la cima piatti al centro e smussati
## intorno. Il fondo piatto appoggia sui gradini e sui bordi; lo smusso, appoggiato a uno spigolo,
## è ancora "pavimento" (così sul bordo non si scivola) e sulle rampe tiene il corpo basso come
## una capsula; lo smusso in cima passa sotto gli architravi delle rampe.
static func _body_points(h: float) -> PackedVector3Array:
	var bevel := minf((BODY_RADIUS - BODY_FLAT_RADIUS) * tan(deg_to_rad(BODY_BEVEL_DEG)), h * 0.25)
	var pts := PackedVector3Array()
	for i in BODY_SIDES:
		var a := TAU * i / BODY_SIDES
		var d := Vector3(cos(a), 0.0, sin(a))
		pts.append(d * BODY_FLAT_RADIUS + Vector3(0.0, -h * 0.5, 0.0))
		pts.append(d * BODY_RADIUS + Vector3(0.0, -h * 0.5 + bevel, 0.0))
		pts.append(d * BODY_RADIUS + Vector3(0.0, h * 0.5 - bevel, 0.0))
		pts.append(d * BODY_FLAT_RADIUS + Vector3(0.0, h * 0.5, 0.0))
	return pts


# --- Scale a pioli --------------------------------------------------------------------------

func is_on_ladder() -> bool:
	return ladder != null


func _update_ladder() -> void:
	var found: Ladder = null
	for area in sensor.get_overlapping_areas():
		if area is Ladder:
			found = area
			break
	if ladder and found != ladder:
		_leave_ladder()
	_ladder_cooldown = maxf(0.0, _ladder_cooldown - get_physics_process_delta_time())
	if ladder or found == null or is_crouching or _ladder_cooldown > 0.0:
		return
	var input := _move_input()
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	# (la direzione, non quanto è spinto lo stick: con lo stick a metà, 0,5, non ci si aggrappava mai; riscontro della
	# 0.3.16, scalette della piscina col controller)
	var toward := wish.length() > 0.2 and wish.normalized().dot(-found.get_climb_normal()) > 0.5
	var falling_onto := not is_on_floor() and velocity.y < -0.5 and global_position.y < found.get_top_y() - 0.3
	if toward or falling_onto:
		ladder = found
		velocity = Vector3.ZERO
		_ladder_travel = 0.0
		_ladder_from_top = global_position.y >= found.get_top_y() - 0.35
		ladder_changed.emit(true)


## I corpi che si passano scavalcando la cima di una scala ([member Ladder.attraversa]), la scala e da quanto.
var _scavalcati: Array[PhysicsBody3D] = []
var _scavalcata: Ladder = null
var _scavalco_t := 0.0


func _scavalca(l: Ladder) -> void:
	_fine_scavalco()
	for b in l.corpi_da_attraversare():
		add_collision_exception_with(b)
		_scavalcati.append(b)
	_scavalcata = l
	_scavalco_t = 0.0


## Le eccezioni dello scavalco finiscono quando non si tocca più niente dei corpi della scala (fuori dai corrimano, da
## una parte o dall'altra), o dopo 6 s.
func _attraversa_scala(delta: float) -> void:
	if _scavalcata == null:
		return
	_scavalco_t += delta
	if not is_instance_valid(_scavalcata) or _scavalco_t > 6.0 or (_scavalco_t > 0.3 and not _tocca_scavalcati()):
		_fine_scavalco()


func _tocca_scavalcati() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = collision_shape.shape
	q.transform = collision_shape.global_transform
	q.margin = 0.04
	q.collision_mask = collision_mask
	for r in get_world_3d().direct_space_state.intersect_shape(q, 16):
		if _scavalcati.has(r.collider):
			return true
	return false


func _fine_scavalco() -> void:
	for b in _scavalcati:
		if is_instance_valid(b):
			remove_collision_exception_with(b)
	_scavalcati.clear()
	_scavalcata = null


func _leave_ladder() -> void:
	if ladder == null:
		return
	ladder = null
	_ladder_cooldown = 0.35
	_ladder_from_top = false
	ladder_changed.emit(false)


## Sulla scala, avanti (W) scende se si guarda in basso: si comincia a scendere sotto -20 gradi e si
## continua finché non si guarda chiaramente in alto (sopra +10), così alzando un po' lo sguardo mentre si
## scende non si risale. Indietro (S) scende sempre.
const LADDER_GIU_DA := -20.0
const LADDER_SU_DA := 10.0
var _ladder_giu := false
var _ladder_giu_su: Ladder = null


func _move_on_ladder(delta: float) -> void:
	var input := _move_input()
	var n := ladder.get_climb_normal()
	if input_enabled and Input.is_action_just_pressed("jump"):
		velocity = n * 3.0 + Vector3.UP * 2.0
		_leave_ladder()
		jumped.emit()
		return
	if _ladder_giu_su != ladder:
		_ladder_giu_su = ladder
		_ladder_giu = pitch < deg_to_rad(LADDER_GIU_DA)
	if pitch < deg_to_rad(LADDER_GIU_DA):
		_ladder_giu = true
	elif pitch > deg_to_rad(LADDER_SU_DA):
		_ladder_giu = false
	var climb := -input.y
	if input.y > 0.0:
		climb = -absf(input.y)
	elif _ladder_giu:
		climb = -climb
	if _ladder_from_top:
		if is_zero_approx(input.y):
			_ladder_from_top = false
		elif climb > 0.0:
			climb = -climb
	if is_on_floor() and climb < 0.0:
		# In fondo alla scala: torna a camminare.
		_leave_ladder()
		_move_on_ground(delta)
		return
	if climb > 0.0 and global_position.y >= ladder.get_top_y() - 0.08:
		# In cima: scavalca il bordo. I corpi della scala che sporgono sopra il bordo (Ladder.attraversa: i corrimano
		# delle scalette della piscina) si passano mentre si scavalca, finché si è usciti (vedi _attraversa_scala).
		velocity = -n * 2.4 + Vector3.UP * 1.6
		_scavalca(ladder)
		_leave_ladder()
		return
	var side := n.cross(Vector3.UP)
	var dist := (global_position - ladder.global_position).dot(n)
	var toward_hold := clampf((ladder_hold_distance - dist) * 6.0, -1.0, 1.0)
	velocity = Vector3.UP * climb * ladder_climb_speed + side * (-input.x) * 1.0 + n * toward_hold
	_ladder_travel += absf(climb) * ladder_climb_speed * delta
	if _ladder_travel >= ladder_step_distance:
		_ladder_travel = 0.0
		footstep.emit(SURFACE_LADDER, false, 0.6)


# --- Inventario -----------------------------------------------------------------------------

func add_item(item_id: StringName, amount := 1, item_name := "") -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	item_added.emit(item_id, item_name if item_name != "" else String(item_id), inventory[item_id])


func has_item(item_id: StringName, amount := 1) -> bool:
	return int(inventory.get(item_id, 0)) >= amount


func remove_item(item_id: StringName, amount := 1) -> bool:
	if not has_item(item_id, amount):
		return false
	inventory[item_id] = int(inventory[item_id]) - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	return true


## Vero coi piedi nell'acqua del canale del tunnel sottomarino (WaterVolume.senza_salto), con l'acqua sopra il
## ginocchio come per il guado: lì non si salta. Su un gommone, coi piedi sopra il pelo, no.
func in_acqua_senza_salto() -> bool:
	for area in sensor.get_overlapping_areas():
		var wv := area as WaterVolume
		if wv and wv.senza_salto and wv.get_surface_height() > global_position.y + GUADO_DA:
			return true
	return false

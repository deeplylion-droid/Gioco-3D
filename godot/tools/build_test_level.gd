extends SceneTree
## Genera la scena di prova graybox res://scenes/test/test_level.tscn.
## Uso: godot --headless --path godot --script res://tools/build_test_level.gd
## Dopo averla generata si può modificare a mano nell'editor; rilanciando questo script
## le modifiche fatte a mano si perdono.
##
## Percorso: stanza di partenza (turbina -> porta, scala a pioli, passaggio basso, mensola da
## raggiungere con la spinta del getto, pavimento bagnato, acqua che scorre, vasca piccola),
## corridoio, sala delle vasche (vasca sorgente da aspirare, vasca grande con piattaforma
## galleggiante, pulsante dello scarico, sporgenza alta, manichino, pozzo mortale).

const OUT := "res://scenes/test/test_level.tscn"

const UNION := CSGShape3D.OPERATION_UNION
const SUB := CSGShape3D.OPERATION_SUBTRACTION

var PLAYER: Resource
var TURBINE: Resource
var DOOR: Resource
var BUTTON: Resource
var TANK: Resource
var PLATFORM: Resource
var LADDER: Resource
var PICKUP: Resource
var POLAROID: Resource
var DUMMY: Resource
var ENV: Resource
var level: Node3D
var _labels := 0


func _initialize() -> void:
	PLAYER = load("res://scenes/player/player.tscn")
	TURBINE = load("res://scenes/props/turbine.tscn")
	DOOR = load("res://scenes/props/powered_door.tscn")
	BUTTON = load("res://scenes/props/water_button.tscn")
	TANK = load("res://scenes/props/water_tank.tscn")
	PLATFORM = load("res://scenes/props/floating_platform.tscn")
	LADDER = load("res://scenes/props/ladder.tscn")
	PICKUP = load("res://scenes/props/pickup.tscn")
	POLAROID = load("res://scenes/props/polaroid.tscn")
	DUMMY = load("res://scenes/enemies/dummy_enemy.tscn")
	ENV = load("res://assets/env/graybox_environment.tres")
	level = Node3D.new()
	level.name = "TestLevel"
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = ENV
	own(env)
	_build_start_room()
	_build_tank_hall()
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_test_level: ", error_string(err))
	level.free()
	quit(0 if err == OK else 1)


# --- Stanza di partenza ------------------------------------------------------------------

func _build_start_room() -> void:
	var room := group("StanzaPartenza")
	var csg := csg_root(room, "Muri")
	box(csg, "Esterno", Vector3(15, 5.5, 13), Vector3(0, 2.25, 0), UNION)
	box(csg, "Interno", Vector3(14, 4.55, 12), Vector3(0, 2.225, 0), SUB)
	box(csg, "Pavimento", Vector3(14.5, 0.05, 12.5), Vector3(0, -0.025, 0), UNION, Graybox.FLOOR)
	box(csg, "NicchiaEsterno", Vector3(5.5, 3.2, 5), Vector3(-10.25, 1.1, 2), UNION)
	box(csg, "NicchiaInterno", Vector3(3, 2.25, 4), Vector3(-11, 1.075, 2), SUB)
	box(csg, "NicchiaPavimento", Vector3(3.4, 0.05, 4.4), Vector3(-11, -0.025, 2), UNION, Graybox.FLOOR)
	box(csg, "MensolaAlta", Vector3(2, 1.55, 2), Vector3(-6, 0.775, 5), UNION, Graybox.DARK)
	box(csg, "Tavolo", Vector3(1.2, 0.8, 0.7), Vector3(2.5, 0.4, 3.5), UNION, Graybox.DARK)
	box(csg, "VanoPorta", Vector3(2.0, 2.6, 1.4), Vector3(0, 1.301, -6.25), SUB)
	box(csg, "PassaggioBasso", Vector3(2.8, 1.15, 1.4), Vector3(-8.3, 0.576, 2.0), SUB)

	# Ballatoio di metallo con la scala a pioli (superficie "metallo" per i passi).
	var balcony := csg_root(room, "Ballatoio")
	balcony.set_meta(&"superficie", &"metallo")
	box(balcony, "Piano", Vector3(2.5, 0.25, 6), Vector3(5.75, 2.375, -2), UNION, Graybox.DARK)
	box(balcony, "Sostegno", Vector3(2.5, 2.25, 2), Vector3(5.75, 1.125, -4), UNION)
	box(balcony, "Ringhiera", Vector3(0.08, 1.0, 3.5), Vector3(4.54, 3.0, -0.75), UNION, Graybox.DARK)
	var ladder := inst(LADDER, room, "ScalaPioli", Vector3(4.5, 0, -4), -PI * 0.5)
	ladder.set(&"height", 2.5)

	# Turbina che alimenta la porta.
	var turbine := inst(TURBINE, room, "Turbina", Vector3(-3.5, 2.2, -6.0))
	var door := inst(DOOR, room, "PortaTurbina", Vector3(0, 0, -6.25))
	var door_sources: Array[PowerSource] = [turbine as PowerSource]
	door.set(&"sources", door_sources)

	# Oggetti da raccogliere e Polaroid.
	pickup(room, "Chiave", &"chiave", "Chiave", Vector3(2.5, 0.8, 3.5))
	pickup(room, "Fusibile", &"fusibile", "Fusibile", Vector3(-11.5, 0, 2.0))
	polaroid(room, "Polaroid01", Vector3(6.3, 2.5, -0.6))
	polaroid(room, "Polaroid02", Vector3(-6.0, 1.55, 5.0))

	# Pavimento bagnato: pozzanghera + zona bagnata per i passi.
	var puddle := MeshInstance3D.new()
	puddle.name = "Pozzanghera"
	var pm := BoxMesh.new()
	pm.size = Vector3(3, 0.01, 3)
	puddle.mesh = pm
	puddle.material_override = Graybox.WET
	puddle.position = Vector3(-1.5, 0.005, 1.5)
	own(puddle, room)
	var wet := WetZone.new()
	wet.name = "ZonaBagnata"
	wet.position = Vector3(-1.5, 0.3, 1.5)
	own(wet, room)
	shape_box(wet, Vector3(3, 0.6, 3))

	# Acqua che scorre (ricarica il serbatoio) e vasca piccola da cui aspirare.
	var stream := FlowingWater.new()
	stream.name = "AcquaCheScorre"
	stream.size = Vector3(1.2, 0.12, 4.0)
	stream.position = Vector3(-4.5, 0, -2.0)
	own(stream, room)
	var basin := inst(TANK, room, "VascaPiccola", Vector3(3.5, 0, -0.5))
	basin.set(&"inner_size", Vector3(1.4, 0.6, 1.0))
	basin.set(&"wall_thickness", 0.15)
	basin.set(&"capacity_liters", 15.0)
	basin.set(&"fill", 0.9)
	basin.set(&"max_fill", 0.9)

	# Oggetti fisici da spingere col getto o camminando.
	ball(room, "Palla1", Vector3(2.5, 0.3, -2.5), 0.3, 2.0)
	ball(room, "Palla2", Vector3(3.3, 0.3, -3.2), 0.25, 1.5)
	crate(room, "Cassa", Vector3(-2.0, 0.3, -3.5), 0.6, 8.0)

	# Giocatore e primo checkpoint.
	var player := inst(PLAYER, level, "Player", Vector3(0, 0, 4.5))
	player.rotation = Vector3.ZERO
	checkpoint(room, "CheckpointPartenza", 0, Vector3(0, 1.5, 4.0), Vector3(4, 3, 3), Vector3(0, -1.5, 0.5))

	# Cartelli.
	label(room, "TURBINA\nspruzzala (tasto sinistro): apre la porta", Vector3(-3.5, 3.55, -5.95))
	label(room, "SCALA A PIOLI: avvicinati e premi W", Vector3(3.7, 3.1, -4.0), 0.0)
	label(room, "PASSAGGIO BASSO\ntieni premuto Ctrl", Vector3(-6.95, 1.75, 2.0), PI * 0.5)
	label(room, "MENSOLA ALTA\nsalta e spruzza verso il basso", Vector3(-6.0, 2.4, 3.95), PI)
	label(room, "PAVIMENTO BAGNATO\n(passi bagnati)", Vector3(-1.5, 1.0, 3.05))
	label(room, "ACQUA CHE SCORRE\nricarica lo zaino", Vector3(-4.5, 1.2, -0.0))
	label(room, "VASCA PICCOLA\naspira col tasto destro", Vector3(3.5, 1.5, 0.1))

	# Luci.
	omni(room, "Luce", Vector3(0, 4.1, 0), Color(1.0, 0.92, 0.8), 1.4, 11.0)
	omni(room, "LuceNicchia", Vector3(-11, 1.9, 2), Color(0.7, 0.8, 1.0), 0.8, 5.0)
	omni(room, "LuceEmergenza", Vector3(6.4, 4.1, 5.4), Color(1.0, 0.12, 0.06), 1.2, 6.0)
	omni(room, "LuceTurbina", Vector3(-3.5, 3.6, -4.8), Color(1.0, 0.85, 0.6), 0.7, 5.0, false)


# --- Corridoio e sala delle vasche --------------------------------------------------------

func _build_tank_hall() -> void:
	var hall := group("SalaVasche")
	var csg := csg_root(hall, "Muri")
	box(csg, "Esterno", Vector3(19, 12, 19), Vector3(0, 2.5, -19), UNION)
	box(csg, "Interno", Vector3(18, 8.05, 18), Vector3(0, 3.975, -19), SUB)
	box(csg, "Pavimento", Vector3(18.5, 0.05, 18.5), Vector3(0, -0.025, -19), UNION, Graybox.FLOOR)
	box(csg, "CorridoioEsterno", Vector3(4, 4.0, 3.6), Vector3(0, 1.5, -8.0), UNION)
	box(csg, "CorridoioInterno", Vector3(3, 3.05, 4.4), Vector3(0, 1.475, -8.0), SUB)
	box(csg, "CorridoioPavimento", Vector3(3.4, 0.05, 4.4), Vector3(0, -0.025, -8.0), UNION, Graybox.FLOOR)
	box(csg, "Gradino", Vector3(4, 1.4, 1.5), Vector3(0, 0.7, -15.75), UNION, Graybox.DARK)
	box(csg, "Rampa", Vector3(4, 0.2, 4.6), Vector3(0, 0.6051, -12.9316), UNION, Graybox.DARK, Vector3(atan(1.0 / 3.0), 0, 0))
	box(csg, "Sporgenza", Vector3(6, 2.5, 5), Vector3(0, 1.25, -25.5), UNION, Graybox.DARK)
	box(csg, "BucoVasca", Vector3(6, 2.3, 7), Vector3(0, -1.05, -20), SUB)
	box(csg, "Pozzo", Vector3(2, 3.0, 2), Vector3(6.5, -1.5, -14), SUB, Graybox.DARK)

	# Vasca grande con la piattaforma galleggiante e la scala per uscire quando è vuota.
	var tank := inst(TANK, hall, "VascaGrande", Vector3(0, -1.6, -20))
	tank.set(&"inner_size", Vector3(5, 3.0, 6))
	tank.set(&"wall_thickness", 0.5)
	tank.set(&"capacity_liters", 40.0)
	tank.set(&"max_fill", 0.95)
	var platform := inst(PLATFORM, hall, "PiattaformaGalleggiante", Vector3(0, -1.3, -20))
	platform.set(&"size", Vector3(2.6, 0.6, 2.6))
	platform.set(&"draft", 0.15)
	platform.set(&"tank", tank)
	var ladder := inst(LADDER, hall, "ScalaVasca", Vector3(1.8, -1.6, -17.0), PI)
	ladder.set(&"height", 3.0)

	# Vasca sorgente: si aspira da qui per riempire quella grande.
	var source := inst(TANK, hall, "VascaSorgente", Vector3(-6, 0, -20))
	source.set(&"inner_size", Vector3(2.5, 1.0, 2.5))
	source.set(&"wall_thickness", 0.25)
	source.set(&"capacity_liters", 60.0)
	source.set(&"max_fill", 0.95)
	source.set(&"fill", 0.95)

	# Pulsante sul muro ovest: apre e chiude lo scarico della vasca grande.
	var button := inst(BUTTON, hall, "PulsanteScarico", Vector3(-9.0, 2.0, -15.5), PI * 0.5)
	var drains: Array[PowerSource] = [button as PowerSource]
	tank.set(&"drain_sources", drains)

	polaroid(hall, "Polaroid03", Vector3(0, 2.5, -25.5))

	# Manichino: lo spinge il getto; se lo lasci arrivare troppo vicino ti uccide.
	var dummy := inst(DUMMY, hall, "Manichino", Vector3(6.5, 0, -24.5))
	dummy.set(&"kill_distance", 1.0)
	dummy.set(&"stop_distance", 0.6)

	ball(hall, "Palla3", Vector3(-4.5, 0.3, -12.0), 0.3, 2.0)
	crate(hall, "Cassa2", Vector3(4.0, 0.3, -12.5), 0.6, 8.0)

	# Pozzo mortale (per provare la morte e la ripartenza dal checkpoint).
	var kill: Area3D = load("res://scripts/game/kill_zone.gd").new()
	kill.name = "PozzoMortale"
	kill.set(&"cause", &"caduta")
	kill.position = Vector3(6.5, -2.4, -14)
	own(kill, hall)
	shape_box(kill, Vector3(2, 1.0, 2))
	var glow := MeshInstance3D.new()
	glow.name = "FondoPozzo"
	var gm := BoxMesh.new()
	gm.size = Vector3(1.9, 0.05, 1.9)
	glow.mesh = gm
	glow.material_override = Graybox.lamp_material(Color(1.0, 0.1, 0.05), 1.5)
	glow.position = Vector3(6.5, -2.95, -14)
	own(glow, hall)

	checkpoint(hall, "CheckpointCorridoio", 1, Vector3(0, 1.5, -8.0), Vector3(3, 3, 2), Vector3(0, -1.5, 0))
	checkpoint(hall, "CheckpointSporgenza", 2, Vector3(0, 4.0, -25.0), Vector3(6, 3, 4), Vector3(0, -1.5, 0))

	label(hall, "VASCA SORGENTE\naspira (tasto destro), poi spruzza\nnella vasca grande", Vector3(-6, 2.2, -18.6))
	label(hall, "VASCA GRANDE: riempila col getto,\nla piattaforma sale fino alla sporgenza", Vector3(0, 4.6, -27.95))
	label(hall, "PULSANTE\nscarico della vasca (on/off)", Vector3(-8.95, 3.0, -15.5), PI * 0.5)
	label(hall, "POZZO MORTALE\n(prova della morte)", Vector3(6.5, 1.6, -12.9))
	label(hall, "MANICHINO: spruzzalo per spingerlo.\nNon farti prendere!", Vector3(6.5, 2.4, -22.0))

	omni(hall, "Luce", Vector3(0, 7.5, -19), Color(0.85, 0.9, 1.0), 2.2, 20.0)
	omni(hall, "LuceIngresso", Vector3(-5, 3.5, -12.5), Color(1.0, 0.9, 0.75), 1.0, 9.0)
	omni(hall, "LuceVasca", Vector3(0, 3.5, -20), Color(0.6, 0.85, 1.0), 0.8, 7.0, false)
	omni(hall, "LuceEmergenza", Vector3(7.5, 3.0, -26.5), Color(1.0, 0.12, 0.06), 1.4, 8.0)


# --- Aiuti ---------------------------------------------------------------------------------

func own(n: Node, parent: Node = null) -> Node:
	(parent if parent else level).add_child(n)
	n.owner = level
	return n


func group(node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	own(n)
	return n


func csg_root(parent: Node, node_name: String) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	c.name = node_name
	c.use_collision = true
	c.collision_layer = Layers.WORLD
	c.collision_mask = 0
	own(c, parent)
	return c


func box(parent: Node, node_name: String, size: Vector3, pos: Vector3, op: int, mat: Material = Graybox.WALL, rot := Vector3.ZERO) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.rotation = rot
	b.operation = op
	b.material = mat
	own(b, parent)
	return b


func inst(scene: PackedScene, parent: Node, node_name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := scene.instantiate() as Node3D
	n.name = node_name
	n.position = pos
	n.rotation = Vector3(0, yaw, 0)
	own(n, parent)
	return n


func shape_box(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	own(cs, parent)
	return cs


func pickup(parent: Node, node_name: String, id: StringName, display: String, pos: Vector3) -> Node3D:
	var p := inst(PICKUP, parent, node_name, pos)
	p.set(&"item_id", id)
	p.set(&"item_name", display)
	return p


func polaroid(parent: Node, node_name: String, pos: Vector3) -> Node3D:
	var p := inst(POLAROID, parent, node_name, pos)
	p.set(&"entry_id", StringName(node_name.to_lower()))
	return p


func checkpoint(parent: Node, node_name: String, order: int, pos: Vector3, size: Vector3, spawn_offset: Vector3) -> Area3D:
	# Caricato a runtime: gli script che usano l'autoload GameState non si compilano prima.
	var cp: Area3D = load("res://scripts/game/checkpoint.gd").new()
	cp.name = node_name
	cp.set(&"order", order)
	cp.position = pos
	own(cp, parent)
	shape_box(cp, size)
	var spawn := Marker3D.new()
	spawn.name = "Ripartenza"
	spawn.position = spawn_offset
	own(spawn, cp)
	cp.set(&"spawn_point", spawn)
	return cp


func ball(parent: Node, node_name: String, pos: Vector3, radius: float, mass: float) -> RigidBody3D:
	var b := _rigid(parent, node_name, pos, mass)
	var s := SphereShape3D.new()
	s.radius = radius
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = s
	own(cs, b)
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = m
	mi.material_override = Graybox.TARGET
	own(mi, b)
	return b


func crate(parent: Node, node_name: String, pos: Vector3, size: float, mass: float) -> RigidBody3D:
	var b := _rigid(parent, node_name, pos, mass)
	var s := BoxShape3D.new()
	s.size = Vector3.ONE * size
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = s
	own(cs, b)
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = m
	mi.material_override = Graybox.WALL
	own(mi, b)
	return b


func _rigid(parent: Node, node_name: String, pos: Vector3, mass: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = node_name
	b.position = pos
	b.mass = mass
	b.collision_layer = Layers.PROPS
	b.collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMIES | Layers.PROPS
	own(b, parent)
	return b


func label(parent: Node, text: String, pos: Vector3, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	_labels += 1
	l.name = "Cartello%02d" % _labels
	l.text = text
	l.position = pos
	l.rotation = Vector3(0, yaw, 0)
	l.font_size = 30
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color(1.0, 0.93, 0.7)
	own(l, parent)
	return l


func omni(parent: Node, node_name: String, pos: Vector3, color: Color, energy: float, light_range: float, shadow := true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.name = node_name
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = light_range
	o.shadow_enabled = shadow
	own(o, parent)
	return o

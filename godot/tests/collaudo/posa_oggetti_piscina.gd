extends Node
## Dove spostare i gonfiabili d'arredo della parte profonda della piscina a onde (enigma dei giocattoli, coordinatore 28
## ottobre: nella parte profonda solo i tre giocattoli dell'enigma). Le due paperelle giganti sulla spiaggia, inclinate
## come la pendenza; i quattro palloni giù per la spiaggia fino a fermarsi contro qualcosa (una paperella, il delfino
## sgonfio, la paperella in cima alla spiaggia), come farebbe un pallone vero. Stampa le trasformazioni da scrivere nella
## scena (Sala/Oggetti, sala_oggetti.glb).

## [x, z, gradi di imbardata]
const PAPERELLE := {"ogg_paperella_gigante_0": [-5.6, -7.6, 40.0], "ogg_paperella_gigante_1": [5.3, -7.0, -159.0]}
## [x, z da dove parte (in basso), chi lo ferma]
const PALLONI := {"ogg_pallone_spiaggia_2": [-4.0, -4.7, "ogg_delfino_gonfiabile_sgonfio_8"],
	"ogg_pallone_spiaggia_3": [0.05, -7.6, "ogg_paperella_gigante_57"],
	"ogg_pallone_spiaggia_43": [5.25, -5.7, "ogg_paperella_gigante_1"],
	"ogg_pallone_spiaggia_71": [-5.65, -6.4, "ogg_paperella_gigante_0"]}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate() as Node3D
	add_child(s)
	for i in 30:
		await get_tree().physics_frame
	var oggetti := s.get_node(^"Sala/Oggetti") as Node3D
	var spazio := s.get_world_3d().direct_space_state
	var fondo_rid: RID
	for nome in PAPERELLE:
		var v: Array = PAPERELLE[nome]
		var h := _giu(spazio, Vector3(v[0], 3.0, v[1]), [])
		fondo_rid = (h.collider as CollisionObject3D).get_rid()
		var n: Vector3 = h.normal
		var o := oggetti.get_node(NodePath(nome)) as Node3D
		o.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, deg_to_rad(v[2])), h.position)
		_stampa(oggetti, o)
	for i in 4:
		await get_tree().physics_frame
	for nome in PALLONI:
		var v: Array = PALLONI[nome]
		var o := oggetti.get_node(NodePath(nome)) as MeshInstance3D
		var r := o.get_aabb().size.y * 0.5 * o.scale.y
		var corpo := o.get_child(0) as CollisionObject3D
		var h := _giu(spazio, Vector3(v[0], 3.0, v[1]), [corpo.get_rid()])
		var n: Vector3 = h.normal
		var su := Vector3(0.0, n.z, -n.y).normalized()   # su per la spiaggia (verso nord)
		var c0: Vector3 = (h.position as Vector3) + n * (r + 0.004)
		var sfera := SphereShape3D.new()
		sfera.radius = r
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sfera
		q.transform = Transform3D(Basis(), c0)
		q.motion = su * 3.0
		q.collision_mask = Layers.WORLD
		q.exclude = [corpo.get_rid(), (h.collider as CollisionObject3D).get_rid()]
		var f := spazio.cast_motion(q)
		var c := c0 + su * 3.0 * f[0]
		var contro := ""
		q.transform = Transform3D(Basis(), c + su * 0.02)
		q.motion = Vector3.ZERO
		for hh in spazio.intersect_shape(q, 4):
			contro += String((hh.collider as Node).get_parent().name) + " "
		o.global_transform = Transform3D(Basis(Vector3.UP, o.rotation.y), c - Vector3(0.0, r, 0.0))
		print("  %s: raggio %.3f, fermo dopo %.2f m contro %s (voluto %s)" % [nome, r, 3.0 * f[0], contro, v[2]])
		_stampa(oggetti, o)
	get_tree().quit()


func _giu(spazio: PhysicsDirectSpaceState3D, da: Vector3, escludi: Array) -> Dictionary:
	var ex: Array[RID] = []
	for e in escludi:
		ex.append(e)
	var q := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 8.0, Layers.WORLD, ex)
	return spazio.intersect_ray(q)


func _stampa(oggetti: Node3D, o: Node3D) -> void:
	var t := oggetti.global_transform.affine_inverse() * o.global_transform
	print("POSA %s transform = Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" % [o.name,
		t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z,
		t.origin.x, t.origin.y, t.origin.z])

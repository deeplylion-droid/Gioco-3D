extends Node
## Sonda del posizionamento delle cose della squadra mascotte nella sala principale, al centimetro (regola
## dell'utente: "basta con queste robe volanti o staccate dal resto"; anche 1-2 cm sono un difetto):
## le statue dello squalo e dei polpi, la targa, il manifesto e l'insegna di Jilly con le lampade, Jilly affacciata
## alla vasca centrale e (dopo il blackout) alla fossa. Per ogni pezzo (ogni mesh):
## - TOCCA: se c'è qualcosa (un'altra mesh, un muro, il pavimento, un altro pezzo dello stesso oggetto) entro
##   [constant CONTATTO] da almeno un suo vertice; se no la distanza minima (è staccato, sospeso);
## - APPOGGIO (statue): quanto stanno sopra il pavimento i punti più bassi della base;
## - PARETE (targa, manifesto, insegna): quanto sta il retro dalla parete;
## - DENTRO: i suoi vertici dentro un'altra cosa (non sua) più di [constant CONTATTO], con la profondità.
## Le mesh senza collisione hanno per la sonda una collisione temporanea (trimesh) su uno strato suo, come nel
## controllo di posizionamento della CI. Jilly è deformata dallo scheletro: i suoi vertici sono quelli disegnati.
## Per la squadra (proposte/ è esclusa dall'export).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://proposte/mascotte/sonda_mascotte_posizioni.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const CONTATTO := 0.012
const STRATO := 1 << 20
const VERTICI_MAX := 3000
const MIE := ["Mascotte/StatuaSqualo", "Mascotte/StatuaPolpoA", "Mascotte/StatuaPolpoB", "Mascotte/TargaJilly",
	"Mascotte/ManifestoJilly", "Mascotte/InsegnaJilly", "Vasca/Medusa", "Gioco/LeiSbuca/MedusaFossa"]

var level: Node
var spazio: PhysicsDirectSpaceState3D
var _di := {}          # RID del corpo -> il nodo "mio" a cui appartiene (o null)
var _nome := {}        # RID del corpo -> percorso leggibile


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	level = (load(LEVEL) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(20)
	# Jilly alla fossa: dopo il blackout, affacciata (fase GUARDA)
	GameState.luci = GameState.Luci.BLACKOUT
	var ls := level.get_node("Gioco/LeiSbuca")
	ls.call(&"_affaccia")
	await _frames(10)
	for n in level.find_children("*", "Node", true, false):
		n.set_physics_process(false)
		if n is AnimationPlayer:
			(n as AnimationPlayer).pause()
	spazio = level.get_viewport().world_3d.direct_space_state
	var mie: Array[Node3D] = []
	for pth in MIE:
		mie.append(level.get_node(pth) as Node3D)
	var zona := AABB()
	for m in mie:
		var a := _aabb(m)
		zona = a if zona.size == Vector3.ZERO else zona.merge(a)
	_corpi_temporanei(mie)
	await _frames(3)
	for m in mie:
		_controlla(m, mie)
	print("FINE")
	get_tree().quit()


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	for mi in _mesh_di(n):
		var a := mi.global_transform * mi.get_aabb()
		out = a if out.size == Vector3.ZERO else out.merge(a)
	return out


func _mesh_di(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh and mi.is_visible_in_tree():
			out.append(mi)
	return out


func _mio(n: Node, mie: Array[Node3D]) -> Node3D:
	for m in mie:
		if m == n or m.is_ancestor_of(n):
			return m
	return null


## Le collisioni temporanee: ogni mesh visibile vicino alle mie cose (non deformata, non acqua) e ogni mio pezzo
## non deformato; i corpi del mondo che ci sono già, segnati con il loro proprietario.
func _corpi_temporanei(mie: Array[Node3D]) -> void:
	var vicino: Array[AABB] = []
	for m in mie:
		vicino.append(_aabb(m).grow(0.6))
	for c in level.find_children("*", "CollisionObject3D", true, false):
		var co := c as CollisionObject3D
		_di[co.get_rid()] = _mio(co, mie)
		_nome[co.get_rid()] = String(level.get_path_to(co))
	for c in level.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.skin != null:
			continue
		var nm := String(mi.name).to_lower()
		if nm.contains("acqua") or nm.contains("water") or nm.contains("pelo") or nm.contains("superficie"):
			continue
		var a := mi.global_transform * mi.get_aabb()
		var serve := false
		for v in vicino:
			if v.intersects(a):
				serve = true
		if not serve or a.size.length() > 40.0:
			continue
		var corpo := StaticBody3D.new()
		corpo.collision_layer = STRATO
		corpo.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		corpo.add_child(cs)
		mi.add_child(corpo)
		corpo.global_transform = mi.global_transform
		_di[corpo.get_rid()] = _mio(mi, mie)
		_nome[corpo.get_rid()] = String(level.get_path_to(mi))


## I vertici del pezzo nel mondo (deformati dallo scheletro se ha una skin), al più VERTICI_MAX.
func _vertici(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var m := mi.mesh
	var tot := 0
	for s in m.get_surface_count():
		tot += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var passo := maxi(1, tot / VERTICI_MAX)
	var pose: Array = []
	if mi.skin:
		var sk := mi.get_node(mi.skeleton) as Skeleton3D
		for i in mi.skin.get_bind_count():
			var osso := mi.skin.get_bind_bone(i)
			if osso < 0:
				osso = sk.find_bone(mi.skin.get_bind_name(i))
			pose.append(sk.global_transform * sk.get_bone_global_pose(osso) * mi.skin.get_bind_pose(i))
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var b = a[Mesh.ARRAY_BONES]
		var w = a[Mesh.ARRAY_WEIGHTS]
		var k: int = (b as PackedInt32Array).size() / maxi(v.size(), 1) if b != null else 0
		for i in range(0, v.size(), passo):
			if mi.skin and k > 0:
				var q := Vector3.ZERO
				var tw := 0.0
				for j in k:
					var ww: float = w[i * k + j]
					if ww > 0.0:
						q += (pose[b[i * k + j]] as Transform3D) * v[i] * ww
						tw += ww
				out.append(q / tw if tw > 0.0 else mi.global_transform * v[i])
			else:
				out.append(mi.global_transform * v[i])
	return out


func _controlla(ob: Node3D, mie: Array[Node3D]) -> void:
	print("== ", level.get_path_to(ob))
	var parti := _mesh_di(ob)
	var tutti := PackedVector3Array()
	for mi in parti:
		var vv := _vertici(mi)
		tutti.append_array(vv)
		var esclusi := _corpi_propri(mi)
		var r := _tocca(vv, esclusi)
		var d := _dentro(vv, ob)
		var riga := "   %s: %s" % [mi.name, "tocca %s" % r[1] if r[0] else "STACCATO: niente entro %.3f m (il più vicino a %s)" % [CONTATTO, r[1]]]
		if d[0] > 0:
			riga += "; DENTRO %s per %d vertici, fino a %.3f m (%s)" % [d[2], d[0], d[1], _bl(d[3])]
		print(riga)
	if ob.name.begins_with("Statua"):
		_appoggio(tutti, ob)
	elif ob.get_parent().name == "Mascotte":
		_parete(tutti, ob)


## I corpi di questo pezzo (la sua collisione temporanea e, per le statue, la collisione della statua).
func _corpi_propri(mi: MeshInstance3D) -> Array[RID]:
	var out: Array[RID] = []
	for c in mi.find_children("*", "StaticBody3D", false, false):
		out.append((c as StaticBody3D).get_rid())
	var p := mi.get_parent()
	while p and p != level:
		if p.name.begins_with("Statua"):
			for c in p.find_children("Collisione", "StaticBody3D", false, false):
				out.append((c as StaticBody3D).get_rid())
		p = p.get_parent()
	return out


## [tocca, con cosa / quanto è lontano il più vicino]
func _tocca(vv: PackedVector3Array, esclusi: Array[RID]) -> Array:
	var sf := SphereShape3D.new()
	for raggio in [CONTATTO, 0.03, 0.06, 0.12, 0.25]:
		sf.radius = raggio
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sf
		q.collision_mask = STRATO | Layers.WORLD
		q.exclude = esclusi
		for v in vv:
			q.transform = Transform3D(Basis(), v)
			var hit := spazio.intersect_shape(q, 1)
			if not hit.is_empty():
				var chi := String(_nome.get((hit[0]["rid"] as RID), "?"))
				if raggio == CONTATTO:
					return [true, chi]
				return [false, "%.3f m (%s)" % [raggio, chi]]
	return [false, "più di 0,25 m"]


## [quanti vertici dentro, profondità massima, dentro cosa, dove]: dentro un corpo non mio (nemmeno dello
## stesso oggetto). Un corpo convesso del mondo: intersect_point; una trimesh: i raggi in tre direzioni la
## attraversano un numero dispari di volte.
func _dentro(vv: PackedVector3Array, ob: Node3D) -> Array:
	var n := 0
	var prof := 0.0
	var chi := ""
	var dove := Vector3.ZERO
	var sf := SphereShape3D.new()
	for v in vv:
		var corpo := _corpo_che_contiene(v, ob)
		if not corpo.is_valid():
			continue
		# la profondità: il raggio della sfera più piccola che tocca la sua superficie
		var p := 0.0
		for r in [0.005, 0.012, 0.025, 0.05, 0.1, 0.2]:
			sf.radius = r
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sf
			q.collision_mask = STRATO | Layers.WORLD
			q.transform = Transform3D(Basis(), v)
			var tocca := false
			for h in spazio.intersect_shape(q, 8):
				if (h["rid"] as RID) == corpo:
					tocca = true
			if tocca:
				break
			p = r
		if p < CONTATTO:
			continue
		n += 1
		if p > prof:
			prof = p
			chi = String(_nome.get(corpo, "?"))
			dove = v
	return [n, prof, chi, dove]


func _corpo_che_contiene(v: Vector3, ob: Node3D) -> RID:
	var qp := PhysicsPointQueryParameters3D.new()
	qp.position = v
	qp.collision_mask = Layers.WORLD
	for h in spazio.intersect_point(qp, 8):
		var rid := (h["rid"] as RID)
		if _di.get(rid) != ob:
			return rid
	var conti: Array[Dictionary] = []
	for dir in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT]:
		var c := {}
		var da := v
		for i in 40:
			var q := PhysicsRayQueryParameters3D.create(da, v + dir * 30.0, STRATO | Layers.WORLD)
			q.hit_back_faces = true
			var h := spazio.intersect_ray(q)
			if h.is_empty():
				break
			var rid := (h["rid"] as RID)
			c[rid] = int(c.get(rid, 0)) + 1
			da = (h["position"] as Vector3) + dir * 0.0005
		conti.append(c)
	for rid in conti[0]:
		if _di.get(rid) == ob:
			continue
		if int(conti[0][rid]) % 2 == 1 and int(conti[1].get(rid, 0)) % 2 == 1 and int(conti[2].get(rid, 0)) % 2 == 1:
			return rid
	return RID()


## Statue: i punti più bassi (entro 2 cm dal minimo) e il pavimento sotto ciascuno.
func _appoggio(vv: PackedVector3Array, ob: Node3D) -> void:
	var minimo := INF
	for v in vv:
		minimo = minf(minimo, v.y)
	var sopra := []
	for v in vv:
		if v.y > minimo + 0.02:
			continue
		var q := PhysicsRayQueryParameters3D.create(v + Vector3.UP * 0.05, v + Vector3.DOWN * 0.5, Layers.WORLD)
		q.exclude = _corpi_propri_statua(ob)
		var h := spazio.intersect_ray(q)
		if not h.is_empty():
			sopra.append(v.y - (h["position"] as Vector3).y)
	sopra.sort()
	if sopra.is_empty():
		print("   APPOGGIO: niente pavimento sotto la base!")
	else:
		print("   APPOGGIO: %d punti della base, da %+.3f a %+.3f m sopra il pavimento (meno: dentro)" % [sopra.size(), sopra[0], sopra[-1]])


func _corpi_propri_statua(ob: Node3D) -> Array[RID]:
	var out: Array[RID] = []
	for c in ob.find_children("*", "StaticBody3D", true, false):
		out.append((c as StaticBody3D).get_rid())
	return out


## Oggetti da parete: i punti del retro (entro 1 cm dal più arretrato) e la parete dietro ciascuno.
func _parete(vv: PackedVector3Array, ob: Node3D) -> void:
	var n := ob.global_basis.z.normalized()      # il davanti
	var dietro := INF
	for v in vv:
		dietro = minf(dietro, v.dot(n))
	var gap := []
	for v in vv:
		if v.dot(n) > dietro + 0.01:
			continue
		var q := PhysicsRayQueryParameters3D.create(v + n * 0.05, v - n * 0.3, Layers.WORLD)
		var h := spazio.intersect_ray(q)
		if not h.is_empty():
			gap.append((v - (h["position"] as Vector3)).dot(n))
	gap.sort()
	if gap.is_empty():
		print("   PARETE: niente parete dietro il retro!")
	else:
		print("   PARETE: %d punti del retro, da %+.3f a %+.3f m dalla parete (meno: dentro)" % [gap.size(), gap[0], gap[-1]])


func _bl(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

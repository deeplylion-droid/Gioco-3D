extends Node
## La posa dei tentacoli di lei affacciata alla fossa dei bimbi (tappa 8), calcolata una volta qui e salvata in
## res://assets/models/medusa/tentacoli_fossa.json; nel gioco la mette TentacoliControIMuri (posa_fissa), senza
## fisica. La posa "affacciata" è fatta per il muro dritto della vasca centrale: nella fossa i tentacoli entravano
## nell'angolo del bordo, nelle pareti e nel pavimento.
## Per ogni tentacolo, osso per osso dalla radice alla punta, con i vertici veri della mesh (lo skinning sulla
## CPU): se un vertice dell'osso è dentro la collisione del mondo, si cerca la rotazione più piccola della sua
## direzione che li porta tutti fuori (a passi di 3 gradi, in 16 direzioni intorno), preferendo quella che alza il
## tratto nel suo piano verticale. Gli ossi dopo ripartono dalla
## direzione dell'animazione, spostati con lui: il tentacolo si appoggia al bordo e ricade come nella posa.
## Uso (da godot/, con il lock):
##   godot --headless --path . --fixed-fps 60 --script res://tests/run.gd -- res://tools/tentacoli_fossa_posa.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const USCITA := "res://assets/models/medusa/tentacoli_fossa.json"
const PASSO := 3.0              # gradi
const MASSIMO := 120.0          # gradi
const GIRI := 16                # direzioni intorno
const LATO := 1.5               # quanto costa in più girare di lato invece di alzare

var spazio: PhysicsDirectSpaceState3D
var _p := PhysicsPointQueryParameters3D.new()
var sk: Skeleton3D
var mondo := {}                 # osso -> Transform3D nel mondo (la posa attuale)
var verts := {}                 # osso -> [[v, [ossi], [pesi], [bind]], ...] (i vertici col peso più grande su di lui)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := (load(LEVEL) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	for i in 20:
		await get_tree().physics_frame
	GameState.luci = GameState.Luci.BLACKOUT
	var ls := level.get_node("Gioco/LeiSbuca")
	ls.call(&"_affaccia")
	ls.set_process(false)
	ls.set_physics_process(false)
	for i in 10:
		await get_tree().physics_frame
	var medusa := level.get_node("Gioco/LeiSbuca/MedusaFossa") as Node3D
	for n in medusa.find_children("*", "AnimationPlayer", true, false):
		(n as AnimationPlayer).seek(0.0, true)
		(n as AnimationPlayer).pause()
	for t in medusa.find_children("*", "SkeletonModifier3D", true, false):
		if t is TentacoliControIMuri:
			(t as SkeletonModifier3D).active = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	spazio = level.get_viewport().world_3d.direct_space_state
	_p.collision_mask = Layers.WORLD
	_p.collide_with_areas = false
	var coperchio = ls.get(&"coperchio")
	if coperchio:
		_p.exclude = [(coperchio as CollisionObject3D).get_rid()]
	sk = medusa.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	await sk.skeleton_updated
	var sg := sk.global_transform
	for b in sk.get_bone_count():
		mondo[b] = sg * sk.get_bone_global_pose(b)
	_leggi_vertici()
	var catene := _catene()
	var giri := {}
	var dentro_prima := 0
	var dentro_dopo := 0
	for catena in catene:
		var n := catena.size()
		var p := PackedVector3Array()
		var g: Array[Transform3D] = []
		for b in catena:
			g.append(mondo[b])
			p.append((mondo[b] as Transform3D).origin)
		p.append(p[n - 1] + (p[n - 1] - p[n - 2]))
		for b in catena:
			dentro_prima += _dentro(b)
		var inizio := p[0]
		for i in n:
			var d0 := p[i + 1] - p[i]
			# l'osso e quelli dopo, spostati con lui (le loro direzioni restano quelle dell'animazione)
			var migliore := Quaternion.IDENTITY
			var peggio := _prova(catena, i, g, inizio, d0, Quaternion.IDENTITY)
			if peggio > 0:
				# fra le rotazioni che portano fuori tutti i vertici, la più economica: l'angolo, più caro se gira di
				# lato invece di alzare il tratto nel suo piano verticale (così la parte in più si stende sul
				# pavimento o sul bordo come un drappo, invece di tornare nella fossa)
				var asse0 := d0.normalized().cross(Vector3.UP)
				if asse0.length() < 1e-3:
					asse0 = d0.normalized().cross(Vector3.RIGHT)
				asse0 = asse0.normalized()
				var costo_min := INF
				var minimo := peggio
				var migliore_parziale := Quaternion.IDENTITY
				var a := PASSO
				while a <= MASSIMO and a < costo_min:
					for k in GIRI:
						var lato := TAU * k / GIRI
						var costo := a * (1.0 + LATO * (1.0 - cos(lato)))
						if costo >= costo_min:
							continue
						var q := Quaternion(asse0.rotated(d0.normalized(), lato), deg_to_rad(a))
						var c := _prova(catena, i, g, inizio, d0, q)
						if c == 0:
							costo_min = costo
							migliore = q
						elif c < minimo:
							minimo = c
							migliore_parziale = q
					a += PASSO
				if costo_min == INF:
					migliore = migliore_parziale
				_prova(catena, i, g, inizio, d0, migliore)
			giri[sk.get_bone_name(catena[i])] = migliore
			inizio = inizio + migliore * d0
		for b in catena:
			var c := _dentro(b)
			dentro_dopo += c
			if c > 0:
				print("   resta %s: %d vertici" % [sk.get_bone_name(b), c])
	# nel riferimento dello scheletro (lei può essere rimessa altrove con la stessa posa relativa)
	var r := sg.basis.get_rotation_quaternion()
	var out := {"origine_scheletro": [sg.origin.x, sg.origin.y, sg.origin.z], "giri": {}}
	var piegati := 0
	for nome in giri:
		var q: Quaternion = giri[nome]
		if q.is_equal_approx(Quaternion.IDENTITY):
			continue
		piegati += 1
		var ql := r.inverse() * q * r
		out["giri"][nome] = [ql.x, ql.y, ql.z, ql.w]
	var f := FileAccess.open(USCITA, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("vertici dei tentacoli nel pieno: prima %d, dopo %d; ossi girati %d" % [dentro_prima, dentro_dopo, piegati])
	print("SCRITTO ", USCITA)
	get_tree().quit()


## Mette l'osso i della catena girato di q (dalla direzione dell'animazione), con la testa in [param inizio], e
## gli ossi dopo spostati con lui; restituisce quanti vertici dell'osso sono nel pieno.
func _prova(catena: PackedInt32Array, i: int, g: Array[Transform3D], inizio: Vector3, d0: Vector3, q: Quaternion) -> int:
	var b := catena[i]
	mondo[b] = Transform3D(Basis(q) * g[i].basis, inizio)
	var fine := inizio + q * d0
	var sposta := fine - g[i + 1].origin if i + 1 < catena.size() else Vector3.ZERO
	for j in range(i + 1, catena.size()):
		mondo[catena[j]] = Transform3D(g[j].basis, g[j].origin + sposta)
	return _dentro(b)


## Quanti vertici dell'osso (quelli col peso più grande su di lui) sono nel pieno, nella posa di [member mondo].
func _dentro(b: int) -> int:
	var conta := 0
	for vv in verts.get(b, []):
		var pos := Vector3.ZERO
		var ossi: PackedInt32Array = vv[1]
		var pesi: PackedFloat32Array = vv[2]
		var bind: Array = vv[3]
		for j in ossi.size():
			pos += ((mondo[ossi[j]] as Transform3D) * (bind[j] as Transform3D) * (vv[0] as Vector3)) * pesi[j]
		_p.position = pos
		if not spazio.intersect_point(_p, 1).is_empty():
			conta += 1
	return conta


func _leggi_vertici() -> void:
	for n in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or mi.mesh == null or not String(mi.name).contains("Tentacoli"):
			continue
		var skin := mi.skin
		var ossa := PackedInt32Array()
		for i in skin.get_bind_count():
			var o := skin.get_bind_bone(i)
			if o < 0:
				o = sk.find_bone(skin.get_bind_name(i))
			ossa.append(o)
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bb: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var k := bb.size() / maxi(v.size(), 1)
			for i in v.size():
				var jm := 0
				var ossi := PackedInt32Array()
				var pesi := PackedFloat32Array()
				var bind := []
				var tot := 0.0
				for j in k:
					if w[i * k + j] > w[i * k + jm]:
						jm = j
					if w[i * k + j] > 0.0:
						ossi.append(ossa[bb[i * k + j]])
						pesi.append(w[i * k + j])
						bind.append(skin.get_bind_pose(bb[i * k + j]))
						tot += w[i * k + j]
				for j in pesi.size():
					pesi[j] /= maxf(tot, 1e-6)
				var dom := ossa[bb[i * k + jm]]
				if not verts.has(dom):
					verts[dom] = []
				(verts[dom] as Array).append([v[i], ossi, pesi, bind])
	var tot := 0
	for b in verts:
		tot += (verts[b] as Array).size()
	print("vertici dei tentacoli: ", tot)


func _catene() -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for b in sk.get_bone_count():
		if not sk.get_bone_name(b).begins_with("tentacolo_"):
			continue
		var p := sk.get_bone_parent(b)
		if p >= 0 and sk.get_bone_name(p).begins_with("tentacolo_"):
			continue
		var catena := PackedInt32Array([b])
		var c := b
		while true:
			var dopo := -1
			for f in sk.get_bone_children(c):
				if sk.get_bone_name(f).begins_with("tentacolo_"):
					dopo = f
					break
			if dopo < 0:
				break
			catena.append(dopo)
			c = dopo
		if catena.size() >= 2:
			out.append(catena)
	return out

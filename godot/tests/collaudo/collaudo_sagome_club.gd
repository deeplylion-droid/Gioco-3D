extends Node
## Collaudo delle sagome del club (ambienti-1, che non le ha fatte; 6 novembre). Nella sala dell'inseguimento vera, con
## le sagome costruite dalla coda della sala, misura sulla geometria vera (collisioni più corpi dalle mesh visibili,
## CorpiMesh, senza le sagome):
##  - sagome sul bordo (vasche 1 e 3): il taglio di base sul bordo (raggi verso il basso da ogni vertice della base:
##    distacco più grande e più piccolo, quanta base poggia), il puntello (la lama) attaccato alla schiena e al suo piede,
##    il piede sul bordo, il mattone sul piede;
##  - sagome della passerella (vasca 2): la base sul grigliato, lo spago attorno al corrimano (la distanza dello spago
##    dal mondo, la più piccola) e nei fori del cartone (quanti vertici dello spago passano da ogni foro).
## Anche 1-2 cm sono un difetto: segna "DIFETTO" sopra i 5 mm di distacco o di compenetrazione.
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/collaudo_sagome_club.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const TOLLERANZA := 0.005

var sala: SalaInseguimento
var club: SagomeClub
var spazio: PhysicsDirectSpaceState3D
var difetti := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 1200:
		await get_tree().physics_frame
		if sala.costruita:
			break
	for i in 10:
		await get_tree().physics_frame
	club = sala.get_node_or_null(^"SagomeClub") as SagomeClub
	if club == null:
		print("SAGOME: mancano")
		get_tree().quit(1)
		return
	sala.set_physics_process(false)
	# i corpi dalle mesh della sala, senza le sagome e senza lei
	var n := 0
	for v in sala.dati["vasche"]:
		var r: Array = v["rett"]
		var c := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(v["fondo"])])
		n += CorpiMesh.crea(sala, AABB(c, Vector3.ZERO).grow(10.0), club)
	for m in sala.lei.find_children("*", "StaticBody3D", true, false):
		m.queue_free()
	for i in 4:
		await get_tree().physics_frame
	spazio = sala.get_world_3d().direct_space_state
	print("SAGOME: %d sagome, corpi dalle mesh %d" % [club.sagome().size(), n])
	var posa := club.posa
	var puntelli: Array = posa["puntelli"]
	var mattoni: Array = posa["mattoni"]
	var legature: Array = posa["legature"]
	var kb := 0
	var kl := 0
	var solo_vasca := int(OS.get_environment("SOLO_VASCA")) if OS.has_environment("SOLO_VASCA") else 0
	for i in posa["sagome"].size():
		var d: Dictionary = posa["sagome"][i]
		if int(d["vasca"]) != 2:
			kb += 0
		if solo_vasca > 0 and int(d["vasca"]) != solo_vasca:
			if int(d["vasca"]) != 2:
				kb += 1
			continue
		var mi := club.get_node("Sagoma_" + String(d["nome"])) as MeshInstance3D
		var xf := mi.global_transform
		var base := _base(d, xf)
		print("== %s (vasca %d, %s)" % [d["nome"], int(d["vasca"]), d["eta"]])
		var g := _distacchi(base)
		_riga("base sul %s: distacco da %+.1f a %+.1f mm, %d vertici della base su %d poggiano entro 2 mm, %d senza niente sotto entro 10 cm" % [
				"grigliato" if int(d["vasca"]) == 2 else "bordo", g[0] * 1000.0, g[1] * 1000.0, g[2], base.size(), g[3]],
				g[1] > TOLLERANZA or g[0] < -TOLLERANZA or g[3] > 0)
		var cp := _cartone_nel_mondo(d, xf)
		_riga("cartone: punti (griglia di 2 cm) con qualcosa del mondo dentro il cartone: %d %s" % [cp[0], cp[1]], cp[0] > 0)
		_riga("base: lunghezza appoggiata sul %s %.0f cm" % ["grigliato" if int(d["vasca"]) == 2 else "bordo", _appoggio(d, xf) * 100.0], false)
		if int(d["vasca"]) != 2:
			var lama := _box(puntelli[kb * 2])
			var piede := _box(puntelli[kb * 2 + 1])
			var mat := _box(mattoni[kb])
			kb += 1
			# la lama: la sua cima contro la schiena del cartone (il piano z = 0 della sagoma, dentro il contorno)
			var cima_lama := _schiena(lama, xf, d)
			_riga("puntello: la cima della lama dalla schiena %+.1f mm (dentro il contorno: %s)" % [cima_lama[0] * 1000.0, cima_lama[1]],
					absf(cima_lama[0]) > TOLLERANZA or not cima_lama[1])
			var lp := _fra_scatole(lama, piede)
			_riga("puntello: la lama dal suo piede %+.1f mm" % (lp * 1000.0), absf(lp) > TOLLERANZA)
			var gp := _distacchi(_fondo(piede))
			_riga("piede del puntello sul bordo: distacco da %+.1f a %+.1f mm, %d senza niente sotto" % [gp[0] * 1000.0, gp[1] * 1000.0, gp[3]],
					gp[1] > TOLLERANZA or gp[0] < -TOLLERANZA or gp[3] > 0)
			var mp := _fra_scatole(mat, piede)
			var gm := _sopra_scatola(mat, piede)
			_riga("mattone sul piede: distacco %+.1f mm, la base del mattone sul piede per il %.0f%%" % [mp * 1000.0, gm * 100.0],
					absf(mp) > TOLLERANZA or gm < 0.5)
			for coppia in [["lama", lama], ["piede", piede], ["mattone", mat]]:
				var dentro := _scatola_nel_mondo(coppia[1])
				_riga("%s nel mondo (scatola 1 mm più piccola): %s" % [coppia[0], dentro if dentro != "" else "niente"], dentro != "")
		else:
			var fori: Array = d.get("fori", [])
			# le legature di questa sagoma: quelle col nodo entro mezzo metro dal suo centro, lungo la passerella
			var legs := legature.filter(func(l): return absf(float(l["nodo"][0]) - float(d["origine"][0])) < 0.5)
			kl += legs.size()
			var passa := []
			for f in fori:
				passa.append(_spago_nel_foro(legs, f, xf))
			_riga("spago nei fori: vertici dello spago per foro %s" % [passa], passa.any(func(x): return x == 0))
			for l in legs:
				var dm := _spago_dal_mondo(l)
				_riga("legatura: lo spago più vicino al mondo a %.1f mm, %d vertici entro 3 mm (nodo in %s)" % [dm[0] * 1000.0, dm[1],
						Vector3(l["nodo"][0], l["nodo"][1], l["nodo"][2])], dm[0] > TOLLERANZA)
	print("SAGOME: difetti %d" % difetti)
	print("SAGOME: finito")
	get_tree().quit(0)


## Una griglia di punti a metà spessore dentro il contorno (a 2 cm l'uno dall'altro, da 1,5 cm sopra la base): raggi di
## 1 cm nel piano del cartone; se uno incontra qualcosa del mondo, quel qualcosa sta dentro il cartone. [quanti, dove]
func _cartone_nel_mondo(d: Dictionary, xf: Transform3D) -> Array:
	var punti: Array = d["punti"]
	var n0 := int(d["anelli"][0])
	var poligono := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for j in n0:
		var q := Vector2(punti[j][0], punti[j][1])
		poligono.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var n := 0
	var dove := {}
	var x := lo.x + 0.01
	while x < hi.x:
		var y := lo.y + 0.015
		while y < hi.y:
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, poligono):
				var c: Vector3 = xf * Vector3(x, y, SagomeClub.SPESSORE / 2.0)
				for dd: Vector3 in [Vector3(0.01, 0, 0), Vector3(-0.01, 0, 0), Vector3(0, 0.01, 0), Vector3(0, -0.01, 0)]:
					var ok := true
					var fine: Vector3 = xf * (Vector3(x, y, SagomeClub.SPESSORE / 2.0) + dd)
					if not Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2(dd.x, dd.y), poligono):
						continue
					var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(c, fine, 0xFFFFFFFF))
					if not r.is_empty():
						n += 1
						dove[_nome(r.collider)] = true
						break
			y += 0.02
		x += 0.02
	return [n, dove.keys()]


## La lunghezza (m) del taglio di base che poggia (raggio verso il basso: distacco entro 2 mm), a passi di 1 cm.
func _appoggio(d: Dictionary, xf: Transform3D) -> float:
	var punti: Array = d["punti"]
	var n0 := int(d["anelli"][0])
	var poligono := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for j in n0:
		var q := Vector2(punti[j][0], punti[j][1])
		poligono.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var tot := 0.0
	var x := lo.x
	while x <= hi.x:
		# il punto più basso del contorno a questa x: un raggio dentro il poligono dal basso
		var y := lo.y
		while y < lo.y + 0.05 and not Geometry2D.is_point_in_polygon(Vector2(x, y + 0.0005), poligono):
			y += 0.0005
		if y < lo.y + 0.05:
			var v: Vector3 = xf * Vector3(x, y, SagomeClub.SPESSORE / 2.0)
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(v + Vector3.UP * 0.05, v + Vector3.DOWN * 0.1, 0xFFFFFFFF))
			if not r.is_empty() and absf(v.y - (r.position as Vector3).y) <= 0.002:
				tot += 0.01
		x += 0.01
	return tot


## Cosa del mondo entra nella scatola (rimpicciolita di 1 mm per lato), "" se niente.
func _scatola_nel_mondo(bx: Dictionary) -> String:
	var forma := BoxShape3D.new()
	forma.size = ((bx["mezza"] as Vector3) * 2.0 - Vector3.ONE * 0.002).max(Vector3.ONE * 0.0005)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = bx["xf"]
	q.collision_mask = 0xFFFFFFFF
	var r := spazio.intersect_shape(q, 4)
	return ", ".join(r.map(func(h): return _nome(h["collider"])))


func _nome(n: Object) -> String:
	if n == null:
		return "?"
	var nd := n as Node
	var s := String(nd.name)
	var p := nd.get_parent()
	for i in 2:
		if p == null or p == sala:
			break
		s = String(p.name) + "/" + s
		p = p.get_parent()
	return s


func _riga(s: String, difetto: bool) -> void:
	if difetto:
		difetti += 1
	print("  %s %s" % ["DIFETTO" if difetto else "ok", s])


## I vertici del taglio di base (entro 3 mm dal più basso), davanti e dietro, nel mondo.
func _base(d: Dictionary, xf: Transform3D) -> Array:
	var punti: Array = d["punti"]
	var basso := INF
	for p in punti:
		basso = minf(basso, float(p[1]))
	var out := []
	for p in punti:
		if float(p[1]) < basso + 0.003:
			for z in [0.0, SagomeClub.SPESSORE]:
				out.append(xf * Vector3(p[0], p[1], z))
	# e i punti di mezzo sui lati della base
	var piu := []
	for a in out:
		for b in out:
			if a != b and a.distance_to(b) > 0.05 and a.distance_to(b) < 0.25:
				piu.append((a + b) / 2.0)
	return out + piu.slice(0, 40)


## Raggi verso il basso: [distacco più piccolo, più grande, quanti entro 2 mm, quanti senza niente sotto entro 10 cm].
func _distacchi(punti: Array) -> Array:
	var mn := INF
	var mx := -INF
	var vicini := 0
	var vuoti := 0
	for v: Vector3 in punti:
		var q := PhysicsRayQueryParameters3D.create(v + Vector3.UP * 0.05, v + Vector3.DOWN * 0.1, 0xFFFFFFFF)
		var r := spazio.intersect_ray(q)
		if r.is_empty():
			vuoti += 1
			continue
		var gap := v.y - (r.position as Vector3).y
		mn = minf(mn, gap)
		mx = maxf(mx, gap)
		if absf(gap) <= 0.002:
			vicini += 1
	return [mn, mx, vicini, vuoti]


func _box(p: Dictionary) -> Dictionary:
	var b: Array = p["base"]
	var c: Array = p["centro"]
	var s: Array = p["misura"]
	var basis := Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8]))
	return {"xf": Transform3D(basis, Vector3(c[0], c[1], c[2])), "mezza": Vector3(s[0], s[1], s[2]) / 2.0}


## Punti su tutte le facce della scatola (5 x 5 per faccia), nel mondo.
func _punti_scatola(bx: Dictionary) -> Array:
	var h: Vector3 = bx["mezza"]
	var xf: Transform3D = bx["xf"]
	var out := []
	for asse in 3:
		for segno in [-1.0, 1.0]:
			for i in 5:
				for j in 5:
					var u := -1.0 + i * 0.5
					var w := -1.0 + j * 0.5
					var l := Vector3.ZERO
					l[asse] = segno
					l[(asse + 1) % 3] = u
					l[(asse + 2) % 3] = w
					out.append(xf * (l * h))
	return out


## La faccia di sotto della scatola (in basso nel mondo).
func _fondo(bx: Dictionary) -> Array:
	var pts := _punti_scatola(bx)
	var basso := INF
	for p: Vector3 in pts:
		basso = minf(basso, p.y)
	return pts.filter(func(p: Vector3): return p.y < basso + 0.001)


## Distanza con segno dal punto alla scatola (negativa dentro).
func _sd(p: Vector3, bx: Dictionary) -> float:
	var l: Vector3 = (bx["xf"] as Transform3D).affine_inverse() * p
	var q := l.abs() - (bx["mezza"] as Vector3)
	return Vector3(maxf(q.x, 0), maxf(q.y, 0), maxf(q.z, 0)).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)


## La distanza fra due scatole: il punto di A più vicino a B (negativa se A entra in B).
func _fra_scatole(a: Dictionary, b: Dictionary) -> float:
	var m := INF
	for p in _punti_scatola(a):
		m = minf(m, _sd(p, b))
	return m


## Quanta parte della faccia di sotto di A sta sopra B (in pianta).
func _sopra_scatola(a: Dictionary, b: Dictionary) -> float:
	var f := _fondo(a)
	var dentro := 0
	for p: Vector3 in f:
		var l: Vector3 = (b["xf"] as Transform3D).affine_inverse() * (p + Vector3.DOWN * 0.003)
		var h: Vector3 = b["mezza"]
		if absf(l.x) <= h.x + 0.001 and absf(l.z) <= h.z + 0.001:
			dentro += 1
	return float(dentro) / maxf(f.size(), 1)


## La cima della lama del puntello rispetto alla schiena della sagoma: [distanza più piccola dal piano z = 0 (negativa
## se entra nel cartone), se quel punto sta dentro il contorno].
func _schiena(lama: Dictionary, xf: Transform3D, d: Dictionary) -> Array:
	var inv := xf.affine_inverse()
	var meglio := INF
	var dentro := false
	var poligono := PackedVector2Array()
	var punti: Array = d["punti"]
	var n0 := int(d["anelli"][0])
	for j in n0:
		poligono.append(Vector2(punti[j][0], punti[j][1]))
	for p in _punti_scatola(lama):
		var l: Vector3 = inv * p
		var dist := -l.z          # la schiena è z = 0, il cartone va da 0 a SPESSORE; dietro è z < 0
		if absf(dist) < absf(meglio):
			meglio = dist
			dentro = Geometry2D.is_point_in_polygon(Vector2(l.x, l.y), poligono)
	return [meglio, dentro]


## Quanti vertici dello spago passano dal foro [param f] (rettangolo nel piano della sagoma), attraverso il cartone.
func _spago_nel_foro(legs: Array, f: Array, xf: Transform3D) -> int:
	var inv := xf.affine_inverse()
	var n := 0
	for l in legs:
		var v: Array = l["v"]
		for j in range(0, v.size(), 3):
			var p: Vector3 = inv * Vector3(v[j], v[j + 1], v[j + 2])
			if p.x >= f[0] - 0.002 and p.x <= f[2] + 0.002 and p.y >= f[1] - 0.002 and p.y <= f[3] + 0.002 \
					and p.z > -0.004 and p.z < SagomeClub.SPESSORE + 0.004:
				n += 1
	return n


## La distanza dello spago dal mondo (il corrimano): sfere sempre più piccole su ogni vertice. [più piccola, entro 3 mm]
func _spago_dal_mondo(l: Dictionary) -> Array:
	var v: Array = l["v"]
	var sfera := SphereShape3D.new()
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sfera
	q.collision_mask = 0xFFFFFFFF
	var mn := INF
	var vicini := 0
	for j in range(0, v.size(), 3):
		var p := Vector3(v[j], v[j + 1], v[j + 2])
		var lo := 0.0
		var hi := 0.05
		sfera.radius = hi
		q.transform = Transform3D(Basis.IDENTITY, p)
		if spazio.intersect_shape(q, 1).is_empty():
			continue
		for k in 10:
			var m := (lo + hi) / 2.0
			sfera.radius = maxf(m, 0.0002)
			if spazio.intersect_shape(q, 1).is_empty():
				lo = m
			else:
				hi = m
		mn = minf(mn, hi)
		if hi <= 0.003:
			vicini += 1
	return [mn, vicini]

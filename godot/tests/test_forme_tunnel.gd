extends Node
## Test: le forme convesse salvate dei modelli del tunnel ("<nome>_forme.res", tools/genera_forme_tunnel.gd) sono le
## stesse che il motore calcola durante la costruzione, e l'involucro convesso dà le stesse sporgenze e gli stessi
## appoggi di tutte le facce (blocchi al primo avvio, 25 ottobre: richiesta del coordinatore, scarto massimo sotto 1 mm):
## 1. ogni forma salvata (collisione e involucro) coincide punto per punto con quella calcolata adesso;
## 2. per 400 direzioni il punto più sporgente dell'involucro è quello di tutte le facce (_contro_il_muro cerca il
##    massimo lungo la normale del muro, _appoggia il minimo in quota): stesse posizioni;
## 3. il gioco le usa davvero (la mesh è riconosciuta: stesso AABB e stessi vertici).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_forme_tunnel.gd

const SCARTO := 0.001

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


## Lo scarto più grande fra due insiemi di punti (per ogni punto, il più vicino dell'altro; nei due versi).
func _scarto(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var peggio := 0.0
	for x in [[a, b], [b, a]]:
		for p: Vector3 in x[0]:
			var vicino := INF
			for q: Vector3 in x[1]:
				vicino = minf(vicino, p.distance_squared_to(q))
			peggio = maxf(peggio, sqrt(vicino))
	return peggio


func _direzioni(n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / n
		var r := sqrt(1.0 - y * y)
		var a := PI * (3.0 - sqrt(5.0)) * i
		out.append(Vector3(cos(a) * r, y, sin(a) * r))
	return out


func _run() -> void:
	var dir := _direzioni(400)
	for nome in SalaSottomarino.MODELLI:
		var f: String = SalaSottomarino.DIR_FIUME + nome + SalaSottomarino.FORME
		var scena := load(String(SalaSottomarino.DIR_FIUME) + nome + ".glb") as PackedScene
		check(ResourceLoader.exists(f) and scena != null, "%s: c'è il file delle forme" % nome)
		if scena == null or not ResourceLoader.exists(f):
			continue
		var d: Dictionary = load(f).get_meta(&"forme", {})
		var n := scena.instantiate() as Node3D
		for x in n.find_children("*", "MeshInstance3D", true, false):
			var mi := x as MeshInstance3D
			var k := String(n.get_path_to(mi))
			if not d.has(k):
				check(false, "%s/%s: forma salvata" % [nome, k])
				continue
			var e: Array = d[k]
			var forma := mi.mesh.create_convex_shape(true, true)
			var inv := mi.mesh.create_convex_shape(true, false)
			var s1 := _scarto((e[0] as ConvexPolygonShape3D).points, forma.points)
			var s2 := _scarto(e[1], inv.points)
			check(s1 <= SCARTO and s2 <= SCARTO, "%s/%s: salvate come calcolate adesso (collisione %.4f mm, involucro %.4f mm, %d e %d punti)" % [nome, k, s1 * 1000.0, s2 * 1000.0, forma.points.size(), inv.points.size()])
			var facce := mi.mesh.get_faces()
			var peggio := 0.0
			for v in dir:
				var h := -INF
				for p: Vector3 in e[1]:
					h = maxf(h, p.dot(v))
				var t := -INF
				for p: Vector3 in facce:
					t = maxf(t, p.dot(v))
				peggio = maxf(peggio, absf(h - t))
			check(peggio <= SCARTO, "%s/%s: sporgenze e appoggi dell'involucro come su tutte le facce (%d direzioni, scarto %.4f mm)" % [nome, k, dir.size(), peggio * 1000.0])
		SalaSottomarino.usa_forme_salvate(nome, n)
		var usate := true
		for x in n.find_children("*", "MeshInstance3D", true, false):
			usate = usate and SalaSottomarino._forme_convesse.has((x as MeshInstance3D).mesh) \
					and SottomarinoArrediA2._involucri.has((x as MeshInstance3D).mesh)
		check(usate, "%s: il gioco usa le forme salvate" % nome)
		n.free()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)

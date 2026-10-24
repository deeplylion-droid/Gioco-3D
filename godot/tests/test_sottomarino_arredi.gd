extends Node
## Test degli arredi di ambienti-1 nel tunnel del viaggio sottomarino (SottomarinoArrediA1), senza schermo:
## - niente nello spazio di lei (a meno di 3,6 m dall'asse fra -29,22 e -24,0: 22 cm di margine sotto la tartaruga);
## - sulle banchine niente fra 0,35 e 2 m sopra il piano (salvo le bitte, sotto i 35 cm, e le lucine a filo);
## - la tartaruga non entra nella volta e le sue catene toccano guscio e piastre; le piastre toccano la volta;
## - reti, cartelli, fanali, salvagente, staffe e faretti toccano il muro (entro 5 mm) senza entrarci più di 5 mm;
## - nell'abisso niente lampade a gabbia gialle né oblò piccoli; ci sono le lampade blu e le lucine.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_sottomarino_arredi.gd

var ok := 0
var falliti := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		ok += 1
		print("  ok    ", msg)
	else:
		falliti += 1
		print("  FALLITO ", msg)


func _run() -> void:
	# per provare le altre versioni (SCELTA_PESCI=A|B|niente, SCELTA_ABISSO=A|B|niente); di base quelle scelte (A, A)
	if OS.get_environment("SCELTA_RETI") != "":
		SottomarinoArrediA1.reti_accese = OS.get_environment("SCELTA_RETI") == "si"
	var ep := OS.get_environment("SCELTA_PESCI")
	if ep != "":
		SottomarinoArrediA1.scelta_pesci = "" if ep == "niente" else ep
	var ea := OS.get_environment("SCELTA_ABISSO")
	if ea != "":
		SottomarinoArrediA1.scelta_abisso = "" if ea == "niente" else ea
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	get_tree().root.add_child(sala)
	sala.costruisci()
	var arr := sala.get_node("ArrediA1") as SottomarinoArrediA1
	_check(arr != null, "gli arredi ci sono")
	if arr == null:
		_fine()
		return
	var lei: Dictionary = sala.dati["lei"]
	var mezza: float = lei["mezza_larghezza_coi_tentacoli"]

	# 1) lo spazio di lei e le banchine
	var in_lei := {}
	var in_banchina := {}
	for x in arr.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		var nome := _nome(arr, mi)
		var xf := arr._xf(mi)
		var facce := mi.mesh.get_faces()
		if facce.is_empty():
			continue
		# (la strada la si cerca una volta per mesh: poi di lato, nel riferimento di quel punto)
		var s_m: float = sala.proietta(xf * facce[0])[0]
		var p_m := sala.punto(s_m)
		var r_m := sala.destra(s_m)
		for v in facce:
			var w := xf * v
			var lat := absf((w - p_m).dot(r_m))
			if lat < mezza and w.y > float(lei["quota_bassa"]) and w.y < -24.0:
				in_lei[nome] = "%.2f,%.2f,%.2f" % [w.x, w.y, w.z]
			if lat > sala.canale and lat < sala.muro - 0.01 and w.y > sala.piano + 0.35 and w.y < sala.piano + 2.0 \
					and not nome.begins_with("Approdo/bitta"):
				in_banchina[nome] = "%.2f,%.2f,%.2f" % [w.x, w.y, w.z]
	_check(in_lei.is_empty(), "niente nello spazio di lei %s" % [in_lei])
	_check(in_banchina.is_empty(), "niente sulle banchine fra 0,35 e 2 m %s" % [in_banchina])

	# 2) la tartaruga: sopra -24, sotto la volta, catene attaccate
	var t := arr.get_node("Tartaruga/tartaruga") as Node3D
	var tri_t := arr._triangoli(t)
	var basso := INF
	var dentro_volta := 0
	var tri_v := arr._tri_tunnel(SottomarinoArrediA1.TARTARUGA_S)
	for i in range(0, tri_t.size(), 3):
		var v := tri_t[i]
		basso = minf(basso, v.y)
		if i % 30 == 0:
			# dal vertice in su: la volta ci deve essere sopra, non sotto (dentro)
			var h = arr._raggio(tri_v, v + Vector3.DOWN * 3.0, v)
			if h != null:
				dentro_volta += 1
	_check(basso > -24.0, "la tartaruga sta sopra -24,0 (basso %.3f)" % basso)
	_check(dentro_volta == 0, "la tartaruga non entra nella volta (%d punti dentro)" % dentro_volta)
	var catene := arr.find_children("catena_tartaruga_*", "MeshInstance3D", true, false)
	_check(catene.size() == 3, "tre catene (%d)" % catene.size())
	for c in catene:
		var f := arr._triangoli(c)
		var lo := Vector3(0, INF, 0)
		var hi := Vector3(0, -INF, 0)
		for v in f:
			if v.y < lo.y:
				lo = v
			if v.y > hi.y:
				hi = v
		var dg := _dist(tri_t, lo)
		# (il capo di sotto infilato nel guscio conta come attaccato: sopra di lui c'è la superficie del guscio)
		if arr._raggio(tri_t, lo, lo + Vector3.UP * 0.03) != null:
			dg = 0.0
		var piastra := arr.get_node("Tartaruga/" + String(c.name).replace("catena", "piastra")) as MeshInstance3D
		var dp := _dist(arr._triangoli(piastra), hi)
		_check(dg < 0.006 and dp < 0.012, "%s: tocca guscio (%.1f mm) e piastra (%.1f mm)" % [c.name, dg * 1000, dp * 1000])
		var top := arr._triangoli(piastra)
		var alto := -INF
		for v in top:
			alto = maxf(alto, v.y)
		var cx := (piastra as Node3D).position
		var hv = arr._raggio(tri_v, Vector3(cx.x, -24.5, cx.z), Vector3(cx.x, -21.0, cx.z))
		_check(hv != null and absf((hv as Vector3).y - alto) < 0.005, "%s a filo della volta" % piastra.name)

	# 3) le cose a muro toccano il muro
	var a_muro := ["Reti/rete_stelle_325", "Reti/rete_stelle_333", "Reti/rete_stelle_388"] if SottomarinoArrediA1.reti_accese else []
	for nome in a_muro + ["Approdo/salvagente_fosforescente",
			"Approdo/fanale_rosso", "Approdo/fanale_verde", "Approdo/cartello_portello_494", "Approdo/cartello_portello_521",
			"Approdo/vetrina_vuota", "Tartaruga/faretto_362", "Tartaruga/faretto_369"]:
		var n := arr.get_node_or_null(nome) as Node3D
		if n == null:
			_check(false, "%s c'è" % nome)
			continue
		var tri := arr._triangoli(n)
		var p0 := tri[0]
		var s0: float = sala.proietta(p0)[0]
		var muro := arr._tri_tunnel(s0)
		var minimo := INF
		var dentro := 0.0
		for i in range(0, tri.size(), 7):
			var v := tri[i]
			var pr := sala.proietta_vicino(v, s0, 5.0)
			var lato := signf(float(pr[1]))
			var d := absf(float(pr[1]))
			if d < sala.muro - 0.4:
				continue
			var p := sala.punto(float(pr[0]))
			var r := sala.destra(float(pr[0]))
			var h = arr._raggio(muro, sala._al(p, r, Vector2(lato * (sala.muro - 1.0), v.y)), sala._al(p, r, Vector2(lato * (sala.muro + 0.4), v.y)))
			if h == null:
				continue
			var dd := Vector2(v.x - p.x, v.z - p.z).length() - Vector2((h as Vector3).x - p.x, (h as Vector3).z - p.z).length()
			minimo = minf(minimo, absf(dd))
			dentro = maxf(dentro, dd)
		_check(minimo < 0.005 and dentro < 0.005, "%s tocca il muro (%.1f mm), dentro al massimo %.1f mm" % [nome, minimo * 1000, dentro * 1000])

	# 4) l'abisso
	var amb := arr._ambiente("abisso")
	var gialle := 0
	var oblo := 0
	for l in sala.get_node("Luci").get_children():
		var pr := sala.proietta((l as Node3D).position)
		if float(pr[0]) > float(amb[0]) + 0.5 and float(pr[0]) < float(amb[1]) - 0.5:
			if l.name == "Oblo":
				oblo += 1
			elif not l is OmniLight3D:
				gialle += 1
	_check(gialle == 0 and oblo == 0, "nell'abisso niente lampade gialle (%d) né oblò piccoli (%d)" % [gialle, oblo])
	var blu := arr.get_node("AbissoLampade").get_child_count() / 2
	var lucine := (arr.get_node("lucine_banchine") as MultiMeshInstance3D).multimesh.instance_count
	_check(blu >= 3 and lucine >= 40, "nell'abisso %d lampade blu e %d lucine" % [blu, lucine])
	# 5) le scelte aperte, se accese
	if SottomarinoArrediA1.scelta_pesci != "":
		var pesci := arr.find_children("pesce_*", "Node3D", true, false)
		_check(pesci.size() >= 8, "pesci (%s): %d" % [SottomarinoArrediA1.scelta_pesci, pesci.size()])
	if SottomarinoArrediA1.scelta_abisso != "":
		var grandi := arr.find_children("oblo_grande_*", "Node3D", true, false)
		_check(grandi.size() == 6, "oblò grandi dell'abisso (%s): %d" % [SottomarinoArrediA1.scelta_abisso, grandi.size()])
	_fine()


func _nome(base: Node, n: Node) -> String:
	var p := String(base.get_path_to(n))
	return p


## La distanza di [param p] dai vertici e dai centri dei triangoli [param tri] (approssimata: basta per i contatti).
func _dist(tri: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	for i in range(0, tri.size(), 3):
		var c := Geometry3D.get_closest_point_to_segment(p, tri[i], tri[i + 1])
		best = minf(best, p.distance_to(c))
		var q := _sul_triangolo(p, tri[i], tri[i + 1], tri[i + 2])
		best = minf(best, p.distance_to(q))
	return best


func _sul_triangolo(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return a
	n = n.normalized()
	var q := p - n * (p - a).dot(n)
	var h = Geometry3D.ray_intersects_triangle(q + n, -n, a, b, c)
	if h != null:
		return h
	var best := Geometry3D.get_closest_point_to_segment(p, a, b)
	for e in [[b, c], [c, a]]:
		var x := Geometry3D.get_closest_point_to_segment(p, e[0], e[1])
		if p.distance_to(x) < p.distance_to(best):
			best = x
	return best


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti > 0 else 0)

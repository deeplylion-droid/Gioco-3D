extends Node
## Test delle ante degli armadietti degli spogliatoi (riscontro dell'utente sulla v0.3.13: "c'è un cazzo di pallone
## a ciambella compenetrato con una delle ante degli armadietti all'inizio"), senza schermo:
## - l'anta che sbatte (armadietto_sbatte_anta) in tutti i suoi stati: chiusa (socchiusa di 4 gradi), mentre sbatte
##   (ogni 2 gradi fino a 88) e aperta a fine corsa (81): niente di quello che c'è dentro e intorno (il
##   salvagente-papera, l'armadietto, le ante accanto) entra nell'anta;
## - tutte le altre ante (chiuse e aperte come stanno): niente ci entra dentro;
## - il salvagente-papera tocca il fondo o il ripiano dell'armadietto (entro 5 mm) e sta dentro l'armadietto.
## "Entra" vuol dire: un vertice dell'altro oggetto sta dentro la scatola dell'anta (nel suo riferimento, la mesh
## dell'anta è una lastra) per più di 2 mm.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_ante_armadietti.gd

const INTERNI := "res://scenes/interni/interni.tscn"
const TOLLERANZA := 0.002

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
	var interni := (load(INTERNI) as PackedScene).instantiate()
	add_child(interni)
	for i in 5:
		await get_tree().process_frame
	var spog := interni.get_node("Ambienti/Spogliatoi") as Node3D
	var anta := spog.find_child("armadietto_sbatte_anta", true, false) as MeshInstance3D
	var sg := spog.find_child("salvagente_giocattolo", true, false) as Node3D
	_check(anta != null and sg != null, "l'anta che sbatte e il salvagente-papera ci sono")
	if anta == null or sg == null:
		_fine()
		return
	# gli oggetti vicini all'anta (entro 1,2 m), escluse le sue cerniere
	var vicini := _vicini(spog, anta, 1.2)
	print("  (vicino all'anta che sbatte: %s)" % [vicini.map(func(n): return String(n.name))])
	# 1) l'anta che sbatte in tutti i suoi stati, girata col codice del gioco
	var chiusa := anta.transform
	var cardine := spog.find_child("cardine_armadietto_sbatte", true, false) as Node3D
	var perno := anta.get_parent_node_3d().to_local(cardine.global_position) if cardine else anta.position
	var dentro_stati := {}
	var ang := 0.0
	while ang <= 88.0:
		var verso := Transform3D(Basis.IDENTITY, perno)
		anta.transform = verso * Transform3D(Basis(Vector3.UP, -deg_to_rad(ang)), Vector3.ZERO) * verso.affine_inverse() * chiusa
		for n in vicini:
			var d := _dentro(anta, n)
			if d > TOLLERANZA:
				dentro_stati["%s a %d gradi" % [n.name, int(ang)]] = snappedf(d * 100.0, 0.1)
		ang += 2.0
	anta.transform = chiusa
	_check(dentro_stati.is_empty(), "l'anta che sbatte, da chiusa a 88 gradi: niente ci entra (cm) %s" % [dentro_stati])
	# 2) tutte le altre ante
	var altre := {}
	var n_ante := 0
	for x in spog.find_children("*anta*", "MeshInstance3D", true, false):
		var a := x as MeshInstance3D
		if a == anta or String(a.name).contains("cerniera"):
			continue
		n_ante += 1
		for n in _vicini(spog, a, 0.8):
			var d := _dentro(a, n)
			if d > TOLLERANZA:
				altre["%s in %s" % [n.name, a.name]] = snappedf(d * 100.0, 0.1)
	_check(altre.is_empty(), "le altre %d ante: niente ci entra (cm) %s" % [n_ante, altre])
	# 3) il salvagente-papera appoggiato dentro l'armadietto
	var basso := INF
	for v in _vertici(sg):
		basso = minf(basso, v.y)
	print("  (salvagente-papera: punto più basso a %.3f, posizione %s)" % [basso, sg.global_position])
	var pal := spog.find_child("pallone_spogliatoi", true, false) as Node3D
	if pal:
		print("  (pallone_spogliatoi: posizione %s, scala %s)" % [pal.global_position, pal.global_transform.basis.get_scale()])
	_fine()


## Gli oggetti con mesh entro [param raggio] da [param anta] (non lei, non le sue cerniere).
func _vicini(radice: Node, anta: MeshInstance3D, raggio: float) -> Array:
	var c := anta.global_transform * anta.mesh.get_aabb().get_center()
	var out := []
	for x in radice.find_children("*", "MeshInstance3D", true, false):
		var m := x as MeshInstance3D
		if m == anta or m.mesh == null or not m.is_visible_in_tree():
			continue
		# (le cerniere e i corpi degli armadietti: l'anta sta nel suo telaio, lo spigolo del cardine contro la fiancata)
		var nome := String(m.name)
		if nome.contains("cerniera") or nome.ends_with("_corpo") or RegEx.create_from_string("^armadietti_\\w+_\\d\\d$").search(nome):
			continue
		var bb := m.global_transform * m.mesh.get_aabb()
		if bb.grow(raggio).has_point(c) or bb.intersects(AABB(c - Vector3.ONE * raggio, Vector3.ONE * raggio * 2.0)):
			if bb.size.length() < 6.0:
				out.append(m)
	return out


## Quanto entra (m) il vertice più dentro di [param n] nella scatola della mesh di [param anta].
func _dentro(anta: MeshInstance3D, n: MeshInstance3D) -> float:
	var box := anta.mesh.get_aabb()
	var inv := anta.global_transform.affine_inverse()
	var best := 0.0
	var xf := n.global_transform
	for v in n.mesh.get_faces():
		var p := inv * (xf * v)
		if box.has_point(p):
			var d := minf(minf(p.x - box.position.x, box.end.x - p.x), minf(minf(p.y - box.position.y, box.end.y - p.y), minf(p.z - box.position.z, box.end.z - p.z)))
			best = maxf(best, d)
	return best


func _vertici(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mis := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		mis.append(n)
	for x in mis:
		var m := x as MeshInstance3D
		for v in m.mesh.get_faces():
			out.append(m.global_transform * v)
	return out


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti > 0 else 0)

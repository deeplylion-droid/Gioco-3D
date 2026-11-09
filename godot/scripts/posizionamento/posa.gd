class_name Posa
## Strumento comune per mettere gli oggetti al loro posto (processo nuovo del 22 ottobre, "per evitare questi errori
## una volta per tutte"): con un raggio si trova il sostegno vero (pavimento, muro, soffitto, gancio), l'oggetto si
## mette a contatto e, se si vuole, diventa figlio del sostegno, così lo segue se si sposta.
## Le funzioni restituiscono true se hanno trovato il sostegno; se no lasciano l'oggetto dov'è e avvisano
## (push_warning): il controllo di posizionamento della CI lo segnalerà come staccato o sospeso.
## Come si usa: docs/tecnico/posizionamento/LEGGIMI.md, "Mettere gli oggetti".

## Quanto lontano si cerca il sostegno (m).
const PORTATA := 3.0
## Strati su cui si appoggia: il mondo e le cose con la loro collisione.
const STRATI := Layers.WORLD
## Oltre il punto della collisione, fin dove si cerca la superficie che si vede (m): la collisione di un muro può
## sporgere qualche centimetro oltre le piastrelle (vasca centrale: 3 cm), o stare dietro.
const OLTRE := 0.3

## Le TriangleMesh delle mesh già usate (per il raggio sulle facce vere): instance id della mesh -> [WeakRef della mesh,
## TriangleMesh]. Con la mesh come chiave la cache la teneva viva: le mesh fatte da codice sono nuove a ogni ripartenza,
## e ognuna restava in memoria con la sua TriangleMesh (+3,3 MB a ogni morte, test_memoria_morti del 28 ottobre).
static var _triangoli := {}


## Appoggia [param nodo] sul primo sostegno sotto: il punto più basso dell'oggetto ([param fondo], metri sotto
## l'origine del nodo) va sul sostegno. [param lega]: diventa figlio di quello che c'è sotto.
static func appoggia_a_terra(nodo: Node3D, fondo := 0.0, lega := false, escludi: Array[RID] = []) -> bool:
	var p := nodo.global_position
	var h := _raggio(nodo, p + Vector3.UP * 0.05, p + Vector3.DOWN * PORTATA, escludi)
	if h.is_empty():
		push_warning("Posa: niente sotto %s (%s)" % [nodo.name, p])
		return false
	nodo.global_position = Vector3(p.x, (h.position as Vector3).y + fondo, p.z)
	if lega:
		_lega(nodo, h.collider)
	return true


## Appoggia [param nodo], piatto (un foglio, una Polaroid), su quello che si vede sotto la sua impronta: un raggio per
## ognuno dei [param punti] (nel sistema del nodo); il nodo va sul più alto delle mesh colpite, [param fondo] sopra. Su un
## grigliato un raggio solo può passare in un buco e trovare la collisione, che spesso sta sopra le barre (pianerottolo
## della torre: 1 cm; collaudo delle Polaroid del 28 ottobre, P12 sospesa di 13 mm). Mesh molto sotto la collisione (più
## di 5 cm: il pavimento sotto il grigliato) non contano; senza mesh vale la collisione.
static func appoggia_su_impronta(nodo: Node3D, punti: Array[Vector3], fondo := 0.0, escludi: Array[RID] = []) -> bool:
	var su_mesh := -INF
	var su_fisica := -INF
	for l in punti:
		var p := nodo.global_transform * l
		var h := _raggio(nodo, Vector3(p.x, nodo.global_position.y + 0.05, p.z), Vector3(p.x, nodo.global_position.y - PORTATA, p.z), escludi)
		if h.is_empty():
			continue
		if h.collider is MeshInstance3D:
			su_mesh = maxf(su_mesh, (h.position as Vector3).y)
		else:
			su_fisica = maxf(su_fisica, (h.position as Vector3).y)
	var y := su_mesh if su_mesh > -INF and (su_fisica == -INF or su_mesh > su_fisica - 0.05) else su_fisica
	if y == -INF:
		push_warning("Posa: niente sotto %s (%s)" % [nodo.name, nodo.global_position])
		return false
	nodo.global_position.y = y + fondo
	return true


## Fissa [param nodo] al muro dietro di lui: [param verso] è la direzione verso cui guarda l'oggetto (fuori dal muro);
## si cerca il muro nella direzione opposta e il retro dell'oggetto ([param spessore] metri dietro l'origine) va sul muro.
## [param candidate]: le mesh da guardare (vedi [method mesh_vicine]); senza, tutte quelle visibili dell'albero.
static func fissa_al_muro(nodo: Node3D, verso: Vector3, spessore := 0.0, lega := false, escludi: Array[RID] = [],
		candidate: Variant = null) -> bool:
	var v := verso.normalized()
	var p := nodo.global_position
	# il raggio parte un po' davanti: un oggetto già un po' dentro il muro torna a filo
	var h := _raggio(nodo, p + v * 0.3, p - v * PORTATA, escludi, candidate)
	if h.is_empty():
		push_warning("Posa: nessun muro dietro %s (%s, verso %s)" % [nodo.name, p, v])
		return false
	nodo.global_position = (h.position as Vector3) + v * spessore
	if lega:
		_lega(nodo, h.collider)
	return true


## Appende [param nodo] sotto [param gancio] (un Node3D, per esempio un'asta o un cavo): l'attacco dell'oggetto
## ([param attacco], metri sopra l'origine del nodo) va sul punto del gancio, e l'oggetto ne diventa figlio.
static func appendi_a(nodo: Node3D, gancio: Node3D, attacco := 0.0) -> void:
	var posa := gancio.global_position - Vector3.UP * attacco
	if nodo.get_parent():
		nodo.reparent(gancio)
	else:
		gancio.add_child(nodo)
	nodo.global_position = posa


## Attacca al soffitto: come appoggia_a_terra ma verso l'alto; [param cima] è il punto più alto dell'oggetto sopra
## l'origine.
static func fissa_al_soffitto(nodo: Node3D, cima := 0.0, lega := false, escludi: Array[RID] = []) -> bool:
	var p := nodo.global_position
	var h := _raggio(nodo, p + Vector3.DOWN * 0.05, p + Vector3.UP * PORTATA, escludi)
	if h.is_empty():
		push_warning("Posa: niente sopra %s (%s)" % [nodo.name, p])
		return false
	nodo.global_position = Vector3(p.x, (h.position as Vector3).y - cima, p.z)
	if lega:
		_lega(nodo, h.collider)
	return true


## Il sostegno lungo il raggio da [param da] ad [param a]: la superficie che si vede, non la collisione (riscontro di
## mascotte, 22 ottobre: la collisione del muro della vasca sporge 3 cm oltre le piastrelle, e la targa restava
## staccata di 3 cm). Prima il raggio della fisica trova il sostegno; poi, sullo stesso raggio fino a OLTRE dopo
## quel punto, la prima faccia di una mesh visibile (il nodo stesso e i suoi figli esclusi). Se nessuna mesh è lì
## (un sostegno di sola collisione), vale la collisione. Restituisce {position, normal, collider}: collider è la
## mesh colpita (per lega) o il corpo della collisione.
## [param candidate]: se c'è, le mesh da guardare al posto di tutte quelle dell'albero (vedi [method mesh_vicine]).
static func _raggio(nodo: Node3D, da: Vector3, a: Vector3, escludi: Array[RID], candidate: Variant = null) -> Dictionary:
	if not nodo.is_inside_tree():
		push_warning("Posa: %s non è ancora nella scena (serve la fisica)" % nodo.name)
		return {}
	var q := PhysicsRayQueryParameters3D.create(da, a, STRATI, escludi)
	q.hit_back_faces = false
	# (senza passare dalle crepe fra due triangoli, dove un raggio solo trova il pavimento sotto: RaggioSicuro)
	var h := RaggioSicuro.interseca(nodo.get_world_3d().direct_space_state, q)
	var dir := (a - da).normalized()
	var fine := a if h.is_empty() else (h.position as Vector3) + dir * OLTRE
	if da.distance_to(fine) > da.distance_to(a):
		fine = a
	var m := _raggio_mesh(nodo, da, fine, candidate)
	return h if m.is_empty() else m


## La prima faccia di una mesh visibile sul segmento [param da]-[param a] ({} se nessuna).
static func _raggio_mesh(nodo: Node3D, da: Vector3, a: Vector3, candidate: Variant = null) -> Dictionary:
	var meglio := {}
	var d_min := INF
	for n in (candidate as Array if candidate != null else nodo.get_tree().root.find_children("*", "MeshInstance3D", true, false)):
		var mi := n as MeshInstance3D
		if not is_instance_valid(mi) or mi.mesh == null or mi == nodo or nodo.is_ancestor_of(mi):
			continue
		# (le candidate di mesh_vicine sono già quelle visibili, anche dentro una zona ancora nascosta)
		if candidate == null and not mi.is_visible_in_tree():
			continue
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var gt := mi.global_transform
		if not (gt * mi.get_aabb()).grow(0.01).intersects_segment(da, a):
			continue
		var tm := _triangoli_di(mi.mesh)
		if tm == null:
			continue
		var inv := gt.affine_inverse()
		var r := tm.intersect_segment(inv * da, inv * a)
		if r.is_empty():
			continue
		var p: Vector3 = gt * (r.position as Vector3)
		var d := da.distance_to(p)
		if d < d_min:
			d_min = d
			meglio = {"position": p, "normal": (gt.basis.inverse().transposed() * (r.normal as Vector3)).normalized(), "collider": mi}
	return meglio


## Le mesh visibili dell'albero (nello stesso ordine di [method _raggio_mesh]) il cui riquadro tocca [param zona]: date a
## [method _raggio] o [method fissa_al_muro] come [param candidate] per più raggi tutti dentro la zona, il risultato è
## lo stesso di guardarle tutte (le altre non toccano nessun segmento), e l'albero si scorre una volta sola invece che a
## ogni raggio (2200 mesh nella sala con la torre: 4 ms a raggio).
## [param radice]: una zona che si costruisce nascosta (la torre dal portone, _prepara_torre: visible = false finché
## non si mostra). Le sue mesh contano come se lei fosse visibile: visibili lei e i loro genitori fino a lei. Senza,
## dal portone gli oggetti messi con Posa non vedevano la torre e finivano dentro il muro (lampade d'emergenza 0 e 4,
## 15 e 40 mm, collaudo di ambienti-1 su 4e9551c8), mentre da F9, una morte o Continua (torre visibile) no.
static func mesh_vicine(nodo: Node3D, zona: AABB, radice: Node = null) -> Array:
	var out: Array = []
	for n in nodo.get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _visibile(mi, radice):
			continue
		if (mi.global_transform * mi.get_aabb()).grow(0.01).intersects(zona.grow(0.01)):
			out.append(mi)
	return out


## Visibile nell'albero; dentro [param radice] (se c'è), visibile fino a lei, che conta come visibile.
static func _visibile(n: Node3D, radice: Node) -> bool:
	if radice == null or not radice.is_ancestor_of(n):
		return n.is_visible_in_tree()
	var x: Node = n
	while x != radice:
		if x is Node3D and not (x as Node3D).visible:
			return false
		x = x.get_parent()
	return true


## L'oggetto diventa figlio del sostegno (il nodo del corpo colpito o, per i corpi importati, il suo genitore
## visibile), mantenendo la posizione nel mondo.
static func _lega(nodo: Node3D, corpo: Object) -> void:
	var sostegno := corpo as Node3D
	if sostegno == null or sostegno == nodo or nodo.is_ancestor_of(sostegno):
		return
	nodo.reparent(sostegno)


## Vero se la TriangleMesh di [param mesh] è già nella cache.
static func ha_triangoli(mesh: Mesh) -> bool:
	var e: Array = _triangoli.get(mesh.get_instance_id(), [])
	return not e.is_empty() and (e[0] as WeakRef).get_ref() == mesh


## Mette nella cache la TriangleMesh [param tm] di [param mesh], costruita da chi chiama (per esempio in un thread, con
## le facce di [method Mesh.get_faces]: le stesse di [method Mesh.generate_triangle_mesh]).
static func metti_triangoli(mesh: Mesh, tm: TriangleMesh) -> void:
	_triangoli[mesh.get_instance_id()] = [weakref(mesh), tm]


## La TriangleMesh di [param mesh], dalla cache (vedi [member _triangoli]) o calcolata adesso.
static func _triangoli_di(mesh: Mesh) -> TriangleMesh:
	var id := mesh.get_instance_id()
	var e: Array = _triangoli.get(id, [])
	if not e.is_empty() and (e[0] as WeakRef).get_ref() == mesh:
		return e[1]
	# (prima di aggiungerne una si tolgono quelle delle mesh liberate: le TriangleMesh sono grandi, 2,6 MB a ripartenza;
	# se restano troppe tutte vive, si ricomincia)
	for k in _triangoli.keys():
		if (_triangoli[k][0] as WeakRef).get_ref() == null:
			_triangoli.erase(k)
	if _triangoli.size() > 256:
		_triangoli.clear()
	var t0 := Time.get_ticks_usec()
	var tm := mesh.generate_triangle_mesh()
	_triangoli[id] = [weakref(mesh), tm]
	# (coi tempi accesi: le TriangleMesh che costano, per spostarle in un thread prima che servano)
	if _tempi and Time.get_ticks_usec() - t0 > 5000:
		print("  Posa: la TriangleMesh di %s (%d superfici) in %.1f ms" % [mesh.resource_name if mesh.resource_name != "" else str(mesh),
				mesh.get_surface_count(), (Time.get_ticks_usec() - t0) / 1000.0])
	return tm


static var _tempi := OS.has_environment("TORRE_TEMPI")

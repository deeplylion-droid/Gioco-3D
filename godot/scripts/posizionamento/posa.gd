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


## Fissa [param nodo] al muro dietro di lui: [param verso] è la direzione verso cui guarda l'oggetto (fuori dal muro);
## si cerca il muro nella direzione opposta e il retro dell'oggetto ([param spessore] metri dietro l'origine) va sul muro.
static func fissa_al_muro(nodo: Node3D, verso: Vector3, spessore := 0.0, lega := false, escludi: Array[RID] = []) -> bool:
	var v := verso.normalized()
	var p := nodo.global_position
	# il raggio parte un po' davanti: un oggetto già un po' dentro il muro torna a filo
	var h := _raggio(nodo, p + v * 0.3, p - v * PORTATA, escludi)
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
static func _raggio(nodo: Node3D, da: Vector3, a: Vector3, escludi: Array[RID]) -> Dictionary:
	if not nodo.is_inside_tree():
		push_warning("Posa: %s non è ancora nella scena (serve la fisica)" % nodo.name)
		return {}
	var q := PhysicsRayQueryParameters3D.create(da, a, STRATI, escludi)
	q.hit_back_faces = false
	var h := nodo.get_world_3d().direct_space_state.intersect_ray(q)
	var dir := (a - da).normalized()
	var fine := a if h.is_empty() else (h.position as Vector3) + dir * OLTRE
	if da.distance_to(fine) > da.distance_to(a):
		fine = a
	var m := _raggio_mesh(nodo, da, fine)
	return h if m.is_empty() else m


## La prima faccia di una mesh visibile sul segmento [param da]-[param a] ({} se nessuna).
static func _raggio_mesh(nodo: Node3D, da: Vector3, a: Vector3) -> Dictionary:
	var meglio := {}
	var d_min := INF
	for n in nodo.get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi == nodo or nodo.is_ancestor_of(mi) or not mi.is_visible_in_tree():
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


## L'oggetto diventa figlio del sostegno (il nodo del corpo colpito o, per i corpi importati, il suo genitore
## visibile), mantenendo la posizione nel mondo.
static func _lega(nodo: Node3D, corpo: Object) -> void:
	var sostegno := corpo as Node3D
	if sostegno == null or sostegno == nodo or nodo.is_ancestor_of(sostegno):
		return
	nodo.reparent(sostegno)


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
	var tm := mesh.generate_triangle_mesh()
	_triangoli[id] = [weakref(mesh), tm]
	return tm

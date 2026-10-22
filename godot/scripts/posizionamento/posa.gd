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


static func _raggio(nodo: Node3D, da: Vector3, a: Vector3, escludi: Array[RID]) -> Dictionary:
	if not nodo.is_inside_tree():
		push_warning("Posa: %s non è ancora nella scena (serve la fisica)" % nodo.name)
		return {}
	var q := PhysicsRayQueryParameters3D.create(da, a, STRATI, escludi)
	q.hit_back_faces = false
	return nodo.get_world_3d().direct_space_state.intersect_ray(q)


## L'oggetto diventa figlio del sostegno (il nodo del corpo colpito o, per i corpi importati, il suo genitore
## visibile), mantenendo la posizione nel mondo.
static func _lega(nodo: Node3D, corpo: Object) -> void:
	var sostegno := corpo as Node3D
	if sostegno == null or sostegno == nodo or nodo.is_ancestor_of(sostegno):
		return
	nodo.reparent(sostegno)

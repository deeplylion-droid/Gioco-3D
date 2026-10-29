class_name RaggioSicuro
## Un raggio della fisica che non passa dalle crepe fra i triangoli. Il test raggio-triangolo di Jolt non è a tenuta: un
## raggio a meno di qualche millesimo di millimetro da un lato condiviso fra due triangoli può passare in mezzo e trovare
## quello che c'è dietro, o niente. Succede solo proprio sopra un lato, ma le cose messe a coordinate tonde ci finiscono:
## sul fondo della piscina, a x = 0, un giocattolo spinto lungo l'asse cadeva sul soffitto della camera delle onde, 2,4 m
## sotto (ricontrollo di ambienti-2 del 29 ottobre).
## Oltre al raggio si lanciano quattro raggi paralleli a [constant SCOSTAMENTO], due per lato, in croce. Se i due di lati
## opposti trovano una superficie più vicina, d'accordo fra loro, il raggio al centro era passato da una crepa e vale la
## più vicina delle due (per un raggio verso il basso, la più alta), riportata sulla sua linea. Vicino a uno spigolo vero
## la superficie la trova un lato solo: lì, come ovunque fuori dalle crepe, il risultato è quello del raggio solo.

## Quanto sono spostati i raggi di controllo (m): mille volte la crepa, sotto ogni dettaglio che si vede.
const SCOSTAMENTO := 0.0025
## Quanto più vicina deve essere la superficie trovata ai lati, e quanto possono differire fra loro (m).
const TOLLERANZA := 0.01


## Come [method PhysicsDirectSpaceState3D.intersect_ray] con [param q], senza passare dalle crepe.
static func interseca(spazio: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D) -> Dictionary:
	var h := spazio.intersect_ray(q)
	var dir := q.to - q.from
	var lung := dir.length()
	if lung < 0.0001:
		return h
	dir /= lung
	var d_centro := INF if h.is_empty() else q.from.distance_to(h.position as Vector3)
	var rif := Vector3.RIGHT if absf(dir.y) > 0.9 else Vector3.UP
	var u := dir.cross(rif).normalized() * SCOSTAMENTO
	var w := dir.cross(u).normalized() * SCOSTAMENTO
	var meglio := {}
	var d_meglio := d_centro
	for lato: Vector3 in [u, w]:
		var h1 := spazio.intersect_ray(_spostato(q, lato))
		var h2 := spazio.intersect_ray(_spostato(q, -lato))
		if h1.is_empty() or h2.is_empty():
			continue
		var d1 := (q.from + lato).distance_to(h1.position as Vector3)
		var d2 := (q.from - lato).distance_to(h2.position as Vector3)
		if absf(d1 - d2) > TOLLERANZA or maxf(d1, d2) > d_centro - TOLLERANZA:
			continue
		var vicino := h1 if d1 <= d2 else h2
		var d := minf(d1, d2)
		if d < d_meglio:
			d_meglio = d
			meglio = vicino.duplicate()
			meglio["position"] = (vicino.position as Vector3) - (lato if d1 <= d2 else -lato)
	return h if meglio.is_empty() else meglio


static func _spostato(q: PhysicsRayQueryParameters3D, di: Vector3) -> PhysicsRayQueryParameters3D:
	var s := PhysicsRayQueryParameters3D.create(q.from + di, q.to + di, q.collision_mask, q.exclude)
	s.collide_with_areas = q.collide_with_areas
	s.collide_with_bodies = q.collide_with_bodies
	s.hit_back_faces = q.hit_back_faces
	s.hit_from_inside = q.hit_from_inside
	return s

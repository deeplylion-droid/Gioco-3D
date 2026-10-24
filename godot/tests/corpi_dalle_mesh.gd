extends RefCounted
## Corpi di collisione temporanei fatti dalle mesh vere (trimesh), per i test e i generatori: dove una collisione manca
## o è più piccola della mesh (le pompe dell'inseguimento non ne hanno), i raggi vedono comunque quello che si vede.
## Stanno sullo strato [constant STRATO], che il gioco non usa: si cercano con Layers.WORLD | STRATO.

const STRATO := 1 << 19


## Crea i corpi per le mesh visibili sotto [param radice] che toccano [param zona], tranne quelle sotto [param salta]
## (lei) e l'acqua (il nome contiene "acqua") e la bava. Restituisce quanti ne ha fatti.
static func crea(radice: Node, zona: AABB, salta: Node = null) -> int:
	var n := 0
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or m.has_meta(&"corpo_dalla_mesh"):
			continue
		if salta and (salta == m or salta.is_ancestor_of(m)):
			continue
		var nome := String(m.name).to_lower() + " " + String(m.get_parent().name).to_lower()
		if nome.contains("acqua") or nome.contains("bava") or nome.contains("water"):
			continue
		if not (m.global_transform * m.get_aabb()).intersects(zona):
			continue
		var forma := m.mesh.create_trimesh_shape()
		if forma == null:
			continue
		var corpo := StaticBody3D.new()
		corpo.collision_layer = STRATO
		corpo.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = forma
		corpo.add_child(cs)
		m.add_child(corpo)
		m.set_meta(&"corpo_dalla_mesh", true)
		n += 1
	return n

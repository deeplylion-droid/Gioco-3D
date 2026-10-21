@tool
extends EditorScenePostImport
## Import dei GLB della sala della torre, per non avere fotogrammi lunghi quando la sala entra in scena
## (SalaTorre.costruisci_a_pezzi la mette un nodo per fotogramma):
## - le forme di collisione trimesh collidono da tutte e due le facce già nel file importato (prima lo
##   faceva SalaTorre all'avvio, e cambiare backface_collision ricostruisce la forma);
## - le forme più grandi (la struttura ha 84000 triangoli in una forma sola: metterla nello spazio fisico
##   costava più di 100 ms) diventano più forme vicine dello stesso corpo, al più FACCE_PER_FORMA
##   triangoli ciascuna, divise lungo l'asse più lungo. La collisione resta la stessa.

const FACCE_PER_FORMA := 8000


func _post_import(scena: Node) -> Object:
	for n in _tutti(scena):
		if n is CollisionShape3D:
			_sistema(n as CollisionShape3D)
	return scena


func _tutti(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_tutti(c))
	return out


func _sistema(cs: CollisionShape3D) -> void:
	var forma := cs.shape as ConcavePolygonShape3D
	if forma == null:
		return
	forma.backface_collision = true
	var facce := forma.get_faces()
	var n := facce.size() / 3
	if n <= FACCE_PER_FORMA:
		return
	# i triangoli in ordine lungo l'asse più lungo dell'insieme, poi a gruppi
	var aabb := AABB(facce[0], Vector3.ZERO)
	for p in facce:
		aabb = aabb.expand(p)
	var asse := aabb.get_longest_axis_index()
	var ordine := range(n)
	ordine.sort_custom(func(a, b): return (facce[a * 3] + facce[a * 3 + 1] + facce[a * 3 + 2])[asse] < (facce[b * 3] + facce[b * 3 + 1] + facce[b * 3 + 2])[asse])
	var pezzi := ceili(float(n) / FACCE_PER_FORMA)
	var per_pezzo := ceili(float(n) / pezzi)
	for k in pezzi:
		var parte := PackedVector3Array()
		for i in range(k * per_pezzo, mini((k + 1) * per_pezzo, n)):
			var t: int = ordine[i]
			parte.append(facce[t * 3])
			parte.append(facce[t * 3 + 1])
			parte.append(facce[t * 3 + 2])
		var nuova := ConcavePolygonShape3D.new()
		nuova.backface_collision = true
		nuova.set_faces(parte)
		if k == 0:
			cs.shape = nuova
		else:
			var altra := CollisionShape3D.new()
			altra.name = "%s_%d" % [cs.name, k]
			altra.shape = nuova
			altra.transform = cs.transform
			cs.get_parent().add_child(altra)
			altra.owner = cs.owner

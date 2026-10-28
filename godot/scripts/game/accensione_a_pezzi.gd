class_name AccensioneAPezzi
## Riaccende una zona grande preparata nascosta e ferma (process_mode DISABLED, come la torre e le stanze della
## Risalita mentre si costruiscono a pezzi) senza fermare il gioco. Rimettere process_mode della radice tutto insieme
## lo propaga a ogni nodo dell'albero in un colpo solo: 226 ms per la torre da sola, 2 s con la sala intera (misure
## del 25 ottobre). Qui ogni nodo si riaccende per conto suo, coi suoi figli fermati uno per uno prima (sono già
## fermi: costa poco), così ogni passo tocca un nodo solo; al più [param ms] millisecondi per fotogramma, anche per
## un nodo con migliaia di figli. Ogni nodo torna alla modalità che aveva (un nodo fermo per conto suo resta fermo,
## coi suoi figli).


## Riaccende [param radice] (e torna alla fine). [param modo] è la modalità da dare alla radice.
static func accendi(radice: Node, modo := Node.PROCESS_MODE_INHERIT, ms := 6.0) -> void:
	if radice == null or not radice.is_inside_tree():
		return
	var albero := radice.get_tree()
	# la pila: [nodo, modalità da rimettere, i suoi figli (presi alla prima visita), quanti fermati, i figli fermati
	# con la loro modalità]; un nodo si riaccende quando i suoi figli sono tutti fermi, e poi tocca a loro
	var pila: Array = [[radice, modo, null, 0, []]]
	var t0 := Time.get_ticks_usec()
	while not pila.is_empty():
		var voce: Array = pila.back()
		var n: Node = voce[0]
		if not is_instance_valid(n):
			pila.pop_back()
			continue
		var originale: Node.ProcessMode = voce[1]
		if voce[2] == null:
			voce[2] = n.get_children() if originale != Node.PROCESS_MODE_DISABLED else []
		var figli: Array = voce[2]
		var i: int = voce[3]
		var fermati: Array = voce[4]
		while i < figli.size() and (Time.get_ticks_usec() - t0) / 1000.0 < ms:
			var c: Node = figli[i]
			if is_instance_valid(c):
				fermati.append([c, c.process_mode, null, 0, []])
				c.process_mode = Node.PROCESS_MODE_DISABLED
			i += 1
		voce[3] = i
		if i >= figli.size():
			pila.pop_back()
			# un corpo statico con tante forme grandi (le collisioni dei GLB: 9-11 forme da 7.500 triangoli) costa
			# tutto insieme quando rientra nella fisica (80-230 ms): diviso in un corpo per forma, ognuno a suo turno
			if _da_dividere(n):
				pila.append_array(_dividi(n, fermati))
				fermati = []
			var tn := Time.get_ticks_usec()
			n.process_mode = originale
			if OS.has_environment("TORRE_TEMPI") and Time.get_ticks_usec() - tn > 10000:
				print("  accensione di %s (%s, %d figli, sotto %s): %.1f ms" % [n.name, n.get_class(), n.get_child_count(), n.get_parent().name, (Time.get_ticks_usec() - tn) / 1000.0])
			pila.append_array(fermati)
		if (Time.get_ticks_usec() - t0) / 1000.0 >= ms:
			await albero.process_frame
			# (si va avanti anche se la zona è uscita dall'albero per un momento: fermata a metà restava spenta, coi
			# checkpoint della torre muti, test_torre del 25 ottobre; si smette solo se è stata liberata)
			if not is_instance_valid(radice):
				return
			t0 = Time.get_ticks_usec()


## Un corpo statico importato (senza script) con più di una forma grande.
static func _da_dividere(n: Node) -> bool:
	if n.get_class() != "StaticBody3D" or n.get_script() != null or n.get_child_count() < 2:
		return false
	var forme := 0
	for c in n.get_children():
		if not c is CollisionShape3D:
			return false
		forme += 1
	return forme >= 2


## Lascia la prima forma a [param corpo] e mette ogni altra in un corpo statico uguale accanto (stessi strati,
## materiale fisico, gruppi e posizione), fermo: torna le voci da riaccendere (i corpi nuovi e le forme, già ferme in
## [param fermati]).
static func _dividi(corpo: StaticBody3D, fermati: Array) -> Array:
	var padre := corpo.get_parent()
	var out: Array = []
	var forme := corpo.get_children()
	out.append(fermati[0])
	for k in range(1, forme.size()):
		var f := forme[k] as CollisionShape3D
		var nuovo := StaticBody3D.new()
		nuovo.name = "%s_%d" % [corpo.name, k]
		nuovo.collision_layer = corpo.collision_layer
		nuovo.collision_mask = corpo.collision_mask
		nuovo.collision_priority = corpo.collision_priority
		nuovo.physics_material_override = corpo.physics_material_override
		nuovo.transform = corpo.transform
		for g in corpo.get_groups():
			nuovo.add_to_group(g)
		nuovo.process_mode = Node.PROCESS_MODE_DISABLED
		# (l'owner si toglie e si rimette dopo, uguale per il corpo nuovo: se no Godot avvisa "owner inconsistent")
		var proprietario := f.owner
		f.owner = null
		corpo.remove_child(f)
		nuovo.add_child(f)
		padre.add_child(nuovo)
		if proprietario and proprietario.is_ancestor_of(nuovo):
			nuovo.owner = proprietario
			f.owner = proprietario
		# il corpo nuovo, poi la sua forma (fermata come le altre)
		out.append(fermati[k])
		out.append([nuovo, Node.PROCESS_MODE_INHERIT, null, 0, []])
	return out


## Libera una zona grande (che non serve più) un nodo per volta, dalle foglie, al più [param ms] millisecondi per
## fotogramma: liberata tutta insieme fermava il gioco (interni e tecnici entrando nella torre: 1 + 2 s, misura del 25
## ottobre). Finché non è finita la zona resta in scena, a pezzi: va usata per zone che il giocatore non vede.
static func libera(radice: Node, ms := 6.0) -> void:
	if radice == null or not is_instance_valid(radice):
		return
	if not radice.is_inside_tree():
		radice.free()
		return
	var albero := radice.get_tree()
	var pila: Array[Node] = [radice]
	var t0 := Time.get_ticks_usec()
	while not pila.is_empty():
		var n: Node = pila.back()
		if not is_instance_valid(n):
			pila.pop_back()
			continue
		var figli := n.get_child_count()
		if figli > 0:
			pila.append(n.get_child(figli - 1))
			continue
		pila.pop_back()
		n.free()
		if (Time.get_ticks_usec() - t0) / 1000.0 >= ms:
			await albero.process_frame
			t0 = Time.get_ticks_usec()

extends RefCounted
## Una copia della scena senza alcuni nodi e senza le risorse che solo loro usano, per gli scatti e i video su
## llvmpipe: lì le texture compresse (BC) si espandono in RGBA, e la sala intera supera la memoria della macchina
## già al caricamento (togliere i nodi dopo non basta: le loro texture sono già caricate). Si scrive in user://.


## [param togli]: i percorsi dei nodi (dalla radice, per esempio "Interni") da togliere con tutto quello che hanno
## sotto. Restituisce il percorso della copia.
static func riduci(scena: String, togli: Array) -> String:
	var testo := FileAccess.get_file_as_string(scena)
	var blocchi := testo.split("\n[")
	var tenuti := PackedStringArray()
	for i in blocchi.size():
		var b := blocchi[i] if i == 0 else "[" + blocchi[i]
		if b.begins_with("[node "):
			var nome := _attr(b, "name")
			var padre := _attr(b, "parent")
			var percorso := nome if padre == "." else (padre + "/" + nome if padre != "" else "")
			if _tolto(percorso, togli) or _tolto(padre, togli):
				continue
		elif b.begins_with("[connection "):
			if _tolto(_attr(b, "from"), togli) or _tolto(_attr(b, "to"), togli):
				continue
		tenuti.append(b)
	# le risorse esterne che non usa più nessuno: via (Godot le caricherebbe lo stesso)
	var corpo := "\n".join(tenuti.slice(1))
	var finale := PackedStringArray()
	for b in tenuti:
		if b.begins_with("[ext_resource "):
			var id := _attr(b, "id")
			if not corpo.contains('ExtResource("%s")' % id):
				continue
		finale.append(b)
	var uscita := "user://scena_ridotta_%s" % scena.get_file()
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	f.store_string("\n".join(finale))
	f.close()
	return uscita


static func _attr(blocco: String, chiave: String) -> String:
	var testa := blocco.get_slice("\n", 0)
	var da := testa.find(chiave + "=\"")
	if da < 0:
		return ""
	da += chiave.length() + 2
	return testa.substr(da, testa.find("\"", da) - da)


static func _tolto(percorso: String, togli: Array) -> bool:
	for t in togli:
		if percorso == t or percorso.begins_with(String(t) + "/"):
			return true
	return false

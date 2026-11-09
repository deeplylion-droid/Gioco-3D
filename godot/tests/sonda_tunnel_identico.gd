extends Node
## Sonda: tutto quello che la costruzione del tunnel mette in scena, per confrontare due versioni del codice (passi
## spezzati, stesso risultato). Per ogni nodo sotto SalaSottomarino (nell'ordine dell'albero): il percorso coi nomi
## (i nomi automatici @Classe@N senza il numero), la classe, la trasformazione nel mondo (al decimo di millimetro), la
## visibilità; per le mesh la mesh (risorsa o numero di vertici) e i materiali; per le luci colore, energia, portata,
## ombre, strati e maschere; per le collisioni la forma. Stampa l'md5 di tutto e, con un secondo argomento, scrive la
## lista in un file. Lei del tunnel non c'è (i suoi nodi audio nascono in un ordine che cambia) e dei gommoni, che
## galleggiano, non c'è la posizione. Costruita a pezzi come nel gioco (costruisci_a_pezzi) o tutta insieme (argomento "subito").
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_tunnel_identico.gd [pezzi|subito] [file]

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"


func _ready() -> void:
	_run.call_deferred()


static func _nome(n: Node) -> String:
	var s := String(n.name)
	if s.begins_with("@"):
		var parti := s.split("@")
		return "@" + (parti[1] if parti.size() > 1 else "")
	return s


static func _v(v: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [v.x, v.y, v.z]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	var modo := a[1] if a.size() > 1 else "pezzi"
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 10:
		await get_tree().process_frame
	var sott := get_tree().current_scene.get_node("SalaSottomarino") as SalaSottomarino
	if modo == "subito":
		sott.costruisci()
	else:
		await sott.costruisci_a_pezzi(6.0)
	var righe: PackedStringArray = []
	for n in sott.find_children("*", "", true, false):
		var percorso: PackedStringArray = []
		var x: Node = n
		while x != sott:
			percorso.append(_nome(x))
			x = x.get_parent()
		percorso.reverse()
		var via := "/".join(percorso)
		# (lei ha i suoi nodi audio in un ordine che cambia, i gommoni galleggiano: della prima niente, dei secondi la forma)
		if via.begins_with("LeiTunnel"):
			continue
		var r := "%s %s" % [via, n.get_class()]
		if n is Node3D and not via.begins_with("Gommoni/"):
			var t := (n as Node3D).global_transform
			r += " o=%s x=%s y=%s z=%s vis=%s" % [_v(t.origin), _v(t.basis.x), _v(t.basis.y), _v(t.basis.z), (n as Node3D).visible]
		if n is VisualInstance3D:
			r += " strati=%d" % (n as VisualInstance3D).layers
		if n is MeshInstance3D:
			var m := (n as MeshInstance3D).mesh
			r += " mesh=%s" % ((m.resource_path if m.resource_path != "" else "%s:%d" % [m.get_class(), m.get_faces().size()]) if m else "-")
			var mat: Material = (n as MeshInstance3D).material_override
			r += " mat=%s" % ((mat.resource_path if mat.resource_path != "" else mat.resource_name + ":" + mat.get_class()) if mat else "-")
		if n is Light3D:
			var l := n as Light3D
			r += " luce=%s,%.3f,%s,ombra=%s,maschera=%d,ombre=%d" % [l.light_color, l.light_energy, str(l.get(&"omni_range") if l is OmniLight3D else l.get(&"spot_range")),
					l.shadow_enabled, l.light_cull_mask, l.shadow_caster_mask]
		if n is CollisionShape3D and (n as CollisionShape3D).shape:
			var sh := (n as CollisionShape3D).shape
			r += " forma=%s" % (sh.get_class() + (":%d" % (sh as ConcavePolygonShape3D).get_faces().size() if sh is ConcavePolygonShape3D else ""))
		righe.append(r)
	var testo := "\n".join(righe)
	if a.size() > 2:
		var f := FileAccess.open(a[2], FileAccess.WRITE)
		f.store_string(testo)
		f.close()
	print("TUNNEL %s: %d nodi, md5 %s" % [modo, righe.size(), testo.md5_text()])
	get_tree().quit()

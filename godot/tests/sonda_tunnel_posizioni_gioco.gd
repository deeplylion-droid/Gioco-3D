extends Node
## Sonda: le posizioni di tutto quello che la costruzione del tunnel mette in scena, nel gioco vero (F9 Inseguimento,
## con sala, torre e condotte intorno), per confrontare due versioni del codice (per esempio Posa con le sole mesh del
## tunnel lungo il raggio). Per ogni nodo sotto SalaSottomarino il percorso e la trasformazione nel mondo; senza lei e
## senza i gommoni, che galleggiano. Scrive la lista nel file dato come argomento.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_tunnel_posizioni_gioco.gd <file>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	MenuProva.parti(get_tree(), "inseguimento")
	var t0 := Time.get_ticks_msec()
	while not AttesaZone.e_pronta(&"tunnel") and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	var sala := get_tree().current_scene
	var sott := sala.get(&"sala_sottomarino") as Node3D
	var righe: PackedStringArray = []
	for n in sott.find_children("*", "Node3D", true, false):
		var via := String(sott.get_path_to(n))
		if via.begins_with("LeiTunnel") or via.begins_with("Gommoni/"):
			continue
		var t := (n as Node3D).global_transform
		righe.append("%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f" % [via, t.origin.x, t.origin.y, t.origin.z,
				t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z])
	var f := FileAccess.open(a[1] if a.size() > 1 else "user://posizioni_tunnel.txt", FileAccess.WRITE)
	f.store_string("\n".join(righe))
	f.close()
	print("POSIZIONI: %d nodi" % righe.size())
	get_tree().quit()

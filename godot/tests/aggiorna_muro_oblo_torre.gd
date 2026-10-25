extends Node
## Calcola dalla mesh torre_A il muro attorno all'oblò della torre (SalaTorre.calcola_muro_oblo: materiali, quote, UV
## e colori dei vertici) e lo salva in SalaTorre.MURO_OBLO, che il gioco legge (calcolarlo costruendo la torre costava
## più di 100 ms in un passo). Da rifare quando cambia torre_struttura.glb. Con "controlla" non scrive: confronta.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/aggiorna_muro_oblo_torre.gd [controlla]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	torre.oblo_lei = false
	add_child(torre)
	await get_tree().process_frame
	var d: Dictionary = torre.dati["oblo_lei"]
	var xf := Transform3D(Basis.looking_at(-SalaTorre.b(d["normale"]).normalized(), Vector3.UP), SalaTorre.b(d["centro"]))
	var mi := torre.find_child("torre_A", true, false) as MeshInstance3D
	var muro := SalaTorre.calcola_muro_oblo(mi, xf, float(d["lato"]) * 0.5)
	var testo := JSON.stringify(muro, " ")
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "controlla":
		var vecchio = JSON.parse_string(FileAccess.get_file_as_string(SalaTorre.MURO_OBLO)) if FileAccess.file_exists(SalaTorre.MURO_OBLO) else null
		var uguale: bool = vecchio != null and JSON.stringify(vecchio, " ") == JSON.stringify(JSON.parse_string(testo), " ")
		print(("ok  " if uguale else "KO  ") + "il muro dell'oblò della torre salvato corrisponde a torre_A (%d fasce)" % muro.size())
		get_tree().quit(0 if uguale else 1)
		return
	var f := FileAccess.open(SalaTorre.MURO_OBLO, FileAccess.WRITE)
	f.store_string(testo)
	f.close()
	print("scritto %s: %d fasce" % [SalaTorre.MURO_OBLO, muro.size()])
	get_tree().quit()

extends Node
## Rifà i materiali campione del tunnel sottomarino (CampioniTunnel.FILE): un materiale senza texture per ogni shader
## del tunnel costruito (SalaSottomarino), come per la Risalita (tests/aggiorna_risorse_risalita.gd). Con "controlla"
## non scrive niente e controlla che ogni shader del tunnel abbia il suo campione (in CI: se il tunnel cambia, si rifà).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/aggiorna_campioni_tunnel.gd [controlla]

const Risalita := preload("res://tests/aggiorna_risorse_risalita.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	await get_tree().process_frame
	var tunnel := {}
	RisorseNodi.materiali_per_shader(sala, tunnel)
	if OS.get_cmdline_user_args().has("controlla"):
		var campioni := {}
		for m in CampioniTunnel.carica():
			campioni[RisorseNodi.chiave_shader(m)] = true
		var mancano := []
		for k in tunnel:
			if not campioni.has(k):
				mancano.append("%s (%s)" % [(tunnel[k] as Material).resource_name, (tunnel[k] as Material).get_class()])
		for x in mancano.slice(0, 10):
			print("  manca il campione di: ", x)
		print("%s  ogni shader del tunnel (%d) ha il suo campione (%d mancano)" % ["ok" if mancano.is_empty() else "KO", tunnel.size(), mancano.size()])
		get_tree().quit(0 if mancano.is_empty() else 1)
		return
	var lista: Array[Material] = []
	for k in tunnel:
		lista.append(Risalita.campione(tunnel[k]))
	var r := Resource.new()
	r.set_meta(&"materiali", lista)
	ResourceSaver.save(r, CampioniTunnel.FILE)
	print("%s: %d materiali" % [CampioniTunnel.FILE, lista.size()])
	get_tree().quit()

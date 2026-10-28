extends Node
## Misura la costruzione a pezzi del tunnel sottomarino come nel gioco (SalaPrincipale._metti_sottomarino): caricato,
## instantiate, add_child, costruisci_a_pezzi (col riscaldamento e le forme dei tentacoli). Stampa ogni fotogramma sopra
## 50 ms e, con TORRE_TEMPI=1, i passi sopra 20 ms.
## Uso: TORRE_TEMPI=1 godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_tunnel_pezzi.gd

var _t := 0
var _misura := false


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	var ora := Time.get_ticks_usec()
	if _misura and _t > 0 and ora - _t > 50000:
		print("BLOCCO %.0f ms" % ((ora - _t) / 1000.0))
	_t = ora


func _run() -> void:
	Game.pause_on_focus_loss = false
	var scena := load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene
	var campioni := CampioniTunnel.carica()
	# come nel gioco: i file del tunnel arrivano col thread insieme alla scena
	var tenuti: Array = []
	for r in SalaSottomarino.risorse():
		tenuti.append(load(r))
	for i in 10:
		await get_tree().process_frame
	_misura = true
	var t0 := Time.get_ticks_usec()
	var s := scena.instantiate() as Node3D
	add_child(s)
	print("instantiate e add_child: %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	await s.call(&"costruisci_a_pezzi")
	print("TUNNEL: costruito in %.1f s (%d campioni)" % [(Time.get_ticks_usec() - t0) / 1e6, campioni.size()])
	get_tree().quit()

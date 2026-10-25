extends Node
## Misura la preparazione nascosta della sala della torre come nel gioco (SalaPrincipale._prepara_torre): caricata
## prima (come dal thread), instantiate, add_child nascosta e ferma, costruisci_a_pezzi (con l'inseguimento). Stampa
## ogni fotogramma sopra i 50 ms e, con TORRE_TEMPI=1, la durata di ogni passo della torre e dell'inseguimento.
## Uso: TORRE_TEMPI=1 godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_torre_pezzi.gd

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
	Engine.set_meta(&"precarica_torre_spento", true)
	var scena := load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene
	for i in 10:
		await get_tree().process_frame
	_misura = true
	var t0 := Time.get_ticks_usec()
	var t := scena.instantiate() as Node3D
	t.set(&"costruzione_a_pezzi", true)
	t.set(&"inseguimento_continua", true)
	t.visible = false
	t.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(t)
	print("instantiate e add_child: %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	await t.call(&"costruisci_a_pezzi")
	print("TORRE: costruita in %.1f s, il fotogramma più carico della torre %.0f ms" % [(Time.get_ticks_usec() - t0) / 1e6, float(t.get(&"fotogramma_piu_carico_ms"))])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit()

extends Node
## Misura quanto ferma il thread principale mettere in scena le zone grandi che il gioco istanzia mentre si gioca
## (fiume e infermeria della Risalita, torre, tunnel sottomarino): per ognuna, caricata prima (come dal thread),
## il tempo di instantiate() e di add_child() (i _ready), da sola, senza la costruzione a pezzi che viene dopo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_istanze.gd

const SCENE := [
	"res://scenes/risalita/fiume.tscn",
	"res://scenes/risalita/infermeria.tscn",
	"res://scenes/sala/torre/sala_torre.tscn",
	"res://scenes/sala/sottomarino/sala_sottomarino.tscn",
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	for percorso: String in SCENE:
		var t0 := Time.get_ticks_usec()
		var scena := load(percorso) as PackedScene
		var t1 := Time.get_ticks_usec()
		for i in 5:
			await get_tree().process_frame
		var t2 := Time.get_ticks_usec()
		var n := scena.instantiate()
		var t3 := Time.get_ticks_usec()
		# come nel gioco: nascosta e ferma (la costruzione a pezzi parte dopo)
		if n is Node3D:
			(n as Node3D).visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.set(&"costruzione_a_pezzi", true)
		add_child(n)
		var t4 := Time.get_ticks_usec()
		print("ISTANZA %s: load %.0f ms (nel gioco nel thread), instantiate %.0f ms, add_child %.0f ms" % [
				percorso.get_file(), (t1 - t0) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0])
		n.queue_free()
		for i in 5:
			await get_tree().process_frame
	print("ISTANZE: finito")
	get_tree().quit()

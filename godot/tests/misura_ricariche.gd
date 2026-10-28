extends Node
## Misura: quanta memoria statica resta dopo aver messo e tolto una scena più volte (per trovare chi non libera la sua
## memoria a ogni ripartenza; test_memoria_morti del 28 ottobre). Stampa la crescita media per giro, dopo il primo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_ricariche.gd [scena,scena]

const SCENE := ["res://scenes/interni/interni.tscn", "res://scenes/tecnici/tecnici.tscn",
	"res://scenes/risalita/risalita.tscn", "res://scenes/sala/enigma_acquari.tscn", "res://scenes/sala/luci_sala.tscn",
	"res://scenes/player/player.tscn", "res://scenes/creature/bambino_agnello.tscn", "res://scenes/sala_principale.tscn"]
const GIRI := 4


func _ready() -> void:
	_run.call_deferred()


func _mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


func _run() -> void:
	Game.pause_on_focus_loss = false
	var scene: Array = SCENE
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		scene = Array(args[1].split(","))
	for percorso in scene:
		var pacchetto := load(percorso) as PackedScene
		var misure: Array[float] = []
		for g in GIRI:
			var n := pacchetto.instantiate()
			add_child(n)
			for i in 30:
				await get_tree().process_frame
			n.queue_free()
			for i in 20:
				await get_tree().process_frame
			misure.append(_mb())
		print("RICARICA %s: %+.2f MB per giro (giri: %s)" % [percorso.get_file(), (misure[-1] - misure[0]) / (GIRI - 1),
			", ".join(misure.map(func(x): return "%.1f" % x))])
	Game.esci(0)

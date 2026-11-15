extends "res://tests/test_agnellino.gd"
## test_agnellino (l'agnellino della scala C2 inseguito dal giocatore) col MonitorBambini: piedi, contatti col bordo
## del buco e con la roba, sparizione, pipeline. Senza schermo (la sala intera col renderer vero non sta in memoria).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_bambini_scala.gd <cartella>

const MON := preload("res://tests/collaudo/monitor_bambini.gd")


func _ready() -> void:
	add_child(MON.new(OS.get_cmdline_user_args()[1]))
	super._ready()

extends Node
## Collaudo: carica gli script dati (dopo il primo argomento) e stampa se si compilano, con gli autoload del progetto.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sintassi.gd <script>...
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	for i in range(1, a.size()):
		var sc = load(a[i])
		print("SINTASSI: %s %s" % [a[i], "ok" if sc and (sc as GDScript).can_instantiate() else "ERRORE"])
	get_tree().quit()

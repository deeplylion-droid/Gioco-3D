extends Node
## Sonda: dove sono, nella sala, i gonfiabili d'arredo spostati fuori dalla parte profonda della piscina a onde.

const NOMI := ["ogg_paperella_gigante_0", "ogg_paperella_gigante_1", "ogg_pallone_spiaggia_2", "ogg_pallone_spiaggia_3",
	"ogg_pallone_spiaggia_43", "ogg_pallone_spiaggia_71"]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate() as Node3D
	add_child(s)
	for nome in NOMI:
		var o := s.get_node_or_null(NodePath("Sala/Oggetti/" + nome)) as Node3D
		var corpo := o.get_child(0) as Node3D if o and o.get_child_count() > 0 else null
		print("OGG %s %s corpo %s" % [nome, o.global_position if o else "manca", corpo.global_position if corpo else "-"])
	get_tree().quit()

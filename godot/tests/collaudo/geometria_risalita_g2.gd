extends "res://tests/collaudo/geometria.gd"
## grafica-2: geometria.gd con le stanze della Risalita caricate subito (infermeria, pozze, corridoi), come il
## controllo della CI (Engine.set_meta risalita_subito). Stessi argomenti di geometria.gd.


func _ready() -> void:
	Engine.set_meta(&"risalita_subito", true)
	super._ready()

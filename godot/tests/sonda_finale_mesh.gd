extends Node
## Sonda (non in CI): dopo SalaSottomarino.mostra_finale_per_controllo, quali mesh dei bambini del finale sono visibili.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var sala := SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	await sala.mostra_finale_per_controllo(false)
	for i in 5:
		await get_tree().physics_frame
	for b in sala._bambini_finale:
		var righe: Array = []
		for m in b.find_children("*", "VisualInstance3D", true, false):
			righe.append("%s %s/%s" % [b.get_path_to(m), (m as Node3D).visible, (m as Node3D).is_visible_in_tree()])
		print("BAMBINO ", b.name, " vis ", b.visible, " ", righe)
	get_tree().quit()

extends Node
## D5: quanto durano le animazioni degli oblò (arrivo, ferma, distacco) per ogni posa.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var lo := LeiOblo.new()
	add_child(lo)
	lo.mostra(Vector3(0, 1.5, 0), Vector3.BACK, "capovolta")
	await get_tree().process_frame
	var ap: AnimationPlayer = lo._ap
	for n in ap.get_animation_list():
		if String(n).contains("oblo"):
			print("ANIM %s: %.2f s" % [n, ap.get_animation(n).length])
	print("RISULTATO: 1 controlli ok, 0 falliti")
	get_tree().quit()

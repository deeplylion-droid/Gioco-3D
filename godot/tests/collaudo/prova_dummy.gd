extends Node
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = load("res://audio/lei/lei_canto_prima_vicino_01.ogg")
	p.play()
	print("PD: driver ", AudioServer.get_driver_name(), " len ", p.stream.get_length())
	for i in 5:
		await get_tree().create_timer(0.5).timeout
		print("PD: t ", (i + 1) * 0.5, " playing ", p.playing, " pos ", p.get_playback_position())
	get_tree().quit()

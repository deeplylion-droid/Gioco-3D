extends Node
## Collaudo: la scena del risveglio con lo squalo, dall'inizio alla fine. Scrive quando parte ogni suono (file,
## volume, posizione), quando la scena finisce e se il giocatore torna a muoversi.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_squalo.gd

var _visti := {}
var _t := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var livello := (load("res://scenes/interni/interni.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 20:
		await get_tree().physics_frame
	var p := GameState.player
	var squalo := livello.get_node_or_null(^"Gioco/RisveglioSqualo")
	print("SQUALO scena presente: ", squalo != null)
	var finito := [false]
	if squalo:
		squalo.connect(&"finito", func(): finito[0] = true)
	livello.call(&"fai_risveglio", p, true)
	var fine_t := -1.0
	while _t < 40.0:
		await get_tree().process_frame
		_t += get_process_delta_time()
		_guarda()
		if finito[0] and fine_t < 0.0:
			fine_t = _t
			print("SQUALO finito a %.2f s; giocatore libero: %s" % [_t, p.input_enabled if p else "?"])
		if fine_t >= 0.0 and _t > fine_t + 2.0:
			break
	if fine_t < 0.0:
		print("SQUALO non finito dopo %.1f s" % _t)
	print("SQUALO giocatore libero alla fine: ", p.input_enabled if p else "?")
	get_tree().quit()


var _conti := {}


func _guarda() -> void:
	var au := get_node_or_null(^"/root/Audio")
	if au:
		var c: Dictionary = au.get(&"conteggio")
		for k in c:
			if int(c[k]) != int(_conti.get(k, 0)):
				_conti[k] = int(c[k])
				var st: AudioStream = au.call(&"stream_di", k)
				var ta: Array = au.call(&"taratura", k)
				print("AUDIO %6.2f s %s file %s taratura %s durata %.2f" % [_t, k, st.resource_path.get_file() if st else "?", ta, st.get_length() if st else 0.0])
	for n in get_tree().root.find_children("*", "Node", true, false):
		if not (n is AudioStreamPlayer or n is AudioStreamPlayer3D):
			continue
		var suona: bool = n.get(&"playing")
		var s: AudioStream = n.get(&"stream")
		var chiave := "%d|%s" % [n.get_instance_id(), s.resource_path if s else ""]
		if suona and not _visti.has(chiave):
			_visti[chiave] = true
			var dove := ""
			if n is AudioStreamPlayer3D:
				dove = " pos %s max_db %.1f" % [(n as Node3D).global_position.snapped(Vector3.ONE * 0.1), (n as AudioStreamPlayer3D).max_db]
			print("SUONO %6.2f s %s vol %.1f dB%s durata %.2f" % [_t, s.resource_path.get_file() if s else "?",
					float(n.get(&"volume_db")), dove, s.get_length() if s else 0.0])
		elif not suona and _visti.has(chiave):
			_visti.erase(chiave)

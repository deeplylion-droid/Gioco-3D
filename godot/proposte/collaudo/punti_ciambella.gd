extends Node
## Collaudo (mascotte): i punti del giro in ciambella sul fiume della risalita, dalle curve dei tratti di
## fiume_gioco.gd (var tratti), nel mondo, ogni [PASSO] m, all'altezza degli occhi di chi sta seduto sulla ciambella.
## Scrive le righe per tests/collaudo/giro.gd: nome x y z yaw pitch (lo sguardo lungo la corsa).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/collaudo/punti_ciambella.gd <uscita>

var PASSO := float(OS.get_environment("PASSO")) if OS.has_environment("PASSO") else 4.0
const OCCHI := 0.95     # sopra il pelo dell'acqua, seduti sulla ciambella

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var uscita := OS.get_cmdline_user_args()[1]
	Engine.set_meta(&"risalita_subito", true)
	var livello := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	for nome in ["Sala", "LuciSala", "Vasca", "Piscina", "Vasche", "Polaroid", "Mascotte", "BambiniBalconata", "Atmosfera"]:
		var n := livello.get_node_or_null(NodePath(nome))
		if n:
			livello.remove_child(n)
			n.free()
	get_tree().root.add_child(livello)
	var fiume: Node3D = null
	for i in 900:
		await get_tree().process_frame
		for n in livello.find_children("*", "Node3D", true, false):
			if n.get(&"tratti") is Dictionary and not (n.get(&"tratti") as Dictionary).is_empty():
				fiume = n
				break
		if fiume:
			break
	if fiume == null:
		print("NIENTE FIUME")
		get_tree().quit(1)
		return
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	var tratti: Dictionary = fiume.get(&"tratti")
	print("tratti: ", tratti.keys())
	for nome in tratti:
		var t: Path3D = tratti[nome]
		var c := t.curve
		var l := c.get_baked_length()
		var passo := PASSO * (2.0 if String(nome).begins_with("Sbagliato") else 1.0)
		var k := 0
		var s := 0.0
		while s <= l:
			var p := t.global_transform * c.sample_baked(s)
			var q := t.global_transform * c.sample_baked(minf(s + 1.0, l))
			var d := q - p
			var yaw := rad_to_deg(atan2(-d.x, -d.z)) if d.length() > 0.01 else 0.0
			f.store_line("c_%s_%02d %.2f %.2f %.2f %.0f -8" % [nome, k, p.x, p.y + OCCHI, p.z, yaw])
			k += 1
			s += passo
	f.close()
	print("SCRITTO ", uscita)
	# le stanze si caricano in un thread: senza aspettarle si esce subito
	OS.kill(OS.get_process_id())

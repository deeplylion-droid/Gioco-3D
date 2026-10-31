extends Node
## Crash della 0.3.17: la torre con le condotte da sola (sala_torre.tscn), col renderer vero e l'ambiente della sala, al
## buio dopo la sala pompe: le lampade d'emergenza del muro est (shadow_caster_mask), l'acqua delle vasche, il giocatore
## vero nella vasca 1 e lei che sale lì con la morbidezza, per [constant SECONDI] s, guardandola. Ogni secondo una riga.
## Con SENZA_MASK=1 le lampade d'emergenza tornano come nella 0.3.16 (shadow_caster_mask pieno, torre_A sugli strati
## di prima), per confronto.
## Uso (sotto il render.lock): xvfb-run ... --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/torre_sola_vera.gd

const SECONDI := 60


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	for i in 30:
		await get_tree().process_frame
	if OS.get_environment("SENZA_MASK") == "1":
		var n := 0
		for l in torre.find_children("*", "Light3D", true, false):
			if (l as Light3D).shadow_caster_mask != 0xFFFFFFFF:
				(l as Light3D).shadow_caster_mask = 0xFFFFFFFF
				n += 1
		var ta := torre.find_child("torre_A", true, false) as GeometryInstance3D
		if ta:
			ta.layers = 1
		print("SENZA_MASK %d luci rimesse" % n)
	var ins := torre.inseguimento as SalaInseguimento
	var v: Dictionary = ins.dati["vasche"][0]
	var r: Array = v["rett"]
	p.teleport(SalaInseguimento.b([(r[0] + r[2]) / 2.0 - 1.0, (r[1] + r[3]) / 2.0, float(v["fondo"]) + 0.05]))
	for i in 30:
		await get_tree().process_frame
	print("PRONTO giocatore a %s, %d luci" % [p.global_position, torre.find_children("*", "Light3D", true, false).size()])
	# (lei non prende: la presa farebbe ripartire dalla sala intera, che renderizzata qui non ci sta in memoria)
	ins.tempo_presa = 9999.0
	ins.call(&"_lei_sale", "vasca_0", ins.call(&"_posto_vasca", 0))
	for s in SECONDI:
		await get_tree().create_timer(1.0, true, false, true).timeout
		if ins.lei:
			p.look_at_point(ins.lei.global_position + Vector3.UP * 3.0)
		print("VIVO %d s, fotogrammi %d, video %d MB, lei %s, morte %s" % [s + 1, Engine.get_frames_drawn(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576,
				ins.get(&"lei_stato"), GameState.is_dying])
	print("FINE torre sola senza chiudersi")
	get_tree().quit()

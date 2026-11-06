extends Node
## grafica-2 (0.3.21): gli scatti dei bersagli da luna park delle paratie (proposta A, scelta dall'utente), per farli
## vedere all'utente prima di metterli nel gioco. La torre con le condotte (sala_torre.tscn), con l'ambiente della sala e
## le luci del blackout (come scatti_tubi_inseguimento.gd), il giocatore vero:
## - in ogni vasca, dal checkpoint (da dove si spara), la giusta e la sbagliata insieme; poi ognuna da 2,5 m;
## - nella vasca 1 il getto che colpisce la giusta;
## - nella vasca 1 lei su (tempo_presa altissimo: non prende).
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_bersagli_g2.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
var cartella := "user://scatti_bersagli"
var p: Player
var ins: SalaInseguimento


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var f := cartella.path_join(nome + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(f, 0.92)
	print("SCATTO ", f)


func _guarda(da: Vector3, verso: Vector3, nome: String, attesa := 40) -> void:
	p.teleport(da + Vector3.UP * 0.05)
	await _fotogrammi(10)
	p.look_at_point(verso)
	await _fotogrammi(attesa)
	p.look_at_point(verso)
	await _fotogrammi(2)
	await _scatto(nome)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _fotogrammi(30)
	ins = torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	ins.comparsa = PackedFloat32Array([9999.0, 9999.0, 9999.0])
	if ins.lei:
		ins.lei.visible = false
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(10)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.water_pack.call(&"set_equipped", true, false)
	var cps: Array = ins.dati["checkpoint"]
	for v in 3:
		var cp: Dictionary = cps[v]
		var da := SalaInseguimento.b(cp["pos"])
		var giusta := -1
		var sbagliata := -1
		for k in ins.paratie.size():
			if int(ins.paratie[k]["vasca"]) == v:
				if bool(ins.paratie[k]["giusta"]):
					giusta = k
				else:
					sbagliata = k
		var bg := SalaInseguimento.b(ins.paratie[giusta]["bersaglio"])
		var bs := SalaInseguimento.b(ins.paratie[sbagliata]["bersaglio"])
		await _guarda(da, (bg + bs) * 0.5, "vasca%d_dal_checkpoint" % (v + 1), 60)
		for k in [giusta, sbagliata]:
			var bk := SalaInseguimento.b(ins.paratie[k]["bersaglio"])
			var n := SalaInseguimento.b(ins.paratie[k]["verso"])
			n.y = 0.0
			var vicino := bk - n.normalized() * 2.5
			vicino.y = da.y
			await _guarda(vicino, bk, "vasca%d_%s_vicino" % [v + 1, "giusta" if k == giusta else "sbagliata"])
		if v == 0:
			# il getto che colpisce la giusta (prima che si apra)
			await _guarda(da, bg, "vasca1_getto_mira", 30)
			p.water_pack.set_tank_amount(20.0)
			Input.action_press(&"spray")
			for i in 24:
				await get_tree().physics_frame
				p.look_at_point(bg)
			await _scatto("vasca1_getto_colpisce")
			for i in 8:
				await get_tree().physics_frame
				p.look_at_point(bg)
			await _scatto("vasca1_getto_colpisce_2")
			Input.action_release(&"spray")
			print("PARATIA giusta vasca 1: getto %.2f s, apre %s" % [float(ins.paratie[giusta]["getto"]), ins.paratie[giusta]["apre"]])
			# di nuovo chiusa, per lei
			ins.paratie[giusta]["getto"] = 0.0
			await _fotogrammi(30)
			# lei su nella vasca 1
			ins._lei_sale("vasca_0", ins._posto_vasca(0))
			await _fotogrammi(150)
			await _guarda(da, (bg + bs) * 0.5, "vasca1_lei_su", 20)
			var occhi := ins.lei.get_eye_position()
			await _guarda(da, (occhi + (bg + bs) * 0.5) * 0.5, "vasca1_lei_su_2", 10)
			ins._scendi()
			await _fotogrammi(120)
	print("BERSAGLI FINE")
	get_tree().quit()

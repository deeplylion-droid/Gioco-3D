extends Node
## Scatti dagli occhi del giocatore per il ricontrollo dell'acqua vista da sotto (riscontro dell'utente sulla 0.3.19,
## test_occhio_sopra_acque): per ogni tubo e scolo che parte da una vasca, accovacciato dentro la bocca (a 3 punti della
## linea) guardando indietro verso la vasca, e in piedi nella vasca guardando la bocca; per ogni acqua, accovacciato in
## mezzo guardando davanti a sé all'altezza degli occhi. La torre da sola, con l'ambiente della sala, al buio dopo la sala
## pompe, come nel gioco.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_occhio_acque.gd <cartella> <prefisso>

const PLAYER := "res://scenes/player/player.tscn"

var cartella := ""
var prefisso := ""
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(prefisso + nome + ".jpg"), 0.9)
	print("SCATTO %s%s occhi %s" % [prefisso, nome, p.camera.global_position])


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	prefisso = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(cartella)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _fotogrammi(30)
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	ins.set(&"_scolo", true)
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	await _fotogrammi(240)
	if ins.lei:
		ins.lei.visible = false
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(5)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	# le bocche dei tubi che partono dalle vasche
	for nome: String in ins.dati["tubi"]:
		if nome == "ins_A_tubo_0":
			continue
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var dir := linea[2] - linea[0]
		dir.y = 0.0
		dir = dir.normalized()
		# in piedi nella vasca, 2,5 m prima della bocca, guardando la bocca
		Input.action_release(&"crouch")
		await _fotogrammi(10)
		p.teleport(linea[0] - dir * 2.5 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1) + Vector3.UP * 0.3)
		await _fotogrammi(40)
		p.look_at_point(linea[0] + Vector3.DOWN * 0.3)
		await _scatto("%s_0_vasca" % nome)
		# accovacciato dentro la bocca, guardando indietro la vasca
		Input.action_press(&"crouch")
		var k := 1
		for i in [3, 6, 9]:
			var piedi := linea[i] + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.15)
			p.teleport(piedi)
			await _fotogrammi(30)
			p.global_position = piedi
			p.velocity = Vector3.ZERO
			p.look_at_point(linea[0] - dir * 2.0 + Vector3.UP * 0.05)
			await _scatto("%s_%d_bocca_indietro" % [nome, k])
			k += 1
	Input.action_release(&"crouch")
	# accovacciato in mezzo a ogni acqua
	Input.action_press(&"crouch")
	var sp := p.get_world_3d().direct_space_state
	for m in torre.find_children("acqua*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		var c := box.get_center().lerp(box.position, 0.35)
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, box.end.y + 0.5, c.z), Vector3(c.x, box.end.y - 3.0, c.z), Layers.WORLD)
		q.exclude = [p.get_rid()]
		var r := sp.intersect_ray(q)
		if r.is_empty():
			continue
		p.teleport((r["position"] as Vector3) + Vector3.UP * 0.05)
		await _fotogrammi(40)
		var verso := box.get_center() - c
		verso.y = 0.0
		p.look_at_point(p.camera.global_position + verso.normalized() * 3.0 + Vector3.DOWN * 0.15)
		await _scatto("acqua_%s_accovacciato" % mi.name)
	Input.action_release(&"crouch")
	get_tree().quit()

extends "res://tests/collaudo/scatti_bocche_da_sotto.gd"
## Ricontrollo di grafica (6 novembre) delle bocche e delle ombre di grafica-2 (lavoro/bocche-ombre-g2 4e4679ec, unito
## coi bersagli da luna park fc93f763). Usa le funzioni di scatti_bocche_da_sotto.gd (le pose dentro il tubo), con pose
## sue:
## - fermo: ogni bocca da 2,5, 1,5, 0,8 e 0,3 m dentro il tubo, guardando la vasca (sotto il pelo), e guardando un po' in su;
## - scivolo: in ogni tubo si entra dalla vasca e, passati 1,3 m, ci si gira verso la vasca mentre si scivola: 6 scatti,
##   uno ogni 3 fotogrammi (scatti o strisce si vedono come differenze fra uno e l'altro);
## - fuori: ogni bocca dalla vasca, 2 m davanti alla parete, sopra il pelo e appena sotto (il retro non deve fare luce);
## - riga: la posa del tubo 3 del coordinatore (65,29; -27,92; -3,15) verso (0,98; 0,15; 0,15);
## - paratie: le tre paratie verdi dalla vasca, e da 3,5 m.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan \
##   --resolution 960x540 --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_bocche_grafica.gd \
##   <cartella> <fermo|scivolo|fuori|riga|paratie|tutto>


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	var fase: String = a[2] if a.size() > 2 else "tutto"
	prefisso = ""
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
	ins = torre.inseguimento as SalaInseguimento
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
	var veli: Array = ins.get(&"_veli")
	# (CANDIDATA=1: com'era sulla candidata b44dfab7, la parete con water_inseguimento.gdshader e l'ombra su tutte e tre
	# le lampade verdi; SOLO=tubo_1,scolo_0: solo quelle bocche; PROFONDITA=0.3,0.5: solo quelle profondità)
	if OS.has_environment("CANDIDATA"):
		prefisso = "candidata_"
		for v: MeshInstance3D in veli:
			(v.material_override as ShaderMaterial).shader = load("res://shaders/water_inseguimento.gdshader") as Shader
		for l in ins.find_children("*", "OmniLight3D", true, false):
			if l.get_meta(&"lampada_paratia_verde", false):
				(l as OmniLight3D).shadow_enabled = true
	var solo: PackedStringArray = OS.get_environment("SOLO").split(",", false)
	var profondita := [2.5, 1.5, 0.8, 0.3]
	if OS.has_environment("PROFONDITA"):
		profondita = Array(OS.get_environment("PROFONDITA").split_floats(","))
	print("COLLAUDO veli: %d, luci con ombra: %d" % [veli.size(), _luci_con_ombra()])
	if fase in ["fermo", "tutto"]:
		for v: MeshInstance3D in veli:
			var nome := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO).trim_prefix("ins_A_")
			if not solo.is_empty() and not solo.has(nome):
				continue
			for lz in profondita:
				await _da_dentro(v, lz)
				await _scatto("fermo_%s_%02d" % [nome, int(lz * 10)])
			if OS.has_environment("PROFONDITA"):
				continue
			await _da_dentro(v, 0.8, 0.6)
			await _scatto("fermo_%s_08_su" % nome)
	if fase in ["scivolo", "tutto"]:
		for v: MeshInstance3D in veli:
			var nome_tubo := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO)
			if not ins.dati["tubi"].has(nome_tubo):
				continue
			p.set_physics_process(true)
			await _entra_fino(v, nome_tubo, 1.3, false)
			for k in 6:
				await _fotogrammi(3)
				await _scatto("scivolo_%s_%d" % [nome_tubo.trim_prefix("ins_A_"), k])
			Input.action_release(&"crouch")
	var cam := Camera3D.new()
	cam.fov = p.camera.fov
	cam.near = p.camera.near
	cam.attributes = p.camera.attributes
	add_child(cam)
	if fase in ["fuori", "riga", "paratie", "tutto"]:
		p.set_physics_process(false)
		p.global_position = Vector3(40.0, -27.0, -5.0)
		cam.make_current()
	if fase in ["fuori", "tutto"]:
		for v: MeshInstance3D in veli:
			var nome := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO).trim_prefix("ins_A_")
			var pelo := float(v.get_meta(&"pelo"))
			var centro := v.global_transform.origin
			for h in [[0.5, "sopra"], [-0.25, "sotto"]]:
				var da := v.global_transform * Vector3(0.0, 0.0, -2.0)
				da.y = pelo + float(h[0])
				cam.global_position = da
				cam.look_at(Vector3(centro.x, pelo - 0.4, centro.z), Vector3.UP)
				await _fotogrammi(8)
				await _scatto("fuori_%s_%s" % [nome, h[1]])
	if fase in ["riga", "tutto"]:
		cam.global_position = Vector3(65.28869, -27.92377, -3.147806)
		cam.look_at(cam.global_position + Vector3(0.976734, 0.149438, 0.153816), Vector3.UP)
		await _fotogrammi(10)
		await _scatto("riga_tubo_3")
	if fase in ["paratie", "tutto"]:
		var dati_luci: Dictionary = ins.luci_dati
		for i in (dati_luci["paratie"] as Array).size():
			var pa: Array = dati_luci["paratie"][i]
			if pa[1] != "verde":
				continue
			var bers := SalaInseguimento.b(dati_luci["bersagli"][i])
			var verso := SalaInseguimento.b(pa[2]).normalized()
			cam.global_position = bers + verso * 3.5 + Vector3.DOWN * 0.3
			cam.look_at(bers + Vector3.UP * 0.6, Vector3.UP)
			await _fotogrammi(8)
			await _scatto("paratia_verde_%d" % i)
	print("COLLAUDO FINITO")
	get_tree().quit()


func _luci_con_ombra() -> int:
	var n := 0
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		if (l as Light3D).shadow_enabled and (l as Light3D).visible:
			n += 1
	return n

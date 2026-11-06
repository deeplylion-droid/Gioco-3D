extends Node
## Scatti delle bocche dei tubi viste da dentro, sotto il pelo, guardando verso la vasca (ricontrollo del collaudo dei
## ritocchi di ambienti-2): la parete d'acqua della bocca (SalaInseguimento._veli_bocche) in tutte e sei le bocche, e
## la riga verde nel tubo 3 con le luci verdi senza ombre vicine accese e spente una alla volta.
## Fasi (secondo argomento): veli | striscia | confronto (PRIMA=1 com'era prima della correzione). Il terzo argomento è il prefisso dei file.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_bocche_da_sotto.gd <cartella> <fase> [prefisso]

const PLAYER := "res://scenes/player/player.tscn"

var cartella := ""
var prefisso := ""
var p: Player
var ins: SalaInseguimento


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
	print("SCATTO %s%s camera %s" % [prefisso, nome, get_viewport().get_camera_3d().global_position])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	var fase := a[2]
	prefisso = a[3] if a.size() > 3 else ""
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
	# (per provare la luce propria della parete d'acqua: LUCE_VELO=<valore>)
	if OS.has_environment("LUCE_VELO"):
		for v: MeshInstance3D in veli:
			(v.material_override as ShaderMaterial).set_shader_parameter(&"luce_propria", float(OS.get_environment("LUCE_VELO")))
	if fase == "fascia":
		# (grafica-2: la fascia scura fra la sala e l'acqua nei primi 0,3-0,5 m dentro il tubo, ricontrollo di grafica
		# delle bocche: da cosa viene. Ogni posa normale, senza la parete della bocca, senza le acque delle vasche, senza
		# tutte e due; e dove sta la camera rispetto al pelo)
		var acque_vasche: Array[MeshInstance3D] = []
		for n in ins.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi in veli or not mi.material_override is ShaderMaterial:
				continue
			var sh := (mi.material_override as ShaderMaterial).shader
			if sh and sh.resource_path.ends_with("water_inseguimento.gdshader"):
				acque_vasche.append(mi)
		print("FASCIA: acque delle vasche %d, pareti %d" % [acque_vasche.size(), veli.size()])
		for v: MeshInstance3D in veli:
			var nome := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO)
			if not (nome.ends_with("tubo_1") or nome.ends_with("scolo_0")):
				continue
			for lz in [0.3, 0.5]:
				await _da_dentro(v, lz)
				var cam := p.camera.global_position
				print("FASCIA %s %.1f: camera a %.3f m dal pelo, occhi_pelo %.3f" % [nome, lz, cam.y - float(v.get_meta(&"pelo")), p.get(&"occhi_pelo")])
				for k in 4:
					v.visible = k % 2 == 0
					for aq in acque_vasche:
						aq.visible = k < 2
					await _fotogrammi(3)
					await _scatto("fascia_%s_%.1f_%s" % [nome.trim_prefix("ins_A_"), lz, ["normale", "senza_parete", "senza_acque", "senza_tutte"][k]])
				v.visible = true
				for aq in acque_vasche:
					aq.visible = true
	elif fase == "veli":
		for v: MeshInstance3D in veli:
			var nome := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO)
			await _da_dentro(v, 1.3)
			await _scatto("%s_da_sotto" % nome)
			if OS.has_environment("SENZA_MAGENTA"):
				continue
			var prima := v.material_override
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.0, 1.0)
			v.material_override = m
			await _scatto("%s_da_sotto_velo_magenta" % nome)
			v.material_override = prima
	elif fase == "confronto":
		# prima e dopo il ricontrollo del collaudo (PRIMA=1: com'era, la parete d'acqua senza luce propria e la lampada
		# verde delle paratie senza ombre): le 6 bocche da dentro, la riga verde nel tubo 3, le 3 paratie verdi dalla vasca
		# (CANDIDATA=1, grafica-2: com'era sulla candidata 0.3.21 b44dfab7, la parete con water_inseguimento.gdshader e
		# l'ombra su tutte e tre le lampade verdi)
		if OS.has_environment("CANDIDATA"):
			for v: MeshInstance3D in veli:
				(v.material_override as ShaderMaterial).shader = load("res://shaders/water_inseguimento.gdshader") as Shader
			for l in ins.find_children("*", "OmniLight3D", true, false):
				if l.get_meta(&"lampada_paratia_verde", false):
					(l as OmniLight3D).shadow_enabled = true
		if OS.has_environment("PRIMA"):
			for v: MeshInstance3D in veli:
				(v.material_override as ShaderMaterial).set_shader_parameter(&"luce_propria", 0.0)
			for l in ins.find_children("*", "OmniLight3D", true, false):
				if l.get_meta(&"lampada_paratia_verde", false):
					(l as OmniLight3D).shadow_enabled = false
		for v: MeshInstance3D in veli:
			var nome := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO)
			await _da_dentro(v, 1.0)
			await _scatto("bocca_%s" % nome.trim_prefix("ins_A_"))
		var cam := Camera3D.new()
		cam.fov = p.camera.fov
		cam.near = p.camera.near
		cam.attributes = p.camera.attributes
		add_child(cam)
		p.set_physics_process(false)
		p.global_position = Vector3(40.0, -27.0, -5.0)
		cam.global_position = Vector3(65.28869, -27.92377, -3.147806)
		cam.look_at(cam.global_position + Vector3(0.976734, 0.149438, 0.153816), Vector3.UP)
		cam.make_current()
		await _fotogrammi(10)
		await _scatto("riga_tubo_3")
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
			cam.global_position = bers + verso * 1.8 + Vector3.DOWN * 0.6
			cam.look_at(bers + Vector3.DOWN * 1.2, Vector3.UP)
			await _fotogrammi(8)
			await _scatto("paratia_verde_%d_bocca" % i)
	elif fase == "striscia":
		# come il collaudo: si entra nel tubo 3 e passati 1,3 m ci si gira verso la vasca mentre si scivola ancora; uno
		# scatto ogni 2 fotogrammi, poi la camera ferma dove la riga si vede di più (POSA=x,y,z,dx,dy,dz)
		var cam := Camera3D.new()
		cam.fov = p.camera.fov
		cam.near = p.camera.near
		cam.attributes = p.camera.attributes
		add_child(cam)
		if not OS.has_environment("POSA"):
			var v: MeshInstance3D = null
			for x: MeshInstance3D in veli:
				if String(x.name).ends_with("tubo_3"):
					v = x
			await _entra_fino(v, "ins_A_tubo_3", 1.3, false)
			for k in 12:
				await _fotogrammi(2)
				var c := p.camera.global_transform
				await _scatto("tubo_3_movimento_%02d" % k)
				print("POSA %02d %s %s" % [k, c.origin, -c.basis.z])
			get_tree().quit()
			return
		var posa := OS.get_environment("POSA").split_floats(",")
		cam.global_position = Vector3(posa[0], posa[1], posa[2])
		cam.look_at(cam.global_position + Vector3(posa[3], posa[4], posa[5]), Vector3.UP)
		cam.make_current()
		p.global_position = Vector3(40.0, -27.0, -5.0)
		p.set_physics_process(false)
		await _fotogrammi(10)
		await _scatto("tubo_3_normale")
		var base := get_viewport().get_texture().get_image()
		for l in get_tree().root.find_children("*", "Light3D", true, false):
			var li := l as Light3D
			if not li.visible or li.light_color.g < li.light_color.r * 1.3 or li.light_color.g < li.light_color.b * 1.1:
				continue
			li.visible = false
			await _fotogrammi(3)
			await RenderingServer.frame_post_draw
			var im := get_viewport().get_texture().get_image()
			var tolto := 0.0
			for y in range(0, base.get_height(), 2):
				for x in range(0, base.get_width(), 2):
					tolto += maxf(base.get_pixel(x, y).g - im.get_pixel(x, y).g, 0.0)
			print("LUCE %s/%s a %s ombre %s energia %.1f: verde tolto %.2f" % [li.get_parent().name, li.name, li.global_position.snapped(Vector3.ONE * 0.01),
					li.shadow_enabled, li.light_energy, tolto])
			if tolto > 5.0:
				await _scatto("tubo_3_senza_%s" % li.name)
			li.visible = true
			await _fotogrammi(2)
	get_tree().quit()


## Il giocatore accovacciato nel tubo della parete [param v], [param lz] m dentro, sotto il pelo, girato verso la vasca
## ([param su]: quanto in alto guarda, sopra il pelo, 2 m nella vasca).
func _da_dentro(v: MeshInstance3D, lz: float, su := 0.0) -> void:
	var nome := String(v.name).trim_prefix(SalaInseguimento.NOME_VELO)
	var linea := PackedVector3Array()
	for q in ins.dati["tubi"][nome]:
		linea.append(SalaInseguimento.b(q))
	var inv := v.global_transform.affine_inverse()
	var piedi := linea[0]
	for i in linea.size() - 1:
		var za := (inv * linea[i]).z
		var zb := (inv * linea[i + 1]).z
		if za <= lz and zb > lz:
			piedi = linea[i].lerp(linea[i + 1], (lz - za) / (zb - za))
			break
	piedi += Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.02)
	Input.action_press(&"crouch")
	p.set_physics_process(true)
	p.teleport(piedi)
	await _fotogrammi(40)
	# (fermo: nel tubo si scivola, e in pochi fotogrammi la camera era già un metro più in là)
	p.set_physics_process(false)
	p.global_position = piedi
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await _fotogrammi(2)
	var pelo := float(v.get_meta(&"pelo"))
	var verso := v.global_transform * Vector3(0.0, 0.0, -2.0)
	verso.y = pelo - 0.15 + su
	p.look_at_point(verso)
	await _fotogrammi(3)


## Come nel collaudo (vista_striscia.gd): il giocatore accovacciato entra dalla vasca nel tubo [param nome] guardando
## avanti, e quando l'occhio è [param lz] m oltre la parete [param v] si ferma e si gira verso la vasca, un po' in su.
func _entra_fino(v: MeshInstance3D, nome: String, lz: float, fermo := true) -> void:
	var linea := PackedVector3Array()
	for q in ins.dati["tubi"][nome]:
		linea.append(SalaInseguimento.b(q))
	var dir := linea[3] - linea[0]
	dir.y = 0.0
	dir = dir.normalized()
	p.teleport(linea[0] - dir * 2.0 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1) + Vector3.UP * 0.5)
	await _fotogrammi(20)
	p.velocity = Vector3.ZERO
	Input.action_press(&"crouch")
	await _fotogrammi(20)
	Input.action_press(&"move_forward")
	var ultimo := 0
	for f in 60 * 12:
		var piedi := p.global_position
		var iv := ultimo
		for i in range(ultimo, mini(ultimo + 12, linea.size())):
			if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
				iv = i
		ultimo = iv
		var g := linea[mini(iv + 4, linea.size() - 1)] - piedi
		g.y = 0.0
		if g.length() > 0.2:
			p.set_look(atan2(-g.x, -g.z), -0.15)
		await get_tree().physics_frame
		if (v.global_transform.affine_inverse() * p.camera.global_position).z > lz:
			break
	Input.action_release(&"move_forward")
	if fermo:
		p.set_physics_process(false)
		p.velocity = Vector3.ZERO
	p.set_look(atan2(dir.x, dir.z), 0.15)
	await _fotogrammi(3)

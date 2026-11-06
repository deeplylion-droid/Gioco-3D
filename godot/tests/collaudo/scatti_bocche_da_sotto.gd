extends Node
## Scatti delle bocche dei tubi viste da dentro, sotto il pelo, guardando verso la vasca (ricontrollo del collaudo dei
## ritocchi di ambienti-2): la parete d'acqua della bocca (SalaInseguimento._veli_bocche) in tutte e sei le bocche, e
## la riga verde nel tubo 3 con le luci verdi senza ombre vicine accese e spente una alla volta.
## Fasi (secondo argomento): veli | striscia. Il terzo argomento è il prefisso dei file.
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
	if fase == "veli":
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
	elif fase == "striscia":
		var v: MeshInstance3D = null
		for x: MeshInstance3D in veli:
			if String(x.name).ends_with("tubo_3"):
				v = x
		await _da_dentro(v, 1.32, 0.3)
		await _scatto("tubo_3_normale")
		var occhi := p.camera.global_position
		var luci := []
		for l in ins.find_children("*", "Light3D", true, false):
			var li := l as Light3D
			if li.visible and not li.shadow_enabled and li.light_color.g > li.light_color.r * 1.5 \
					and li.global_position.distance_to(occhi) < 12.0:
				luci.append(li)
		print("LUCI verdi senza ombre entro 12 m: %d" % luci.size())
		for li: Light3D in luci:
			li.visible = false
			await _fotogrammi(4)
			await _scatto("tubo_3_senza_%s" % li.name)
			print("  %s a %s, %.1f m, energia %.1f, raggio %.1f" % [li.name, li.global_position, li.global_position.distance_to(occhi),
					li.light_energy, (li as OmniLight3D).omni_range if li is OmniLight3D else (li as SpotLight3D).spot_range])
			li.visible = true
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

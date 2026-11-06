extends Node
## Collaudo del pelo radente (grafica-2, lavoro/fascia-pelo-radente; ricontrollo di ambienti-1, 6 novembre). La torre con
## le condotte e il giocatore vero, come scatti_bocche_da_sotto.gd:
##  - in ogni vasca, accucciati, si cammina avanti e indietro, si salta e si atterra: quanto scende al più l'occhio sopra
##    il pelo (sotto 0,18 m il pelo cambia colore: non deve succedere);
##  - in ognuna delle sei bocche si entra accucciati dalla vasca camminando, fino a 1,2 m dentro: per ogni fotogramma
##    l'altezza dell'occhio sul pelo e (con "scatti") il colore medio della metà bassa dello schermo, per vedere se il
##    pelo cambia colore di colpo (salto di colore fra due fotogrammi), e uno scatto ogni 2 fotogrammi attorno al cambio.
## Uso (sotto il render.lock):
##   godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_pelo_radente.gd
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_pelo_radente.gd scatti <cartella>

const PLAYER := "res://scenes/player/player.tscn"

var scatti := false
var cartella := "/tmp/collaudo_pelo_radente"
var p: Player
var ins: SalaInseguimento


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	scatti = a.has("scatti")
	if scatti and a.size() > 2:
		cartella = a[2]
	_run.call_deferred()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	if scatti:
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
	for i in 3000:
		await get_tree().process_frame
		if ins.costruita:
			break
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
	# 1) accucciati nelle vasche (con SOLO=nome,nome solo quelle bocche, e niente vasche)
	var quante_vasche := 0 if OS.has_environment("SOLO") else (ins.dati["vasche"] as Array).size()
	for v in quante_vasche:
		var d: Dictionary = ins.dati["vasche"][v]
		var r: Array = d["rett"]
		var pelo := float(d["acqua"])
		var a := SalaInseguimento.b([lerpf(r[0], r[2], 0.25), lerpf(r[1], r[3], 0.5), float(d["fondo"]) + 0.05])
		var b2 := SalaInseguimento.b([lerpf(r[0], r[2], 0.75), lerpf(r[1], r[3], 0.5), float(d["fondo"]) + 0.05])
		p.teleport(a)
		Input.action_press(&"crouch")
		await _fotogrammi(60)
		var minimo := INF
		for giro in 2:
			var meta := b2 if giro == 0 else a
			Input.action_press(&"move_forward")
			for f in 240:
				p.look_at_point(Vector3(meta.x, p.get_eye_position().y, meta.z))
				await get_tree().physics_frame
				minimo = minf(minimo, p.camera.global_position.y - pelo)
				if Vector2(p.global_position.x - meta.x, p.global_position.z - meta.z).length() < 0.3:
					break
			Input.action_release(&"move_forward")
		# il salto accucciato e l'atterraggio
		for s in 3:
			Input.action_press(&"jump")
			await _fotogrammi(3)
			Input.action_release(&"jump")
			for f in 90:
				await get_tree().physics_frame
				minimo = minf(minimo, p.camera.global_position.y - pelo)
		Input.action_release(&"crouch")
		await _fotogrammi(30)
		print("VASCA %d: accucciati, camminando e saltando, l'occhio scende al più a %.3f m sopra il pelo (il pelo cambia sotto 0,18)" % [v + 1, minimo])
	# 2) dentro le sei bocche, camminando accucciati dalla vasca
	var veli: Array = ins.get(&"_veli")
	for vl: MeshInstance3D in veli:
		var nome := String(vl.name).trim_prefix(SalaInseguimento.NOME_VELO)
		if OS.has_environment("SOLO") and not OS.get_environment("SOLO").split(",").has(nome.trim_prefix("ins_A_")):
			continue
		var pelo := float(vl.get_meta(&"pelo"))
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var inv := vl.global_transform.affine_inverse()
		# la partenza: 1,6 m davanti alla bocca, nella vasca, sul fondo
		var davanti := vl.global_transform * Vector3(0.0, 0.0, -1.6)
		var giu := PhysicsRayQueryParameters3D.create(davanti + Vector3.UP * 1.0, davanti + Vector3.DOWN * 3.0, 1, [p.get_rid()])
		var rr := get_viewport().find_world_3d().direct_space_state.intersect_ray(giu)
		var partenza := (rr.position as Vector3) if not rr.is_empty() else davanti
		# la meta: il punto della linea del tubo a 1,2 m dentro
		var meta := linea[0]
		for i in linea.size() - 1:
			var za := (inv * linea[i]).z
			var zb := (inv * linea[i + 1]).z
			if za <= 1.2 and zb > 1.2:
				meta = linea[i].lerp(linea[i + 1], (1.2 - za) / (zb - za))
				break
		for verso in (["entra"] if OS.has_environment("GUARDA_INDIETRO") else ["entra", "esce"]):
			p.set_physics_process(true)
			# (indietro: si entra camminando all'indietro, guardando la vasca)
			var da := partenza if verso != "esce" else meta + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.02)
			var verso_dove := meta if verso == "entra" else partenza
			p.teleport(da + Vector3.UP * 0.05)
			Input.action_press(&"crouch")
			# (nel tubo si scivola: per uscire si parte subito)
			await _fotogrammi(60 if verso == "entra" else 2)
			var righe := []
			var prima_col := Color.BLACK
			var salto := 0.0
			var salto_dove := ""
			var k := 0
			await _fotogrammi(1)
			var tasto := &"move_back" if verso == "indietro" else &"move_forward"
			Input.action_press(tasto)
			for f in 360:
				p.look_at_point(verso_dove + Vector3.UP * (0.05 if verso == "entra" else (0.4 if verso == "esce" else -0.3)))
				await get_tree().physics_frame
				var h := p.camera.global_position.y - pelo
				var dentro := (inv * p.camera.global_position).z
				var col := Color.BLACK
				if scatti and h < 0.25:
					# (GUARDA_INDIETRO: lo scatto da una camera negli occhi del giocatore girata verso la vasca, come chi entra
					# nella bocca voltandosi a guardare indietro)
					var dietro: Camera3D = null
					if OS.has_environment("GUARDA_INDIETRO"):
						dietro = Camera3D.new()
						dietro.fov = p.camera.fov
						dietro.near = p.camera.near
						dietro.attributes = p.camera.attributes
						add_child(dietro)
						dietro.global_position = p.camera.global_position
						dietro.look_at(partenza + Vector3.UP * 0.2, Vector3.UP)
						dietro.make_current()
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					var im := get_viewport().get_texture().get_image()
					if dietro:
						p.camera.make_current()
						dietro.queue_free()
					col = _media(im)
					if f > 0:
						var dd := absf(col.get_luminance() - prima_col.get_luminance())
						if dd > salto:
							salto = dd
							salto_dove = "fotogramma %d, occhio a %.3f m sul pelo, %.2f m dentro" % [f, h, dentro]
					prima_col = col
					if h < 0.20 and h > 0.04 and k < 30:
						im.save_jpg(cartella.path_join("%s_%s_%03d_h%03d.jpg" % [nome.trim_prefix("ins_A_"), verso, f, int(h * 1000)]), 0.88)
						k += 1
				righe.append("%d %.3f %.2f %.3f" % [f, h, dentro, col.get_luminance()])
				if (verso != "esce" and dentro > 1.2) or (verso == "esce" and dentro < -1.2) or (f > 60 and p.velocity.length() < 0.01):
					break
			Input.action_release(tasto)
			Input.action_release(&"crouch")
			var hmin := INF
			for rg in righe:
				hmin = minf(hmin, float(String(rg).split(" ")[1]))
			print("BOCCA %s (%s): %d fotogrammi, occhio sul pelo da %s a %.3f m; nella sfumatura (0,12-0,18) per %d fotogrammi%s" % [nome, verso,
					righe.size(), String(righe[0]).split(" ")[1], hmin,
					righe.filter(func(x): var h := float(String(x).split(" ")[1]); return h > 0.12 and h < 0.18).size(),
					("; salto di luminosità più grande fra due fotogrammi %.3f (%s)" % [salto, salto_dove]) if scatti else ""])
			if OS.has_environment("OGNI_FOTOGRAMMA"):
				for rg in righe:
					print("FOTOGRAMMA %s %s" % [nome, rg])
		p.set_physics_process(false)
		await _fotogrammi(5)
	print("FINE")
	get_tree().quit()


## Il colore medio della metà bassa dello schermo (dove sta il pelo entrando nella bocca).
func _media(im: Image) -> Color:
	var w := im.get_width()
	var hh := im.get_height()
	var s := Color(0, 0, 0, 0)
	var n := 0
	for y in range(hh / 2, hh, 8):
		for x in range(0, w, 8):
			s += im.get_pixel(x, y)
			n += 1
	return s / n

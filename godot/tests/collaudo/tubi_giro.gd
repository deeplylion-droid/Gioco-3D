extends Node
## Collaudo dei tubi dell'inseguimento (correzioni della 0.3.17), col renderer vero e il giocatore vero, come
## scatti_tubi_inseguimento.gd di ambienti-2: la torre da sola (con l'inseguimento), al buio. Per un tubo: il giocatore
## entra spingendo avanti e scivola fino in fondo, senza teletrasporti; uno scatto ogni [constant OGNI] fotogrammi
## dagli occhi, guardando avanti lungo la linea. Misura a ogni fotogramma quanto la camera si avvicina alla parete del
## tubo (distanza dalla linea del centro contro il raggio) e se il giocatore resta fermo. All'arrivo, in piedi e
## accovacciato: avanti, a sinistra, a destra, indietro verso la bocca del tubo e in alto (l'acqua vista da sotto).
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/tubi_giro.gd <cartella> <tubo> [ombra px py]
## Con "ombra px py": nello scatto accovacciato a sinistra, chi fa l'ombra che si vede nel punto (px, py) dello
## schermo: il punto del mondo, le luci con ombra che lo raggiungono e gli oggetti che fanno ombra fra lui e ogni luce.

const PLAYER := "res://scenes/player/player.tscn"
const OGNI := 15
var cartella := ""
var tubo := ""
var ombra := Vector2(-1, -1)
var p: Player


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	tubo = a[2]
	if a.size() > 5 and a[3] == "ombra":
		ombra = Vector2(float(a[4]), float(a[5]))
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%s.jpg" % [tubo, nome]), 0.88)


## La distanza di [param q] dalla linea (il segmento più vicino).
func _dalla_linea(linea: PackedVector3Array, q: Vector3) -> float:
	var d := INF
	for i in linea.size() - 1:
		var a := linea[i]
		var b := linea[i + 1]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		d = minf(d, q.distance_to(a + ab * t))
	return d


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
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
	if ins.lei:
		ins.lei.visible = false
	var linea := PackedVector3Array()
	for q in ins.dati["tubi"][tubo]:
		linea.append(SalaInseguimento.b(q))
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(10)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.teleport(linea[0] + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1))
	await _fotogrammi(2)
	p.look_at_point(linea[mini(6, linea.size() - 1)] + Vector3.UP * 0.1)
	p.velocity = (linea[2] - linea[0]).normalized() * 3.0
	Input.action_press(&"move_forward")
	var k := 0
	var ultimo := 0
	var arrivato := 0
	var max_cam := 0.0
	var max_cam_dove := Vector3.ZERO
	var fermo := 0
	var max_fermo := 0
	var prima := p.global_position
	var t_arrivo := -1.0
	var uscito_a := -1
	for f in 60 * 20:
		await get_tree().physics_frame
		if f == 40:
			Input.action_release(&"move_forward")
		var piedi := p.global_position
		var i_vicino := ultimo
		for i in range(ultimo, mini(ultimo + 12, linea.size())):
			if linea[i].distance_to(piedi) < linea[i_vicino].distance_to(piedi):
				i_vicino = i
		ultimo = i_vicino
		var cam := p.get_viewport().get_camera_3d()
		var dentro := ins.in_tubo(piedi)
		if dentro and cam:
			var dc := _dalla_linea(linea, cam.global_position)
			if dc > max_cam:
				max_cam = dc
				max_cam_dove = cam.global_position
		elif uscito_a < 0 and f > 60:
			uscito_a = f
		fermo = fermo + 1 if piedi.distance_to(prima) < 0.005 else 0
		max_fermo = maxi(max_fermo, fermo)
		prima = piedi
		var avanti := i_vicino
		var l := 0.0
		while avanti < linea.size() - 1 and l < 3.0:
			l += linea[avanti].distance_to(linea[avanti + 1])
			avanti += 1
		var dir := linea[avanti] - linea[i_vicino]
		if i_vicino == linea.size() - 1 or not dentro and f > 60:
			dir = Vector3(p.velocity.x, 0.0, p.velocity.z)
		if dir.length() > 0.1:
			p.look_at_point(p.global_position + Vector3.UP * 0.9 + dir.normalized() * 3.0 + Vector3.DOWN * 0.3)
		if f % OGNI == 0:
			await _scatto("%03d" % k)
			k += 1
		if i_vicino >= linea.size() - 2:
			if t_arrivo < 0:
				t_arrivo = f / 60.0
			arrivato += 1
			if arrivato > 90:
				break
	print("TUBI: %s: %d punti, in fondo dopo %.1f s, uscito dal tubo al fotogramma %d, fermo al più %d fotogrammi di fila; camera al più %.2f m dalla linea (raggio %.2f) in %s; arrivo in %s, in acqua %s" % [
		tubo, linea.size(), t_arrivo, uscito_a, max_fermo, max_cam, SalaInseguimento.R_TUBO, max_cam_dove.snapped(Vector3.ONE * 0.01),
		p.global_position.snapped(Vector3.ONE * 0.01), p.get(&"in_water") if p.get(&"in_water") != null else "?"])
	# all'arrivo: in piedi e accovacciato
	await _fotogrammi(60)
	var fine := linea[linea.size() - 1]
	var verso := Vector3(fine.x - linea[linea.size() - 4].x, 0, fine.z - linea[linea.size() - 4].z).normalized()
	var lato := verso.cross(Vector3.UP)
	for modo in ["in_piedi", "accovacciato"]:
		if modo == "accovacciato":
			Input.action_press(&"crouch")
			await _fotogrammi(40)
		var occhi := p.get_viewport().get_camera_3d().global_position
		for v in [["avanti", verso], ["sinistra", -lato], ["destra", lato], ["bocca", -verso + Vector3.UP * 0.3], ["alto", verso * 0.3 + Vector3.UP]]:
			p.look_at_point(occhi + (v[1] as Vector3) * 3.0)
			await _fotogrammi(8)
			await _scatto("arrivo_%s_%s" % [modo, v[0]])
			if ombra.x >= 0 and modo == "accovacciato" and v[0] == "sinistra":
				_chi_fa_ombra(ombra)
		print("TUBI: %s arrivo %s: occhi %s, piedi %s" % [tubo, modo, occhi.snapped(Vector3.ONE * 0.01), p.global_position.snapped(Vector3.ONE * 0.01)])
	Input.action_release(&"crouch")
	print("TUBI: finito")
	get_tree().quit()


## Chi fa l'ombra che si vede nel punto [param pt] dello schermo (vedi "ombra" nell'uso).
func _chi_fa_ombra(pt: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	var da := cam.project_ray_origin(pt)
	var q := PhysicsRayQueryParameters3D.create(da, da + cam.project_ray_normal(pt) * 60.0)
	q.exclude = [p.get_rid()]
	var h := get_tree().root.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		print("OMBRA: nessun muro nel punto %s" % pt)
		return
	var w: Vector3 = h.position + (h.normal as Vector3) * 0.03
	print("OMBRA: punto %s sul muro %s (%s), normale %s" % [w.snapped(Vector3.ONE * 0.01), h.collider.get_path() if h.collider else "?", (w - cam.global_position).length(), (h.normal as Vector3).snapped(Vector3.ONE * 0.01)])
	var geo := get_tree().root.find_children("*", "GeometryInstance3D", true, false).filter(func(g): return g.is_visible_in_tree() \
			and (g as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		var luce := l as Light3D
		if not luce.is_visible_in_tree() or not luce.shadow_enabled or luce.light_energy <= 0.0:
			continue
		var lp := luce.global_position
		if luce is OmniLight3D and lp.distance_to(w) > (luce as OmniLight3D).omni_range:
			continue
		if luce is SpotLight3D and lp.distance_to(w) > (luce as SpotLight3D).spot_range:
			continue
		if luce is DirectionalLight3D:
			lp = w + luce.global_basis.z * 200.0
		var fra := []
		for g in geo:
			var gi := g as GeometryInstance3D
			if gi.layers & luce.light_cull_mask == 0:
				continue
			var bb := gi.global_transform * gi.get_aabb()
			if bb.grow(0.02).intersects_segment(w, lp):
				fra.append([bb.get_volume(), str(gi.get_path()), bb.get_center().snapped(Vector3.ONE * 0.01), bb.size.snapped(Vector3.ONE * 0.01)])
		fra.sort_custom(func(x, y): return x[0] < y[0])
		print("OMBRA: luce %s %s, colore %s, energia %.2f, a %.1f m: fra muro e luce %d oggetti con ombra" % [luce.get_class(), luce.get_path(),
				luce.light_color, luce.light_energy, lp.distance_to(w), fra.size()])
		for f in fra.slice(0, 8):
			print("OMBRA:    %s centro %s misure %s" % [f[1], f[2], f[3]])

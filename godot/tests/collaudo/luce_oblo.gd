extends Node
## Collaudo: la luce rosa di lei dietro gli oblò (LeiOblo) non deve passare nei muri delle stanze vicine. Per ogni oblò
## della Risalita (la Risalita da sola, al buio, come scatti_oblo_lei.gd) o della torre: lei compare, si prendono i punti
## dove si cammina (pavimento a raggi) entro la portata della sua luce da cui la luce NON si vede (un muro in mezzo,
## sulla collisione); da ognuno, alla quota degli occhi e guardando verso la luce, uno scatto con lei e uno con la luce
## spenta: dove la differenza è rosa, la luce passa il muro. Stampa per punto lo scarto rosa e salva gli scatti peggiori.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --script res://tests/run.gd -- res://tests/collaudo/luce_oblo.gd <cartella> [risalita|torre]

const PLAYER := "res://scenes/player/player.tscn"

var cartella := "user://luce_oblo"
var cam: Camera3D


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred(a[2] if a.size() > 2 else "risalita")


func _run(dove: String) -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var scena := "res://scenes/risalita/risalita.tscn" if dove == "risalita" else "res://scenes/sala/torre/sala_torre.tscn"
	var radice := (load(scena) as PackedScene).instantiate() as Node3D
	add_child(radice)
	cam = Camera3D.new()
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	for i in 30:
		await get_tree().physics_frame
	var spazio := get_viewport().world_3d.direct_space_state
	for o in radice.find_children("*", "ObloLei", true, false):
		var ob := o as ObloLei
		ob.set_process(false)
		ob._mostra()
		for i in 20:
			await get_tree().process_frame
		var luci := ob.find_children("*", "OmniLight3D", true, false)
		if luci.is_empty():
			print("LUCE: %s senza luce" % ob.name)
			continue
		var luce := luci[0] as OmniLight3D
		var lp := luce.global_position
		var portata := luce.omni_range
		var punti: Array[Vector3] = []
		var passo := 1.0
		var n := int(portata / passo)
		for ix in range(-n, n + 1):
			for iz in range(-n, n + 1):
				var q := Vector3(lp.x + ix * passo, lp.y + 6.0, lp.z + iz * passo)
				if Vector2(q.x - lp.x, q.z - lp.z).length() > portata:
					continue
				# i pavimenti sotto (fino a 3 piani)
				var y := q.y
				for k in 3:
					var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y, q.z), Vector3(q.x, lp.y - 8.0, q.z), Layers.WORLD))
					if h.is_empty():
						break
					var piede: Vector3 = h["position"]
					y = piede.y - 0.3
					if (h["normal"] as Vector3).y < 0.7:
						continue
					var occhio := piede + Vector3.UP * 1.6
					if occhio.distance_to(lp) > portata:
						continue
					# c'è spazio per stare in piedi (niente sopra la testa)
					if not spazio.intersect_ray(PhysicsRayQueryParameters3D.create(piede + Vector3.UP * 0.1, occhio, Layers.WORLD)).is_empty():
						continue
					# la luce da qui non si vede: un muro in mezzo
					if spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio, lp, Layers.WORLD)).is_empty():
						continue
					# e nemmeno il vetro (dal corridoio dell'oblò la luce si vede dal vetro: è giusto)
					var cv := ob.centro_vetro() + ob.normale() * 0.08
					if (occhio - cv).dot(ob.normale()) > 0.0 \
							and spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhio, cv, Layers.WORLD)).is_empty():
						continue
					punti.append(occhio)
		print("LUCE: %s, luce in %s, portata %.1f, %d punti dietro i muri" % [ob.name, lp.snapped(Vector3.ONE * 0.01), portata, punti.size()])
		# (su llvmpipe ogni scatto è lento: al più 8 punti, i più vicini alla luce, sparsi di almeno 1,5 m)
		punti.sort_custom(func(x, y): return x.distance_to(lp) < y.distance_to(lp))
		var scelti: Array[Vector3] = []
		for q in punti:
			var lontano := true
			for e in scelti:
				if e.distance_to(q) < 1.5:
					lontano = false
					break
			if lontano:
				scelti.append(q)
			if scelti.size() >= 8:
				break
		punti = scelti
		var risultati := []
		for occhio in punti:
			cam.global_position = occhio
			var verso := lp - occhio
			verso.y = clampf(verso.y, -2.0, 2.0)
			cam.look_at(occhio + verso, Vector3.UP)
			luce.visible = true
			var con := await _scatto()
			luce.visible = false
			var senza := await _scatto()
			luce.visible = true
			var r := _rosa(con, senza)
			risultati.append([r[0], r[1], occhio, con, senza])
		risultati.sort_custom(func(x, y): return x[0] > y[0])
		var k2 := 0
		for e in risultati:
			print("LUCE:   %s da %s: rosa medio %.4f, massimo %.3f" % [ob.name, (e[2] as Vector3).snapped(Vector3.ONE * 0.01), e[0], e[1]])
			if k2 < 4 and float(e[1]) > 0.04:
				(e[3] as Image).save_jpg(cartella.path_join("%s_%d_con.jpg" % [ob.name, k2]), 0.85)
				(e[4] as Image).save_jpg(cartella.path_join("%s_%d_senza.jpg" % [ob.name, k2]), 0.85)
				k2 += 1
		ob.via()
	print("LUCE: finito")
	get_tree().quit()


func _scatto() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Quanto è più rosa l'immagine con la luce rispetto a quella senza: [media, massimo] di (rosso + blu) / 2 - verde in più.
func _rosa(a: Image, b: Image) -> Array:
	var s := 0.0
	var m := 0.0
	var n := 0
	for y in range(0, a.get_height(), 6):
		for x in range(0, a.get_width(), 6):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxf(0.0, ((ca.r - cb.r) + (ca.b - cb.b)) * 0.5 - maxf(0.0, ca.g - cb.g))
			s += d
			m = maxf(m, d)
			n += 1
	return [s / maxf(n, 1), m]

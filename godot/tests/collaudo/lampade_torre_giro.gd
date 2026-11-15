extends Node
## Collaudo 0.3.23 (giro corto della torre su f2f810a2): le 7 lampade d'emergenza rosse della torre nelle strade vere,
## dal portone, F9 torre, la morte nella torre e Continua dal titolo. Per ogni strada: quando la torre c'è, dove stanno le
## lampade (LT:), quanto distano dal muro e se qualcosa sta dentro la scatola (la stessa misura di
## test_lampade_torre_strade), i fotogrammi sopra 50 e 100 ms dall'arrivo (o dall'enigma) a 3 s dopo la torre pronta, e
## con Vulkan due scatti per lampada (di fronte a 1,6 m e radente lungo il muro a 0,6 m) più la vista dagli occhi.
## Uso: [STRADE=portone | STRADE=f9,morte,continua] godot ... --script res://tests/run.gd -- res://tests/collaudo/lampade_torre_giro.gd <cartella>

const LEVEL := "res://scenes/sala_principale.tscn"
const TITOLO := "res://scenes/ui/menu_principale.tscn"

var cart := ""
var scatti := false
var _misura_on := false
var _ultimo := 0
var _lunghi: Array = []
var _n := 0
var _max := 0.0
var _t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	if _misura_on and _ultimo > 0:
		var ms := (t - _ultimo) / 1000.0
		_n += 1
		_max = maxf(_max, ms)
		if ms > 50.0:
			_lunghi.append("%.0f ms (n %d, %.2f s)" % [ms, _n, (t - _t0) / 1000000.0])
	_ultimo = t


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _misura_via() -> void:
	_lunghi = []
	_n = 0
	_max = 0.0
	_ultimo = 0
	_t0 = Time.get_ticks_usec()
	_misura_on = true


func _misura_stop(nome: String) -> void:
	_misura_on = false
	var sopra100 := _lunghi.filter(func(x): return float(String(x).split(" ")[0]) > 100.0)
	print("LT: %s: fotogrammi %d, il più lungo %.1f ms, sopra 50 ms %d %s, sopra 100 ms %d" % [nome, _n, _max, _lunghi.size(), _lunghi, sopra100.size()])


func _arrivati(entro_s: float, vecchio_id: int = 0) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		var p := GameState.player
		if sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" and p and is_instance_valid(p) \
				and p.get_instance_id() != vecchio_id and p.is_inside_tree() and not GameState.is_dying:
			return true
		await get_tree().process_frame
	return false


func _torre(secondi: float) -> Node3D:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secondi * 1000.0:
		var sala := get_tree().current_scene
		var t: Node3D = sala.get(&"sala_torre") if sala else null
		if t and is_instance_valid(t) and bool(t.get(&"costruita")) and t.is_visible_in_tree():
			print("LT: torre pronta dopo %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
			return t
		await get_tree().process_frame
	return null


static func _lampade(torre: Node3D) -> Array:
	var out: Array = []
	var luci := torre.get_node_or_null(^"Luci")
	for c in (luci.get_children() if luci else []):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			out.append(c)
	return out


## [distanza del retro dal muro (m), quante volte qualcosa sta dentro la scatola, verso del muro] (come il test).
static func _misura(corpo: MeshInstance3D) -> Array:
	var bx := (corpo.mesh as BoxMesh).size
	var v := Vector3.RIGHT if bx.x < bx.z else Vector3.BACK
	v = (corpo.global_basis * v).normalized()
	var p := corpo.global_position
	var a1 := v.cross(Vector3.UP).normalized()
	var a2 := v.cross(a1).normalized()
	var spessore := minf(bx.x, bx.z)
	var vicine := Posa.mesh_vicine(corpo, AABB(p, Vector3.ZERO).grow(1.2))
	var dietro_meno := INF
	var dietro_piu := INF
	for verso in [v, -v]:
		var gap := INF
		for i in [-1, 0, 1]:
			for j in [-1, 0, 1]:
				var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
				var h := Posa._raggio_mesh(corpo, p + o + verso * 0.05, p + o - verso * 0.6, vicine)
				if not h.is_empty():
					gap = minf(gap, ((p + o - verso * (spessore * 0.5)) - (h.position as Vector3)).dot(verso))
		if verso == v:
			dietro_piu = gap
		else:
			dietro_meno = gap
	var gap: float = minf(dietro_piu, dietro_meno)
	var dir: Vector3 = v if dietro_piu <= dietro_meno else -v
	var dentro := 0
	var mezzo := bx * 0.5 - Vector3.ONE * 0.001
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			var o: Vector3 = a1 * (i * 0.13) + a2 * (j * 0.13)
			var lungo := spessore * 0.5 - 0.001
			if not Posa._raggio_mesh(corpo, p + o + dir * lungo, p + o - dir * lungo, vicine).is_empty():
				dentro += 1
			var o2: Vector3 = a1 * (i * 0.13) + dir * (j * (spessore * 0.5 - 0.002))
			if not Posa._raggio_mesh(corpo, p + o2 + Vector3.UP * mezzo.y, p + o2 - Vector3.UP * mezzo.y, vicine).is_empty():
				dentro += 1
	# dir: dal centro della lampada verso il muro
	return [gap, dentro, -dir]


func _scatto(nome: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


func _strada(nome: String, torre: Node3D) -> void:
	var lamp := _lampade(torre)
	print("LT: %s: lampade %d" % [nome, lamp.size()])
	var ins: Node = torre.get(&"inseguimento")
	if ins:
		print("LT: %s: passi lunghi dell'inseguimento %s" % [nome, ins.get(&"passi_lunghi")])
	print("LT: %s: fotogramma più carico della costruzione a pezzi %.1f ms" % [nome, float(torre.get(&"fotogramma_piu_carico_ms"))])
	var dati: Array = []
	for k in lamp.size():
		var m := _misura(lamp[k])
		dati.append(m)
		print("LT: %s lampada %d in %s: dal muro %.1f mm, dentro %d, muro verso %s" % [nome, k,
				(lamp[k] as Node3D).global_position.snappedf(0.0001), m[0] * 1000.0, m[1], (m[2] as Vector3).snappedf(0.01)])
	if not scatti:
		return
	await _scatto(nome + "_occhi")
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.02
	get_tree().current_scene.add_child(cam)
	cam.make_current()
	for k in lamp.size():
		var p := (lamp[k] as Node3D).global_position
		var muro: Vector3 = dati[k][2]
		var lungo := muro.cross(Vector3.UP).normalized()
		cam.global_position = p - muro * 1.6 + Vector3.DOWN * 0.3
		cam.look_at(p, Vector3.UP)
		await _scatto("%s_L%d_fronte" % [nome, k])
		cam.global_position = p - muro * 0.3 + lungo * 0.6
		cam.look_at(p, Vector3.UP)
		await _scatto("%s_L%d_radente" % [nome, k])
		cam.global_position = p - muro * 0.3 - lungo * 0.6 + Vector3.DOWN * 0.15
		cam.look_at(p, Vector3.UP)
		await _scatto("%s_L%d_radente2" % [nome, k])
	cam.queue_free()
	if GameState.player:
		for cc in GameState.player.find_children("*", "Camera3D", true, false):
			(cc as Camera3D).make_current()
			break
	await _frames(3)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	DirAccess.make_dir_recursive_absolute(cart)
	scatti = DisplayServer.get_name() != "headless"
	var strade := OS.get_environment("STRADE")
	if strade == "":
		strade = "portone,f9,morte,continua"
	Game.pause_on_focus_loss = false
	for s in strade.split(","):
		match s:
			"portone":
				GameState.reset_progress()
				get_tree().change_scene_to_file(LEVEL)
				print("LT: portone: sala arrivata %s" % await _arrivati(900.0))
				await _frames(30)
				var level := get_tree().current_scene
				_misura_via()
				var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
				if enigma:
					enigma.emit_signal(&"comparso")
				await get_tree().process_frame
				(level.get(&"portone") as PortoneTorre).apri_quando_pronta()
				var t := await _torre(300.0)
				await _frames(3)
				var t0 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t0 < 3000:
					await get_tree().process_frame
				_misura_stop("portone (dall'enigma a 3 s dopo la torre)")
				if t:
					await _strada("portone", t)
				else:
					print("LT: portone: la torre non c'è")
			"f9", "morte", "continua":
				var vecchio_id := GameState.player.get_instance_id() if GameState.player and is_instance_valid(GameState.player) else 0
				if s == "f9":
					if get_tree().current_scene == null or String(get_tree().current_scene.name) != "MenuPrincipale":
						get_tree().change_scene_to_file(TITOLO)
						await _frames(60)
					print("LT: F9 torre: %s" % MenuProva.parti(get_tree(), "torre"))
				elif s == "morte":
					GameState.kill_player(&"prova")
				else:
					Game.return_to_title()
					var fino := Time.get_ticks_msec() + 300000
					while Time.get_ticks_msec() < fino and not (get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale"):
						await _frames(5)
					await _frames(60)
					print("LT: continua: salvataggio %s" % GameState.has_save())
					get_tree().current_scene.call(&"continua")
				var arr := await _arrivati(900.0, vecchio_id)
				print("LT: %s: arrivato %s, giocatore a %s" % [s, arr, GameState.player.global_position.snappedf(0.01) if GameState.player else null])
				_misura_via()
				var t := await _torre(300.0)
				var t0 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t0 < 3000:
					await get_tree().process_frame
				_misura_stop("%s (dall'arrivo a 3 s dopo la torre)" % s)
				if t:
					await _strada(s, t)
				else:
					print("LT: %s: la torre non c'è" % s)
	print("LT: RSS finale %d MB" % (OS.get_static_memory_usage() / 1048576))
	print("LT: finito")
	get_tree().quit()

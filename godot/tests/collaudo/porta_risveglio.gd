extends Node
## Collaudo 0.3.25 (perno della porta tagliafuoco del risveglio liberato, 8921e9e3): la porta tagliafuoco nella scena
## dello squalo. Strade: "nuova" (la sala con una partita nuova, come dopo la schermata di caricamento di Nuova partita),
## "inizio" (dal titolo, F9 Inizio: _avvia_nuova_partita, lo spot saltato), "interni" (gli interni da soli come
## giro_squalo, col renderer vero: alla fine scatti ravvicinati del cardine). Ogni 0,5 s di scena (PR:): il perno
## (PernoPortaTagliafuoco) nell'albero, la porta figlia del perno, la rotazione del perno, la porta chiusa; alla fine
## la posizione del perno contro il cardine, la collisione della porta e gli errori del log.
## Uso: godot ... --script res://tests/run.gd -- res://tests/collaudo/porta_risveglio.gd <nuova|inizio|interni> [cartella]

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const LEVEL := "res://scenes/sala_principale.tscn"
const INTERNI := "res://scenes/interni/interni.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const INTERNI_NELLA_SALA := Transform3D(Basis.IDENTITY, Vector3(-9.7, 0.0, 40.9))

var cart := ""


class Errori extends Logger:
	var errori: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, _code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errori.append("%s:%d %s" % [file.get_file(), line, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _errori := Errori.new()


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(cam: Camera3D, nome: String, da: Vector3, verso: Vector3) -> void:
	cam.global_position = da
	cam.look_at(verso, Vector3.UP)
	await _frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


func _monta_interni() -> void:
	var radice := Node3D.new()
	radice.name = "SalaSoloInterni"
	var look := LookSala.new()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	radice.add_child(we)
	var interni := (load(INTERNI) as PackedScene).instantiate() as Node3D
	interni.name = "Interni"
	interni.set(&"giocatore_proprio", false)
	interni.transform = INTERNI_NELLA_SALA
	radice.add_child(interni)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	p.name = "Player"
	p.transform = INTERNI_NELLA_SALA * (interni.get_node(^"Gioco/Risveglio") as Node3D).transform
	radice.add_child(p)
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	if p.water_pack:
		p.water_pack.set_tank_amount(10.0)
		p.water_pack.set_equipped(false, false)
	interni.call(&"fai_risveglio", p)


func _run() -> void:
	OS.add_logger(_errori)
	var a := OS.get_cmdline_user_args()
	var strada := a[1] if a.size() > 1 else "nuova"
	cart = a[2] if a.size() > 2 else "user://porta"
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	RisveglioSqualo.forza_nei_test = true
	match strada:
		"nuova":
			GameState.reset_progress()
			get_tree().change_scene_to_file(LEVEL)
		"inizio":
			get_tree().change_scene_to_file(TITOLO)
			await _frames(60)
			get_tree().current_scene.call(&"_avvia_nuova_partita")
			await _frames(60)
			for n in get_tree().root.get_children():
				if n is LettoreSpot:
					n.call(&"_fine")
		"interni":
			await _monta_interni()
	var s: RisveglioSqualo = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc:
			s = sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo
			if s:
				break
	if s == null:
		print("PR: %s: la scena dello squalo non c'è" % strada)
		get_tree().quit(1)
		return
	print("PR: %s: RisveglioSqualo trovato dopo %.1f s, in corso %s" % [strada, (Time.get_ticks_msec() - t0) / 1000.0, s.in_corso()])
	var prossimo := 0.0
	var t1 := Time.get_ticks_msec()
	var visto_in_corso := false
	while Time.get_ticks_msec() - t1 < 120000:
		await get_tree().process_frame
		if not is_instance_valid(s):
			break
		visto_in_corso = visto_in_corso or s.in_corso()
		var ts: float = s.get(&"_t")
		if ts >= prossimo or (visto_in_corso and not s.in_corso()):
			prossimo = ts + 0.5
			var perno := s.get(&"_perno") as Node3D
			var porta := s.porta
			print("PR: t %.2f s, in corso %s; perno %s nell'albero %s, porta figlia del perno %s, giro del perno %.1f°, porta chiusa %s" % [ts, s.in_corso(),
					perno != null, perno.is_inside_tree() if perno else false, porta != null and perno != null and porta.get_parent() == perno,
					rad_to_deg(perno.rotation.y) if perno else 0.0, s.get(&"_porta_chiusa")])
		if visto_in_corso and not s.in_corso():
			break
	var perno := s.get(&"_perno") as Node3D if is_instance_valid(s) else null
	if perno:
		var cardine: Vector3 = s.get(&"cardine")
		print("PR: fine: perno in %s (locale %s, cardine %s), collisione della porta %s, porta chiusa %s" % [perno.global_position.snappedf(0.001),
				perno.position.snappedf(0.001), cardine.snappedf(0.001), perno.find_child("Collisione", true, false) != null, s.get(&"_porta_chiusa")])
		if strada == "interni":
			var cam := Camera3D.new()
			cam.fov = 60.0
			cam.near = 0.02
			get_tree().root.add_child(cam)
			cam.make_current()
			var c := perno.global_position + Vector3.UP * 1.0
			var lamp := OmniLight3D.new()
			lamp.omni_range = 3.0
			lamp.light_energy = 0.8
			cam.add_child(lamp)
			for g in [0, 60, 120, 180, 240, 300]:
				var d := Vector3(sin(deg_to_rad(g)), 0, cos(deg_to_rad(g)))
				for h in [0.2, 1.0, 1.9]:
					await _scatto(cam, "cardine_%03d_h%.1f" % [g, h], perno.global_position + Vector3.UP * h + d * 0.7, perno.global_position + Vector3.UP * h)
			await _scatto(cam, "porta_intera", c + (perno.global_basis.z + perno.global_basis.x).normalized() * 2.5 + Vector3.UP * 0.4, c)
	print("PR: errori nel log: %d %s" % [_errori.errori.size(), _errori.errori.slice(0, 5)])
	print("PR: finito")
	get_tree().quit()

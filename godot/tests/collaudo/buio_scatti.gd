extends Node
## Collaudo 0.4.0, zona B, col renderer vero, nella sala ridotta (senza interni, tecnici, risalita): BS:.
## 1. il giro della luce: il giocatore dentro la sala, scatti ogni 1,5 s per un giro intero da tre camere (dagli occhi
##    accanto alla vasca grande verso l'area bimbi, dall'alto sull'area bimbi, radente sul pavimento fra le vasche);
## 2. per ogni punto d'uscita (letale spento): il giocatore sul bordo, lei che esce, e quando è su gli scatti dagli
##    occhi, dall'alto sulla vasca e da vicino a ogni giocattolo; poi torna sotto;
## 3. la fossa: il giocatore verso l'area bimbi, il giro che finisce, lei alla fossa dagli occhi.
## Il 3D si disegna solo prima degli scatti. Tempo a fotogrammi (--fixed-fps 60).
## Uso: xvfb-run ... --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/buio_scatti.gd <cartella> [parti: giro,punti,fossa]

const LEVEL := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Tecnici", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata",
		"Mascotte", "Atmosfera", "Sala/TorreScivoli", "Sala/Dettagli", "Vasca", "Piscina", "Sala/Piscina", "Sala/VascaCentrale",
		"Sala/Cupola", "Polaroid", "Gioco/EnigmaAcquari", "SalaSottomarino", "SalaTorre", "Sala/AngoloPalloni", "Scarabocchi"]
var cart := ""
var cam: Camera3D
var buio: LeiSalaAlBuio
var p: Player
var _disegna := false


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _process(_d: float) -> void:
	get_viewport().disable_3d = not _disegna


func _scatto(nome: String, da: Vector3, verso: Vector3, fov := 70.0) -> void:
	_disegna = true
	cam.fov = fov
	cam.global_position = da
	cam.look_at(verso, Vector3.UP if absf((verso - da).normalized().y) < 0.97 else Vector3.RIGHT)
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.88)
	_disegna = false


func _metti(pos: Vector3, verso: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 3.0, Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	p.teleport(h.position + Vector3.UP * 0.02 if not h.is_empty() else pos)
	var d := verso - (p.global_position + Vector3.UP * 1.6)
	p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _occhi() -> Vector3:
	return p.global_position + Vector3.UP * 1.6


func _luce() -> OmniLight3D:
	return buio.acqua.get(&"_luce") as OmniLight3D


func _giro() -> void:
	_metti(Vector3(-18.5, 0, 6.0), Vector3(-12.5, 0, -10))
	var f := 0
	while buio.stato != LeiSalaAlBuio.Stato.GIRO and f < 600:
		await _frames(1)
		f += 1
	print("BS: giro: stato %s dopo %d fotogrammi" % [LeiSalaAlBuio.Stato.keys()[buio.stato], f])
	cam.make_current()
	for k in 26:
		var l := _luce()
		var lp := l.global_position
		var tag := "%02d" % k
		print("BS: giro %s: luce in %s energia %.2f" % [tag, lp.snappedf(0.01), l.light_energy])
		await _scatto("giro_%s_occhi" % tag, Vector3(-18.5, 1.6, -1.0), Vector3(-12.0, 0.0, -11.0))
		await _scatto("giro_%s_alto" % tag, Vector3(-4.0, 5.0, -6.0), Vector3(-12.0, 0.0, -12.0))
		await _scatto("giro_%s_luce" % tag, lp + Vector3(2.5, 1.7, 2.5), lp, 80.0)
		# (l'ultimo si fa dove sta la luce, da 3,8 m)
		await _frames(84)


func _punti() -> void:
	buio.letale = false
	for k in 4:
		var q: Node3D = buio.acqua.punti_uscita[k]
		var v := buio.vasca_grande
		var m := v.inner_size * 0.5
		var loc: Vector3 = [Vector3(m.x + 0.45, 0, 0), Vector3(-m.x - 0.45, 0, 0), Vector3(0, 0, m.z + 0.45), Vector3(0, 0, -m.z - 0.45)][k]
		var bordo := v.to_global(loc)
		bordo.y = 0.0
		if buio.stato != LeiSalaAlBuio.Stato.GIRO:
			_metti(Vector3(-15.0, 0, 16.8), v.global_position)
			for i in 300:
				if buio.stato == LeiSalaAlBuio.Stato.GIRO:
					break
				await _frames(1)
		_metti(bordo, Vector3(q.global_position.x, -0.2, q.global_position.z))
		var f := 0
		while AcquaDiLei.Fase.keys()[buio.acqua.fase] != "SU" and f < 60 * 80:
			await _frames(1)
			f += 1
		print("BS: punto %d: fase %s dopo %.1f s (punto scelto %s)" % [k, AcquaDiLei.Fase.keys()[buio.acqua.fase], f / 60.0,
				buio.acqua.punti_uscita.find(buio.acqua.get(&"_punto"))])
		await _frames(20)
		var lei: Node3D = buio.acqua.get(&"_lei")
		var testa := lei.global_position + Vector3.UP * 2.5 if lei else q.global_position
		await _scatto("punto%d_occhi" % k, _occhi(), testa)
		await _scatto("punto%d_alto" % k, v.global_position + Vector3(0, 7.5, 0.01), v.global_position, 75.0)
		var di_lato := (bordo - q.global_position)
		di_lato.y = 0
		await _scatto("punto%d_lato" % k, q.global_position + di_lato.normalized().rotated(Vector3.UP, PI / 2) * 5.0 + Vector3.UP * 1.6, q.global_position + Vector3.UP * 0.8)
		var gr := buio.galleggianti_e_raggi()
		for g in gr:
			var gp := (g as Node3D).global_position
			var verso_q := q.global_position - gp
			verso_q.y = 0
			var da := gp - verso_q.normalized() * 1.3 + Vector3.UP * 0.9
			await _scatto("punto%d_gioc_%s" % [k, g.name], da, gp + verso_q.normalized() * 0.4, 65.0)
			await _scatto("punto%d_gioc_%s_lato" % [k, g.name], gp + verso_q.normalized().rotated(Vector3.UP, PI / 2) * 1.2 + Vector3.UP * 0.35, gp, 65.0)
		# torna sotto e il giocatore si allontana
		buio.acqua.respingi()
		_metti(Vector3(-18.5, 0, 9.0), v.global_position)
		for i in 60 * 6:
			await _frames(1)


func _fossa() -> void:
	var ls := buio.lei_sbuca
	var fp := ls.punto_sbuca.global_position
	if buio.stato != LeiSalaAlBuio.Stato.GIRO:
		_metti(Vector3(-15.0, 0, 16.8), buio.vasca_grande.global_position)
		for i in 300:
			if buio.stato == LeiSalaAlBuio.Stato.GIRO:
				break
			await _frames(1)
	_metti(Vector3(-18.5, 0, -1.5), fp + Vector3.UP)
	var f := 0
	while buio.stato != LeiSalaAlBuio.Stato.FINITO and f < 600:
		await _frames(1)
		f += 1
	print("BS: fossa: stato %s" % LeiSalaAlBuio.Stato.keys()[buio.stato])
	p.get_viewport().get_camera_3d()
	for k in 8:
		await _scatto("fossa_%02d_occhi" % k, _occhi(), fp + Vector3.UP * 1.0)
		print("BS: fossa %d: LeiSbuca %s, luce di lei %s" % [k, LeiSbuca.Fase.keys()[ls.fase], _luce().global_position.snappedf(0.01) if _luce() and _luce().visible else "spenta"])
		await _frames(25)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var parti := (a[2] if a.size() > 2 else "giro,punti,fossa").split(",")
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(OS.get_environment("PRESET") if OS.get_environment("PRESET") != "" else "medio")
	GameState.prepara_ripresa(MenuProva.istantanea("sala_buio"))
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI))
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene and not GameState.is_restoring():
			break
	await _frames(60)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p = GameState.player as Player
	buio = get_tree().current_scene.find_child("LeiSalaAlBuio", true, false) as LeiSalaAlBuio
	cam = Camera3D.new()
	cam.near = 0.03
	add_child(cam)
	print("BS: giocatore %s, luci %s, sala al buio %s" % [p.global_position.snappedf(0.01), GameState.luci, buio != null])
	for s in parti:
		match s:
			"giro":
				await _giro()
			"punti":
				cam.make_current()
				await _punti()
			"fossa":
				await _fossa()
	print("BS: finito")
	get_tree().quit()

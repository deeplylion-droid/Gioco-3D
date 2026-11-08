extends Node
## Collaudo finale della 0.3.22 (ambienti-2), parte 1: l'inizio del gioco dagli occhi del giocatore, con la cartella
## utente vuota (XDG_DATA_HOME su una cartella nuova: niente impostazioni, niente salvataggi, cache degli shader vuota).
## Il titolo vero (menu_principale.tscn, nessuna calibrazione al primo avvio), Nuova partita col mouse, lo spot VHS (pochi
## secondi, poi saltato tenendo premuto un tasto), la schermata di caricamento con Jilly; poi l'ingresso come lo fa
## Caricamento._entra (velo nero con «Preparazione della sala…», QualitaAutomatica.avvia se da_fare(), lo schermo che si
## schiarisce), ma con gli interni al posto della sala intera (che col renderer software non sta in memoria): gli interni
## nella loro posizione nella sala, l'ambiente della sala (LookSala), il giocatore al risveglio, come giro_squalo.gd.
## La scena dello squalo intera, poi i primi corridoi a piedi (tasto avanti e sguardo, come test_strada.gd: corridoio,
## spogliatoi, stanzino con lo zaino, lavapiedi, tornello e saracinesca con le scorciatoie, fin sotto la saracinesca).
## Scatti numerati in <cartella>; a ogni fotogramma una riga in dati.jsonl: tempo, fase, opacità del nero, tempo della
## scena dello squalo, controllo al giocatore, preset. Alla fine il confronto delle lampade degli interni (energia delle
## luci e fattore delle LuceEmergenza) fra l'ingresso e 5 s dopo la scena.
## Si lancia come scena (con --script il gioco è "automatico": niente squalo e niente prova della qualità):
##   XDG_DATA_HOME=<cartella vuota> xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##     --resolution 1280x720 res://tests/collaudo/giro_0322_inizio.tscn -- <cartella>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const INTERNI := "res://scenes/interni/interni.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const INTERNI_NELLA_SALA := Transform3D(Basis.IDENTITY, Vector3(-9.7, 0.0, 40.9))

var registratore := false
var cartella := "/tmp/giro_0322"
## "titolo": dal titolo alla schermata di caricamento piena, poi esce; "ingresso": dal nero dell'ingresso in poi.
var fase := "titolo"
var _reg: FileAccess
var _n := 0
var _t0 := 0
var _fase := "titolo"
var _interni: Node3D
var _squalo: RisveglioSqualo
var _p: Player
var _luci_prima := {}
var _vetri_prima := 0


func _ready() -> void:
	if registratore:
		_run.call_deferred()
		return
	var a := OS.get_cmdline_user_args()
	var r := Node.new()
	r.set_script(get_script())
	r.name = "Giro0322"
	r.set(&"registratore", true)
	if a.size() > 0:
		r.set(&"cartella", a[0])
	if a.size() > 1:
		r.set(&"fase", a[1])
	get_tree().root.add_child.call_deferred(r)
	if a.size() < 2 or a[1] != "ingresso":
		get_tree().change_scene_to_file.call_deferred(TITOLO)


func _ora() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _scatto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var f := "%03d_%s" % [_n, nome]
	_n += 1
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(f + ".jpg"), 0.88)
	print("SCATTO %s a %.2f s" % [f, _ora()])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		_riga()


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().process_frame
		_riga()


func _riga() -> void:
	if _reg == null:
		return
	var d := {"t": snappedf(_ora(), 0.001), "fase": _fase, "preset": str(Grafica.valore("preset"))}
	if Dissolvenza.presente(get_tree()):
		d["nero"] = snappedf(Dissolvenza.di(get_tree()).opacita(), 0.001)
	if is_instance_valid(_squalo):
		d["squalo_t"] = snappedf(float(_squalo.get(&"_t")), 0.001)
		d["squalo_attivo"] = _squalo.in_corso()
	if is_instance_valid(_p):
		d["controllo"] = _p.input_enabled
		d["pos"] = [snappedf(_p.global_position.x, 0.01), snappedf(_p.global_position.y, 0.01), snappedf(_p.global_position.z, 0.01)]
	d["qualita"] = get_tree().root.has_node(^"QualitaAutomatica")
	_reg.store_line(JSON.stringify(d))


func _cerca(radice: Node, classe: String, testo: String) -> Node:
	for n in radice.find_children("*", classe, true, false):
		if testo == "" or (n.get(&"text") != null and String(n.get(&"text")).contains(testo)):
			return n
	return null


func _run() -> void:
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(cartella)
	_reg = FileAccess.open(cartella.path_join("dati.jsonl"), FileAccess.WRITE)
	print("GIRO0322: cartella utente %s, salvataggio %s, qualità da fare %s, preset %s" % [OS.get_user_data_dir(),
			GameState.has_save(), QualitaAutomatica.da_fare(), Grafica.valore("preset")])
	if fase == "ingresso":
		await _ingresso()
		return
	# 1. il titolo: finché si è schiarito (con la cache degli shader vuota i primi fotogrammi sono lenti)
	await _secondi(2.0)
	var t_tit := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_tit < 300000 and (not Dissolvenza.presente(get_tree()) or Dissolvenza.di(get_tree()).opacita() > 0.02):
		await _frames(1)
	print("GIRO0322: titolo chiaro a %.2f s" % _ora())
	await _secondi(1.0)
	var titolo := get_tree().current_scene
	print("GIRO0322: titolo %s; calibrazione a schermo: %s" % [titolo.name if titolo else "nessuno",
			get_tree().root.find_child("*alibra*", true, false) != null])
	await _scatto("titolo")
	await _secondi(2.0)
	await _scatto("titolo_dopo_6s")
	var voce := titolo.find_child("NuovaPartita", true, false) as Button
	if voce == null:
		print("GIRO0322: KO la voce Nuova partita non c'è")
		get_tree().quit(1)
		return
	# il clic del mouse sulla voce, come il giocatore
	var c := voce.get_global_rect().get_center()
	for premuto in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = premuto
		ev.position = c
		ev.global_position = c
		Input.parse_input_event(ev)
		await _frames(2)
	_fase = "spot"
	await _secondi(1.5)
	await _scatto("dopo_nuova_partita")
	# 2. lo spot: qualche secondo, poi tenuto premuto un tasto per saltarlo
	var spot: Node = null
	for i in 300:
		spot = get_tree().root.find_child("*Spot*", true, false)
		if spot:
			break
		await _frames(1)
	print("GIRO0322: spot VHS %s" % ("partito" if spot else "NON partito"))
	await _secondi(3.0)
	await _scatto("spot")
	var tasto := InputEventKey.new()
	tasto.keycode = KEY_SPACE
	tasto.physical_keycode = KEY_SPACE
	tasto.pressed = true
	Input.parse_input_event(tasto)
	await _secondi(0.6)
	await _scatto("spot_tenuto")
	await _secondi(1.0)
	var su := tasto.duplicate() as InputEventKey
	su.pressed = false
	Input.parse_input_event(su)
	# 3. la schermata di caricamento con Jilly (si tiene lì finché la sala è caricata nel thread e ci sono gli scatti)
	var car: Node = null
	var t_spot := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_spot < 600000:
		var sc := get_tree().current_scene
		if sc and sc.get_script() and String((sc.get_script() as Script).resource_path).ends_with("caricamento.gd"):
			car = sc
			break
		await _frames(1)
	if car == null:
		print("GIRO0322: KO la schermata di caricamento non è arrivata")
		get_tree().quit(1)
		return
	_fase = "caricamento"
	if fase == "reale":
		await _reale()
		return
	car.set(&"tempo_minimo", 1.0e9)
	print("GIRO0322: caricamento a %.2f s, video di Jilly %s" % [_ora(), car.get(&"_video") != null])
	for s in [1.0, 1.5, 2.0]:
		await _secondi(s)
		await _scatto("caricamento_%.1fs" % _ora())
	var t_car := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_car < 600000 and float(car.get(&"avanzamento")) < 0.99:
		await _frames(10)
	print("GIRO0322: barra al %d%% a %.2f s" % [roundi(float(car.get(&"avanzamento")) * 100.0), _ora()])
	await _scatto("caricamento_pieno")
	# (la sala caricata e gli interni insieme non stanno nella memoria della macchina: l'ingresso in un altro processo)
	var velo0 := Dissolvenza.di(get_tree())
	await velo0.scurisci(0.7, "Preparazione della sala…")
	await _scatto("preparazione")
	print("GIRO0322: FINE della parte titolo a %.2f s" % _ora())
	_reg.close()
	get_tree().quit()


## 4. L'ingresso come Caricamento._entra (lo schermo nero con «Preparazione della sala…»), con gli interni al posto
## della sala; la prova della qualità se va fatta, poi la scena dello squalo e i corridoi.
func _ingresso() -> void:
	_fase = "ingresso"
	var albero := get_tree()
	var velo := Dissolvenza.di(albero)
	velo.nero("Preparazione della sala…")
	await _frames(2)
	Game.capture_mouse()
	var prova := QualitaAutomatica.da_fare()
	var vecchia := get_tree().current_scene
	_monta_interni()
	if vecchia and vecchia != get_tree().current_scene:
		vecchia.queue_free()
	if prova:
		QualitaAutomatica.avvia(albero, 8)
	else:
		velo.schiarisci(1.6, 8)
	print("GIRO0322: ingresso a %.2f s, prova della qualità %s" % [_ora(), "partita" if prova else "NON partita (già fatta)"])
	await _squalo_e_corridoi(velo, prova)


## Senza schermo (la sala intera ci sta): il caricamento entra da sé nella sala vera (Caricamento._entra, con la prova
## della qualità se va fatta), poi la scena dello squalo e i corridoi come nell'ingresso. Le misure del renderer finto
## valgono per i tempi (il fotogramma è veloce come su una scheda vera), non per le immagini.
func _reale() -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 900000:
		await _frames(1)
		var sc := get_tree().current_scene
		if sc and sc.scene_file_path.ends_with("sala_principale.tscn"):
			_squalo = sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo
			if _squalo:
				_interni = sc.get_node(^"Interni") as Node3D
				break
	if _squalo == null:
		print("GIRO0322: KO la sala non è arrivata")
		get_tree().quit(1)
		return
	_p = GameState.player
	var prova := get_tree().root.has_node(^"QualitaAutomatica")
	print("GIRO0322: sala vera a %.2f s, scena dello squalo %s, prova della qualità %s" % [_ora(),
			"in corso" if _squalo.in_corso() else "NON partita", "in corso" if prova else "no"])
	for l in _interni.find_children("*", "Light3D", true, false):
		_luci_prima[_interni.get_path_to(l)] = [(l as Light3D).light_energy, (l as Light3D).is_visible_in_tree()]
	await _squalo_e_corridoi(Dissolvenza.di(get_tree()), prova)


func _squalo_e_corridoi(velo: Dissolvenza, prova: bool) -> void:
	# 5. la scena dello squalo: uno scatto ogni 0,4 s finché il nero non è andato, poi negli istanti della scena
	_fase = "squalo"
	var istanti: Array = []
	var tempi: Dictionary = _squalo.tempi
	for l in tempi.get("lampi", []):
		istanti.append_array([float(l[0]) + 0.05, float(l[0]) + 0.12])
	istanti.append_array([float(tempi.get("luce", 2.4)) + 0.4])
	for f in tempi.get("fiuti", []):
		istanti.append(float(f) + 0.15)
	istanti.append_array([float(tempi.get("goccia", 4.4)) + 0.3, float(tempi.get("apre", 5.0)) + 0.2])
	for m in tempi.get("morsi", []):
		istanti.append(float(m[0]) + 0.1)
	istanti.append_array([float(tempi.get("richiamo", 8.4)) + 0.4, float(tempi.get("esita", 12.7)), float(tempi.get("porta", 13.9)) + 0.6])
	istanti.sort()
	var t_nero := -1.0
	var t_schiarito := -1.0
	var t_prova_fine := -1.0
	var t_controllo := -1.0
	var prossimo_passo := 0.0
	# l'attesa dello schermo chiaro (eda4fc21): quanti fotogrammi, i suoni che suonano nella scena e negli interni, se la
	# camera e la testa dello squalo si muovono
	var n_attesa := 0
	var suoni_attesa := {}
	var cam0 = null
	var cam_mossa := 0.0
	var testa0 = null
	var testa_mossa := 0.0
	var attesa_finita := false
	var lampo_visto := false
	var primo_lampo: float = float((tempi.get("lampi", [[0.55, 0.16]]) as Array)[0][0])
	var t_in := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_in < 3600000:
		await get_tree().process_frame
		_riga()
		var ts := float(_squalo.get(&"_t"))
		var nero := Dissolvenza.di(get_tree()).opacita() if Dissolvenza.presente(get_tree()) else 0.0
		var attesa: bool = _squalo.has_method(&"in_attesa") and bool(_squalo.call(&"in_attesa"))
		if attesa:
			n_attesa += 1
			for a in _interni.find_children("*", "", true, false):
				if (a is AudioStreamPlayer or a is AudioStreamPlayer3D) and a.get(&"playing"):
					suoni_attesa[str(_interni.get_path_to(a))] = true
			var cam := get_viewport().get_camera_3d()
			if cam:
				if cam0 == null:
					cam0 = cam.global_transform
				cam_mossa = maxf(cam_mossa, (cam.global_transform.origin - (cam0 as Transform3D).origin).length()
						+ (cam.global_transform.basis.z - (cam0 as Transform3D).basis.z).length())
			var sk := _squalo.get(&"_scheletro") as Skeleton3D
			var ossa: Dictionary = _squalo.get(&"_ossa")
			if sk and int(ossa.get("testa", -1)) >= 0:
				var o := sk.to_global(sk.get_bone_global_pose(int(ossa["testa"])).origin)
				if testa0 == null:
					testa0 = o
				testa_mossa = maxf(testa_mossa, (o - (testa0 as Vector3)).length())
		elif not attesa_finita and _squalo.in_corso():
			attesa_finita = true
			print("GIRO0322: ATTESA dello schermo chiaro: %d fotogrammi, finita a %.2f s (nero %.3f, prova della qualità %s); suoni che suonavano: %s; camera mossa %.4f; testa dello squalo mossa %.4f m" % [
					n_attesa, _ora(), nero, get_tree().root.has_node(^"QualitaAutomatica"), str(suoni_attesa.keys()), cam_mossa, testa_mossa])
		if not lampo_visto and ts >= primo_lampo + 0.05:
			lampo_visto = true
			print("GIRO0322: PRIMO LAMPO a %.2f s della scena: nero %.3f, prova della qualità %s" % [ts, nero, get_tree().root.has_node(^"QualitaAutomatica")])
		if t_prova_fine < 0.0 and prova and not get_tree().root.has_node(^"QualitaAutomatica"):
			t_prova_fine = ts
			print("GIRO0322: prova della qualità finita a %.2f s della scena, preset %s" % [ts, Grafica.valore("preset")])
		if t_nero < 0.0 and nero < 0.98:
			t_nero = ts
			print("GIRO0322: il nero comincia a schiarirsi a %.2f s della scena" % ts)
		if t_schiarito < 0.0 and nero < 0.02:
			t_schiarito = ts
			print("GIRO0322: schermo chiaro a %.2f s della scena" % ts)
		if _squalo.in_corso() and ts < 3.0 and ts >= prossimo_passo:
			await _scatto("squalo_%05.2fs_nero%.2f" % [ts, nero])
			prossimo_passo += 0.4
		elif _squalo.in_corso() and not istanti.is_empty() and ts >= float(istanti[0]):
			await _scatto("squalo_%05.2fs" % ts)
			while not istanti.is_empty() and float(istanti[0]) <= ts:
				istanti.pop_front()
		if t_controllo < 0.0 and _p.input_enabled and not _squalo.in_corso():
			t_controllo = _ora()
			print("GIRO0322: controllo al giocatore a %.2f s della scena" % ts)
			break
	await _secondi(5.0)
	await _scatto("dopo_squalo_5s")
	await _confronta_luci()
	# 6. i primi corridoi a piedi
	_fase = "corridoi"
	await _vai("dal corridoio del risveglio agli spogliatoi", [Vector3(4.3, 0, 39.6), Vector3(-2.9, 0, 39.6), Vector3(-2.9, 0, 37.0)])
	await _vai("dagli spogliatoi dentro lo stanzino", [Vector3(-1.5, 0, 34.0), Vector3(-1.0, 0, 32.45), Vector3(2.5, 0, 32.45), Vector3(3.6, 0, 32.47)])
	var zaini := _interni.find_children("*", "PackPickup", true, false)
	if not zaini.is_empty():
		_p.look_at_point((zaini[0] as Node3D).global_position + Vector3(0, 0.35, 0))
		await _frames(3)
		await _scatto("zaino")
		Input.action_press(&"interact")
		await _frames(2)
		Input.action_release(&"interact")
		await _frames(10)
	print("GIRO0322: zaino preso %s" % (_p.water_pack != null and _p.water_pack.equipped))
	await _vai("dallo stanzino al lavapiedi, fino al tornello", [Vector3(2.5, 0, 32.45), Vector3(-1.0, 0, 32.45),
		Vector3(-0.45, 0, 31.2), Vector3(-0.45, 0, 28.5), Vector3(0, 0, 26.6)])
	print("GIRO0322: (scorciatoia: tornello sbloccato e saracinesca aperta, come test_strada)")
	_interni.call(&"_sblocca_tornello")
	await _vai("il tornello", [Vector3(0, 0, 25.0), Vector3(0, 0, 22.9)])
	var saracinesca := _interni.find_child("Saracinesca", true, false)
	if saracinesca:
		saracinesca.call(&"load_state", {"latched": true, "open": 1.0})
	await _frames(10)
	await _vai("fin sotto la saracinesca, davanti alla sala", [Vector3(0, 0, 20.6)])
	_p.set_look(PI, 0.0)
	await _frames(5)
	await _scatto("fine_corridoi_indietro")
	_p.set_look(0.0, 0.0)
	await _frames(5)
	await _scatto("fine_corridoi_verso_sala")
	print("GIRO0322: FINE a %.2f s" % _ora())
	_reg.close()
	get_tree().quit()


## Gli interni con l'ambiente della sala e il giocatore al risveglio (come nel _ready della sala).
func _monta_interni() -> void:
	var radice := Node3D.new()
	radice.name = "SalaSoloInterni"
	var look := LookSala.new()
	var we := WorldEnvironment.new()
	we.environment = look.ambiente
	we.camera_attributes = look.attributi_camera
	look.free()
	radice.add_child(we)
	_interni = (load(INTERNI) as PackedScene).instantiate() as Node3D
	_interni.name = "Interni"
	_interni.set(&"giocatore_proprio", false)
	_interni.transform = INTERNI_NELLA_SALA
	radice.add_child(_interni)
	_p = (load(PLAYER) as PackedScene).instantiate() as Player
	_p.name = "Player"
	_p.transform = INTERNI_NELLA_SALA * (_interni.get_node(^"Gioco/Risveglio") as Node3D).transform
	radice.add_child(_p)
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	if _p.water_pack:
		_p.water_pack.set_tank_amount(10.0)
		_p.water_pack.set_equipped(false, false)
	for l in _interni.find_children("*", "Light3D", true, false):
		_luci_prima[_interni.get_path_to(l)] = [(l as Light3D).light_energy, (l as Light3D).is_visible_in_tree()]
	for n in _interni.find_children("*_vetro", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_override != null:
			_vetri_prima += 1
	_squalo = _interni.get_node(^"Gioco/RisveglioSqualo") as RisveglioSqualo
	_interni.call(&"fai_risveglio", _p)


## Le lampade degli interni dopo la scena: nessuna più spenta o più debole di quando si è entrati (il massimo su 3 s
## di gioco, perché i neon sfarfallano e le luci rosse di emergenza pulsano).
func _confronta_luci() -> void:
	var massimo := {}
	for i in 90:
		for k in _luci_prima:
			var l := _interni.get_node_or_null(k) as Light3D
			if l == null:
				continue
			var e := l.light_energy if l.is_visible_in_tree() else 0.0
			massimo[k] = maxf(float(massimo.get(k, 0.0)), e)
		await _frames(1)
	var diverse := 0
	for k in _luci_prima:
		var l := _interni.get_node_or_null(k) as Light3D
		if l == null:
			continue
		var prima: Array = _luci_prima[k]
		var e0 := float(prima[0]) if bool(prima[1]) else 0.0
		if float(massimo.get(k, 0.0)) < e0 - 0.001:
			diverse += 1
			print("GIRO0322: LUCE più spenta dopo lo squalo: %s energia all'ingresso %.3f, al massimo in 3 s %.3f" % [k, e0,
					float(massimo.get(k, 0.0))])
	var emergenza := 0
	for n in _interni.find_children("*", "Node3D", true, false):
		if n is LuceEmergenza and absf(float(n.get(&"fattore")) - 1.0) > 0.001:
			emergenza += 1
			print("GIRO0322: LUCE di emergenza col fattore %.3f: %s" % [float(n.get(&"fattore")), _interni.get_path_to(n)])
	var vetri := 0
	for n in _interni.find_children("*_vetro", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_override != null:
			vetri += 1
	print("GIRO0322: LAMPADE dopo lo squalo: %d luci su %d più spente, %d di emergenza abbassate, %d vetri con un materiale sostituito (all'ingresso %d)" % [
			diverse, _luci_prima.size(), emergenza, vetri, _vetri_prima])


func _vai(nome: String, punti: Array) -> void:
	for t in punti:
		if not await _cammina_verso(t, 900):
			print("GIRO0322: KO %s: fermo in %s andando verso %s" % [nome, _p.global_position.snapped(Vector3.ONE * 0.01), t])
			_p.teleport(punti.back() + Vector3(0, 0.05, 0), _p.yaw, 0.0)
			await _frames(10)
			return
	print("GIRO0322: ok %s" % nome)


func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	var fermo := 0
	var prima := _p.global_position
	var t_scatto := Time.get_ticks_msec()
	for i in max_frames:
		var d := t - _p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		_p.set_look(atan2(-d.x, -d.z), deg_to_rad(-8.0))
		await get_tree().physics_frame
		_riga()
		if Time.get_ticks_msec() - t_scatto > 2500:
			t_scatto = Time.get_ticks_msec()
			await _scatto("strada")
		if i % 60 == 59:
			fermo = fermo + 1 if _p.global_position.distance_to(prima) < 0.05 else 0
			prima = _p.global_position
			if fermo >= 3:
				break
	Input.action_release(&"move_forward")
	return arrivato

extends Node
## Collaudo della scena dello squalo all'inizio con la luce viola e la nebbia (AtmosferaSqualo), nel gioco vero: dal
## caricamento alla sala principale con gli interni, come da "Nuova partita" (senza lo spot VHS), dagli occhi del
## giocatore. Uno scatto ogni [constant PASSO] s dal risveglio a [constant DOPO] s dopo il ritorno del controllo, poi
## verso la porta e indietro; a ogni fotogramma una riga in dati.jsonl: camera, distanza della camera dalla pelle dello
## squalo (tutti i vertici, nella posa del momento) e se ci sta dentro, luce viola, controluce, nebbia, porta, suoni
## partiti, tremolio, pipeline compilate.
## Modi: "alto" (preset di serie), "basso" (grafica al minimo: nebbia volumetrica spenta), "prima" (AtmosferaSqualo
## spenta: per confrontare porta, suoni, tremolio e camera con com'era). Senza "scatti" come terzo argomento niente
## scatti (si può lanciare senza schermo, per i confronti).
## Con "interni" come quarto argomento non si carica la sala intera (renderizzata non ci sta più nei 15 GB della
## macchina di prova: va fuori memoria durante il caricamento) ma solo quello che si vede: gli interni nella posizione
## che hanno nella sala, con l'ambiente e gli attributi della camera della sala (LookSala), il Player dove lo mette la
## sala, il risveglio nello stesso fotogramma in cui entra la scena (come nel _ready della sala) e la stessa dissolvenza
## dal nero del caricamento (8 fotogrammi neri, poi 1,6 s).
## Si lancia come scena, non con --script: con --script il gioco è "automatico" e salta la scena dello squalo. Prima
## si prepara la grafica (preset e calibrazione fatta) con prepara_grafica.gd.
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/prepara_grafica.gd alto
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 res://tests/collaudo/giro_squalo.tscn -- <cartella> <alto|basso|prima> scatti [interni|sala] [fino]

const CARICAMENTO := "res://scenes/ui/caricamento.tscn"
const INTERNI := "res://scenes/interni/interni.tscn"
const PLAYER := "res://scenes/player/player.tscn"
## Dove stanno gli interni e il giocatore nella sala principale (sala_principale.tscn).
const INTERNI_NELLA_SALA := Transform3D(Basis.IDENTITY, Vector3(-9.7, 0.0, 40.9))
const PASSO := 0.5
const DOPO := 5.0

var registratore := false
var cartella := "user://giro_squalo"
var modo := "alto"
var scatti := false
## Se > 0: il giro si ferma a questo tempo (secondi dall'inizio), per un confronto veloce.
var fino := 0.0
var _reg: FileAccess
var _array := {}
var _suoni_visti := {}
var _luci_contate := {}


func _ready() -> void:
	if registratore:
		_registra.call_deferred()
		return
	var a := OS.get_cmdline_user_args()
	var r := Node.new()
	r.set_script(get_script())
	r.name = "GiroSqualo"
	r.set(&"registratore", true)
	if a.size() > 0:
		r.set(&"cartella", a[0])
	if a.size() > 1:
		r.set(&"modo", a[1])
	r.set(&"scatti", a.size() > 2 and a[2] == "scatti")
	if a.size() > 4:
		r.set(&"fino", float(a[4]))
	get_tree().root.add_child.call_deferred(r)
	GameState.reset_progress()
	if a.size() > 3 and a[3] == "interni":
		_monta_interni.call_deferred()
	else:
		get_tree().change_scene_to_file.call_deferred(CARICAMENTO)


## Gli interni con l'ambiente della sala, come li vede il giocatore all'inizio del gioco.
func _monta_interni() -> void:
	var velo := Dissolvenza.di(get_tree())
	await velo.scurisci(0.0)
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
	var vecchia := get_tree().current_scene
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	# lo zaino si trova nello stanzino: si parte senza (come nel _ready della sala, dopo quello del giocatore)
	if p.water_pack:
		p.water_pack.set_tank_amount(10.0)
		p.water_pack.set_equipped(false, false)
	# (nel _ready della sala, appena entrata: GameState.player è già lui)
	interni.call(&"fai_risveglio", p)
	velo.schiarisci(1.6, 8)
	if vecchia and vecchia != radice:
		vecchia.queue_free()


func _registra() -> void:
	DirAccess.make_dir_recursive_absolute(cartella)
	_reg = FileAccess.open(cartella.path_join("dati.jsonl"), FileAccess.WRITE)
	print("GIRO: modo %s, preset %s, nebbia %s, in %s" % [modo, Grafica.valore("preset"), Grafica.valore("nebbia"), cartella])
	# la sala entra in scena: il risveglio parte nel suo _ready
	var s: RisveglioSqualo = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc and (sc.scene_file_path.ends_with("sala_principale.tscn") or sc.name == "SalaSoloInterni"):
			s = sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo
			if s:
				break
	if s == null:
		print("GIRO: la sala non è arrivata")
		get_tree().quit(1)
		return
	var p := GameState.player
	var atm := s.get_node_or_null(^"Atmosfera") as AtmosferaSqualo
	if modo == "prima" and atm:
		atm.process_mode = Node.PROCESS_MODE_DISABLED
		atm.visible = false
	print("GIRO: sala pronta, scena dello squalo %s" % ("in corso" if s.in_corso() else "NON partita"))
	var fotogramma := 0
	var t_scatto := 0.0
	var n := 0
	var t_controllo := -1.0
	var t := 0.0
	while true:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		fotogramma += 1
		if t_controllo < 0.0 and p.input_enabled and not s.in_corso():
			t_controllo = t
			print("GIRO: controllo di nuovo al giocatore a %.2f s" % t)
		var fase := "scena" if t_controllo < 0.0 else "dopo"
		_riga(fotogramma, t, fase, s, atm, p)
		if scatti and t >= t_scatto:
			await _scatto("%03d_%s_%05.2fs" % [n, fase, t])
			n += 1
			t_scatto += PASSO
		if t_controllo >= 0.0 and t >= t_controllo + DOPO:
			break
		if fino > 0.0 and t >= fino:
			break
		if t > 60.0:
			print("GIRO: dopo 60 s il controllo non è tornato")
			break
	# la nebbia non resta nel corridoio: verso la porta e indietro
	if scatti and fino <= 0.0:
		var porta := s.get(&"_perno") as Node3D
		if porta:
			p.look_at_point(porta.global_position + Vector3.UP * 1.2)
			for i in 4:
				await get_tree().process_frame
			_riga(fotogramma + 1, t, "verso_porta", s, atm, p)
			await _scatto("%03d_fine_verso_porta" % n)
			p.look_at_point(p.camera.global_position * 2.0 - (porta.global_position + Vector3.UP * 1.2))
			for i in 4:
				await get_tree().process_frame
			await _scatto("%03d_fine_indietro" % (n + 1))
	_reg.close()
	print("GIRO FINITO")
	get_tree().quit()


func _riga(f: int, t: float, fase: String, s: RisveglioSqualo, atm: AtmosferaSqualo, p: Player) -> void:
	var cam := p.camera
	var d := {"f": f, "t": snappedf(t, 0.001), "fase": fase, "t_scena": snappedf(float(s.get(&"_t")), 0.001),
		"cam": _v(cam.global_position), "cam_rot": _v(cam.global_rotation_degrees), "input": p.input_enabled,
		"porta_chiusa": bool(s.get(&"_porta_chiusa")), "scossa": snappedf(float(s.get(&"_scossa")), 0.0001)}
	if p.water_pack:
		d["zaino"] = [p.water_pack.equipped, p.water_pack.view_model.is_visible_in_tree() if p.water_pack.view_model else false,
			p.has_item(&"zaino_pompa")]
	var perno := s.get(&"_perno") as Node3D
	if perno:
		d["porta_gradi"] = snappedf(perno.rotation_degrees.y, 0.01)
	if atm:
		d["luce"] = snappedf(atm.luce.light_energy, 0.01)
		d["bordo"] = snappedf(atm.bordo.light_energy, 0.01)
		d["nebbia"] = snappedf((atm.nebbia.material as FogMaterial).density, 0.0001)
		d["diradata"] = snappedf(atm.diradata(), 0.001)
		d["nebbia_visibile"] = atm.nebbia.is_visible_in_tree()
	var lc: Variant = s.get(&"_luce_corsa")
	if is_instance_valid(lc):
		d["luce_corsa"] = snappedf((lc as OmniLight3D).light_energy, 0.01)
	var nuovi := []
	for k in (s.get(&"_suoni") as Dictionary):
		if not _suoni_visti.has(k):
			_suoni_visti[k] = true
			nuovi.append(k)
	if not nuovi.is_empty():
		d["suoni"] = nuovi
	d["pipeline"] = [int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))]
	# le luci della scena che non toccano lo squalo (AtmosferaSqualo le toglie durante la scena e le rimette dopo):
	# una volta a metà scena e una dopo
	var quando := "scena" if fase == "scena" and t > 3.0 else ("dopo" if fase == "dopo" and t > 0.0 else "")
	if quando != "" and not _luci_contate.has(quando):
		_luci_contate[quando] = true
		var senza := 0
		var tutte := 0
		for l in get_tree().current_scene.find_children("*", "Light3D", true, false):
			tutte += 1
			if not ((l as Light3D).light_cull_mask & RisveglioSqualo.STRATO_SQUALO):
				senza += 1
		d["luci_senza_squalo"] = [senza, tutte]
	if s.squalo and is_instance_valid(s.squalo) and s.squalo.visible:
		var pelle := _pelle(s, cam.global_position)
		d["pelle"] = snappedf(pelle[0], 0.001)
		d["dentro"] = pelle[1]
	_reg.store_line(JSON.stringify(d))


## La distanza della camera dalla pelle dello squalo (tutti i vertici, nella posa del momento, come la disegna lo
## skinning) e se la camera sta dentro (dalla parte di dentro della normale del vertice più vicino).
func _pelle(s: RisveglioSqualo, occhio: Vector3) -> Array:
	var sk := s.get(&"_scheletro") as Skeleton3D
	var migliore := INF
	var dentro := false
	for n in s.squalo.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null or sk == null or not mi.is_visible_in_tree():
			continue
		var ossa: Array[Transform3D] = []
		for b in mi.skin.get_bind_count():
			var osso := mi.skin.get_bind_bone(b)
			if osso < 0:
				osso = sk.find_bone(mi.skin.get_bind_name(b))
			ossa.append(sk.global_transform * (sk.get_bone_global_pose(osso) if osso >= 0 else Transform3D()) * mi.skin.get_bind_pose(b))
		for si in mi.mesh.get_surface_count():
			var chiave := [mi.mesh, si]
			if not _array.has(chiave):
				_array[chiave] = mi.mesh.surface_get_arrays(si)
			var arr: Array = _array[chiave]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var ix = arr[Mesh.ARRAY_BONES]
			var w = arr[Mesh.ARRAY_WEIGHTS]
			if ix == null or w == null or (ix as PackedInt32Array).is_empty():
				continue
			var per := (ix as PackedInt32Array).size() / v.size()
			for k in v.size():
				var q := Vector3.ZERO
				var nq := Vector3.ZERO
				for j in per:
					var peso: float = w[k * per + j]
					if peso > 0.0:
						var tr := ossa[ix[k * per + j]]
						q += (tr * v[k]) * peso
						nq += (tr.basis * nr[k]) * peso
				var dd := q.distance_to(occhio)
				if dd < migliore:
					migliore = dd
					dentro = (occhio - q).dot(nq) < 0.0
	return [migliore, dentro]


func _v(x: Vector3) -> Array:
	return [snappedf(x.x, 0.001), snappedf(x.y, 0.001), snappedf(x.z, 0.001)]


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)

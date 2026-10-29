extends "res://tests/test_enigma_giocattoli.gd"
## Collaudo della nebbia viola nel gioco (ambienti-2, 29 ottobre, per la 0.3.16), nel livello vero col giocatore vero:
## 1. dove si accende: a ogni checkpoint e in punti scelti (dentro e fuori dalle tre zone), la nebbia dopo l'arrivo;
## 2. le soglie: camminando a passo d'uomo dentro e fuori dalla sala e dall'infermeria, quanto sale e scende per
##    fotogramma (niente salti) e dove cambia;
## 3. le ripartenze: il checkpoint della pozza vuota (nella sala), la morte e Continua dal disco: subito piena;
## 4. l'opzione "Nebbia viola" dentro la sala: spenta scende piano, accesa risale, e si salva.
## Usa il caricamento di test_enigma_giocattoli.gd.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_nebbia.gd [parti]

var n: NebbiaViola
var _parti: PackedStringArray


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	_parti = a[1].split(",") if a.size() > 1 else PackedStringArray(["mappa", "soglie", "ripartenze", "opzione"])
	n = Grafica.nebbia_viola
	if "mappa" in _parti:
		await _mappa()
	if "soglie" in _parti:
		await _soglie()
	if "ripartenze" in _parti:
		await _ripartenze()
	if "opzione" in _parti:
		await _opzione()
	_fine()


func _carica_tutto() -> void:
	await _carica()
	# la risalita (fiume e infermeria) subito, come negli scatti dei muri
	var r := level.get_node_or_null(^"Risalita")
	if r and r.has_method(&"carica_subito"):
		r.call(&"carica_subito")
		await _frames(30)


## Porta il giocatore in [param pos] (salto: la nebbia vale subito) e aspetta [param s] secondi.
func _vai(pos: Vector3, s := 0.5) -> void:
	p.teleport(pos, 0.0, 0.0)
	for i in int(s * 60):
		await get_tree().physics_frame


func _mappa() -> void:
	print("1. Dove si accende la nebbia")
	await _carica_tutto()
	var zone := level.find_children("*", "ZonaNebbiaViola", true, false)
	print("  zone nel livello: ", zone.map(func(z): return String(level.get_path_to(z))))
	var punti: Array = []
	for c in level.find_children("*", "Checkpoint", true, false):
		var cp := c as Checkpoint
		punti.append([String(level.get_path_to(cp)), cp.get_spawn_transform().origin])
	var inferm := level.find_children("*", "InfermeriaGioco", true, false)
	for f in inferm:
		punti.append(["infermeria (centro)", (f as Node3D).global_position + Vector3(0, 0.1, 0)])
	punti.append_array([
		["sala, pozza", Vector3(0, -1.9, 2.0)],
		["sala, centro bordo sud", Vector3(0, 0.05, -4.0)],
		["sala, verso la torre (x 18)", Vector3(18.0, 0.05, 0.0)],
		["sala, angolo z 19", Vector3(-9.7, 0.05, 19.0)],
		["interni", Vector3(-9.7, 0.05, 40.9)],
		["fuori x 22", Vector3(22.0, 0.05, 0.0)],
	])
	for pt in punti:
		var pos: Vector3 = pt[1]
		var f := _fondo_sotto(pos + Vector3.UP * 1.0, [])
		if f > -50.0:
			pos.y = f + 0.05
		await _vai(pos, 0.6)
		print("  NEBBIA %-60s %s: quanto %.2f, in zona %s" % [pt[0], pos.snapped(Vector3.ONE * 0.1), n.quanto, n.in_zona()])


## Cammina a passo d'uomo (4,5 m/s, a piccoli passi: niente salti) da [param da] ad [param a], registrando la nebbia.
func _passeggia(nome: String, da: Vector3, a: Vector3) -> void:
	await _vai(da, 3.5)
	var inizio := n.quanto
	var passi := int(da.distance_to(a) / (4.5 / 60.0))
	var salto := 0.0
	var cambio := Vector3.INF
	var prima := n.quanto
	for i in passi + 120:
		var t := minf(1.0, float(i) / passi)
		p.global_position = da.lerp(a, t)
		await get_tree().physics_frame
		salto = maxf(salto, absf(n.quanto - prima))
		if cambio == Vector3.INF and absf(n.quanto - prima) > 0.0001 and n.quanto != inizio:
			cambio = p.global_position
		prima = n.quanto
	for i in 200:
		await get_tree().physics_frame
		salto = maxf(salto, absf(n.quanto - prima))
		prima = n.quanto
	check(salto <= 1.0 / (60.0 * NebbiaViola.DURATA) * 1.6, "%s: niente salti (al massimo %.4f per fotogramma, %.4f è 3 s)" % [nome, salto, 1.0 / (60.0 * NebbiaViola.DURATA)])
	print("  SOGLIA %s: da %.2f a %.2f, comincia a cambiare in %s" % [nome, inizio, n.quanto, cambio.snapped(Vector3.ONE * 0.1)])


func _soglie() -> void:
	print("2. Le soglie camminando")
	await _carica_tutto()
	await _passeggia("sala verso gli interni (esce)", Vector3(-9.7, 0.05, 14.0), Vector3(-9.7, 0.05, 30.0))
	await _passeggia("dagli interni nella sala (entra)", Vector3(-9.7, 0.05, 30.0), Vector3(-9.7, 0.05, 14.0))
	await _passeggia("sala verso la torre (esce, x 20)", Vector3(14.0, 0.05, 0.0), Vector3(26.0, 0.05, 0.0))
	var inferm := level.find_children("*", "InfermeriaGioco", true, false)
	if not inferm.is_empty():
		var c := (inferm[0] as Node3D).global_position
		await _passeggia("infermeria verso fuori (+x 8 m)", c + Vector3(0, 0.1, 0), c + Vector3(8, 0.1, 0))
		await _passeggia("da fuori nell'infermeria", c + Vector3(8, 0.1, 0), c + Vector3(0, 0.1, 0))


func _ripartenze() -> void:
	print("3. Ripartenze nella sala")
	await _carica_tutto()
	GameState.save_to_disk = true
	await _svuota()
	await _frames(60)
	var cp := level.get_node(^"Piscina/CheckpointPozzaVuota") as Checkpoint
	GameState.reach_checkpoint(cp)
	await _frames(30)
	check(n.quanto > 0.99, "al checkpoint della pozza vuota la nebbia è piena (%.2f)" % n.quanto)
	GameState.kill_player(&"collaudo")
	var vecchio := level
	var primo := -1.0
	for k in 1500:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and s != vecchio and GameState.player != null and is_instance_valid(GameState.player):
			if primo < 0.0 and GameState.player.input_enabled:
				primo = n.quanto
				break
	check(primo > 0.99, "dopo la morte, al primo fotogramma col giocatore, la nebbia è già piena (%.2f)" % primo)
	GameState.reset_progress()
	check(GameState.continue_from_disk(), "c'è il salvataggio su disco")
	primo = -1.0
	var t0 := Time.get_ticks_msec()
	var minimo := 1.0
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and s.scene_file_path == LEVEL and GameState.player != null and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			primo = n.quanto
			break
	for k in 30:
		await get_tree().process_frame
		minimo = minf(minimo, n.quanto)
	check(primo > 0.99 and minimo > 0.99, "con Continua dal disco la nebbia è subito piena e resta (%.2f, minimo %.2f)" % [primo, minimo])


func _opzione() -> void:
	print("4. L'opzione Nebbia viola dentro la sala")
	await _carica_tutto()
	await _vai(Vector3(0, 0.05, -4.0), 4.0)
	check(n.quanto > 0.99, "nella sala è piena (%.2f)" % n.quanto)
	Grafica.salva_su_disco = true
	Grafica.imposta("nebbia_viola", false)
	var dopo1 := 0.0
	for i in 60:
		await get_tree().physics_frame
	dopo1 = n.quanto
	for i in 200:
		await get_tree().physics_frame
	check(dopo1 > 0.55 and dopo1 < 0.8 and n.quanto == 0.0 and not n._quad.visible, "spenta dall'opzione scende piano (dopo 1 s %.2f) fino a 0 e non si disegna" % dopo1)
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	var salvata := false
	for sez in cfg.get_sections():
		if cfg.has_section_key(sez, "nebbia_viola"):
			salvata = cfg.get_value(sez, "nebbia_viola") == false
	check(salvata, "l'opzione spenta è salvata in settings.cfg")
	Grafica.imposta("nebbia_viola", true)
	for i in 60:
		await get_tree().physics_frame
	var dopo2 := n.quanto
	for i in 200:
		await get_tree().physics_frame
	check(dopo2 > 0.2 and dopo2 < 0.45 and n.quanto == 1.0, "riaccesa risale piano (dopo 1 s %.2f) fino a piena" % dopo2)
	print("  LINGUA: ", TranslationServer.translate("Nebbia viola"), " | testi.csv: Nebbia viola -> Purple fog")

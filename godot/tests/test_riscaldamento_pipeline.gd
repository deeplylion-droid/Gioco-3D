extends Node
## Test automatico (renderer vero; in CI quello software, llvmpipe, con xvfb): il riscaldamento degli shader dietro
## la schermata di caricamento dell'avvio (RiscaldamentoShader) e poi niente compilazioni che fermano il gioco (blocchi
## al primo avvio, v0.3.14; decisione del coordinatore del 25 ottobre: col renderer software si contano le pipeline,
## non i millisecondi):
## 1. durante il riscaldamento al più [constant AL_PIU] pipeline che bloccano ("surface" e "draw") per fotogramma (un
##    materiale nuovo per fotogramma: il suo primo disegno ne compila 3-10 insieme; limite del coordinatore, 25 ottobre);
## 2. poi lei compare dietro un oblò (ObloLei, come nel gioco): al primo fotogramma in cui si vede, e nei seguenti,
##    nessuna compilazione "surface" né "draw" (le "specialization" vanno in sottofondo: si stampano).
## 3. il tunnel del viaggio sottomarino costruito come nel gioco (a pezzi, col suo riscaldamento) e poi visto lungo
##    tutta la strada: nessuna compilazione "surface" né "draw".
## 5. nel tunnel la nebbia viola (NebbiaViola) che sale entrando: nessuna compilazione "surface" né "draw".
## (la torre al primo fotogramma visibile la prova test_torre_ingresso.gd)
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_riscaldamento_pipeline.gd

const AL_PIU := 10
## Caso noto, da togliere appena corretto (si stampa con la misura): il corpo di lei (la mesh "Medusa", più superfici
## con formati di vertici diversi) col materiale neutro, nel primo passo del suo modello: 12 pipeline in un fotogramma.
## (25 ottobre, sera: l'avvio dell'oblò da 32 e gli 8 "draw" di lei all'oblò sono corretti.)
const NOTI := {"lei: Medusa": 12}

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _conta() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var vero := RenderingServer.get_rendering_device() != null
	check(vero, "c'è il renderer vero (%s)" % RenderingServer.get_video_adapter_name())
	if not vero:
		_fine()
		return
	var env := WorldEnvironment.new()
	# l'ambiente della sala con le impostazioni grafiche, come nel gioco (e come nel riscaldamento)
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()

	print("1. Il riscaldamento dietro la schermata di caricamento")
	var r := RiscaldamentoShader.new()
	add_child(r)
	var prima := _conta()
	var peggiore := 0
	var n := 0
	var t0 := Time.get_ticks_msec()
	while not r.concluso and Time.get_ticks_msec() - t0 < 1200000:
		await get_tree().process_frame
		var ora := _conta()
		var bloccano := int(ora[0] - prima[0] + ora[1] - prima[1])
		prima = ora
		n += 1
		if bloccano > AL_PIU and NOTI.has(r.pezzo) and bloccano <= int(NOTI[r.pezzo]):
			print("  noto  %s: %d pipeline in un fotogramma (al più %d)" % [r.pezzo, bloccano, NOTI[r.pezzo]])
			continue
		if bloccano > AL_PIU:
			print("    %d pipeline in un fotogramma (materiale %d/%d %s)" % [bloccano, r.fatti, r.totale, r.pezzo])
		peggiore = maxi(peggiore, bloccano)
	check(r.concluso, "il riscaldamento finisce (%d materiali, %d fotogrammi, %.0f s)" % [r.totale / 2, n, (Time.get_ticks_msec() - t0) / 1000.0])
	check(peggiore <= AL_PIU, "al più %d pipeline che bloccano per fotogramma (il peggiore %d)" % [AL_PIU, peggiore])

	print("2. Lei compare dietro un oblò")
	var o := ObloLei.new()
	o.zona = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	add_child(o)
	o.set_process(false)
	# con la camera vera del giocatore, lancia e zaino in mano (sullo strato del viewmodel, nella luce rosa di lei: il
	# collaudo di grafica-2 del 25 ottobre trovava lì gli "draw" che con una camera nuda non c'erano)
	var giocatore := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node3D
	add_child(giocatore)
	var zaino := giocatore.find_children("*", "WaterPack", true, false)
	if not zaino.is_empty():
		(zaino[0] as WaterPack).set_equipped(true, false)
	var occhio := giocatore.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var davanti := o.centro_vetro() + o.normale() * 2.5
	giocatore.global_position = davanti - Vector3.UP * (occhio.global_position.y - giocatore.global_position.y) + Vector3.UP * 0.2
	giocatore.look_at(Vector3(o.centro_vetro().x, giocatore.global_position.y, o.centro_vetro().z))
	giocatore.process_mode = Node.PROCESS_MODE_DISABLED
	occhio.make_current()
	occhio.look_at(o.centro_vetro())
	for i in 10:
		await get_tree().process_frame
	# come negli oblò leggeri (mascotte): lei creata nascosta mentre la zona si costruisce e disegnata fuori vista nel
	# mondo della zona un pezzo per volta (RiscaldamentoShader.disegna_a_pezzi); poi, quando compare, basta mostrarla
	o._mostra()
	o.lei.visible = false
	await RiscaldamentoShader.disegna_a_pezzi(o.lei, get_viewport())
	for i in 4:
		await get_tree().process_frame
	prima = _conta()
	o.lei.visible = true
	for i in 8:
		await get_tree().process_frame
	var c := _conta()
	var s := int(c[0] - prima[0])
	var d := int(c[1] - prima[1])
	check(o.lei != null and o.lei.visible, "lei si vede dietro il vetro")
	check(s == 0 and d == 0, "nessuna compilazione che blocca quando compare (surface %d, draw %d; in sottofondo %d)" % [s, d, int(c[2] - prima[2])])
	o.queue_free()
	giocatore.queue_free()
	cam.make_current()

	print("3. Il tunnel sottomarino, visto lungo la strada")
	cam.global_position = Vector3(0, 50, 0)
	cam.look_at(Vector3(0, 100, 1))
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	await sala.costruisci_a_pezzi()
	for i in 30:
		await get_tree().process_frame
	prima = _conta()
	var posti := 0
	var dove := []
	var x := 0.0
	while x < sala.lunghezza():
		var p := sala.punto(x)
		cam.global_position = Vector3(p.x, sala.piano + 1.6, p.z) - sala.destra(x) * 5.0
		cam.look_at(cam.global_position + sala.direzione(x), Vector3.UP)
		for i in 3:
			await get_tree().process_frame
		var ora := _conta()
		if ora[0] != prima[0] or ora[1] != prima[1]:
			dove.append("s %.0f: surface %d, draw %d" % [x, ora[0] - prima[0], ora[1] - prima[1]])
		prima = ora
		posti += 1
		x += 15.0
	check(dove.is_empty(), "lungo il tunnel (%d punti) nessuna compilazione che blocca%s" % [posti, "" if dove.is_empty() else ": " + ", ".join(dove.slice(0, 8))])

	print("4. Nel tunnel col giocatore vero: a s 133 ti giri, lei riemerge dietro e la spruzzi")
	# (misura del 28 ottobre, prima di LeiTunnel.prepara: 16 "draw" quando riemergeva)
	var g := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(g)
	await get_tree().process_frame
	var zaini := g.find_children("*", "WaterPack", true, false)
	var pack: WaterPack = zaini[0] if not zaini.is_empty() else null
	if pack:
		pack.set_equipped(true, false)
		pack.set_tank_amount(pack.tank_capacity)
	g.input_enabled = true
	(g.find_children("*", "Camera3D", true, false)[0] as Camera3D).make_current()
	var s0 := 133.0
	var piedi := sala._al(sala.punto(s0), sala.destra(s0), Vector2(-(sala.canale + sala.banchina * 0.5), sala.piano + 0.1))
	var avanti := sala.direzione(s0)
	g.teleport(piedi, atan2(-avanti.x, -avanti.z))
	for i in 20:
		await get_tree().process_frame
	var lt := sala.lei_tunnel
	var dietro := sala.punto(s0 - 8.0)
	dietro.y = sala.acqua
	prima = _conta()
	lt.riemergi(dietro, avanti)
	# girato verso di lei, lo sguardo sul viso
	var viso := lt.find_child("Viso", true, false) as Node3D
	var occhi_g := g.global_position + Vector3.UP * 1.6
	for i in 40:
		var dir_lei := viso.global_position - occhi_g
		g.teleport(piedi, atan2(-dir_lei.x, -dir_lei.z), atan2(dir_lei.y, Vector2(dir_lei.x, dir_lei.z).length()))
		await get_tree().process_frame
	c = _conta()
	check(int(c[0] - prima[0]) == 0 and int(c[1] - prima[1]) == 0,
		"ti giri e lei riemerge dietro: nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])
	var colpi := [0.0]
	(viso as WaterHitbox).water_hit.connect(func(l: float, _p: Vector3, _d: Vector3) -> void: colpi[0] += l)
	var spruzzava := false
	prima = _conta()
	Input.action_press("spray")
	for i in 120:
		var dir_lei := viso.global_position - occhi_g
		g.teleport(piedi, atan2(-dir_lei.x, -dir_lei.z), atan2(dir_lei.y, Vector2(dir_lei.x, dir_lei.z).length()))
		await get_tree().process_frame
		spruzzava = spruzzava or (pack != null and pack.is_spraying)
	Input.action_release("spray")
	for i in 10:
		await get_tree().process_frame
	c = _conta()
	check(spruzzava and colpi[0] > 0.0, "il getto parte e la colpisce (%.1f litri sul viso)" % colpi[0])
	check(int(c[0] - prima[0]) == 0 and int(c[1] - prima[1]) == 0,
		"spruzzandola nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])

	print("5. La nebbia viola del tunnel: entrando sale (con l'alone di lei), poi spenta dalle opzioni")
	# (riscaldata all'avvio da RiscaldamentoShader: accendendola nessuna compilazione che blocca)
	var nv := Grafica.nebbia_viola
	GameState.player = g
	nv.quanto = 0.0
	prima = _conta()
	var vista := 0.0
	for i in 200:
		var dir_lei := viso.global_position - occhi_g
		g.teleport(piedi, atan2(-dir_lei.x, -dir_lei.z), atan2(dir_lei.y, Vector2(dir_lei.x, dir_lei.z).length()))
		await get_tree().process_frame
		vista = maxf(vista, nv.quanto)
	c = _conta()
	check(nv.in_zona() and vista > 0.5, "nel tunnel la nebbia viola c'è (%.2f)" % vista)
	check(int(c[0] - prima[0]) == 0 and int(c[1] - prima[1]) == 0,
		"accendendo la nebbia viola nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [c[0] - prima[0], c[1] - prima[1], c[2] - prima[2]])
	g.queue_free()
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)

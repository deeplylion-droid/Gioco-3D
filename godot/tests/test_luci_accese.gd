extends Node
## Test (renderer vero; llvmpipe con xvfb): le luci che si accendono o si spengono durante il gioco non compilano
## pipeline che fermano il gioco (richiesta del coordinatore, 25 ottobre: col blackout nessuna omni tocca le mesh
## dell'oblò personale, e la luce rosa di lei chiedeva la variante "omni accese", 8 draw al primo fotogramma).
## Dopo il riscaldamento della schermata di caricamento (RiscaldamentoShader), come nel gioco:
## 1. infermeria della Risalita, preparata come nel gioco (disegnata fuori vista), vista dalla porta: il negatoscopio
##    spento, poi l'interruttore colpito (si accende con la sua luce larga);
## Per ogni accensione si contano le compilazioni "surface" e "draw" dei fotogrammi dopo (le "specialization" vanno in
## sottofondo: si stampano). Per ora si stampano i numeri (misura): il limite si mette quando si è deciso cosa correggere.
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_luci_accese.gd

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


## Le compilazioni nei [param n] fotogrammi dopo [param fai].
func _dopo(fai: Callable, n := 8) -> Array:
	for i in 6:
		await get_tree().process_frame
	var prima := _conta()
	fai.call()
	for i in n:
		await get_tree().process_frame
	var ora := _conta()
	return [int(ora[0] - prima[0]), int(ora[1] - prima[1]), int(ora[2] - prima[2])]


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if RenderingServer.get_rendering_device() == null:
		check(false, "c'è il renderer vero")
		_fine()
		return
	var env := WorldEnvironment.new()
	env.environment = RiscaldamentoShader.ambiente()
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0, 500, 0)
	print("0. Il riscaldamento della schermata di caricamento")
	var r := RiscaldamentoShader.new()
	add_child(r)
	while not r.concluso:
		await get_tree().process_frame

	print("1. Infermeria: il negatoscopio si accende")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var inf := (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate() as Node3D
	add_child(inf)
	await RiscaldamentoShader.disegna_fuori_vista(inf, get_viewport())
	var neg := inf.get(&"negatoscopio") as Node3D
	# dalla parte opposta della stanza, verso il negatoscopio
	var verso := neg.global_position
	cam.global_position = verso + neg.global_basis.z * 4.0 + Vector3.DOWN * 0.1
	cam.look_at(verso)
	var c: Array = await _dopo(func() -> void: pass, 30)
	print("    prima vista della stanza: surface %d, draw %d (in sottofondo %d)" % c)
	c = await _dopo(func() -> void: (inf.get(&"interruttore") as PowerSource).powered = true)
	print("MISURA negatoscopio acceso: surface %d, draw %d (in sottofondo %d)" % c)
	check(bool(neg.call(&"e_acceso")), "il negatoscopio è acceso")
	inf.queue_free()
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)

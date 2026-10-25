extends Node
## Test automatico (renderer vero; in CI quello software, llvmpipe, con xvfb): il riscaldamento degli shader dietro
## la schermata di caricamento dell'avvio (RiscaldamentoShader) e poi niente compilazioni che fermano il gioco (blocchi
## al primo avvio, v0.3.14; decisione del coordinatore del 25 ottobre: col renderer software si contano le pipeline,
## non i millisecondi):
## 1. durante il riscaldamento al più [constant AL_PIU] pipeline che bloccano ("surface" e "draw") per fotogramma;
## 2. poi lei compare dietro un oblò (ObloLei, come nel gioco): al primo fotogramma in cui si vede, e nei seguenti,
##    nessuna compilazione "surface" né "draw" (le "specialization" vanno in sottofondo: si stampano).
## (la torre al primo fotogramma visibile la prova test_torre_ingresso.gd)
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_riscaldamento_pipeline.gd

const AL_PIU := 2

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
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
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
		if bloccano > AL_PIU:
			print("    %d pipeline in un fotogramma (materiale %d/%d)" % [bloccano, r.fatti, r.totale])
		peggiore = maxi(peggiore, bloccano)
	check(r.concluso, "il riscaldamento finisce (%d materiali, %d fotogrammi, %.0f s)" % [r.totale / 2, n, (Time.get_ticks_msec() - t0) / 1000.0])
	check(peggiore <= AL_PIU, "al più %d pipeline che bloccano per fotogramma (il peggiore %d)" % [AL_PIU, peggiore])

	print("2. Lei compare dietro un oblò")
	var o := ObloLei.new()
	o.zona = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	add_child(o)
	o.set_process(false)
	cam.global_position = o.centro_vetro() + o.normale() * 2.5 + Vector3.UP * 0.2
	cam.look_at(o.centro_vetro())
	for i in 10:
		await get_tree().process_frame
	prima = _conta()
	o._mostra()
	for i in 8:
		await get_tree().process_frame
	var c := _conta()
	var s := int(c[0] - prima[0])
	var d := int(c[1] - prima[1])
	check(o.lei != null and o.lei.visible, "lei si vede dietro il vetro")
	check(s == 0 and d == 0, "nessuna compilazione che blocca quando compare (surface %d, draw %d; in sottofondo %d)" % [s, d, int(c[2] - prima[2])])
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)

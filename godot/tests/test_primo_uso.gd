extends Node
## Test automatico: niente blocchi al primo uso degli effetti (riscontri sulla v0.3.4 e v0.3.5:
## "la prima volta che si spruzza il gioco si blocca per circa 1 secondo"). Dopo la preparazione
## (PreparaEffetti), la prima volta che si spruzza e che scoppia un geyser il motore non deve
## compilare pipeline che fermano il fotogramma: i monitor Performance delle compilazioni "surface"
## (shader della superficie) e "draw" (pipeline al momento di disegnare) restano a zero.
## L'aspirazione dalla vasca lava-piedi degli spogliatoi si misura e si stampa soltanto: lì il motore
## compila ancora 2 pipeline "surface" che non vengono dagli effetti dello zaino (nascosti tutti, ci
## sono lo stesso: vengono dalla scena) e sulla v0.3.5 l'utente non ha più visto il blocco.
## Le "specialization" si fanno in un thread a parte (intanto si disegna con l'ubershader): si
## stampano soltanto.
## Serve il renderer vero (Vulkan; nella CI quello software, llvmpipe, con xvfb): con --headless il
## motore non compila niente e il test non vale.
## Uso: xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 \
##        --script res://tests/run.gd -- res://tests/test_primo_uso.gd

const LEVEL := "res://scenes/interni/interni.tscn"
const POSIZIONE := Vector3(9.7, 0.0, -10.6)
const POZZA := Vector3(9.7, -0.05, -12.9)
const MIRA := Vector3(9.7, 1.2, -17.8)
const MONITOR := {
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

var p: Player
var _passed := 0
var _failed := 0
var _prima := {}


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _azzera() -> void:
	for k in MONITOR:
		_prima[k] = Performance.get_monitor(MONITOR[k])


func _conta() -> Dictionary:
	var c := {}
	for k in MONITOR:
		c[k] = int(Performance.get_monitor(MONITOR[k]) - _prima[k])
	return c


func _controlla(cosa: String, c: Dictionary) -> void:
	check(c.surface == 0 and c.draw == 0, "%s: nessuna compilazione che blocca (surface %d, draw %d; in sottofondo %d)" % [cosa, c.surface, c.draw, c.spec])


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	print("Il renderer")
	var vero := RenderingServer.get_rendering_device() != null
	check(vero, "c'è il renderer vero (%s)" % RenderingServer.get_video_adapter_name())
	if not vero:
		_fine()
		return
	if OS.get_cmdline_user_args().has("senza_preparazione"):
		Engine.set_meta(&"prepara_effetti_spento", true)  # per vedere che il test se ne accorge
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	check(p.water_pack.get_node_or_null(^"GettoPotente") != null, "lo zaino ha il getto B (GettoPotente)")
	p.water_pack.call(&"set_equipped", true, false)
	p.teleport(POSIZIONE, 0.0, 0.0)
	p.look_at_point(MIRA)
	await _frames(40)

	print("La prima volta, dopo la preparazione")
	p.water_pack.set_tank_amount(20.0)
	_azzera()
	Input.action_press(&"spray")
	await _frames(30)
	Input.action_release(&"spray")
	await _frames(10)
	_controlla("spruzzo (carica, nastro, schizzi, macchie)", _conta())
	p.look_at_point(POZZA)
	p.water_pack.set_tank_amount(0.0)
	await _frames(30)
	_azzera()
	Input.action_press(&"suck")
	await _frames(25)
	Input.action_release(&"suck")
	await _frames(10)
	var asp := _conta()
	print("  (aspirazione: surface %d, draw %d, in sottofondo %d)" % [asp.surface, asp.draw, asp.spec])
	_azzera()
	var g := GeyserFossa.new()
	get_tree().current_scene.add_child(g)
	g.scoppia(p.global_position + p.global_basis * Vector3(0.0, 0.0, -4.0), [])
	await _frames(20)
	_controlla("geyser", _conta())
	g.queue_free()
	_fine()


func _fine() -> void:
	Input.action_release(&"spray")
	Input.action_release(&"suck")
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)

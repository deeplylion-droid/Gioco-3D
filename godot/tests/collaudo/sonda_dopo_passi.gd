extends Node
## Ricontrollo dei caricamenti del tunnel (0.3.25, enigmi): quanto costa sul thread principale quello che il tunnel fa
## dopo i passi, senza schermo (lei non si prepara: LeiTunnel.prepara esce senza renderer). Nella scena di prova:
## 1. strati_riscaldamento() (nel fotogramma dell'ultimo passo, prima di _riscalda);
## 2. FormeTunnel._contesto (all'inizio di prepara_a_pezzi, nello stesso fotogramma);
## 3. FormeTunnel.prepara_a_pezzi, fotogramma per fotogramma: il lavoro delle forme in ogni fotogramma (dal ritorno
##    dell'attesa alla prossima attesa), misurato come fotogramma intero meno quello di un fotogramma vuoto.
## Uso: godot --headless --path godot --script res://tests/run.gd -- <questo> [giri]

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"
var _ultimo := 0
var _fot: Array = []
var _misura := false


func _ready() -> void:
	process_priority = -1000
	_run.call_deferred()


func _process(_d: float) -> void:
	var t := Time.get_ticks_usec()
	if _misura and _ultimo > 0:
		_fot.append((t - _ultimo) / 1000.0)
	_ultimo = t


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var giri := int(a[1]) if a.size() > 1 else 3
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 10:
		await get_tree().process_frame
	var sott := get_tree().current_scene.get_node("SalaSottomarino") as SalaSottomarino
	await sott.costruisci_a_pezzi(6.0)
	for i in 30:
		await get_tree().process_frame
	# un fotogramma vuoto, per togliere la base
	_fot = []
	_misura = true
	for i in 60:
		await get_tree().process_frame
	_misura = false
	var base: Array = _fot.duplicate()
	base.sort()
	var b := float(base[base.size() / 2])
	print("DOPO_PASSI: fotogramma vuoto della scena di prova %.1f ms (mediana)" % b)
	var id := sott.get_instance_id()
	for g in giri:
		var t0 := Time.get_ticks_usec()
		sott.strati_riscaldamento()
		var t_strati := (Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		var ctx: Dictionary = FormeTunnel._contesto(sott)
		var t_ctx := (Time.get_ticks_usec() - t0) / 1000.0
		ctx.clear()
		FormeTunnel._cache.erase(id)
		FormeTunnel.lascia_tenute()
		await get_tree().process_frame
		_fot = []
		_misura = true
		var tf := Time.get_ticks_usec()
		await FormeTunnel.prepara_a_pezzi(sott)
		var durata := (Time.get_ticks_usec() - tf) / 1000.0
		await get_tree().process_frame
		_misura = false
		var lavoro: Array = _fot.map(func(x): return snappedf(x - b, 0.1))
		var ordinati := lavoro.duplicate()
		ordinati.sort()
		ordinati.reverse()
		print("DOPO_PASSI giro %d: strati_riscaldamento %.1f ms; FormeTunnel._contesto %.1f ms; forme a pezzi in %.0f ms su %d fotogrammi, lavoro per fotogramma: il primo %.1f ms, i più lunghi %s, sopra 10 ms %d, sopra 15 ms %d" % [
				g + 1, t_strati, t_ctx, durata, lavoro.size(), lavoro[0] if lavoro.size() > 0 else 0.0,
				ordinati.slice(0, 6), lavoro.filter(func(x): return x > 10.0).size(), lavoro.filter(func(x): return x > 15.0).size()])
	print("DOPO_PASSI: FINE")
	get_tree().quit()

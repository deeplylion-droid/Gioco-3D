extends Node
## Test: la luce rosa del riscaldamento del tunnel si posa solo sul tunnel (#131, collaudo finale della 0.3.21: senza
## ombre passava i muri, e dalla prima vista colorava di rosa per 0,1-0,15 s il muro, la scaletta e la ringhiera del
## bacino delle condotte, che il giocatore vede). Nella scena di prova con le condotte e il tunnel
## (scenes/test/sottomarino_prova.tscn), il riscaldamento (SalaSottomarino._riscalda; senza schermo mette solo gli strati):
## 1. le mesh del tunnel sullo strato 1 hanno anche EffettiInseguimento.STRATO_RISCALDA; quelle su altri strati (l'acqua)
##    no, e tengono i loro;
## 2. nessuna mesh fuori dal tunnel (le condotte, il bacino, il giocatore) ha quello strato;
## 3. accesa per il riscaldamento, la luce rosa ha la maschera STRATO_RISCALDA e basta: nessuna mesh fuori dal tunnel
##    combacia con lei; spenta, torna alla maschera del gioco.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_riscalda_tunnel_strati.gd

const LEVEL := "res://scenes/test/sottomarino_prova.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", cosa)
	else:
		_ko += 1
		print("  KO    ", cosa)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 10:
		await get_tree().process_frame
	var level := get_tree().current_scene
	var sott := level.get_node("SalaSottomarino") as SalaSottomarino
	sott.costruisci()
	for i in 5:
		await get_tree().process_frame
	# come nel gioco, dopo la costruzione (senza schermo mette gli strati e si ferma lì)
	var t0 := Time.get_ticks_usec()
	await sott.call(&"_riscalda")
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("    strati del riscaldamento messi in %.1f ms" % ms)
	check(ms < 20.0, "0. mettere gli strati alle mesh del tunnel costa poco, in un fotogramma (%.1f ms)" % ms)
	var bit := EffettiInseguimento.STRATO_RISCALDA
	var nel_tunnel := 0
	var senza := 0
	var altri_ok := true
	for n in sott.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.layers & 1:
			nel_tunnel += 1
			if not g.layers & bit:
				senza += 1
		elif g.layers & bit:
			altri_ok = false
			print("    sullo strato del riscaldamento senza lo strato 1: %s (%d)" % [sott.get_path_to(g), g.layers])
	check(nel_tunnel > 50 and senza == 0, "1. le %d mesh del tunnel sullo strato 1 hanno anche lo strato del riscaldamento (senza: %d)" % [nel_tunnel, senza])
	check(altri_ok, "1. le mesh del tunnel su altri strati (l'acqua) tengono i loro")
	var fuori: Array[GeometryInstance3D] = []
	var contate := 0
	for n in level.find_children("*", "GeometryInstance3D", true, false):
		if sott.is_ancestor_of(n):
			continue
		contate += 1
		if (n as GeometryInstance3D).layers & bit:
			fuori.append(n)
	for g in fuori.slice(0, 10):
		print("    fuori dal tunnel con lo strato del riscaldamento: %s" % level.get_path_to(g))
	check(contate > 50 and fuori.is_empty(), "2. nessuna delle %d mesh fuori dal tunnel (condotte, bacino) ha lo strato del riscaldamento (%d)" % [contate, fuori.size()])
	var eff := sott.get(&"effetti") as EffettiInseguimento
	check(eff != null, "3. gli effetti dell'inseguimento ci sono")
	if eff:
		var cam := Camera3D.new()
		add_child(cam)
		cam.global_position = sott.punto(0.0) + Vector3.UP * 1.6
		eff.riscalda_da(cam, true)
		check(eff.luce.visible and eff.luce.light_cull_mask == bit,
			"3. accesa per il riscaldamento, la luce rosa ha solo lo strato del riscaldamento (%x)" % eff.luce.light_cull_mask)
		var toccate := 0
		for n in level.find_children("*", "GeometryInstance3D", true, false):
			if not sott.is_ancestor_of(n) and (n as GeometryInstance3D).layers & eff.luce.light_cull_mask:
				toccate += 1
		check(toccate == 0, "3. nessuna mesh fuori dal tunnel combacia con la luce del riscaldamento (%d)" % toccate)
		eff.riscalda_da(cam, false)
		check(not eff.luce.visible and eff.luce.light_cull_mask == EffettiInseguimento.MASCHERA_GIOCO,
			"3. spenta, la luce torna alla maschera del gioco (%x)" % eff.luce.light_cull_mask)
		cam.queue_free()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)

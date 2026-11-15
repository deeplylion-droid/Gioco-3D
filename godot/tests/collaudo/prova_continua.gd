extends Node
## Collaudo 0.3.22 (ricontrollo di fa71293d): Continua dal titolo con la qualità ancora da provare (qualita_provata
## falso, come test_primo_ingresso ma dalla voce Continua). Prima una Nuova partita senza prova per avere il
## salvataggio, poi il titolo, il profilo rimesso «nuovo» e Continua: la prova parte, finisce, lo schermo si schiarisce,
## niente albero nullo (PC:).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/prova_continua.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _arrivati(entro_s: float) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		if sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" \
				and get_tree().get_first_node_in_group(&"player") != null and not GameState.is_dying:
			return true
		await _frames(5)
	return false


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(30)
	get_tree().current_scene.call(&"_avvia_nuova_partita")
	await _frames(60)
	for n in get_tree().root.get_children():
		if n is LettoreSpot:
			n.call(&"_fine")
	print("PC: nuova partita arrivata %s, salvataggio %s" % [await _arrivati(600.0), GameState.has_save()])
	await _frames(120)
	# (il salvataggio su disco arriva col checkpoint: una morte e la ripartenza, come in car_entrate)
	GameState.kill_player(&"prova")
	await _frames(30)
	print("PC: ripartiti %s, salvataggio %s" % [await _arrivati(300.0), GameState.has_save()])
	await _frames(60)
	Game.return_to_title()
	var fino := Time.get_ticks_msec() + 300000
	while Time.get_ticks_msec() < fino and not (get_tree().current_scene and String(get_tree().current_scene.name) == "MenuPrincipale"):
		await _frames(5)
	await _frames(60)
	Grafica.valori["qualita_provata"] = false
	Grafica.valori["scelta_automatica"] = ""
	QualitaAutomatica.forza_nei_test = true
	QualitaAutomatica.misura_finta_test = func(preset: String) -> bool: return preset == "alto"
	print("PC: al titolo, prova da fare %s, salvataggio %s, lingua %s" % [QualitaAutomatica.da_fare(), GameState.has_save(), TranslationServer.get_locale()])
	get_tree().current_scene.call(&"continua")
	var vista := false
	var caricamento := false
	fino = Time.get_ticks_msec() + 600000
	while Time.get_ticks_msec() < fino:
		await _frames(5)
		if get_tree().current_scene and String(get_tree().current_scene.name) == "Caricamento":
			caricamento = true
		if get_tree().root.get_node_or_null(^"QualitaAutomatica") != null:
			vista = true
		if bool(Grafica.valore("qualita_provata")):
			break
	var sc := get_tree().current_scene
	print("PC: Continua: schermata di caricamento %s, prova partita %s, provata %s, preset %s, scena %s" % [caricamento, vista,
		Grafica.valore("qualita_provata"), Grafica.valore("preset"), sc.name if sc else "-"])
	var schiarito := false
	fino = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < fino:
		await _frames(5)
		if not Dissolvenza.presente(get_tree()) or Dissolvenza.di(get_tree()).opacita() <= 0.01:
			schiarito = true
			break
	print("PC: schermo schiarito %s, nodo della prova andato %s, giocatore %s" % [schiarito,
		get_tree().root.get_node_or_null(^"QualitaAutomatica") == null, get_tree().get_first_node_in_group(&"player") != null])
	QualitaAutomatica.forza_nei_test = false
	QualitaAutomatica.misura_finta_test = Callable()
	print("PC: finito")
	Game.esci(0)

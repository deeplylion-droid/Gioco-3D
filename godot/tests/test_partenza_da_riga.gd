extends Node
## L'opzione nascosta della riga di comando del titolo (MenuPrincipale._partenza_da_riga, per il controllo "Prova su
## Vulkan" della CI): senza i suoi argomenti non fa niente. Il titolo si apre come sempre, nessun timer della prova,
## nessun registro, nessuna partenza e nessuna riga PROVA. Qui gli argomenti dopo il -- sono solo il percorso del test.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_partenza_da_riga.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const MENU := preload("res://scripts/ui/menu/menu_principale.gd")

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var argomenti := OS.get_cmdline_user_args()
	check(not Array(argomenti).any(func(a: String) -> bool: return a.begins_with("--partenza=") or a.begins_with("--resta=") \
			or a.begins_with("--esci-dopo=")), "nessun argomento della prova (%s)" % [argomenti])
	get_tree().change_scene_to_file(TITOLO)
	for i in 120:
		await get_tree().process_frame
	var sc := get_tree().current_scene
	check(sc != null and sc.get_script() == MENU, "il titolo è aperto e resta il titolo (%s)" % [sc.name if sc else "-"])
	check(MENU._riga_fatta == true, "la riga di comando è stata guardata, una volta")
	check(get_tree().root.get_node_or_null(^"PartenzaDaRiga") == null, "nessun timer della prova")
	check(MENU._registro_prova == "", "nessun registro della prova")
	check(not GameState.is_dying and GameState.player == null, "nessuna partenza: niente giocatore")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)

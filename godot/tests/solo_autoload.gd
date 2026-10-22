extends SceneTree
## Avvia il gioco solo fino agli autoload e si chiude (per test_nome_nuovo: il primo avvio col nome nuovo).


func _initialize() -> void:
	quit.call_deferred()

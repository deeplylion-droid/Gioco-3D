extends "res://tests/collaudo/partita_tunnel.gd"
## Collaudo del bambino della galleria (bambini visti di sfuggita) nella partita vera del tunnel, con lei che insegue:
## partita_tunnel.gd fino a 240 m, col MonitorBambini (piedi, contatti, sparizione, pipeline). Stampa anche, mentre il
## bambino si vede, la distanza di lei e se il giocatore è stato preso.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_bambini_tunnel.gd <cartella>

const MON := preload("res://tests/collaudo/monitor_bambini.gd")
var mon: Node
var _finito := false


func _process(_d: float) -> void:
	if cart == "" or sott == null or not is_instance_valid(sott):
		return
	if mon == null:
		mon = MON.new(cart.path_join("bambino"))
		add_child(mon)
	var b := sott.find_child("BambinoGalleria", true, false) as BambinoSfuggita
	if b and Engine.get_process_frames() % 30 == 0 and b.stato != BambinoSfuggita.Stato.ATTESA and b.stato != BambinoSfuggita.Stato.FINITO:
		mon.evento("bambino %s; giocatore a s %.1f, lei a %.1f m dietro (%s), prese %d" % [BambinoSfuggita.Stato.keys()[b.stato], s_g,
			sott._s_bersaglio - sott.lei_s, SalaSottomarino.Lei.keys()[sott.lei_stato], prese])
	if not _finito and s_g > 240.0:
		_finito = true
		mon.evento("a 240 m: bambino %s, morsi %d, prese %d, respinte %d" % [BambinoSfuggita.Stato.keys()[b.stato] if b else "-", morsi, prese, respinte])
		get_tree().quit()

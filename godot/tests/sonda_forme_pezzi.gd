extends Node
## Sonda: le forme del tunnel calcolate a pezzi nel gioco vero (F9 Inseguimento, FormeTunnel.prepara_a_pezzi mentre il
## tunnel si prepara) uguali a quelle calcolate tutte subito (FormeTunnel.prepara) su un tunnel nuovo costruito accanto.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_forme_pezzi.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), "inseguimento")
	var t0 := Time.get_ticks_msec()
	while not AttesaZone.e_pronta(&"tunnel") and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
	var s := get_tree().current_scene
	var tun := s.get(&"sala_sottomarino") as SalaSottomarino
	var a_pezzi: Array = FormeTunnel._cache.get(tun.get_instance_id(), [])
	FormeTunnel.lascia_tenute()
	var nuovo := (load("res://scenes/sala/sottomarino/sala_sottomarino.tscn") as PackedScene).instantiate() as SalaSottomarino
	tun.get_parent().add_child(nuovo)
	nuovo.global_transform = tun.global_transform
	nuovo.costruisci()
	FormeTunnel.prepara(nuovo)
	var subito: Array = FormeTunnel._cache.get(nuovo.get_instance_id(), [])
	var ok := not a_pezzi.is_empty() and str(a_pezzi) == str(subito)
	print("SONDA_FORME: a pezzi %d, subito %d, uguali: %s, md5 %s" % [a_pezzi.size(), subito.size(), ok, str(a_pezzi).md5_text()])
	Game.esci(0 if ok else 1)

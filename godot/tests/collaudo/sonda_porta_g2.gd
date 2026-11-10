extends Node
## Sonda di grafica-2 (ricontrollo di lavoro/torre-robusta, 0.3.25): la porta tagliafuoco della scena dello squalo nel
## gioco vero, da Nuova partita (titolo, spot, caricamento) e da F9 Inizio (menu di prova: la stessa nuova partita).
## Stampa dove sta il perno, a chi è attaccata la porta, la collisione, l'angolo della porta e quanto la porta si stacca
## dal perno (la sua posizione nel sistema del perno: deve restare ferma) dall'inizio alla fine della scena, i nodi
## orfani e quanti perni ci sono.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_porta_g2.gd <nuova|f9>

const TITOLO := "res://scenes/ui/menu_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _perni() -> int:
	return get_tree().root.find_children("PernoPortaTagliafuoco", "", true, false).size()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var via: String = a[1] if a.size() > 1 else "nuova"
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.valori["qualita_provata"] = true
	Grafica.valori["calibrato"] = true
	RisveglioSqualo.forza_nei_test = true
	get_tree().change_scene_to_file(TITOLO)
	await _frames(30)
	var titolo := get_tree().current_scene
	print("PORTA: via %s, titolo %s" % [via, titolo.name if titolo else "-"])
	if via == "f9":
		titolo.call(&"_parti_prova", "inizio")
	else:
		titolo.call(&"_avvia_nuova_partita")
	var s: RisveglioSqualo = null
	var fino := Time.get_ticks_msec() + 900000
	while Time.get_ticks_msec() < fino:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc and String(sc.name) != "Caricamento":
			s = sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo
			if s and s.in_corso():
				break
	if s == null:
		print("PORTA: la scena non è partita")
		print("RISULTATO: 0 controlli ok, 1 falliti")
		get_tree().quit(1)
		return
	await _frames(3)
	var perno := s.get(&"_perno") as Node3D
	var porta := s.porta
	var corpo := perno.get_node_or_null(^"Collisione") if perno else null
	if corpo == null and porta:
		corpo = porta.get_node_or_null(^"Collisione")
	print("PORTA: perno %s, nell'albero %s, genitore %s, posizione %s" % [perno != null, perno.is_inside_tree() if perno else false,
		perno.get_parent().name if perno and perno.get_parent() else "-", perno.global_position if perno else Vector3.ZERO])
	print("PORTA: porta attaccata a %s; collisione %s (strato %d); perni nell'albero %d" % [porta.get_parent().name if porta else "-",
		corpo != null, (corpo as CollisionObject3D).collision_layer if corpo else -1, _perni()])
	var locale0 := perno.global_transform.affine_inverse() * porta.global_transform if perno and porta else Transform3D()
	var stacco := 0.0
	var ultimo_gradi := -999.0
	var righe := 0
	var max_gradi := 0.0
	while s.in_corso():
		await get_tree().process_frame
		if not is_instance_valid(perno) or not is_instance_valid(porta):
			print("PORTA: perno o porta liberati durante la scena")
			break
		var loc := perno.global_transform.affine_inverse() * porta.global_transform
		stacco = maxf(stacco, loc.origin.distance_to(locale0.origin))
		var gradi := rad_to_deg(perno.rotation.y)
		max_gradi = maxf(max_gradi, absf(gradi))
		if absf(gradi - ultimo_gradi) >= 10.0:
			print("PORTA: a %.2f s perno a %.1f gradi" % [float(s.get(&"_t")), gradi])
			ultimo_gradi = gradi
			righe += 1
	await _frames(30)
	print("PORTA: alla fine della scena perno a %.1f gradi (massimo %.1f), porta attaccata a %s, la porta si è staccata dal perno al più di %.4f m" % [
		rad_to_deg(perno.rotation.y) if is_instance_valid(perno) else 0.0, max_gradi,
		porta.get_parent().name if is_instance_valid(porta) else "-", stacco])
	print("PORTA: perni nell'albero %d, nodi orfani %d" % [_perni(), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	print("RISULTATO: 1 controlli ok, 0 falliti")
	get_tree().quit()

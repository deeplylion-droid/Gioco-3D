extends Node
## L'agnellino della scala di C2 (tappa 7 B) inseguito dal giocatore che corre: compare col blackout salendo la
## rampa F2, scappa quando ti avvicini, corre piano con le zampe a tempo e si infila nella grata sfondata del
## muro di C2 prima che tu lo raggiunga; quando sparisce è tutto dentro la cavità buia. Mentre si infila non
## passa mai attraverso il muro, il pavimento o la roba accatastata, e il giocatore nel buco non ci entra, neanche accucciato.
## Prova della v0.3.5: "sgambetta come una pazza, facciamo che invece corre piano ed entra in un buco nel muro
## invece che sparire".
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_agnellino.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Da dove si parte (la rampa F2) e la strada di corsa fino al buco, nelle coordinate della scena dei tecnici.
const PARTENZA := Vector3(49.5, 3.625, -7.8)
const CORSA := [Vector3(44.55, 7.25, -7.8), Vector3(44.55, 7.25, -4.0), Vector3(44.55, 9.05, 2.0), Vector3(44.55, 9.05, 4.3)]
## Il buco (come tools/blender/ambienti2_raccordo.py): largo 0,85, alto 0,9, nel muro spesso 0,3.
const BUCO_MEZZA_LARGHEZZA := 0.425
const BUCO_ALTO := 0.9
const MURO := 0.3

var p: Player
var tec: Node3D
var ag: AgnellinoScala
var _comparso := false
var _sparito_a := -1
var _fuori_dalla_cavita := false
var _corso := 0
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	tec = get_tree().current_scene.get_node("Tecnici")
	ag = tec.get_node_or_null("AgnellinoScala") as AgnellinoScala
	check(ag != null, "c'è l'agnellino della scala")
	if ag == null:
		_fine()
		return
	await _frames(30)
	check(ag.bambino == null, "prima del blackout non compare")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	p.teleport(tec.to_global(PARTENZA) + Vector3(0, 0.05, 0), PI * 0.5, 0.0)
	await _frames(10)
	var b: Bambino = null
	var minima := INF
	var tempo_anim := 0.0
	var tempo_atteso := 0.0
	var compenetra := ""
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var tappa := 0
	for i in 1500:
		if b == null and ag.bambino and is_instance_valid(ag.bambino):
			b = ag.bambino
			_comparso = true
			b.sparito.connect(_su_sparito.bind(b))
		if tappa < CORSA.size():
			var t: Vector3 = tec.to_global(CORSA[tappa])
			var d := t - p.global_position
			if Vector2(d.x, d.z).length() < 0.35:
				tappa += 1
				continue
			p.set_look(atan2(-d.x, -d.z), 0.0)
		elif _sparito_a >= 0:
			break
		if b and is_instance_valid(b) and b.visible:
			minima = minf(minima, b.global_position.distance_to(p.global_position))
			if b.modalita == Bambino.Modalita.SCAPPA:
				for ap in b.find_children("*", "AnimationPlayer", true, false):
					tempo_anim = (ap as AnimationPlayer).speed_scale
				# (l'animazione va alla velocità del corpo, misurata sui piedi: Bambino._passo_animazione)
				tempo_atteso = clampf(b._vel / b.vel_corsa_anim, 0.25, 1.6)
				if compenetra == "":
					compenetra = _compenetra(b)
		await get_tree().physics_frame
		_corso += 1
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	check(_comparso, "salendo la rampa F2 l'agnellino compare in cima alla scala di C2")
	check(is_equal_approx(ag.velocita_corsa, 3.0) and tempo_anim > 0.0 and absf(tempo_anim - tempo_atteso) < 0.01,
			"corre piano (%.1f m/s), con l'animazione a tempo (velocità %.2f)" % [ag.velocita_corsa, tempo_anim])
	check(_sparito_a >= 0, "si infila nel buco e sparisce (dopo %d frame di corsa)" % _sparito_a)
	check(_sparito_a >= 0 and not _fuori_dalla_cavita, "quando sparisce è tutto dentro la cavità, al buio")
	check(compenetra == "", "correndo e infilandosi non passa attraverso muri, pavimento e roba accatastata %s" % compenetra)
	check(minima > 1.2, "correndo non lo si raggiunge (il più vicino: %.1f m)" % minima)
	await _frames(10)
	check(ag.bambino == null or not is_instance_valid(ag.bambino), "non c'è più")
	# il giocatore nel buco non ci entra, neanche accucciato
	var dir := tec.global_basis * Vector3(1, 0, 0)
	p.teleport(tec.to_global(Vector3(44.2, 9.1, ag.buco_z)), atan2(-dir.x, -dir.z), 0.0)
	Input.action_press(&"crouch")
	await _frames(30)
	Input.action_press(&"move_forward")
	var massima := -INF
	for i in 150:
		p.set_look(atan2(-dir.x, -dir.z), 0.0)
		massima = maxf(massima, tec.to_local(p.global_position).x)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")
	check(massima > 44.7 and massima < ag.muro_x, "nel buco il giocatore non entra, neanche accucciato (arriva a x %.2f, il muro è a %.2f)" % [massima, ag.muro_x])
	_fine()


## Punti del corpo (lungo il suo asse alto, piegato quando si infila): dentro lo spessore del muro solo dentro
## il buco, mai sotto il pavimento.
func _compenetra(b: Bambino) -> String:
	for h in range(0, 14):
		for l in range(-2, 3):
			var w: Vector3 = _piedi(b) + b.global_basis.y * (h * 0.1) + b.global_basis.x * (l * 0.1)
			var q := tec.to_local(w)
			var alto := q.y - ag.posizione.y
			if alto < -0.03:
				return "(sotto il pavimento: %s)" % q
			if q.x > ag.muro_x and q.x < ag.muro_x + MURO:
				if alto > BUCO_ALTO or absf(q.z - ag.buco_z) > BUCO_MEZZA_LARGHEZZA:
					return "(nel muro: %s)" % q
			# e dentro niente di solido (la roba accatastata ai muri, gli spigoli del buco)
			if h > 0:
				var pq := PhysicsPointQueryParameters3D.new()
				pq.position = w
				pq.exclude = [p.get_rid()]
				var dentro := p.get_world_3d().direct_space_state.intersect_point(pq, 1)
				if not dentro.is_empty():
					return "(dentro %s: %s)" % [dentro[0].collider.name, q]
	return ""


## I piedi del modello (quando si piega i modelli si alzano un po' sopra il nodo).
func _piedi(b: Bambino) -> Vector3:
	var m := b.get_node_or_null(^"Calmo") as Node3D
	return m.global_position if m else b.global_position


## Quando sparisce: tutti i punti del corpo oltre il muro, dentro la cavità.
func _su_sparito(b: Bambino) -> void:
	_sparito_a = _corso
	for h in range(0, 14):
		for l in range(-2, 3):
			var w: Vector3 = _piedi(b) + b.global_basis.y * (h * 0.1) + b.global_basis.x * (l * 0.1)
			if tec.to_local(w).x < ag.muro_x + MURO:
				_fuori_dalla_cavita = true
				print("  fuori dalla cavità quando sparisce: ", tec.to_local(w))
				return


func _fine() -> void:
	print("risultato: %d ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

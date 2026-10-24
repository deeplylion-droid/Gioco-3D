extends Node
## Test dell'oblò con lei dietro il vetro (ObloLei, GDD "Jilly dietro gli oblò"), col Player vero:
## - prima del blackout lei non c'è;
## - compare solo col vetro fuori dalla vista, mai sotto gli occhi;
## - resta finché non la vedi bene, e intanto l'occhio ti segue (anche se ti sposti);
## - se guardi via si stacca piano e sparisce; una volta sola: guardando di nuovo non c'è più, neanche ripartendo;
## - se ti avvicini si stacca anche prima di averla vista bene;
## - se te ne vai senza averla vista va via senza farsi vedere e la volta dopo ricompare;
## - nessuna compenetrazione: lei (le ossa, o la testa di prova) resta dentro la vasca, dietro il vetro, anche mentre
##   si stacca.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_oblo_lei.gd

const PLAYER := "res://scenes/player/player.tscn"

var p: Player
var ok := 0
var falliti := 0
## Il punto di lei più fuori dalla vasca visto finora (metri; negativo: dentro).
var _fuori_max := -INF
var _fuori_dove := ""
var _oblo_misurato: ObloLei


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var mondo := Node3D.new()
	mondo.name = "Prova"
	get_tree().root.add_child(mondo)
	_pavimento(mondo)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	get_tree().root.add_child(p)
	await _frames(10)
	GameState.luci = GameState.Luci.PRIMA_DEL_RISVEGLIO
	await _vista_e_via(mondo)
	await _avvicinati(mondo)
	await _te_ne_vai(mondo)
	print("RISULTATO: %d controlli ok, %d falliti" % [ok, falliti])
	get_tree().quit(1 if falliti else 0)


# --- aiuti ---------------------------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_misura_lei()


func _secondi(s: float) -> void:
	await _frames(int(s * 60.0))


func _controlla(cond: bool, cosa: String) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa)


func _pavimento(mondo: Node3D) -> void:
	var c := StaticBody3D.new()
	c.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(60, 0.2, 60)
	cs.shape = b
	c.add_child(cs)
	mondo.add_child(c)
	c.position = Vector3(0, -0.1, 0)


## Un oblò nel muro x = [param x0] (il nodo sulla faccia del muro, la normale verso +Z), centro a 1,5 m, con la vasca
## e le distanze di [param opzioni] (quelle dei corridoi della Risalita).
func _oblo(mondo: Node3D, x0: float, posa: String, opzioni := {}) -> ObloLei:
	var o := ObloLei.new()
	o.name = "Oblo_%s" % posa
	o.posa = posa
	for k in opzioni:
		o.set(k, opzioni[k])
	o.position = Vector3(x0, 1.5, 0.0)
	o.zona = AABB(Vector3(x0 - 6.0, -1.0, 0.0), Vector3(12.0, 4.0, 12.0))
	# (gli oblò di prova stanno a 20 m l'uno dall'altro: le vasche larghe fino a 9,6 m non si toccano)
	mondo.add_child(o)
	return o


## Il giocatore a [param pos] (sul pavimento) che guarda [param verso] (un punto).
func _metti(pos: Vector3, verso: Vector3) -> void:
	p.teleport(pos)
	await _frames(2)
	p.look_at_point(verso)
	await _frames(2)


## Lei è dentro la vasca? Il punto più fuori delle sue ossa, in metri oltre l'interno della vasca (negativo: dentro), nel
## sistema dell'oblò.
func _fuori(o: ObloLei) -> float:
	if o.lei == null or not is_instance_valid(o.lei):
		return -INF
	var punti := PackedVector3Array()
	var nomi := PackedStringArray()
	for sk in o.lei.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		for b in s.get_bone_count():
			punti.append(s.global_transform * s.get_bone_global_pose(b).origin)
			nomi.append(s.get_bone_name(b))
	if punti.is_empty():
		punti.append(o.lei.get_eye_position())
		nomi.append("occhio")
	var peggio := -INF
	var l := o.vasca_larga * 0.5
	var h := ObloLei.PIASTRA * 0.5
	var z1 := -o.spessore_muro - ObloLei.STACCO_VASCA - o.vasca_fonda
	for i in punti.size():
		var lq := o.to_local(punti[i])
		# davanti: il vetro (dalla parte dell'acqua) dentro la piastra, la faccia della vasca fuori
		var z0 := -o.spessore_muro if absf(lq.x) < h and absf(lq.y) < h else -o.spessore_muro - ObloLei.STACCO_VASCA
		var f := maxf(maxf(absf(lq.x - o.vasca_spostata) - l, lq.z - z0), maxf(z1 - lq.z, maxf(-o.vasca_sotto - lq.y, lq.y - o.vasca_sopra)))
		if f > peggio:
			peggio = f
			if f > _fuori_max:
				_fuori_dove = "%s in (%.2f, %.2f, %.2f), stato %d" % [nomi[i], lq.x, lq.y, lq.z, o.stato]
	return peggio


var _lei_vista: Node = null
var _fotogrammi_lei := 0


## (dal terzo fotogramma dopo che compare: nel primo l'animazione non ha ancora messo la posa)
func _misura_lei() -> void:
	if _oblo_misurato == null:
		return
	if _oblo_misurato.lei != _lei_vista:
		_lei_vista = _oblo_misurato.lei
		_fotogrammi_lei = 0
	_fotogrammi_lei += 1
	if _fotogrammi_lei > 3:
		_fuori_max = maxf(_fuori_max, _fuori(_oblo_misurato))


## L'angolo fra dove guarda l'occhio di lei e la camera del giocatore (gradi).
func _angolo_occhio(o: ObloLei) -> float:
	if o.lei == null or o.lei.lei == null:
		return 180.0
	var occhio := o.lei.get_eye_position()
	var dir := o.lei.get_eye_direction()
	return rad_to_deg(dir.angle_to(p.camera.global_position - occhio))


# --- i casi --------------------------------------------------------------------------------------------------------

func _vista_e_via(mondo: Node3D) -> void:
	print("Compare, ti guarda, se ne va quando guardi via, una volta sola")
	var o := _oblo(mondo, 0.0, "schiacciata", {"vasca_larga": 6.6, "vasca_fonda": 5.6, "vasca_sotto": 8.0})
	_oblo_misurato = o
	await _frames(5)
	var vetro := o.global_position
	# prima del blackout: niente
	await _metti(Vector3(0, 0, 4.0), vetro + Vector3(0, 0, 20.0))
	await _secondi(1.0)
	_controlla(o.stato == ObloLei.Stato.ATTESA and o.lei == null, "prima del blackout lei non c'è")
	# col vetro davanti agli occhi non compare
	await _metti(Vector3(0, 0, 4.0), vetro)
	GameState.luci = GameState.Luci.BLACKOUT
	await _secondi(1.5)
	_controlla(o.stato == ObloLei.Stato.ATTESA and o.lei == null, "col vetro in vista non compare (mai sotto gli occhi)")
	# girato dall'altra parte compare
	await _metti(Vector3(0, 0, 4.0), vetro + Vector3(0, 0, 20.0))
	await _secondi(0.5)
	_controlla(o.stato == ObloLei.Stato.PRONTA and o.lei != null, "girato dall'altra parte, lei compare dietro il vetro")
	# la guardi: resta, e dopo un po' l'hai vista
	await _metti(Vector3(0, 0, 4.0), vetro)
	await _secondi(0.6)
	_controlla(o.stato == ObloLei.Stato.PRONTA, "guardandola resta (non va via appena la vedi)")
	await _secondi(1.0)
	_controlla(o.stato == ObloLei.Stato.VISTA, "dopo averla guardata 1,2 s l'hai vista")
	await _secondi(0.8)
	var a1 := _angolo_occhio(o)
	_controlla(a1 < 25.0, "l'occhio guarda il giocatore (%.0f gradi)" % a1)
	# ti sposti di lato continuando a guardarla: l'occhio ti segue e lei resta
	await _metti(Vector3(2.2, 0, 3.2), vetro)
	await _secondi(1.2)
	var a2 := _angolo_occhio(o)
	_controlla(a2 < 25.0 and o.stato == ObloLei.Stato.VISTA, "spostandosi, l'occhio segue (%.0f gradi) e lei resta" % a2)
	# guardi via: si stacca piano (non sparisce di colpo) e poi non c'è più
	await _metti(Vector3(2.2, 0, 3.2), vetro + Vector3(0, 0, 20.0))
	await _secondi(0.6)
	_controlla(o.stato == ObloLei.Stato.VIA and o.lei != null, "guardando via si stacca, ancora lì per sparire piano")
	await _secondi(3.5)
	_controlla(o.stato == ObloLei.Stato.FINITA and o.lei == null, "poi è sparita")
	await _metti(Vector3(0, 0, 4.0), vetro + Vector3(0, 0, 20.0))
	await _secondi(1.0)
	await _metti(Vector3(0, 0, 4.0), vetro)
	await _secondi(1.0)
	_controlla(o.stato == ObloLei.Stato.FINITA and o.lei == null, "una volta sola: girandosi di nuovo non c'è più")
	var s := o.save_state()
	o.load_state(s)
	_controlla(bool(s.get("finito", false)) and o.stato == ObloLei.Stato.FINITA, "lo stato finito si salva coi checkpoint")
	_controlla(_fuori_max <= 0.0, "lei è sempre rimasta dentro la vasca, dietro il vetro (peggio %.2f m: %s)" % [_fuori_max, _fuori_dove])
	_oblo_misurato = null
	o.queue_free()
	await _frames(3)


func _avvicinati(mondo: Node3D) -> void:
	print("Se ti avvicini si stacca")
	var o := _oblo(mondo, 20.0, "sbircia", {"vasca_larga": 2.56, "vasca_spostata": 0.2, "vasca_fonda": 5.6, "vasca_sotto": 7.0, "vicino": 0.9, "lato_sbircia": 1.0})
	_oblo_misurato = o
	_fuori_max = -INF
	await _frames(5)
	var vetro := o.global_position
	await _metti(Vector3(20.0, 0, 5.0), vetro + Vector3(0, 0, 20.0))
	await _secondi(0.4)
	_controlla(o.stato == ObloLei.Stato.PRONTA, "compare girati dall'altra parte")
	# ti giri e vai dritto al vetro, prima di averla vista bene
	await _metti(Vector3(20.0, 0, o.vicino - 0.35), vetro)
	await _secondi(0.3)
	_controlla(o.stato == ObloLei.Stato.VIA, "avvicinandosi sotto %.1f m si stacca subito" % o.vicino)
	await _secondi(3.5)
	_controlla(o.stato == ObloLei.Stato.FINITA and o.lei == null, "e sparisce")
	_controlla(_fuori_max <= 0.0, "anche qui sempre dentro la vasca (peggio %.2f m: %s)" % [_fuori_max, _fuori_dove])
	_oblo_misurato = null
	o.queue_free()
	await _frames(3)


func _te_ne_vai(mondo: Node3D) -> void:
	print("Se te ne vai senza vederla, la volta dopo ricompare")
	var o := _oblo(mondo, -20.0, "capovolta", {"vasca_larga": 10.2, "vasca_spostata": -0.3, "vasca_fonda": 5.6, "vasca_sotto": 3.6, "vasca_sopra": 5.8})
	_oblo_misurato = o
	_fuori_max = -INF
	await _frames(5)
	var vetro := o.global_position
	await _metti(Vector3(-20.0, 0, 5.0), vetro + Vector3(0, 0, 20.0))
	await _secondi(0.4)
	_controlla(o.stato == ObloLei.Stato.PRONTA, "compare")
	await _metti(Vector3(-20.0, 0, 16.0), vetro + Vector3(0, 0, 40.0))
	await _secondi(0.5)
	_controlla(o.stato == ObloLei.Stato.ATTESA and o.lei == null, "uscito dalla zona senza vederla: va via")
	await _metti(Vector3(-20.0, 0, 5.0), vetro + Vector3(0, 0, 20.0))
	await _secondi(0.4)
	_controlla(o.stato == ObloLei.Stato.PRONTA and o.lei != null, "rientrando ricompare")
	await _metti(Vector3(-20.0, 0, 5.0), vetro)
	await _secondi(2.0)
	o.via()
	await _secondi(3.5)
	_controlla(o.stato == ObloLei.Stato.FINITA and o.lei == null, "via() la manda via piano (per la torre)")
	_controlla(_fuori_max <= 0.0, "a testa in giù sempre dentro la vasca (peggio %.2f m: %s)" % [_fuori_max, _fuori_dove])
	_oblo_misurato = null
	o.queue_free()
	await _frames(3)

extends Node
## Test del canto di sirena di lei nel tunnel (addon audio, classe Statua, richiesta dell'utente del 25 ottobre).
## Finché l'utente non sceglie la variante le frasi (lei_tunnel_canto) non sono nel catalogo: il test usa al loro
## posto un suono che c'è (lei_insegue_sb1) per provare quando parte e quando tace:
## - senza le frasi nel catalogo non suona niente e non ci sono errori;
## - mentre insegue (insegue_aperta, insegue_morde) parte entro 4 s, una frase alla volta, con 3-7 s di pausa fra
##   la fine di una e l'inizio della successiva, dalla sua bocca (VoceLei);
## - tace quando si ritrae (getto), quando prende (la morte), quando sbatte sul portello e quando sparisce;
## - dopo la morte e la ripartenza da un checkpoint (sparita, poi riemerge e insegue) riparte, una frase alla volta;
## - se lei sparisce dalla scena a metà frase, la frase si spegne.
## (Senza uscita audio i suoni sono finti e i lettori della riserva si riprendono subito: qui una frase può finire
## prima che nel gioco, dove il lettore suona davvero e non viene ripreso. La pausa conta dalla fine della frase.)
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_canto_tunnel.gd

const PROVA := &"lei_insegue_sb1"

var lei: MedusaAffacciata
var ap: AnimationPlayer
var st
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var classe_statua = (Audio.get_script() as GDScript).get(&"Statua")
	lei = MedusaAffacciata.new()
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.animazioni_inseguimento = true
	add_child(lei)
	await _frames(3)
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	for x in Audio._attivi:
		if x.get(&"n") == lei:
			st = x
	check(st != null, "la voce di lei c'è (Statua)")
	if st == null:
		_fine()
		return

	print("Senza le frasi nel catalogo")
	var vero: StringName = classe_statua.canto_nome
	classe_statua.canto_nome = &"lei_tunnel_canto_che_non_c_e"
	ap.play(&"inseguimento/insegue_aperta")
	await _secondi(6.0)
	check(not st.canta(), "mentre insegue non suona niente")
	classe_statua.canto_nome = PROVA

	print("Mentre insegue")
	var partenze := await _guarda(4.2)
	check(partenze.size() == 1, "parte entro 4 s (%d frasi)" % partenze.size())
	check(st.canto != null and (st.canto as Node3D).global_position.distance_to(lei.get_node(^"VoceLei").global_position) < 0.05,
		"dalla sua bocca (VoceLei)")
	var giro := await _guarda(24.0)
	check(giro.size() >= 2, "insegue per 24 s: %d frasi" % giro.size())
	check(_pause_giuste(giro), "una frase alla volta, 3-7 s di pausa fra una e l'altra %s" % [giro])
	ap.play(&"inseguimento/insegue_morde")
	var morde := await _guarda(10.0)
	check(morde.size() >= 1, "anche quando morde vicina (%d)" % morde.size())

	print("Quando tace")
	for anim in [&"inseguimento/ritrae", &"inseguimento/presa", &"inseguimento/schianto"]:
		ap.play(&"inseguimento/insegue_aperta")
		await _fino_a_che_canta(12.0)
		ap.play(anim)
		await _secondi(0.7)
		check(not st.canta(), "%s: la frase si spegne (0,5 s)" % anim)
		var dopo := await _guarda(3.0)
		check(dopo.is_empty(), "%s: nessuna frase nuova" % anim)
	ap.play(&"inseguimento/insegue_aperta")
	await _fino_a_che_canta(12.0)
	lei.visible = false
	await _secondi(0.7)
	check(not st.canta(), "sparita (via): la frase si spegne")
	check((await _guarda(5.0)).is_empty(), "sparita: nessuna frase nuova")

	print("Morte e ripartenza")
	lei.visible = true
	ap.play(&"inseguimento/insegue_aperta")
	await _fino_a_che_canta(12.0)
	ap.play(&"inseguimento/presa")
	await _secondi(2.0)
	lei.visible = false       # (la ripartenza dal checkpoint: via(), poi riemergi())
	await _secondi(1.0)
	lei.visible = true
	ap.play(&"inseguimento/riemerge")
	var riemerge := await _guarda(1.5)
	check(riemerge.is_empty(), "mentre riemerge non canta")
	ap.play(&"inseguimento/insegue_aperta")
	var ripartito := await _guarda(16.0)
	check(ripartito.size() >= 1 and ripartito[0][0] < 4.1, "dopo la ripartenza riparte entro 4 s %s" % [ripartito])
	check(_pause_giuste(ripartito), "e una frase alla volta %s" % [ripartito])

	print("Lei sparisce dalla scena a metà frase")
	await _fino_a_che_canta(12.0)
	var lettore: Node = st.canto
	var partito: float = st.canto_partito
	lei.queue_free()
	await _secondi(0.6)
	check(not (is_instance_valid(lettore) and lettore.get(&"playing") and float(lettore.get_meta(&"partito", -2.0)) == partito),
		"la frase si spegne")
	classe_statua.canto_nome = vero
	_fine()


## Guarda per [param t] secondi: i tempi (dall'inizio) in cui parte una frase nuova, e quanto è durata ognuna:
## [[inizio, fine], ...]. Controlla anche che non ce ne siano mai due insieme.
func _guarda(t: float) -> Array:
	var out := []
	var prima := -1.0
	var era := false
	for i in int(round(t * 60.0)):
		await get_tree().process_frame
		if not is_instance_valid(lei):
			break
		var ora: bool = st.canta()
		var p: float = st.canto_partito
		var tempo := (i + 1) / 60.0
		if ora and (not era or p != prima):
			out.append([tempo, -1.0])
			prima = p
		if era and not ora and not out.is_empty():
			out[-1][1] = tempo
		era = ora
	return out


func _pause_giuste(frasi: Array) -> bool:
	for i in range(1, frasi.size()):
		var fine_prima: float = frasi[i - 1][1]
		if fine_prima < 0.0:
			return false
		var pausa: float = frasi[i][0] - fine_prima
		if pausa < 2.95 or pausa > 7.1:
			return false
	return true


func _fino_a_che_canta(t: float) -> void:
	for i in int(round(t * 60.0)):
		if st.canta():
			return
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Con --fixed-fps 60: t secondi.
func _secondi(t: float) -> void:
	await _frames(int(round(t * 60.0)))


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)

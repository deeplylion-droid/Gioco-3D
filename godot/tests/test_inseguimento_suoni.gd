extends Node
## Test del cuore del giocatore e del ritmo d'inseguimento nel tunnel (addon audio, classe Statua; suoni di
## assets_src/audio/genera_inseguimento.py, proposte del 25 ottobre sera):
## - i suoni ci sono (5 battiti, 6 colpi);
## - prima che lei insegua (riemerge) niente;
## - mentre insegue: lontana (18 m) il cuore a circa 72 battiti al minuto e il ritmo rado, vicina (8 m) il cuore a circa
##   128 e il ritmo fitto, e più forti;
## - mentre si ritrae dal getto il cuore rallenta e il ritmo si dirada; quando prende o sparisce tacciono;
## - il cuore sta 5 dB sotto il canto e il ritmo è 3,5 dB più basso, come nell'esempio approvato (collaudo del 29 ottobre);
## - cuore_attivo e ritmo_attivo spengono l'uno o l'altro (per la scelta dell'utente).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_inseguimento_suoni.gd

const Catalogo := preload("res://addons/audio/catalogo.gd")
const CUORE := &"cuore_battito"
const RITMO := &"inseguimento_colpo"

var lei: MedusaAffacciata
var ap: AnimationPlayer
var p: Node3D
var st
var _vol_max := [-80.0, -80.0]   # il volume più alto di un battito e di un colpo nell'ultimo _conta
var _colpi_pieni := 0            # i colpi del ritmo nell'ultimo _conta senza i doppi (5,2 dB più piano)
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var classe_statua = (Audio.get_script() as GDScript).get(&"Statua")
	check((Catalogo.SUONI.get(CUORE, []) as Array).size() == 5 and (Catalogo.SUONI.get(RITMO, []) as Array).size() == 6,
		"i suoni ci sono: 5 battiti e 6 colpi")
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	p.global_position = Vector3(0, 0, 0)
	lei = MedusaAffacciata.new()
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.animazioni_inseguimento = true
	add_child(lei)
	await _frames(5)
	GameState.player = p
	p.process_mode = Node.PROCESS_MODE_DISABLED     # (fermo: conta solo la distanza)
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	for x in Audio._attivi:
		if x.get(&"n") == lei:
			st = x
	check(st != null, "la voce di lei c'è (Statua)")
	if st == null:
		_fine()
		return

	print("Prima che insegua")
	lei.global_position = Vector3(0, 0, -12)
	ap.play(&"inseguimento/riemerge")
	var c := await _conta(3.0)
	check(c[0] == 0 and c[1] == 0, "mentre riemerge niente cuore né ritmo (%d, %d)" % c)

	print("Lontana e vicina")
	lei.global_position = Vector3(0, 0, -18)
	ap.play(&"inseguimento/insegue_aperta")
	await _secondi(2.0)
	var lontana := await _conta(20.0)
	var vol_lontana: Array = _vol_max.duplicate()
	var pieni_lontana := _colpi_pieni
	lei.global_position = Vector3(0, 0, -8)
	await _secondi(9.0)                                 # (il cuore accelera piano)
	var vicina := await _conta(20.0)
	var vol_vicina: Array = _vol_max.duplicate()
	var pieni_vicina := _colpi_pieni
	print("  lontana: %d battiti e %d colpi in 20 s; vicina: %d e %d" % [lontana[0], lontana[1], vicina[0], vicina[1]])
	check(lontana[0] >= 22 and lontana[0] <= 26, "lontana il cuore a circa 72 al minuto (%d in 20 s)" % lontana[0])
	check(vicina[0] >= 40 and vicina[0] <= 45, "vicina il cuore a circa 128 al minuto (%d in 20 s)" % vicina[0])
	# (i colpi pieni, senza i doppi che arrivano a caso una volta su cinque: lontana uno ogni 1,5 s × 0,8-1,25, cioè
	# 10,7-16,7 in 20 s; vicina uno ogni 0,55 s × 0,8-1,25, cioè 29-45. Contando anche i doppi una volta usciva 20 da
	# lontana: CI di lavoro/audio-chiusura, 29 ottobre)
	check(pieni_lontana >= 10 and pieni_lontana <= 17, "lontana il ritmo rado (%d colpi pieni in 20 s, %d coi doppi)" % [pieni_lontana, lontana[1]])
	check(pieni_vicina >= 28 and pieni_vicina <= 46, "vicina il ritmo fitto (%d colpi pieni in 20 s, %d coi doppi)" % [pieni_vicina, vicina[1]])
	check(vol_vicina[0] > vol_lontana[0] + 6.0, "vicina il cuore più forte (%.1f contro %.1f dB)" % [vol_vicina[0], vol_lontana[0]])
	# sotto il canto come nell'esempio approvato: a 8 m il battito a -5 dB, il canto (lei_tunnel_canto) a 0 (29 ottobre)
	check(vol_vicina[0] <= -5.0 and vol_vicina[0] >= -6.0, "vicina il cuore 5 dB sotto il canto, come nell'esempio (%.1f dB)" % vol_vicina[0])
	check(vol_vicina[1] <= -3.5 and vol_vicina[1] >= -4.0, "vicino il ritmo 3,5 dB più basso, come nell'esempio (%.1f dB)" % vol_vicina[1])

	print("Il getto: si ritrae")
	ap.play(&"inseguimento/ritrae")
	var bpm_prima: float = st.bpm
	var ritrae := await _conta(2.0)
	check(st.bpm < bpm_prima - 4.0, "mentre si ritrae il cuore rallenta (%.0f -> %.0f al minuto)" % [bpm_prima, st.bpm])
	check(ritrae[1] <= 4, "e il ritmo si dirada (%d colpi in 2 s)" % ritrae[1])

	print("Quando tace")
	for anim in [&"inseguimento/presa", &"inseguimento/schianto"]:
		ap.play(&"inseguimento/insegue_aperta")
		await _secondi(1.0)
		ap.play(anim)
		await _frames(2)
		var zitto := await _conta(3.0)
		check(zitto[0] == 0 and zitto[1] == 0, "%s: niente cuore né ritmo (%d, %d)" % [anim, zitto[0], zitto[1]])
	ap.play(&"inseguimento/insegue_aperta")
	await _secondi(1.0)
	lei.visible = false
	var sparita := await _conta(3.0)
	check(sparita[0] == 0 and sparita[1] == 0, "sparita: niente cuore né ritmo (%d, %d)" % sparita)
	lei.visible = true

	print("Le scelte")
	classe_statua.cuore_attivo = false
	var senza_cuore := await _conta(5.0)
	check(senza_cuore[0] == 0 and senza_cuore[1] > 0, "solo il ritmo (%d, %d)" % senza_cuore)
	classe_statua.cuore_attivo = true
	classe_statua.ritmo_attivo = false
	var senza_ritmo := await _conta(5.0)
	check(senza_ritmo[0] > 0 and senza_ritmo[1] == 0, "solo il cuore (%d, %d)" % senza_ritmo)
	classe_statua.ritmo_attivo = true
	_fine()


## I battiti e i colpi in [param t] secondi. Intanto, fotogramma per fotogramma, il volume più alto dato a un battito e
## a un colpo fatti partire ([member _vol_max]): così si legge il volume dei colpi pieni, e non quello dell'ultimo lettore
## della riserva, che a volte è il colpo doppio, 5,2 dB più piano (test instabile sulla CI di lavoro/torre-rosso, 29
## ottobre: -8,7 dB invece di -3,5).
func _conta(t: float) -> Array:
	var c0 := int(Audio.conteggio.get(CUORE, 0))
	var r0 := int(Audio.conteggio.get(RITMO, 0))
	_vol_max = [-80.0, -80.0]
	var flussi := [Audio.stream_di(CUORE), Audio.stream_di(RITMO)]
	# (senza uscita audio i lettori della riserva si riprendono subito: un colpo nuovo si riconosce perché il suo lettore
	# cambia volume o momento di partenza, il meta "finto_fino")
	var prima := {}
	var volumi_ritmo: Array[float] = []
	for pl in Audio.find_children("*", "AudioStreamPlayer", true, false):
		prima[pl] = [pl.get(&"stream"), pl.get(&"volume_db"), pl.get_meta(&"finto_fino", -1.0)]
	for i in int(round(t * 60.0)):
		await get_tree().process_frame
		for pl in Audio.find_children("*", "AudioStreamPlayer", true, false):
			var ora := [pl.get(&"stream"), pl.get(&"volume_db"), pl.get_meta(&"finto_fino", -1.0)]
			var k := flussi.find(ora[0])
			if k >= 0 and ora != prima.get(pl, []):
				_vol_max[k] = maxf(_vol_max[k], float(ora[1]))
				if k == 1:
					volumi_ritmo.append(float(ora[1]))
			prima[pl] = ora
	# i colpi pieni: quelli al volume più alto (i doppi sono 5,2 dB sotto)
	_colpi_pieni = volumi_ritmo.filter(func(v): return v > _vol_max[1] - 2.6).size()
	return [int(Audio.conteggio.get(CUORE, 0)) - c0, int(Audio.conteggio.get(RITMO, 0)) - r0]


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


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

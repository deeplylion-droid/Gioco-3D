extends Node
## Test della voce di lei nell'inseguimento (addon audio, classe Statua; suoni di
## assets_src/audio/genera_lei_inseguimento.py): con le animazioni "inseguimento/<nome>" di MedusaAffacciata
## partono i versi giusti, sulla sua testa; colpo_grata dà un verso per colpo (tre in 1,5 s); il nuovo
## verso taglia quello prima.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_lei_voce.gd

const SUONI := [&"lei_insegue_sale", &"lei_insegue_presa", &"lei_insegue_respinta", &"lei_insegue_sb1",
	&"lei_insegue_grata"]

var lei: MedusaAffacciata
var ap: AnimationPlayer
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("I suoni")
	for s: StringName in SUONI:
		check(Audio.stream_di(s) != null, "%s c'è nel catalogo" % s)
	lei = MedusaAffacciata.new()
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.animazioni_inseguimento = true
	add_child(lei)
	await _frames(3)
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(lei.get_node_or_null(^"VoceLei") is Node3D, "la voce viene dalla sua testa (VoceLei)")

	print("Le animazioni")
	for coppia in [[&"sale_dall_acqua", &"lei_insegue_sale"], [&"presa", &"lei_insegue_presa"],
			[&"respinta", &"lei_insegue_respinta"], [&"sale_dall_acqua_veloce", &"lei_insegue_sale"],
			[&"affacciata_sb1", &"lei_insegue_sb1"]]:
		var prima := int(Audio.conteggio.get(coppia[1], 0))
		ap.play(StringName("inseguimento/" + String(coppia[0])))
		await _frames(2)
		check(int(Audio.conteggio.get(coppia[1], 0)) == prima + 1, "%s: %s" % [coppia[0], coppia[1]])
	var prima_grata := int(Audio.conteggio.get(&"lei_insegue_grata", 0))
	ap.play(&"inseguimento/colpo_grata")
	await _secondi(1.5)
	ap.play(&"inseguimento/scende")
	await _frames(2)
	var colpi := int(Audio.conteggio.get(&"lei_insegue_grata", 0)) - prima_grata
	check(colpi == 3, "colpo_grata per 1,5 s: tre versi di rabbia (%d)" % colpi)
	var incombe_prima := Audio.conteggio.duplicate()
	ap.play(&"inseguimento/incombe")
	await _frames(10)
	check(Audio.conteggio == incombe_prima, "incombe non aggiunge versi (il ringhio della salita continua)")
	lei.queue_free()
	_fine()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Con --fixed-fps 60: t secondi di animazione.
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

extends Node3D
## Porta stagna finta per le prove della stanza delle pozze (EnigmaPozze), finché la stanza vera di ambienti-1 non c'è:
## ha solo apri(subito), che la segna aperta.

var aperta := false
var aperta_subito := false


func apri(subito := false) -> void:
	aperta = true
	aperta_subito = subito

extends BaseProva
## Prova per tools/ci/morbidezza_operatori.py (--prova): salvata in uid_prova.tres; costruisce due altre classi nei
## valori dei suoi var (si costruiscono nel thread anche loro).

const Aiuto2 := preload("res://aiuto2_prova.gd")

var lato := 3.0 - 1.0  # A RISCHIO
var aiuto := AiutoProva.new()
var aiuto2 := Aiuto2.new()
var aiuto3 := preload("res://aiuto3_prova.gd").new()

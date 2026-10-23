extends Node
## Lo spot si fa in due (regia e lettore): l'occhio vero nel video pulsa con un OcchioIpnotico in [member
## OcchioIpnotico.solo_occhio], l'effetto sullo schermo lo mette dal vivo il lettore. Qui i due, con lo stesso progresso
## nel tempo (dal 38° al 43° secondo) ma a fotogrammi diversi (30 e 60 al secondo), devono avere il battito in passo,
## anche coi fotogrammi fermi del lettore; e prima del progresso l'occhio vero non pulsa.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/spot/test_occhio_passo.gd

const SCRIPT := "res://scripts/spot/occhio_ipnotico.gd"
const SHADER := "res://shaders/spot/occhio_ipnotico.gdshader"

var _ok := 0
var _falliti := 0


func _ready() -> void:
	var regia := ColorRect.new()
	regia.set_script(load(SCRIPT))
	regia.set(&"solo_occhio", true)
	var lettore := ColorRect.new()
	lettore.set_script(load(SCRIPT))
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	lettore.material = m
	add_child(regia)
	add_child(lettore)
	var fermi := [0]
	lettore.connect(&"fermo", func(acceso: bool): fermi[0] += int(acceso))
	# la regia a 30 fotogrammi al secondo, il lettore a 60: si confronta la fase ogni 1/30 di secondo
	var scarto := 0.0
	var prima_ferma := true
	for k in range(int(43.5 * 30)):
		var t := k / 30.0
		var p := clampf((t - 38.0) / 5.0, 0.0, 1.0)
		regia.set(&"progresso", p)
		regia.call(&"_process", 1.0 / 30.0)
		for j in 2:
			lettore.set(&"progresso", clampf((t + j / 60.0 - 38.0) / 5.0, 0.0, 1.0))
			lettore.call(&"_process", 1.0 / 60.0)
		if p <= 0.0 and float(regia.get(&"_fase")) != 0.0:
			prima_ferma = false
		var d := absf(float(regia.get(&"_fase")) - float(lettore.get(&"_fase")))
		scarto = maxf(scarto, minf(d, 1.0 - d))
	_controlla(prima_ferma, "prima del progresso il battito non corre")
	_controlla(fermi[0] > 0, "il lettore ha avuto dei fotogrammi fermi (%d)" % fermi[0])
	_controlla(scarto < 0.08, "battito in passo fra regia e lettore (scarto massimo %.3f di battito)" % scarto)
	_controlla(not regia.visible, "nella regia non si disegna niente")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _falliti])
	get_tree().quit(1 if _falliti > 0 else 0)


func _controlla(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok   " + cosa)
	else:
		_falliti += 1
		print("  FALLITO " + cosa)

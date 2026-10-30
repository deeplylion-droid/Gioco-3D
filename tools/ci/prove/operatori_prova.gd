extends Node
## Prova per tools/ci/morbidezza_operatori.py (--prova): ogni riga con "# A RISCHIO" deve essere trovata, le altre no.

var parti_usec := {}
var _forme: Array = []


func _lavora(giro: int, principale: bool) -> void:
	_fai_lavoro([])


func _fai_lavoro(lv: Array) -> void:
	var p := Vector3.ZERO
	var n := 3
	for fo in _forme:
		if fo[2] == 1:  # A RISCHIO
			pass
		if 1 == fo[2]:  # A RISCHIO
			pass
		var k := fo[0].size() - 1  # A RISCHIO
		var d := p - fo[9]  # A RISCHIO
		var e := p - (fo[9] as Vector3)
		var g := fo[3].end.x * 2.0  # A RISCHIO
		var c := int(fo[2]) + 1
		var b: AABB = fo[3]
		fo[2] = 5
	parti_usec["giri"] += 1  # A RISCHIO
	parti_usec["giri"] = int(parti_usec["giri"]) + 1
	var m := max(1.0, 2.0) * 3.0  # A RISCHIO
	var mf := maxf(1.0, 2.0) * 3.0
	var s := 2.0 + clamp(p.x, 0.0, 1.0)  # A RISCHIO
	var j := (n + 1) % 4  # A RISCHIO
	var q := n / 2  # A RISCHIO
	var r := float(n) / 2
	_altro(p)


func _altro(p: Vector3) -> void:
	var a := abs(p.x) - 1.0  # A RISCHIO
	var ok := absf(p.x) - 1.0

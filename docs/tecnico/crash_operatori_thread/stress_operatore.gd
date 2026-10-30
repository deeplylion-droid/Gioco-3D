extends SceneTree
## Prova di stress del difetto di Godot 4.7.2 (gdscript_vm.cpp, OPCODE_OPERATOR): alla prima esecuzione di un
## operatore con un operando senza tipo la firma si scrive nel bytecode prima del puntatore della funzione, e chi legge
## non prende il mutex. Ogni giro compila uno script nuovo (bytecode freddo) e lo fa partire su N thread insieme.
## Uso: godot --headless --script stress_operatore.gd -- senza_tipo|con_tipo [giri] [righe]

const N := 4
var _via := false
var _stop := false
var _inst: Array = []
var _arr: Array = [Vector3(0.25, 0.25, 0.25), Vector3(2, 2, 2)]
var _sem := Semaphore.new()
var _fatti := Semaphore.new()
var _thread: Array[Thread] = []


func _sorgente(con_tipo: bool, righe: int) -> String:
	var s := "extends RefCounted\n"
	if con_tipo:
		s += "var a := 0\nfunc lavora(arr: Array) -> void:\n\tvar v := Vector3(0.5, 0.5, 0.5)\n\tvar w: Vector3 = arr[0]\n\tvar r := Vector3.ZERO\n"
		for i in righe:
			s += "\ta += 1\n" if i % 2 == 0 else "\tr = v - w\n"
	else:
		s += "var d := {\"a\": 0}\nfunc lavora(arr: Array) -> void:\n\tvar v := Vector3(0.5, 0.5, 0.5)\n\tvar r\n"
		for i in righe:
			s += "\td[\"a\"] += 1\n" if i % 2 == 0 else "\tr = v - arr[0]\n"
	return s


func _corri(i: int) -> void:
	while true:
		_sem.wait()
		if _stop:
			return
		var o: Object = _inst[i]
		while not _via:
			pass
		o.call("lavora", _arr)
		_fatti.post()


func _init() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var con_tipo := argomenti.size() > 0 and argomenti[0] == "con_tipo"
	var giri := int(argomenti[1]) if argomenti.size() > 1 else 500
	var righe := int(argomenti[2]) if argomenti.size() > 2 else 3000
	var src := _sorgente(con_tipo, righe)
	print("modo ", "con_tipo" if con_tipo else "senza_tipo", ", ", giri, " giri, ", righe, " righe, ", N, " thread")
	for i in N:
		var t := Thread.new()
		t.start(_corri.bind(i))
		_thread.append(t)
	var t0 := Time.get_ticks_msec()
	for g in giri:
		var gd := GDScript.new()
		gd.source_code = src
		if gd.reload() != OK:
			push_error("compilazione fallita")
			break
		var nuovi: Array = []
		for i in N:
			nuovi.append(gd.new())
		_inst = nuovi
		_via = false
		for i in N:
			_sem.post()
		OS.delay_usec(300)
		_via = true
		for i in N:
			_fatti.wait()
		if (g + 1) % 100 == 0:
			print("  giro ", g + 1, " ok (", Time.get_ticks_msec() - t0, " ms)")
	_stop = true
	for i in N:
		_sem.post()
	for t in _thread:
		t.wait_to_finish()
	print("FINE senza crash")
	quit(0)

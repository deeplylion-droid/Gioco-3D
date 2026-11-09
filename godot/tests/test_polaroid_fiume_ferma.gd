extends Node
## Test: la Polaroid 16 del fiume si appoggia anche se il fiume resta costruito nascosto e fermo a lungo (richiesta del
## coordinatore, 9 novembre: la Risalita costruisce fiume, infermeria e pozze nascosti e fermi, coi corpi fuori dalla
## fisica; PolaroidPhoto._appoggia aspettava il pavimento al più 20 secondi, poi Posa non trovava niente sotto).
## 1. Il fiume costruito visibile e acceso: dove si appoggia la P16 (il riferimento).
## 2. Il fiume costruito nascosto e fermo, lasciato così 30 secondi, poi riacceso a pezzi (AccensioneAPezzi) e
##    mostrato, come in RisalitaGioco._costruisci_stanze: la P16 è nello stesso posto (al decimo di millimetro), col fondo
##    a filo del pavimento sotto di lei (al più 1 mm nel punto più vicino e niente dentro: test_polaroid_appoggiate).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_polaroid_fiume_ferma.gd

const FIUME := "res://scenes/risalita/fiume.tscn"
const APPOGGIATE := preload("res://tests/test_polaroid_appoggiate.gd")

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", cosa)
	else:
		_ko += 1
		print("  KO    ", cosa)


func _secondi(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(s, false, true).timeout
	print("    (passati %.1f s di gioco, %.1f s veri)" % [s, (Time.get_ticks_msec() - t0) / 1000.0])


## Il fiume costruito a pezzi sotto una radice nuova; [param fermo]: nascosto e fermo durante la costruzione.
func _fiume(fermo: bool) -> Node3D:
	var radice := Node3D.new()
	add_child(radice)
	var f := (load(FIUME) as PackedScene).instantiate() as Node3D
	f.name = "Fiume"
	f.set(&"costruzione_a_pezzi", true)
	if fermo:
		f.visible = false
		f.process_mode = Node.PROCESS_MODE_DISABLED
	radice.add_child(f)
	await f.call(&"costruisci_a_pezzi")
	return f


## [posizione della P16, distanza del fondo dal pavimento sotto nel punto più vicino (m), punti dentro] o [] se non c'è.
func _p16(f: Node3D) -> Array:
	var p := f.find_child("Polaroid16", true, false) as PolaroidPhoto
	if p == null:
		return []
	var m: Array = APPOGGIATE.misura(p)
	return [p.global_position, float(m[0]) if int(m[3]) > 0 else INF, int(m[2])]


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("1. Il fiume costruito visibile e acceso")
	var a := await _fiume(false)
	await _secondi(3.0)
	var ra := _p16(a)
	check(ra.size() == 2, "la P16 c'è")
	if ra.size() == 2:
		print("    P16 in %s, fondo a %.2f mm dal pavimento" % [(ra[0] as Vector3).snappedf(0.0001), ra[1] * 1000.0])
		check(ra[1] >= -0.0001 and ra[1] <= 0.001 and ra[2] == 0, "appoggiata: il fondo a %.2f mm dal pavimento, %d punti dentro" % [ra[1] * 1000.0, ra[2]])
	a.get_parent().queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("2. Il fiume costruito nascosto e fermo, lasciato così 30 s, poi riacceso")
	var b := await _fiume(true)
	var p := b.find_child("Polaroid16", true, false) as Node3D
	var prima := p.global_position if p else Vector3.ZERO
	await _secondi(30.0)
	check(p != null and p.global_position.is_equal_approx(prima), "da ferma la P16 non si è mossa (aspetta la stanza accesa)")
	await AccensioneAPezzi.accendi(b)
	b.visible = true
	await _secondi(3.0)
	var rb := _p16(b)
	check(rb.size() == 2, "la P16 c'è")
	if rb.size() == 2 and ra.size() == 2:
		print("    P16 in %s, fondo a %.2f mm dal pavimento" % [(rb[0] as Vector3).snappedf(0.0001), rb[1] * 1000.0])
		check(rb[1] >= -0.0001 and rb[1] <= 0.001 and rb[2] == 0, "appoggiata: il fondo a %.2f mm dal pavimento, %d punti dentro" % [rb[1] * 1000.0, rb[2]])
		check((ra[0] as Vector3).distance_to(rb[0]) < 0.0001, "nello stesso posto di quando il fiume si costruisce acceso (%.2f mm)" % ((ra[0] as Vector3).distance_to(rb[0]) * 1000.0))
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)

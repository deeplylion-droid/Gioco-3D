extends Node
## Test delle luci bianche al 40% (VarianteLuci) nel gioco vero: con la partenza del menu di prova (come F9) del fiume
## lento e poi del tunnel sottomarino, le zone caricate come in gioco, e di nuovo dopo una morte (la sala ricaricata e
## ripartita dal checkpoint), nessuna luce bianca non esclusa si disegna sopra 0,4 × la sua energia, e nessun
## materiale bianco delle lampade sopra 0,4 × la sua emissione (riscontro dell'utente sulla 0.3.16: fiume e tunnel
## troppo luminosi; tests/sonda_luci_bianche.gd stampa i dettagli).
## Senza schermo non si disegna e frame_pre_draw non arriva: il test fa lui, a fine fotogramma, quello che fa il
## disegno (LuciBianche.applica, la misura, LuciBianche.ripristina).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_luci_bianche_gioco.gd

const PARTENZE := ["fiume", "tunnel"]
const FOTOGRAMMI := 20
## Margine sul 40%: una luce che cambia da sola fra la lettura della base e il disegno (sfarfallio, lampeggio).
const TOLLERANZA := 0.05

var ok := 0
var falliti := 0
var _lb: Node
var _base_luci := {}
var _base_mat := {}
var _misura := false
var _piene := {}
var _mat_pieni := {}
var _luci_viste := 0


func _ready() -> void:
	_lb = get_node(^"/root/LuciBianche")
	process_priority = -1000
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	_controlla(is_equal_approx(float(_lb.get(&"fattore")), VarianteLuci.FATTORE_VARIANTE), "LuciBianche è al 40%",
			[_lb.get(&"fattore")])
	for id in PARTENZE:
		if not MenuProva.parti(get_tree(), id):
			_controlla(false, "la partenza %s c'è" % id, [])
			continue
		await _aspetta_giocatore(null)
		await _misura_per("%s, dopo la partenza" % id)
		var vecchio := GameState.player
		GameState.kill_player()
		await _aspetta_giocatore(vecchio)
		await _misura_per("%s, dopo una morte" % id)
	print("test_luci_bianche_gioco: %d ok, %d falliti" % [ok, falliti])
	Game.esci(1 if falliti > 0 else 0)


func _process(_d: float) -> void:
	if not _misura:
		return
	# le basi, prima del disegno (gli script lavorano sui valori pieni)
	_base_luci.clear()
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		_base_luci[l.get_instance_id()] = l.light_energy
	_base_mat.clear()
	for g: GeometryInstance3D in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		for m in _materiali(g):
			if m.emission_enabled and VarianteLuci.is_bianca(m.emission) and m.emission_energy_multiplier >= VarianteLuci.EMISSIONE_MINIMA:
				_base_mat[m.get_instance_id()] = [m, m.emission_energy_multiplier, g]
	_disegno.call_deferred()


## Quello che succede al disegno: LuciBianche applica, si legge, LuciBianche ripristina.
func _disegno() -> void:
	_lb.call(&"applica")
	var fattore := float(_lb.get(&"fattore")) + TOLLERANZA
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		if not l.is_visible_in_tree() or not VarianteLuci.is_bianca(l.light_color):
			continue
		if _lb.call(&"_esclusa", l) or VarianteLuci._nome_colorato(l.name):
			continue
		var b: float = _base_luci.get(l.get_instance_id(), -1.0)
		if b <= 0.0:
			continue
		_luci_viste += 1
		if l.light_energy > b * fattore:
			_piene[l.get_instance_id()] = "%s %.2f (base %.2f)" % [l.get_path(), l.light_energy, b]
	for id in _base_mat:
		var e: Array = _base_mat[id]
		var m: BaseMaterial3D = e[0]
		if not is_instance_valid(e[2]) or VarianteLuci._nome_colorato(m.resource_name):
			continue
		if m.emission_energy_multiplier > float(e[1]) * fattore and _lb.call(&"_lampada", e[2]) and not _lb.call(&"_esclusa", e[2]):
			_mat_pieni[id] = "%s su %s %.2f (base %.2f)" % [m.resource_name, (e[2] as Node).get_path(), m.emission_energy_multiplier, e[1]]
	_lb.call(&"ripristina")


func _misura_per(titolo: String) -> void:
	_piene.clear()
	_mat_pieni.clear()
	_luci_viste = 0
	_misura = true
	for i in FOTOGRAMMI:
		await get_tree().process_frame
	_misura = false
	await get_tree().process_frame
	_controlla(_luci_viste > 0, "%s: ci sono luci bianche da guardare" % titolo, [_luci_viste])
	_controlla(_piene.is_empty(), "%s: nessuna luce bianca sopra il 40%%" % titolo, _piene.values().slice(0, 10))
	_controlla(_mat_pieni.is_empty(), "%s: nessuna lampada bianca sopra il 40%%" % titolo, _mat_pieni.values().slice(0, 10))


func _aspetta_giocatore(vecchio: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree() and p.input_enabled and not GameState.is_dying:
			break
	await Game.aspetta_caricamenti(get_tree().current_scene, 120.0)
	for i in 60:
		await get_tree().process_frame


func _materiali(g: GeometryInstance3D) -> Array:
	var out := []
	for m in [g.material_override, g.material_overlay]:
		if m is BaseMaterial3D:
			out.append(m)
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		var mi := g as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			for m in [mi.get_surface_override_material(s), mi.mesh.surface_get_material(s)]:
				if m is BaseMaterial3D:
					out.append(m)
	return out


func _controlla(cond: bool, cosa: String, dove: Array) -> void:
	if cond:
		ok += 1
		print("  ok      " + cosa)
	else:
		falliti += 1
		print("  FALLITO " + cosa + ": " + str(dove))

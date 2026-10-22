extends Node
## La variante delle luci bianche al 40% (scripts/game/luci_bianche.gd, autoload LuciBianche):
## 1. di base il fattore è 1 e non tocca niente (la build normale resta identica);
## 2. al 40%, nel disegno, le luci bianche e bianco-calde scendono al 40%, le rosse e le colorate no; dopo il
##    disegno tornano i valori pieni (gli script li ritrovano);
## 3. l'emissione dei materiali bianchi delle lampade e l'energia del VoxelGI scendono anche loro, le colorate no;
## 4. una luce che cambia da sola (FlickerLight, che scrive light_energy a ogni fotogramma) tiene il fattore;
## 5. la torcia resta com'è; F7 passa dal 100% al 40% e indietro.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_luci_bianche.gd

var _passed := 0
var _failed := 0
var _visto := {}        # nel disegno (fra applica e ripristina): luce o materiale -> energia


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var lb := get_node(^"/root/LuciBianche")
	print("1. Di base")
	check(is_equal_approx(float(ProjectSettings.get_setting("gioco/luci_bianche", 1.0)), 1.0) and is_equal_approx(lb.fattore, 1.0),
		"il fattore è 1 (impostazione e autoload)")
	check(not RenderingServer.frame_pre_draw.is_connected(lb.applica), "con il fattore 1 non tocca il disegno")

	var radice := Node3D.new()
	add_child(radice)
	var colori := {"bianca": Color(1, 1, 1), "calda": Color(1.0, 0.86, 0.68), "lampadina": Color(1.0, 0.72, 0.42),
		"rossa": Color(1.0, 0.12, 0.08), "verde": Color(0.2, 1.0, 0.35), "rosa": Color(1.0, 0.45, 0.75),
		"viola": Color(0.6, 0.3, 1.0), "blu": Color(0.3, 0.5, 1.0)}
	var luci := {}
	for nome in colori:
		var l := OmniLight3D.new()
		l.name = nome
		l.light_color = colori[nome]
		l.light_energy = 2.0
		radice.add_child(l)
		luci[nome] = l
	var mat_bianco := StandardMaterial3D.new()
	mat_bianco.emission_enabled = true
	mat_bianco.emission = Color(1.0, 0.95, 0.85)
	mat_bianco.emission_energy_multiplier = 3.0
	var mat_rosso := StandardMaterial3D.new()
	mat_rosso.emission_enabled = true
	mat_rosso.emission = Color(1.0, 0.1, 0.05)
	mat_rosso.emission_energy_multiplier = 3.0
	for m in [mat_bianco, mat_rosso]:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = m
		radice.add_child(mi)
	var gi := VoxelGI.new()
	gi.data = VoxelGIData.new()
	gi.data.energy = 1.5
	radice.add_child(gi)
	# una luce che sfarfalla da sola
	var fl_luce := OmniLight3D.new()
	fl_luce.light_color = Color(1, 1, 1)
	radice.add_child(fl_luce)
	var fl := FlickerLight.new()
	fl.light = fl_luce
	fl.base_energy = 2.0
	fl.flicker_rate = 2.0
	radice.add_child(fl)
	# la torcia del giocatore
	var torcia := Torcia.new()
	radice.add_child(torcia)
	await _frames(3)
	var luce_torcia: Light3D = torcia.find_children("*", "Light3D", true, false)[0] if not torcia.find_children("*", "Light3D", true, false).is_empty() else null

	print("2. Al 40%")
	lb.imposta(0.4)
	await _frames(2)
	check(RenderingServer.frame_pre_draw.is_connected(lb.applica) and RenderingServer.frame_post_draw.is_connected(lb.ripristina),
		"al 40% si applica prima di ogni disegno e si toglie dopo")
	# in headless il disegno non c'è: applica() e ripristina() a mano, come li chiama il RenderingServer
	var torcia_piena := luce_torcia.light_energy if luce_torcia else 0.0
	var fl_max_rapporto := 0.0
	var fl_ok := true
	for k in 30:
		await get_tree().process_frame          # lo sfarfallio scrive light_energy qui
		var pieno := fl_luce.light_energy
		lb.applica()
		for nome in luci:
			_visto[nome] = (luci[nome] as Light3D).light_energy
		_visto["mat_bianco"] = mat_bianco.emission_energy_multiplier
		_visto["mat_rosso"] = mat_rosso.emission_energy_multiplier
		_visto["gi"] = gi.data.energy
		if luce_torcia:
			_visto["torcia"] = luce_torcia.light_energy
		var nel_disegno := fl_luce.light_energy
		lb.ripristina()
		if pieno > 0.05:
			var r := nel_disegno / pieno
			fl_ok = fl_ok and absf(r - 0.4) < 0.02 and is_equal_approx(fl_luce.light_energy, pieno)
			fl_max_rapporto = maxf(fl_max_rapporto, r)
	for nome in ["bianca", "calda", "lampadina"]:
		check(absf(float(_visto.get(nome, -1.0)) - 0.8) < 0.01, "nel disegno la luce %s scende al 40%% (%.2f)" % [nome, float(_visto.get(nome, -1.0))])
	for nome in ["rossa", "verde", "rosa", "viola", "blu"]:
		check(absf(float(_visto.get(nome, -1.0)) - 2.0) < 0.01, "la luce %s resta com'era (%.2f)" % [nome, float(_visto.get(nome, -1.0))])
	check(is_equal_approx((luci["bianca"] as Light3D).light_energy, 2.0), "dopo il disegno gli script ritrovano il valore pieno")
	check(absf(float(_visto.get("mat_bianco", -1.0)) - 1.2) < 0.01 and absf(float(_visto.get("mat_rosso", -1.0)) - 3.0) < 0.01,
		"l'emissione bianca scende al 40%%, la rossa no (%.2f, %.2f)" % [float(_visto.get("mat_bianco", -1.0)), float(_visto.get("mat_rosso", -1.0))])
	check(absf(float(_visto.get("gi", -1.0)) - 0.6) < 0.01, "il VoxelGI scende al 40%% (%.2f)" % float(_visto.get("gi", -1.0)))
	check(fl_ok and fl_max_rapporto > 0.3, "la luce che sfarfalla da sola tiene il fattore, e dopo il disegno ritrova il suo valore (rapporto %.2f)" % fl_max_rapporto)
	if luce_torcia:
		check(absf(float(_visto.get("torcia", -1.0)) - torcia_piena) < 0.01, "la torcia resta com'è")

	print("3. F7 e ritorno al 100%")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_F7
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	check(is_equal_approx(lb.fattore, 1.0) and not RenderingServer.frame_pre_draw.is_connected(lb.applica),
		"F7 torna al 100% e non tocca più il disegno")
	check(is_equal_approx((luci["bianca"] as Light3D).light_energy, 2.0) and is_equal_approx(gi.data.energy, 1.5)
			and is_equal_approx(mat_bianco.emission_energy_multiplier, 3.0), "al 100% tutto com'era")
	Input.parse_input_event(e)
	await _frames(3)
	check(is_equal_approx(lb.fattore, 0.4), "F7 di nuovo: 40%")
	lb.imposta(1.0)
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

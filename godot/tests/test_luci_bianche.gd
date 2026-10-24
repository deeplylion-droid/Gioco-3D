extends Node
## La luce normale del gioco: le luci bianche al 40% (scripts/game/luci_bianche.gd, autoload LuciBianche; scelta
## dell'utente del 23 ottobre: "le luci a 40% vanno bene quindi via la scelta e restano così"):
## 1. di serie il fattore è 0,4 (impostazione e autoload), e non c'è più il tasto F7 né la scritta;
## 2. al 40%, nel disegno, le luci bianche e bianco-calde scendono al 40%, le rosse e le colorate no; dopo il
##    disegno tornano i valori pieni (gli script li ritrovano);
## 3. l'emissione dei materiali bianchi delle lampade e l'energia del VoxelGI scendono anche loro, le colorate no; Jilly
##    (la Medusa) e gli emissivi che non sono lampade restano com'erano; il disegno sull'acquario scende;
## 4. una luce che cambia da sola (FlickerLight, che scrive light_energy a ogni fotogramma) tiene il fattore;
## 5. gli strumenti possono tornare al 100% (imposta) e allora non tocca più il disegno.
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
	print("1. Di serie")
	check(is_equal_approx(float(ProjectSettings.get_setting("gioco/luci_bianche", 1.0)), 0.4) and is_equal_approx(lb.fattore, 0.4),
		"il fattore è 0,4 (impostazione e autoload)")
	check(not lb.has_method(&"_unhandled_input") and not lb.has_method(&"_mostra"), "niente tasto F7 e niente scritta \"Luci 40%/100%\"")
	lb.imposta(1.0)
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
		mi.name = "Lampadina" if m == mat_bianco else "LampadinaRossa"
		mi.mesh = BoxMesh.new()
		mi.material_override = m
		radice.add_child(mi)
	# Jilly (la Medusa: il suo bagliore è il personaggio) resta; il disegno sul vetro dell'acquario scende (l'utente)
	var medusa := Node3D.new()
	medusa.name = "Medusa"
	radice.add_child(medusa)
	var mat_medusa := StandardMaterial3D.new()
	mat_medusa.resource_name = "M_tentacoli"
	mat_medusa.emission_enabled = true
	mat_medusa.emission = Color(0.95, 0.9, 1.0)
	mat_medusa.emission_energy_multiplier = 2.0
	var tent := MeshInstance3D.new()
	tent.mesh = BoxMesh.new()
	tent.material_override = mat_medusa
	medusa.add_child(tent)
	var luce_medusa := OmniLight3D.new()
	luce_medusa.light_color = Color(1, 1, 1)
	luce_medusa.light_energy = 2.0
	medusa.add_child(luce_medusa)
	var mat_disegno := StandardMaterial3D.new()
	mat_disegno.resource_name = "disegno_carta"
	mat_disegno.emission_enabled = true
	mat_disegno.emission = Color(1.0, 0.97, 0.9)
	mat_disegno.emission_energy_multiplier = 0.6
	var disegno := MeshInstance3D.new()
	disegno.name = "disegno_carta"
	disegno.mesh = QuadMesh.new()
	disegno.material_override = mat_disegno
	radice.add_child(disegno)
	# un materiale emissivo bianco qualsiasi (non una lampada, grande e lontano dalle luci): resta
	var mat_muro := StandardMaterial3D.new()
	mat_muro.emission_enabled = true
	mat_muro.emission = Color(1, 1, 1)
	mat_muro.emission_energy_multiplier = 1.0
	var muro := MeshInstance3D.new()
	muro.name = "Muro"
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 3, 0.2)
	muro.mesh = bm
	muro.material_override = mat_muro
	var stanza := Node3D.new()
	stanza.name = "Stanza"
	stanza.position = Vector3(50, 0, 0)
	radice.add_child(stanza)
	stanza.add_child(muro)
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
	await _frames(3)

	print("2. Al 40%")
	lb.imposta(0.4)
	await _frames(2)
	check(RenderingServer.frame_pre_draw.is_connected(lb.applica) and RenderingServer.frame_post_draw.is_connected(lb.ripristina),
		"al 40% si applica prima di ogni disegno e si toglie dopo")
	# in headless il disegno non c'è: applica() e ripristina() a mano, come li chiama il RenderingServer
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
		_visto["medusa"] = mat_medusa.emission_energy_multiplier
		_visto["luce_medusa"] = luce_medusa.light_energy
		_visto["disegno"] = mat_disegno.emission_energy_multiplier
		_visto["muro"] = mat_muro.emission_energy_multiplier
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
	check(absf(float(_visto.get("medusa", -1.0)) - 2.0) < 0.01 and absf(float(_visto.get("luce_medusa", -1.0)) - 2.0) < 0.01,
		"Jilly (la Medusa) resta com'era: il bagliore dei tentacoli e la sua luce bianca (%.2f, %.2f)" % [float(_visto.get("medusa", -1.0)), float(_visto.get("luce_medusa", -1.0))])
	check(absf(float(_visto.get("disegno", -1.0)) - 0.24) < 0.01, "il disegno sull'acquario scende anche lui al 40%% (%.2f)" % float(_visto.get("disegno", -1.0)))
	check(absf(float(_visto.get("muro", -1.0)) - 1.0) < 0.01, "un emissivo bianco che non è una lampada resta com'era (%.2f)" % float(_visto.get("muro", -1.0)))
	check(fl_ok and fl_max_rapporto > 0.3, "la luce che sfarfalla da sola tiene il fattore, e dopo il disegno ritrova il suo valore (rapporto %.2f)" % fl_max_rapporto)

	print("3. Al 100% (per gli strumenti)")
	lb.imposta(1.0)
	await _frames(3)
	check(is_equal_approx(lb.fattore, 1.0) and not RenderingServer.frame_pre_draw.is_connected(lb.applica),
		"al 100% non tocca più il disegno")
	check(is_equal_approx((luci["bianca"] as Light3D).light_energy, 2.0) and is_equal_approx(gi.data.energy, 1.5)
			and is_equal_approx(mat_bianco.emission_energy_multiplier, 3.0), "al 100% tutto com'era")
	lb.imposta(0.4)
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

extends Node
## Test della scena dello squalo all'inizio a schermo chiaro (passaggio finale di ambienti-2 sulla candidata b18a9003:
## al primo avvio la prova della qualità teneva lo schermo nero mentre la scena era già partita, e i primi due lampi
## cadevano nel nero; negli avvii normali la sala entra con la dissolvenza di 1,6 s). Dal titolo, Nuova partita, la
## schermata di caricamento vera fino alla sala, con la scena dello squalo vera (RisveglioSqualo.forza_nei_test):
## 1. la scena aspetta lo schermo chiaro: intanto il suo tempo è fermo e non suona niente;
## 2. parte solo quando il velo della dissolvenza è a zero e la prova della qualità è finita;
## 3. il primo lampo cade con lo schermo chiaro.
## Due profili: "nuovo" (qualita_provata falso: la prova della qualità, con QualitaAutomatica.forza_nei_test e la misura
## finta) e "provato" (la qualità già provata: solo la dissolvenza).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_squalo_schermo.gd nuovo|provato

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _velo() -> float:
	return Dissolvenza.di(get_tree()).opacita() if Dissolvenza.presente(get_tree()) else 0.0


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var nuovo := not (a.size() > 1 and a[1] == "provato")
	print("Profilo: %s" % ("nuovo (con la prova della qualità)" if nuovo else "qualità già provata"))
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.valori["qualita_provata"] = not nuovo
	Grafica.valori["scelta_automatica"] = "" if nuovo else "alto"
	QualitaAutomatica.forza_nei_test = nuovo
	QualitaAutomatica.misura_finta_test = func(preset: String) -> bool: return preset == "alto"
	RisveglioSqualo.forza_nei_test = true
	get_tree().change_scene_to_file(TITOLO)
	for i in 30:
		await get_tree().process_frame
	get_tree().current_scene.call(&"_avvia_nuova_partita")
	# la sala (fino a 10 minuti: il caricamento nel thread) con la scena dello squalo avviata
	var s: RisveglioSqualo = null
	var prova_vista := false
	var fino := Time.get_ticks_msec() + 600000
	while Time.get_ticks_msec() < fino:
		await get_tree().process_frame
		if QualitaAutomatica.in_corso(get_tree()):
			prova_vista = true
		var sc := get_tree().current_scene
		if sc and String(sc.name) != "Caricamento":
			s = sc.find_child("RisveglioSqualo", true, false) as RisveglioSqualo
			if s and s.in_corso():
				break
	check(s != null and s.in_corso(), "nella sala la scena dello squalo è avviata")
	if s == null:
		_fine()
		return
	# la goccia di bava: all'inizio si disegna trasparente per qualche fotogramma anche se la scena è già partita, così la
	# sua pipeline 2D è pronta prima che compaia (sonda di grafica-2, 0.3.24: la scena la nascondeva al primo fotogramma,
	# e la pipeline si compilava quando compariva); poi resta nascosta fino al suo momento
	var goccia := s.get(&"_goccia") as ColorRect
	var disegnata := 0
	var a_vista := false
	for i in RisveglioSqualo.FOTOGRAMMI_GOCCIA + 5:
		if goccia and goccia.is_visible_in_tree() and not bool(s.get(&"_goccia_disegnata")):
			disegnata += 1
			a_vista = a_vista or s.goccia_visibile()
		await get_tree().process_frame
	check(disegnata > 0 and not a_vista,
		"la goccia si disegna trasparente all'inizio della scena per %d fotogrammi (pipeline pronta), senza vedersi" % disegnata)
	check(goccia != null and not goccia.is_visible_in_tree() and bool(s.get(&"_goccia_disegnata")),
		"poi la goccia resta nascosta fino al suo momento")
	var audio := get_node_or_null(^"/root/Audio")
	var lampo0 := float((s.tempi.get("lampi", [[0.55, 0.16]]) as Array)[0][0])
	var attesa_vista := false
	var attesa_ferma := true
	var attesa_muta := true
	var velo_inizio := -1.0
	var prova_inizio := false
	var velo_lampo := -1.0
	var prova_lampo := false
	fino = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < fino and s.in_corso():
		await get_tree().process_frame
		if QualitaAutomatica.in_corso(get_tree()):
			prova_vista = true
		var t := float(s.get(&"_t"))
		if s.in_attesa():
			attesa_vista = true
			attesa_ferma = attesa_ferma and t == 0.0
			if audio:
				attesa_muta = attesa_muta and int((audio.get(&"conteggio") as Dictionary).get(&"squalo_annusa", 0)) == 0
		if t > 0.0 and velo_inizio < 0.0:
			velo_inizio = _velo()
			prova_inizio = QualitaAutomatica.in_corso(get_tree())
		if t >= lampo0:
			velo_lampo = _velo()
			prova_lampo = QualitaAutomatica.in_corso(get_tree())
			break
	if nuovo:
		check(prova_vista and bool(Grafica.valore("qualita_provata")), "profilo nuovo: la prova della qualità c'è stata ed è finita")
	check(attesa_vista and attesa_ferma and attesa_muta,
		"a schermo nero la scena aspetta: il suo tempo è fermo e non suona niente")
	check(velo_inizio >= 0.0 and velo_inizio <= 0.001 and not prova_inizio,
		"la scena parte solo a schermo chiaro (velo %.3f, prova della qualità %s)" % [velo_inizio, "in corso" if prova_inizio else "finita"])
	check(velo_lampo >= 0.0 and velo_lampo <= 0.001 and not prova_lampo,
		"il primo lampo cade con lo schermo chiaro (velo %.3f)" % velo_lampo)
	_fine()


func _fine() -> void:
	QualitaAutomatica.forza_nei_test = false
	QualitaAutomatica.misura_finta_test = Callable()
	RisveglioSqualo.forza_nei_test = false
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)

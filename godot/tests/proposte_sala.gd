extends Node
## Scatti delle PROPOSTE per la sala principale (15 ottobre 2026). Niente di questo è nel gioco:
## carica sala_principale.tscn, toglie, sposta e aggiunge pezzi a runtime (prima che la scena entri
## nell'albero, così il gioco la prepara come sempre) e fotografa con una camera libera.
## I pezzi nuovi sono in res://proposte/sala/: GLB e dati.json da tools/blender/proposte_sala.py,
## disposizioni_bimbi.json da tools/proposte/disposizioni_bimbi.py.
##
## In tutti gli scatti la sala è già come l'ha decisa l'utente il 15 ottobre: senza soppalco, senza
## recinto della spiaggia, senza ruota a pale, ruota del cancello, turbina e quadro elettrico; il
## cordone intorno alla vasca della medusa è chiuso. Senza gli scivoli di oggi: partono dalla torre,
## che va in una sala nuova, e vanno rifatti.
##
## Uso, sotto il render.lock (un processo per scatto: tools/proposte_sala.sh):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/proposte_sala.gd <cartella> <scatto> [preset] [frame]
## Scatti: bimbi_L1_pianta, bimbi_L1_arrivo (e L2, L3), pulsante_A_spiaggia, pulsante_A_vicino,
## pulsante_A_verde, pulsante_B_spiaggia, pulsante_B_vicino, soppalco_f_da_terra, soppalco_insieme,
## transenne, torre_nord_cancello, torre_nord_pianta, torre_est_cancello, torre_est_pianta.
## Le piante sono viste dall'alto ortografiche: risoluzione verticale per bimbi e torre_nord
## (1000x1400), orizzontale per torre_est (1600x1000).

const LEVEL := "res://scenes/sala_principale.tscn"
const DIR := "res://proposte/sala/"
const DETTAGLI_JSON := "res://assets/ambiente/dettagli/posizionamento.json"
const DETTAGLI_PROPOSTA := "user://proposte_dettagli"
## materiali delle proposte con una texture disegnata (i GLB delle proposte non hanno immagini)
const TEXTURE_PROP := {"M_prop_strisce": "cornice_strisce_col.jpg", "M_prop_cartello": "cartello_botola_col.jpg",
	"M_prop_insegna_torre": "insegna_torre_col.jpg", "M_prop_portone": "portone_torre_col.jpg"}
const GIOCATTOLI := ["det_barchetta", "det_paletta", "det_secchiello", "det_paperella", "det_pesce", "det_pistola",
	"det_maschera", "det_ciabatta", "det_asciugamano"]

## camere: [posizione, punto guardato] (coordinate Godot)
const CAMERE := {
	"bimbi_arrivo": [Vector3(-8.3, 1.7, -4.0), Vector3(-16.0, 2.0, -13.2)],
	"pulsante_spiaggia": [Vector3(0.6, 1.7, -14.2), Vector3(1.2, -1.6, 3.5)],
	"pulsante_vicino": [Vector3(-0.8, -0.27, -1.2), Vector3(1.3, -1.6, 3.6)],
	"soppalco_f_da_terra": [Vector3(18.4, 1.7, -0.5), Vector3(0.0, 2.2, 1.5)],
	"soppalco_insieme": [Vector3(18.6, 9.6, 18.6), Vector3(-5.0, 0.5, -5.5)],
	"transenne": [Vector3(-3.6, 1.7, 17.6), Vector3(0.0, 1.0, 10.8)],
	"torre_nord_cancello": [Vector3(-1.5, 1.7, -13.6), Vector3(0.0, 3.8, -24.0)],
	"torre_est_cancello": [Vector3(8.6, 1.7, -14.2), Vector3(20.0, 3.4, -15.0)],
}
## piante: [centro, altezza inquadrata in metri]
const PIANTE := {
	"bimbi": [Vector3(-13.5, 40.0, -13.4), 22.4],
	"torre_nord": [Vector3(0.0, 60.0, -12.0), 67.0],
	"torre_est": [Vector3(10.0, 60.0, -3.0), 49.0],
}

var out_dir := "user://proposte_sala"
var scatto := "transenne"
var preset := "alto_smaa"
var settle := 40
var level: Node3D
var p: Player
var dati := {}
var disp := {}
var pianta := false
var materiali_sala := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		scatto = args[2]
	if args.size() > 3 and args[3] != "":
		preset = args[3]
	if args.size() > 4:
		settle = int(args[4])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	if preset == "alto_smaa":
		Grafica.applica_preset("alto")
		Grafica.imposta("antialiasing", 2)
	else:
		Grafica.applica_preset(preset)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	dati = JSON.parse_string(FileAccess.get_file_as_string(DIR + "dati.json"))
	disp = JSON.parse_string(FileAccess.get_file_as_string(DIR + "disposizioni_bimbi.json"))
	pianta = scatto.ends_with("_pianta")
	level = (load(LEVEL) as PackedScene).instantiate()
	_raccogli_materiali()
	_comune()
	var scarta := _scarta_base
	if scatto.begins_with("bimbi_"):
		var k := scatto.get_slice("_", 1)
		_disposizione(k)
		scarta = func(q: Dictionary) -> bool: return _scarta_base(q) or _scarta_bimbi(q, k)
	elif scatto.begins_with("pulsante_"):
		_pulsante(scatto.get_slice("_", 1), scatto.ends_with("_verde"))
	elif scatto.begins_with("torre_"):
		_torre(scatto.get_slice("_", 1))
		var v := scatto.get_slice("_", 1)
		scarta = func(q: Dictionary) -> bool: return _scarta_base(q) or _scarta_varco(q, v)
	_dettagli(scarta)
	if pianta:
		_per_pianta()
	# la medusa della tappa 8 non si vede mai negli scatti; la medusa della vasca solo da certi punti
	_togli(["Gioco/LeiSbuca"])
	if scatto.begins_with("bimbi_") or scatto.ends_with("_cancello"):
		_togli(["Vasca/Medusa", "Gioco/RitornoAlBuio"])
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	var lamp := level.get_node_or_null("Vasca/Sfarfallio")
	if lamp and lamp.has_method("turn_on"):
		lamp.turn_on()
	await _frames(2)
	_dopo_ingresso()
	var cam := Camera3D.new()
	cam.name = "CameraProposta"
	level.add_child(cam)
	if pianta:
		var k := "bimbi" if scatto.begins_with("bimbi_") else scatto.trim_suffix("_pianta")
		var pp: Array = PIANTE[k]
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = pp[1]
		cam.near = 0.5
		cam.far = 120.0
		cam.global_position = pp[0]
		cam.look_at(pp[0] - Vector3(0, 10, 0), Vector3(0, 0, -1))
		# piante: le coordinate dei bordi dell'immagine, per i disegni sopra (tools/proposte/pianta_sopra.py)
		var vp := get_viewport().get_visible_rect().size
		var mezza_h: float = pp[1] / 2.0
		var mezza_w: float = mezza_h * vp.x / vp.y
		print("PIANTA x ", pp[0].x - mezza_w, " ", pp[0].x + mezza_w, " z ", pp[0].z - mezza_h, " ", pp[0].z + mezza_h)
	else:
		var chiave := scatto
		if scatto.begins_with("bimbi_"):
			chiave = "bimbi_arrivo"
		elif scatto.begins_with("pulsante_"):
			chiave = "pulsante_spiaggia" if scatto.ends_with("spiaggia") else "pulsante_vicino"
		var c: Array = CAMERE[chiave]
		cam.fov = 62.0
		cam.near = 0.05
		cam.far = 200.0
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
	cam.make_current()
	# il giocatore lontano dall'inquadratura (resta nella scena: la scena lo vuole)
	p.teleport(Vector3(0.0, 0.0, 19.0), 0.0, 0.0)
	await _frames(settle)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out_dir.path_join("%s.jpg" % scatto), 0.92)
	print("salvato ", scatto)
	print("memoria massima del processo: ", _picco_memoria())
	get_tree().quit()


# ----------------------------------------------------------------------------- uguale per tutti

func _comune() -> void:
	# niente interni e ambienti tecnici (non si vedono, e senza c'è più memoria); niente bambini
	# sul soppalco (il soppalco non c'è più)
	_togli(["Interni", "Tecnici", "BambiniBalconata", "RuotaESecchio", "Piscina/TurbinaScarico", "Piscina/GonfiabileIncastrato"])
	# deciso dall'utente il 15 ottobre: niente recinto, niente ruote, niente turbina; il quadro elettrico
	# serviva al secchio ed era sulla colonna del soppalco nord
	_togli_in("Sala/Interattivi", ["sala_recinto_spiaggia", "sala_cancello_spiaggia", "sala_ruota_cancello",
		"sala_trasmissione_cancello", "sala_turbina_scarico", "sala_turbina_carter", "sala_quadro_elettrico"])
	_togli_in("Sala/AreaBimbi", ["sala_ruota_pale"])
	# gli scivoli di oggi partono dalla torre che si sposta (sala della torre nuova) e passano sopra
	# l'area bimbi e la piscina: vanno rifatti, negli scatti delle proposte non ci sono
	_togli_in("Sala/TorreScivoli", ["sala_scivolo_grande", "sala_scivolo_medio", "sala_scivolo_spirale", "sala_sostegni_scivoli"])
	# senza soppalco: via soppalco, colonne, ringhiere, scala; plafoniere, cartelloni, altoparlanti,
	# colature e plafoniere calde rifatti sulle pareti (base.glb); fari della medusa sulla parete sud;
	# cordone chiuso intorno alla vasca
	_togli_in("Sala/Architettura", ["sala_galleria", "sala_colonne", "sala_ringhiere", "sala_scala_galleria",
		"sala_scala_galleria_grigliato", "sala_lampade", "sala_cartellone_n0", "sala_cartellone_n1", "sala_cartellone_n2",
		"sala_cartellone_s0", "sala_altoparlanti", "sala_colature", "sala_plafoniere_calde"])
	var vc := level.get_node("Sala/VascaCentrale")
	for n in vc.get_children():
		if String(n.name).begins_with("sala_vasca_colonnina") or n.name in [&"sala_vasca_cordone", &"sala_monumento_fari"]:
			vc.remove_child(n)
			n.free()
	_aggiungi("base.glb", "PropostaBase")
	var b: Dictionary = dati.base
	for nome in b.luci_neon:
		_metti_luce(nome, b.luci_neon[nome])
	for nome in b.luci_calde:
		_metti_luce(nome, b.luci_calde[nome])
	for nome in b.luci_fari:
		var l := _luce(nome)
		if l:
			l.position = _v(b.luci_fari[nome].pos)
			l.look_at_from_position(l.position, _v(b.luci_fari[nome].mira), Vector3.UP)


## Dettagli da non montare in tutti gli scatti: quelli appesi sotto il soppalco.
func _scarta_base(q: Dictionary) -> bool:
	return q.zona == "sotto la galleria"


func _dettagli(scarta: Callable) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DETTAGLI_JSON))
	var tenuti := []
	var tolti := 0
	for q in d.posti:
		if scarta.call(q):
			tolti += 1
		else:
			tenuti.append(q)
	d.posti = tenuti
	DirAccess.make_dir_recursive_absolute(DETTAGLI_PROPOSTA)
	var f := FileAccess.open(DETTAGLI_PROPOSTA.path_join("posizionamento.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	level.get_node("Sala/Dettagli").set(&"cartella", DETTAGLI_PROPOSTA)
	print("dettagli tolti: ", tolti)


# ----------------------------------------------------------------------------- area bimbi

func _disposizione(k: String) -> void:
	var L: Dictionary = disp.disposizioni[k]
	var c0 := _v(disp.struttura_oggi_godot)
	var c1 := _v(L.struttura.centro_godot)
	var R := Basis(Vector3.UP, deg_to_rad(L.struttura.rotazione_gradi))
	var T := Transform3D(R, c1 - R * c0)
	for percorso in ["Sala/AreaBimbi/sala_struttura_gioco", "Sala/AreaBimbi/sala_secchio_gigante", "Sala/Luci/luce_area_bimbi", "Polaroid/Polaroid04"]:
		var n := level.get_node_or_null(percorso) as Node3D
		if n:
			n.transform = T * n.transform
	# vasca piccola: il modello e la vasca d'acqua del gioco
	var v0 := _v(disp.vb2_oggi_godot)
	var v1 := _v(L.vb2_godot)
	(level.get_node("Sala/AreaBimbi/sala_vasca_bimbi_2") as Node3D).position += Vector3(v1.x - v0.x, 0, v1.z - v0.z)
	(level.get_node("Vasche/VascaBimbi2") as Node3D).position = Vector3(v1.x, 0.02, v1.z)
	# funghi
	for f in L.funghi:
		var n := level.get_node("Sala/Oggetti/" + f.nodo) as Node3D
		var s := n.scale
		n.basis = Basis(Vector3.UP, deg_to_rad(f.rotazione_gradi)).scaled(s)
		n.position = _v(f.pos_godot)
	# oggetti sparsi: via
	_togli_in("Sala/Oggetti", disp.togli_oggetti)
	# festone e plafoniera dell'area bimbi (LuciSala li crea nel suo _ready)
	var luci := level.get_node("LuciSala")
	var punti := PackedVector3Array()
	for q in L.festone_godot:
		punti.append(_v(q))
	luci.set(&"festone_punti", punti)
	luci.set(&"plafoniera_bimbi", _v(L.plafoniera_godot))
	luci.set(&"mira_plafoniera_bimbi", _v(L.mira_plafoniera_godot))


func _scarta_bimbi(q: Dictionary, k: String) -> bool:
	var pos: Array = q.posizione
	var x: float = pos[0]
	var z: float = pos[2]
	var a: Dictionary = disp.area_godot
	var ax: Array = a.x
	var az: Array = a.z
	var nell_area: bool = x >= ax[0] and x <= ax[1] and z >= az[0] and z <= az[1]
	if not nell_area:
		return false
	for g in GIOCATTOLI:
		if String(q.nodo).begins_with(g):
			return true
	if q.zona in ["sala", "angolo", "sotto le lampade"]:
		return true   # oggetti sparsi a terra nell'area bimbi
	for r in disp.disposizioni[k].ingombri_godot:
		var rr: Array = r
		if x > float(rr[0]) - 0.2 and x < float(rr[2]) + 0.2 and z > float(rr[1]) - 0.2 and z < float(rr[3]) + 0.2:
			return true
	return false


# ----------------------------------------------------------------------------- piscina vuota, pulsante

func _pulsante(versione: String, verde: bool) -> void:
	# piscina vuota: l'acqua della pozza a zero, niente gocce
	var pozza := level.get_node("Piscina/Pozza")
	pozza.set(&"fill", 0.0)
	_togli(["Piscina/AcquaPozza", "Atmosfera/GocceNellaPozza"])
	_togli_in("Sala/Interattivi", ["sala_pulsante_portello"])
	_aggiungi("pulsante_%s.glb" % versione.to_lower(), "PropostaPulsante")
	if versione == "A":
		var d: Dictionary = dati.pulsante_a
		var col := Color(0.15, 1.0, 0.3) if verde else Color(1.0, 0.68, 0.08)
		var o := OmniLight3D.new()
		o.name = "LuceLampeggiante"
		o.light_color = col
		o.light_energy = 4.0
		o.omni_range = 7.0
		o.omni_attenuation = 1.3
		o.shadow_enabled = true
		o.light_volumetric_fog_energy = 2.0
		o.position = _v(d.faro_godot) + Vector3(0, 0.05, -0.25)
		level.add_child(o)
		if verde:
			var hatch := level.get_node("Sala/Interattivi/sala_portello_scarico") as Node3D
			hatch.basis = Basis(Vector3.RIGHT, deg_to_rad(-170.0)) * hatch.basis
	else:
		var d: Dictionary = dati.pulsante_b
		# il faretto sul braccio del cartello: punta la piastra a strisce (al buio, senza luce, non si vede)
		var s := SpotLight3D.new()
		s.name = "FarettoPulsante"
		s.light_color = Color(1.0, 0.88, 0.7)
		s.light_energy = 14.0
		s.spot_range = 8.0
		s.spot_angle = 30.0
		s.spot_attenuation = 0.8
		s.shadow_enabled = true
		s.light_volumetric_fog_energy = 1.5
		level.add_child(s)
		s.position = _v(d.faretto_godot)
		var piastra := _v(d.pulsante_godot) + Vector3(0, 0, 0.15)
		s.look_at_from_position(s.position, piastra, Vector3.UP)
		# e una luce corta davanti al cartello, per leggerlo
		var o := OmniLight3D.new()
		o.name = "LuceCartello"
		o.light_color = Color(1.0, 0.9, 0.75)
		o.light_energy = 1.6
		o.omni_range = 1.6
		o.position = _v(d.cartello_godot) + Vector3(0, 0.55, -0.45)
		level.add_child(o)


# ----------------------------------------------------------------------------- sala della torre

func _torre(v: String) -> void:
	var d: Dictionary = dati["torre_" + v]
	_aggiungi("torre_%s.glb" % v, "PropostaTorre")
	# le pareti col varco sostituiscono quelle di prima; le plafoniere della parete col varco pure
	_togli_in("Sala/Architettura", ["sala_pareti_basse", "sala_pareti_alte", "sala_obloi"])
	_togli_in("Sala/PropostaBase", ["sala_lampade"] + Array(d.get("nascondi", [])))
	for nome in d.luci_tolte:
		var l := _luce(nome)
		if l:
			l.visible = false
	for nome in d.luci_neon:
		_metti_luce(nome, d.luci_neon[nome])
	if d.has("sposta_insegna_pesce_godot"):
		for percorso in ["Sala/Architettura/sala_insegna_pesce", "Sala/Luci/luce_insegna_rosa"]:
			var n := level.get_node_or_null(percorso) as Node3D
			if n:
				n.position += _v(d.sposta_insegna_pesce_godot)
	# la torre nella sala nuova (gli scivoli di oggi restano fuori: vanno rifatti)
	var c0 := Vector3(13.5, 0, -17.5)
	var R := Basis(Vector3.UP, deg_to_rad(d.ruota_torre_gradi))
	var T := Transform3D(R, c0 + _v(d.sposta_torre_godot) - R * c0)
	for percorso in ["Sala/TorreScivoli/sala_torre", "Sala/TorreScivoli/sala_torre_grigliati", "Sala/PropostaBase/sala_plafoniera_calda_3",
			"Sala/Luci/luce_calda_3", "Polaroid/Polaroid10"]:
		var n := level.get_node_or_null(percorso) as Node3D
		if n:
			n.transform = T * n.transform
	# luci: lampade rosse (cancello chiuso), insegna, la torre illuminata nella sala nuova
	for q in d.luci_rosse:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.12, 0.06)
		o.light_energy = 3.0
		o.omni_range = 4.5
		o.light_volumetric_fog_energy = 2.0
		o.position = _v(q) + Vector3(0, 0.0, 0.0)
		level.add_child(o)
	var oi := OmniLight3D.new()
	oi.light_color = Color(1.0, 0.85, 0.6)
	oi.light_energy = 1.2
	oi.omni_range = 5.0
	oi.position = _v(d.insegna)
	level.add_child(oi)
	var s := SpotLight3D.new()
	s.light_color = Color(0.72, 0.86, 1.0)
	s.light_energy = 14.0
	s.spot_range = 32.0
	s.spot_angle = 26.0
	s.shadow_enabled = true
	s.light_volumetric_fog_energy = 2.5
	level.add_child(s)
	s.position = _v(d.faro_torre)
	s.look_at_from_position(s.position, _v(d.mira_torre), Vector3.UP)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.6, 0.72, 0.85)
	fill.light_energy = 0.8
	fill.omni_range = 16.0
	var tg := _v(d.torre_godot)
	fill.position = tg + Vector3(0, 6.0, 0)
	level.add_child(fill)
	if v == "est":
		var dentro := OmniLight3D.new()   # luce della sala che filtra sotto il portone
		dentro.light_color = Color(0.75, 0.88, 1.0)
		dentro.light_energy = 2.0
		dentro.omni_range = 6.0
		dentro.position = Vector3(21.2, 1.0, -15.0)
		level.add_child(dentro)


func _scarta_varco(q: Dictionary, v: String) -> bool:
	var pos: Array = q.posizione
	var x: float = pos[0]
	var z: float = pos[2]
	if v == "nord":
		return absf(x) < 3.9 and z < -22.8
	return x > 18.8 and z < -10.8 and z > -19.2


# ----------------------------------------------------------------------------- piante

func _per_pianta() -> void:
	# via soffitto, cupola e travi: si guarda dall'alto
	_togli(["Sala/Cupola", "Sala/PropostaTorre/prop_sala_torre_nord_soffitto", "Sala/PropostaTorre/prop_sala_torre_est_soffitto"])
	_togli_in("Sala/Architettura", ["sala_soffitto", "sala_soffitto_travi", "sala_schegge_cupola"])


func _dopo_ingresso() -> void:
	if not pianta:
		return
	# luce piena dall'alto e niente nebbia: la pianta si deve leggere
	for we in level.find_children("*", "WorldEnvironment", true, false):
		var env := (we as WorldEnvironment).environment
		if env:
			env = env.duplicate()
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.55, 0.57, 0.6)
			env.ambient_light_energy = 0.9
			env.glow_enabled = false
			(we as WorldEnvironment).environment = env
	for fv in level.find_children("*", "FogVolume", true, false):
		(fv as Node3D).visible = false
	for n in level.find_children("PlafonieraBimbi", "", true, false):
		(n as Node3D).visible = false
	var sole := DirectionalLight3D.new()
	sole.name = "SolePianta"
	sole.light_color = Color(1.0, 0.97, 0.92)
	sole.light_energy = 1.6
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 120.0
	level.add_child(sole)
	sole.basis = Basis.looking_at(Vector3(-0.35, -1.0, -0.25).normalized(), Vector3(0, 0, -1))


# ----------------------------------------------------------------------------- utilità

func _togli(percorsi: Array) -> void:
	for percorso in percorsi:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()


func _togli_in(padre: String, nomi: Array) -> void:
	var pp := level.get_node_or_null(NodePath(padre))
	if pp == null:
		push_warning("manca " + padre)
		return
	for nome in nomi:
		var n := pp.get_node_or_null(NodePath(String(nome)))
		if n:
			pp.remove_child(n)
			n.free()
		else:
			push_warning("manca %s/%s" % [padre, nome])


func _aggiungi(file: String, nome: String) -> Node3D:
	var n := (load(DIR + file) as PackedScene).instantiate() as Node3D
	n.name = nome
	_rimappa(n)
	level.get_node("Sala").add_child(n)
	return n


## Tutti i materiali della sala per nome (prima di togliere qualcosa).
func _raccogli_materiali() -> void:
	for mi in level.get_node("Sala").find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i)
			if mat and mat.resource_name != "" and not materiali_sala.has(mat.resource_name):
				materiali_sala[mat.resource_name] = mat


## I pezzi delle proposte usano gli stessi materiali della sala; i loro con le texture disegnate le caricano qui.
func _rimappa(radice: Node) -> void:
	var nuovi := {}
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i)
			if mat == null:
				continue
			var nome := mat.resource_name
			if materiali_sala.has(nome):
				(mi as MeshInstance3D).set_surface_override_material(i, materiali_sala[nome])
			elif TEXTURE_PROP.has(nome) and mat is StandardMaterial3D:
				if not nuovi.has(nome):
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					sm.albedo_texture = load(DIR + "tex/" + TEXTURE_PROP[nome])
					sm.albedo_color = Color.WHITE
					if sm.emission_enabled:
						sm.emission_texture = sm.albedo_texture
						sm.emission = Color.WHITE
					nuovi[nome] = sm
				(mi as MeshInstance3D).set_surface_override_material(i, nuovi[nome])
			elif nome.begins_with("M_amb_"):
				print("materiale non trovato nella sala: ", nome)


func _luce(nome: String) -> Light3D:
	return level.get_node_or_null("Sala/Luci/" + nome) as Light3D


func _metti_luce(nome: String, pos) -> void:
	var l := _luce(nome)
	if l:
		l.position = _v(pos)


func _v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _picco_memoria() -> String:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return "?"
	while not f.eof_reached():
		var riga := f.get_line()
		if riga.begins_with("VmHWM:"):
			return "%d MB" % int(int(riga.split(":")[1].strip_edges().split(" ")[0]) / 1024)
	return "?"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

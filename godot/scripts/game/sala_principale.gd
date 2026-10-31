extends Node3D
## Demo giocabile della sala principale (vertical slice) sull'architettura vera dell'acquapark.
## Si entra dagli spogliatoi, si prende lo zaino-pompa dalla rastrelliera dei bagnini, si
## incontra la medusa affacciata alla vasca (la lampada si accende quando ti avvicini).
## Tappa 5 (PiscinaOnde): svuoti la piscina a onde con lo zaino, aspirando l'acqua della parte
## profonda e sparandola fuori dalla vasca; a piscina vuota il pulsante della botola si attiva, lo
## colpisci e scendi dalla scala del pozzo. Tappa 6, sotto la sala (ambienti tecnici): la sala
## pompe e il risveglio (RisveglioSalaPompe). Poi il ritorno al buio (tappa 7) e lei che sbuca dal
## bordo (tappa 8); la demo finisce al portone della sala della torre, sulla parete est.

## Materiale delle pozzanghere della sala (addon acqua) al posto di M_amb_pozzanghera del GLB.
@export var puddle_material: Material

## La lampada sul palo vicino alla vasca: si accende quando ti avvicini.
@export var statue_lamp: FlickerLight
## La luce della lampada (in sala_luci.glb): la mira la regola LuciSala.
@export var statue_lamp_light: NodePath
@export var lamp_trigger: Area3D
## La medusa al centro della sala (con un metodo pulse() per la sigla).
@export var statue: Node
## Easter egg (16 ottobre): il getto in faccia alla medusa affacciata le fa chiudere l'occhio per
## questi secondi (si chiude in 0,25 s e si riapre da solo); i colpi mentre è chiuso non lo fanno
## ripartire. Un bersaglio del getto (WaterHitbox) davanti alla sua faccia, di questo raggio (m).
@export var occhio_chiuso_secondi := 5.0
@export var raggio_faccia := 0.6
## Il pulsante per i bambini sul muro della vasca: fa partire la sigla.
@export var jingle_button: WaterButton
@export var jingle_button_mesh: NodePath
@export var hatch: Node
@export var hatch_button_mesh: NodePath
## Il checkpoint di quando la pozza della piscina a onde è vuota (lo raggiunge questo script).
@export var checkpoint_pozza: Checkpoint
## Gli ambienti tecnici sotto la sala (pozzo, camera delle onde, sala pompe, raccordo).
@export var tecnici: Node3D
## La sala pompe: ordine delle pompe, leva e risveglio (RisveglioSalaPompe).
@export var risveglio: Node
## Dove finisce la demo: in fondo alla scia della tappa 7 o, con la tappa 8, davanti al portone
## della sala della torre.
@export var fine_demo_trigger: Area3D
## Il testo sotto "FINE DEL CAPITOLO 1".
@export_multiline var fine_demo_testo := "La scia continua nel buio.\nGrazie per aver giocato!"
## La tappa 7, il ritorno al buio (RitornoAlBuio).
@export var ritorno: Node
## La tappa 8, lei che sbuca dal bordo della fossa nell'area bimbi (LeiSbuca).
@export var lei_sbuca: Node
## Il portone della sala della torre (PortoneTorre): la demo finisce lì, dopo la tappa 8.
@export var portone: Node
## La sala della torre (scenes/sala/torre/sala_torre.tscn): si carica in un thread quando il portone
## comincia ad aprirsi (dopo la tappa 8) e da lì in poi la demo finisce nella vasca del fondo della
## torre, non più davanti al portone. Vuoto: niente torre (la demo finisce al portone, come prima).
@export_file("*.tscn") var sala_torre_scena := "res://scenes/sala/torre/sala_torre.tscn"
## Il testo sotto "FINE DEL CAPITOLO 1" in fondo alla discesa della torre.
@export_multiline var fine_torre_testo := "La discesa continua nel buio.\nGrazie per aver giocato!"
## Il tunnel del viaggio sottomarino (l'inseguimento allungato dopo SB1, scelte dell'utente del 24 ottobre): si carica
## in un thread appena si entra nella torre e si costruisce a pezzi mentre si è nelle condotte; entra nel gioco dopo
## SB1 (lei si tuffa e si sale la scaletta); passata la sua prima curva, torre e condotte si liberano (memoria). Vuoto:
## niente tunnel (SB1 finisce col nero, come prima).
@export_file("*.tscn") var sala_sottomarino_scena := "res://scenes/sala/sottomarino/sala_sottomarino.tscn"
var sala_sottomarino: Node3D
var _sottomarino_in_caricamento := false
## I materiali campione degli shader del tunnel (CampioniTunnel): tenuti da quando si comincia a caricarlo.
var _campioni_tunnel: Array = []
var _torre_liberata := false
## Materiale del vetro della cupola (rivoli di pioggia, si accende coi lampi).
@export var dome_glass: Material
@export var show_controls_hint := true
## Litri nello zaino all'inizio della demo (se si parte già con lo zaino).
@export var start_water := 10.0
## Se falso si parte senza zaino: è sulla rastrelliera dei bagnini all'ingresso.
@export var start_with_pack := false

var demo_finished := false
## La sala della torre, quando è caricata.
var sala_torre: Node3D
## Precarica la sala della torre in un thread quando compaiono gli acquari (EnigmaAcquari.comparso):
## all'apertura del portone è già pronta anche su un PC lento. Negli strumenti che non arrivano alla
## torre (scatti, misure) si spegne con Engine.set_meta(&"precarica_torre_spento", true).
@export var precarica_torre := true
var _torre_in_caricamento := false
# La scena della torre caricata ma non ancora nella sala (il guscio provvisorio resta finché il
# portone non si apre); _torre_voluta: il portone si è aperto, la torre va messa appena c'è.
var _torre_pronta: PackedScene
var _torre_voluta := false
var _torre_fallita := false
## Riserva della torre: se il portone è aperto e il thread non ha ancora finito dopo tanti secondi, la si
## carica qui, a parte (CACHE_MODE_IGNORE_DEEP: senza aspettare le risorse che il thread tiene a metà).
const ATTESA_TORRE := 20.0
var _torre_voluta_da := 0
## Il portone aspetta la torre (AttesaZone): si costruisce a pezzi più grandi.
var _torre_in_attesa := false
## Interni e tecnici si stanno liberando a pezzi (entrati nella torre).
var _liberando := false
## La torre si sta riaccendendo a pezzi (AccensioneAPezzi).
var _accendendo_torre := false
# La torre costruita a pezzi e preparata (materiali già disegnati fuori vista) mentre si è all'enigma:
# resta nascosta e ferma finché il portone non si apre.
var _torre_nascosta: Node3D
var _torre_preparata := false
var _dentro_torre := false
# Gli shader dei materiali che la torre crea da codice, pronti dall'ingresso nella sala (SalaTorre.materiali_campione).
var _materiali_torre: Array[Material] = []

# Il bersaglio del getto sulla faccia della medusa (_faccia_bagnabile).
var _faccia: WaterHitbox


## La nebbia viola in tutta la sala (scelta dell'utente del 29 ottobre): la zona va dai muri della sala (x da -20 a 20,
## z da -24 a 20: tools/blender/ambiente_sala.py, X0..X1 e Y0..Y1) e dal fondo della piscina e della fossa dei bimbi
## alla cupola, quindi sale passando le porte (gli interni, la torre, la Risalita e i tecnici restano fuori);
## l'alone solo dalle lampade della sala (dietro i muri no).
const NEBBIA_SALA := AABB(Vector3(-20.0, -3.5, -24.0), Vector3(40.0, 22.5, 44.0))


func _nebbia_viola() -> void:
	var z := ZonaNebbiaViola.new()
	z.name = "NebbiaViola"
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = NEBBIA_SALA.size
	cs.shape = b
	cs.position = NEBBIA_SALA.get_center()
	z.add_child(cs)
	z.quota = 0.0
	z.luci = [^"../Sala", ^"../LuciSala"]
	add_child(z)


func _ready() -> void:
	# Prima del primo frame: meno varianti di shader, a parità di aspetto (UnificaMateriali).
	UnificaMateriali.unifica(self)
	_setup_hall()
	_nebbia_viola()
	if lamp_trigger:
		lamp_trigger.body_entered.connect(_on_lamp_trigger)
		# Ripartendo da un checkpoint già oltre il lampione la lampada è accesa: il trigger è
		# all'ingresso e non lo si ripassa.
		GameState.player_respawned.connect(_on_player_respawned)
	if jingle_button:
		jingle_button.pressed.connect(_on_jingle)
		_press_with(jingle_button, jingle_button_mesh)
	var hatch_button := get_node_or_null(^"Piscina/PulsantePortello") as WaterButton
	if hatch_button:
		_press_with(hatch_button, hatch_button_mesh)
	if hatch and hatch.has_signal(&"opened"):
		hatch.connect(&"opened", _on_hatch_opened)
	var puddle := get_node_or_null(^"Piscina/Pozza") as WaterTank
	if puddle and checkpoint_pozza:
		puddle.emptied.connect(func(): GameState.reach_checkpoint(checkpoint_pozza))
	if fine_demo_trigger:
		fine_demo_trigger.body_entered.connect(_on_fine_demo)
	_faccia_bagnabile.call_deferred()
	_setup_tecnici()
	if show_controls_hint:
		_show_hint.call_deferred()
	var p := GameState.player
	if p and p.water_pack:
		p.water_pack.set_tank_amount(start_water)
		if not start_with_pack:
			# anche nelle ripartenze (GameState lo rimette a chi parte con lo zaino o l'ha preso): da un checkpoint degli
			# interni prima dello stanzino non si riparte con lo zaino addosso
			p.water_pack.start_equipped = false
			if not p.has_item(&"zaino_pompa"):
				p.water_pack.set_equipped(false, false)
	# Con gli interni montati si parte dal risveglio nel corridoio (non quando si riparte da un
	# checkpoint o da un salvataggio).
	var interni := get_node_or_null(^"Interni")
	if p and interni and interni.has_method(&"fai_risveglio") and not GameState.is_restoring():
		interni.call(&"fai_risveglio", p)
	_setup_torre()


## La struttura di gioco dell'area bimbi: lo scivolo giallo e i tre tetti a piramide non hanno
## collisioni nel GLB (solo pedane, passerelle, parapetti e scala): ci si passava attraverso (prova
## della v0.3.2, punto 10, "lo scivolo giallo è incorporeo"). Una collisione che segue la forma
## esatta della mesh: sullo scivolo si cammina e si scivola, sui tetti si sta sopra.
func _collisione_struttura_gioco() -> void:
	var mi := get_node_or_null(^"Sala/AreaBimbi/sala_struttura_gioco") as MeshInstance3D
	if mi == null:
		for n in find_children("sala_struttura_gioco", "MeshInstance3D", true, false):
			mi = n as MeshInstance3D
			break
	if mi == null or mi.mesh == null or mi.has_node(^"CollisioneForma"):
		return
	var corpo := StaticBody3D.new()
	corpo.name = "CollisioneForma"
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var trimesh := mi.mesh.create_trimesh_shape()
	trimesh.backface_collision = true   # bordi e testate sottili: niente da attraversare da dietro
	forma.shape = trimesh
	corpo.add_child(forma)
	mi.add_child(corpo)


## Le scalette della piscina a onde: la loro collisione nel GLB (sala_scaletta_e e _o) è una scatola sola, dal fondo
## fino alla cima dei corrimano, 95 cm sopra il bordo, e in cima alla scala (Ladder) il giocatore ci sbatteva contro e
## ricadeva giù: dalla piscina si usciva solo dalla spiaggia (riscontro della 0.3.16, col controller). La scatola resta
## (sul bordo i corrimano non si attraversano camminando), e la Ladder la fa passare solo mentre si scavalca la cima
## ([member Ladder.attraversa]).
const SCALETTE_PISCINA := {"Piscina/ScalettaEst": "sala_scaletta_e", "Piscina/ScalettaOvest": "sala_scaletta_o"}


func _scalette_piscina() -> void:
	var sala := get_node_or_null(^"Sala/Piscina")
	if sala == null:
		return
	for percorso in SCALETTE_PISCINA:
		var l := get_node_or_null(NodePath(percorso)) as Ladder
		if l == null:
			continue
		for corpo in sala.find_children(String(SCALETTE_PISCINA[percorso]), "StaticBody3D", true, false):
			l.attraversa.append(l.get_path_to(corpo))


## I due teli di Jilly ai lati della statua, bruciati e scarabocchiati (richiesta dell'utente del 30 ottobre: "vanno
## bruciati e scarabocchiati moltissimo"; le texture le fa assets_src/ambienti_interni/poster/rovina.py, telo_arcobaleno e
## telo_bagnina). Il GLB della sala resta com'è: lo usa anche lo spot VHS, dove il parco è ancora nuovo. La carta è
## incollata sulla lamiera della cornice: dove manca (alpha scissor) si vede la lamiera.
const TELI_ROVINATI := {
	"sala_cartellone_mascotte_0": ["M_amb_cartellone_medusa", "res://assets/ambiente/sala/cartelloni_rovinati/telo_arcobaleno_rovinato.png"],
	"sala_cartellone_mascotte_1": ["M_amb_cartellone_bagnino", "res://assets/ambiente/sala/cartelloni_rovinati/telo_bagnina_rovinato.png"],
}


## Ritocchi alla sala importata: lampada della statua, vetro della cupola, luci rosse.
func _setup_hall() -> void:
	_cordone_vasca()
	_collisione_struttura_gioco()
	_scalette_piscina()
	_teli_rovinati()
	# La lampada sul palo: mira, cono e ombre li regola LuciSala (luce da ritratto sul viso della
	# medusa); qui solo l'accensione con lo sfarfallio, sulla luce e sulla lampadina.
	var lamp := get_node_or_null(statue_lamp_light) as SpotLight3D
	if lamp:
		# La lampadina (amb_lampione*): la si cerca in tutta la sala, il palo sta nel GLB del centro.
		var bulb: StandardMaterial3D = null
		var sala := get_node_or_null(^"Sala")
		if sala:
			for n in sala.find_children("amb_lampione*", "MeshInstance3D", true, false):
				bulb = _find_surface_material(n, "M_amb_lampadina")
				if bulb:
					break
		if statue_lamp:
			statue_lamp.set_targets(lamp, bulb)
	if dome_glass:
		var glass := get_node_or_null(^"Sala/Cupola/sala_cupola_vetro") as MeshInstance3D
		if glass and glass.mesh:
			for i in glass.mesh.get_surface_count():
				glass.set_surface_override_material(i, dome_glass)
	var lights := get_node_or_null(^"Sala/Luci")
	if lights:
		for l in lights.get_children():
			if l is OmniLight3D and String(l.name).begins_with("luce_emergenza"):
				(l as OmniLight3D).light_volumetric_fog_energy = 2.2
				# Le due vicine all'ingresso fanno ombre (la statua e il piedistallo).
				if String(l.name) in ["luce_emergenza_34", "luce_emergenza_35"]:
					(l as OmniLight3D).shadow_enabled = true
					l.set_meta(&"grafica_priorita_ombra", 1)
			elif l is SpotLight3D and String(l.name).begins_with("luce_neon"):
				(l as SpotLight3D).light_volumetric_fog_energy = 0.8
			elif l is SpotLight3D and String(l.name).begins_with("luce_cartellone"):
				# Faretti caldi sui due teli con la mascotte ai lati della statua (LookSala non li
				# conosce): valori di INTEGRAZIONE.md dell'ambiente.
				var c := l as SpotLight3D
				c.light_color = Color(1.0, 0.78, 0.5)
				# Secondari rispetto alla statua: deboli e stretti sul telo.
				c.light_energy = 1.2
				c.spot_angle = 22.0
				c.spot_range = 6.0
				c.shadow_enabled = false
				c.light_volumetric_fog_energy = 0.8
	# Illuminazione globale calcolata in anticipo (tools/bake_voxel_gi.gd), così il preset Alto
	# non la calcola all'avvio: va messa adesso, prima che la grafica la calcoli (in differita).
	if puddle_material:
		for n in find_children("*pozzanghere*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh:
				for i in mi.mesh.get_surface_count():
					var m := mi.mesh.surface_get_material(i)
					if m and m.resource_name == "M_amb_pozzanghera":
						mi.set_surface_override_material(i, puddle_material)


## La tappa 5 rifatta (decisa dall'utente il 15 ottobre): niente ruota a pale né secchio da
## riempire, niente recinto, niente turbina dello scarico. Finché l'ambiente non manda i modelli
## nuovi, il cancello del recinto resta spalancato (con la sua collisione) e la turbina dello
## scarico, che non serve più, non si vede.
## Il muro invisibile del cordone chiuso intorno alla vasca della medusa (cordone_vasca_0..19 di
## sala_vasca_centrale.glb, D1): ferma il giocatore ma non il getto (l'easter egg dell'occhio e il
## pulsante della sigla si raggiungono da fuori), sul livello "barriere". Lo mette già
## ambiente_post_import.gd; qui per sicurezza, se un import vecchio non l'avesse fatto.
func _cordone_vasca() -> void:
	for n in find_children("cordone_vasca_*", "CollisionObject3D", true, false):
		(n as CollisionObject3D).collision_layer = Layers.BARRIERS


## Duplica il materiale [param mat_name] di una mesh importata e lo mette come override
## (così si può cambiare l'emissione di quella mesh soltanto).
func _teli_rovinati() -> void:
	var arch := get_node_or_null(^"Sala/Architettura")
	if arch:
		metti_teli_rovinati(arch)


## Mette sui due teli di [param arch] (la sala importata) il materiale con la texture rovinata: copia di quello
## importato (stessi colori dei vertici e ruvidezza) con l'alpha scissor come i M_amb_alfa_*. Torna quante superfici ha
## cambiato (2). La usano anche gli scatti, che caricano la sala a pezzi (proposte/poster_sala/scatti_teli.gd).
static func metti_teli_rovinati(arch: Node) -> int:
	var fatti := 0
	for nome: String in TELI_ROVINATI:
		var mi := arch.find_child(nome, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_warning("sala: niente %s per il telo rovinato" % nome)
			continue
		var voce: Array = TELI_ROVINATI[nome]
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or m.resource_name != voce[0]:
				continue
			var r := m.duplicate() as StandardMaterial3D
			r.albedo_texture = load(voce[1]) as Texture2D
			r.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			r.alpha_scissor_threshold = 0.5
			r.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			mi.set_surface_override_material(i, r)
			fatti += 1
	return fatti


static func _find_surface_material(n: Node, mat_name: String) -> StandardMaterial3D:
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return null
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m is StandardMaterial3D and m.resource_name == mat_name:
			var copy := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.emission_enabled = true
			mi.set_surface_override_material(i, copy)
			return copy
	return null


## Il tappo del pulsante del modello rientra quando il pulsante è premuto.
func _press_with(button: WaterButton, mesh_path: NodePath) -> void:
	var cap := get_node_or_null(mesh_path) as Node3D
	if cap == null:
		return
	var rest := cap.position
	var inward := cap.global_basis.z.normalized() * -0.025
	button.powered_changed.connect(func(on: bool):
		var t := create_tween()
		t.tween_property(cap, ^"position", rest + (inward if on else Vector3.ZERO), 0.12))


func _hud() -> Hud:
	var p := GameState.player
	return p.get_node_or_null(^"HUD") as Hud if p else null


func _show_hint() -> void:
	# durante le scene (il risveglio con lo squalo) i comandi sono bloccati: la riga arriva quando il
	# giocatore li riprende, non sopra la scena
	var p := GameState.player
	while p and is_instance_valid(p) and not p.input_enabled and is_inside_tree():
		await get_tree().process_frame
	var hud := _hud()
	if hud:
		hud.show_hint("WASD muoviti · Shift corri · Ctrl abbassati · Spazio salta · E usa · Esc pausa", 10.0)


## Chiamato quando il giocatore prende lo zaino.
func on_pack_taken() -> void:
	var hud := _hud()
	if hud:
		hud.show_hint("Tasto destro: aspira l'acqua · Tasto sinistro: spruzza", 9.0)


func _on_lamp_trigger(body: Node3D) -> void:
	if body is Player and statue_lamp and not statue_lamp.is_on:
		statue_lamp.turn_on()


func _on_player_respawned() -> void:
	var p := GameState.player
	if statue_lamp and not statue_lamp.is_on and p and p.global_position.z < lamp_trigger.global_position.z:
		statue_lamp.turn_on(true)


func _on_jingle() -> void:
	# La sigla (rovinata) la suona l'addon audio; qui i canali della campana pulsano a tempo.
	if statue and statue.has_method(&"pulse"):
		statue.call(&"pulse", 6.0)


func _on_hatch_opened() -> void:
	# Sotto c'è il pozzo con la scala: si scende nella camera delle onde.
	pass


## Ritocchi agli ambienti tecnici montati sotto la sala.
func _setup_tecnici() -> void:
	if tecnici == null:
		return
	# Il coperchio in cima al pozzo nel modello della camera è un doppione del portello della
	# sala (LEGGIMI degli ambienti tecnici): via, collisione compresa (tolto, non nascosto: il controllo di
	# posizionamento rende visibile quello che è nascosto e lo trovava dentro il fondo della piscina).
	var doppione := tecnici.get_node_or_null(^"Ambienti/CameraOnde/PORTELLO") as Node3D
	if doppione:
		doppione.get_parent().remove_child(doppione)
		doppione.queue_free()


## Il bersaglio del getto sulla faccia della medusa (easter egg dell'occhio che si chiude). Segue
## la faccia a ogni passo della fisica (_segui_faccia). Prima si metteva una volta sola, due passi di
## fisica dopo l'ingresso della sala: nel gioco il caricamento è lungo e il primo fotogramma recupera
## più passi di fisica prima di disegnare, così l'animazione non era ancora partita e il bersaglio
## restava sull'occhio della posa di riposo, 2,6 m sopra la faccia (v0.3.1: "se spruzzo l'acqua in
## faccia alla medusina non chiude l'occhio"; nei test, a 60 fotogrammi fissi, non succedeva).
func _faccia_bagnabile() -> void:
	var m := statue as Node3D
	if m == null or not m.has_method(&"chiudi_occhio") or not m.has_method(&"get_eye_position"):
		return
	_faccia = WaterHitbox.new()
	_faccia.name = "FacciaMedusa"
	# Figlio della medusa (quando sparisce al buio si spegne con lei), ma la posizione la decide lei.
	_faccia.top_level = true
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = raggio_faccia
	forma.shape = sfera
	_faccia.add_child(forma)
	m.add_child(_faccia)
	_segui_faccia()
	_faccia.water_hit.connect(func(_litri: float, _punto: Vector3, _dir: Vector3):
		if m.visible and not bool(m.call(&"occhio_chiuso")):
			m.call(&"chiudi_occhio", occhio_chiuso_secondi))


func _physics_process(_delta: float) -> void:
	_segui_faccia()


## Il bersaglio del getto davanti alla faccia: dove sta l'occhio adesso (con l'animazione e lo
## sguardo), 15 cm più in basso.
func _segui_faccia() -> void:
	if _faccia == null or not is_instance_valid(_faccia) or not is_instance_valid(statue):
		return
	_faccia.global_position = (statue.call(&"get_eye_position") as Vector3) + Vector3(0.0, -0.15, 0.0)


func _on_fine_demo(body: Node3D) -> void:
	if demo_finished or not body is Player:
		return
	if sala_torre_scena != "":
		return  # con la sala della torre la demo finisce in fondo alla discesa (_on_fine_torre)
	# Al portone della sala della torre la demo finisce solo dopo la tappa 8; se si apre all'arrivo
	# (PortoneTorre.Apertura.ALL_ARRIVO) la scritta arriva quando è aperto.
	if portone and portone.has_method(&"si_puo_aprire"):
		if not bool(portone.call(&"si_puo_aprire")):
			return
		demo_finished = true
		if not bool(portone.call(&"is_aperto")):
			portone.call(&"apri")
			await portone.aperto
			await get_tree().create_timer(0.8, false).timeout
	demo_finished = true
	_fine_della_demo(fine_demo_testo)


# --- La sala della torre ------------------------------------------------------------------------

func _setup_torre() -> void:
	if sala_torre_scena == "" or portone == null:
		return
	_materiali_torre = SalaTorre.materiali_campione()
	AttesaZone.non_pronta(&"torre")
	AttesaZone.non_pronta(&"tunnel")
	# l'enigma risolto con la torre non ancora pronta (un PC lento): il portone aspetta, la torre va avanti più svelta
	if portone and portone.has_signal(&"attesa_iniziata"):
		portone.connect(&"attesa_iniziata", _torre_attesa_dal_portone)
	portone.connect(&"apertura_iniziata", _carica_torre)
	var enigma := get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma and enigma.has_signal(&"comparso") and precarica_torre and not Engine.has_meta(&"precarica_torre_spento"):
		enigma.connect(&"comparso", _precarica_torre)
		if bool(enigma.get(&"comparsi")):
			_precarica_torre.call_deferred()
	if GameState.is_restoring() and String(GameState.snapshot.get("checkpoint", "")).begins_with("SalaSottomarino"):
		# si riparte da un checkpoint del tunnel: torre e condotte non ci sono più, solo il tunnel
		_ripristina_sottomarino.call_deferred()
		return
	if GameState.is_restoring() and String(GameState.snapshot.get("checkpoint", "")).begins_with("SalaTorre"):
		# si riparte da un checkpoint della torre: la si carica subito, si è già dentro
		_aggiungi_torre(load(sala_torre_scena) as PackedScene)
		_entra_in_torre(false)
	else:
		# ripartendo da un checkpoint col portone già aperto (load_state non riapre) la torre va caricata
		GameState.player_respawned.connect(func():
			if sala_torre == null and portone.has_method(&"is_aperto") and bool(portone.call(&"is_aperto")):
				_carica_torre())


## Il portone si apre: la torre entra nella sala appena è caricata (o subito, se è già pronta).
func _carica_torre() -> void:
	if not _torre_voluta:
		_torre_voluta_da = Time.get_ticks_msec()
	_torre_voluta = true
	if sala_torre:
		return
	if not _torre_preparata:
		AttesaZone.attendi(&"torre")
	if _torre_preparata:
		_mostra_torre()
	elif _torre_nascosta:
		return  # si sta preparando: entra appena è pronta
	elif _torre_pronta:
		_prepara_torre()
	elif _torre_fallita:
		_aggiungi_torre(load(sala_torre_scena) as PackedScene)
	elif not _torre_in_caricamento:
		_precarica_torre()
		if not _torre_in_caricamento:
			_aggiungi_torre(load(sala_torre_scena) as PackedScene)


## Comincia a caricare la torre in un thread, senza metterla ancora nella sala.
func _precarica_torre() -> void:
	if sala_torre or _torre_in_caricamento or _torre_pronta or sala_torre_scena == "" or Game.uscendo:
		return
	# già caricata prima di una ripartenza (GameState.tieni): niente thread, si prepara subito
	var tenuta := GameState.tenuta(sala_torre_scena) as PackedScene
	if tenuta:
		_torre_fallita = false
		for r in SalaInseguimento.risorse():
			if not ResourceLoader.has_cached(r):
				Game.carica_in_thread(r)
		_torre_pronta = tenuta
		_prepara_torre.call_deferred()
		return
	if Game.carica_in_thread(sala_torre_scena, "PackedScene") == OK:
		_torre_in_caricamento = true
		_torre_fallita = false
		# e i file che l'inseguimento carica costruendosi (lei, le fonti degli arredi)
		for r in SalaInseguimento.risorse():
			Game.carica_in_thread(r)
	else:
		_torre_fallita = true


func _process(_delta: float) -> void:
	if _sottomarino_in_caricamento:
		_aggiorna_sottomarino()
	if not _torre_in_caricamento or Game.uscendo:
		return
	var stato := Game.stato_thread(sala_torre_scena)
	if stato == ResourceLoader.THREAD_LOAD_LOADED:
		_torre_in_caricamento = false
		var scena := ResourceLoader.load_threaded_get(sala_torre_scena) as PackedScene
		# tenuta per le ripartenze, con i file dell'inseguimento già arrivati (vedi GameState.tieni)
		GameState.tieni(sala_torre_scena, scena)
		for r in SalaInseguimento.risorse():
			if ResourceLoader.has_cached(r):
				GameState.tieni(r, load(r))
		# (con la riserva già in sala la copia del thread non serve: si lascia andare)
		if sala_torre == null:
			_torre_pronta = scena
			_prepara_torre()
	elif stato == ResourceLoader.THREAD_LOAD_IN_PROGRESS and _torre_voluta and sala_torre == null \
			and Time.get_ticks_msec() - _torre_voluta_da > ATTESA_TORRE * 1000.0:
		# Il portone è aperto da un po' e il thread non ha finito (un PC lento, la cache fredda). Prima qui si
		# caricava e si costruiva tutta la torre in un fotogramma (20 s di gioco fermo nella misura del 25 ottobre):
		# adesso si aspetta il thread senza bloccare; cosa si vede intanto lo decide AttesaZone.
		AttesaZone.attendi(&"torre")
	elif stato == ResourceLoader.THREAD_LOAD_FAILED or stato == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Riserva: se il thread non ce la fa, la torre si carica qui (un attimo di fermo), così il
		# giocatore non resta mai davanti al portone aperto senza la sala.
		_torre_in_caricamento = false
		_torre_fallita = true
		push_warning("Sala della torre: caricamento nel thread fallito (%s), la carico appena serve" % sala_torre_scena)
		if _torre_voluta:
			_aggiungi_torre(load(sala_torre_scena) as PackedScene)


## La torre caricata entra nella sala nascosta e ferma, si costruisce un pezzo per fotogramma e si
## disegna una volta fuori vista; all'apertura del portone basta mostrarla ([method _mostra_torre]).
func _prepara_torre() -> void:
	if sala_torre or _torre_nascosta or _torre_pronta == null:
		return
	var t := _torre_pronta.instantiate() as Node3D
	t.set(&"costruzione_a_pezzi", true)
	t.set(&"inseguimento_continua", sala_sottomarino_scena != "")
	t.visible = false
	t.process_mode = Node.PROCESS_MODE_DISABLED
	_torre_nascosta = t
	add_child(t)
	# (col portone già aperto, a pezzi più grandi: si entra prima, mai tutta in un fotogramma)
	await t.call(&"costruisci_a_pezzi", 20.0 if _torre_voluta or _torre_in_attesa else 8.0)
	# (fuori dall'albero: una morte ha ricaricato la sala mentre la torre si preparava)
	if not is_instance_valid(t) or t != _torre_nascosta or not t.is_inside_tree():
		return
	await t.call(&"prepara_materiali", get_viewport())
	if not is_instance_valid(t) or t != _torre_nascosta or not t.is_inside_tree():
		return
	_torre_preparata = true
	AttesaZone.pronta(&"torre")
	if _torre_voluta:
		_mostra_torre()


func _accendi_torre() -> void:
	_accendendo_torre = true
	await AccensioneAPezzi.accendi(sala_torre)
	_accendendo_torre = false


## Il portone aspetta la torre: che si stia caricando (se non è partita) e che si costruisca a pezzi più grandi.
func _torre_attesa_dal_portone() -> void:
	AttesaZone.attendi(&"torre")
	_torre_in_attesa = true
	if sala_torre or _torre_nascosta or _torre_pronta:
		return
	if _torre_fallita:
		# il thread non ce l'ha fatta: l'unico caso che carica qui
		_torre_pronta = load(sala_torre_scena) as PackedScene
		_prepara_torre()
	elif not _torre_in_caricamento:
		_precarica_torre()


## Vero mentre la torre si prepara nascosta (si costruisce a pezzi e si disegna fuori vista): prima di liberare la sala
## (la ripartenza dopo una morte, il ritorno al titolo) si aspetta che finisca (Game.aspetta_caricamenti).
func lavori_in_corso() -> bool:
	# (e i lavori a pezzi dei blocchi: la torre che si riaccende, interni e tecnici che si liberano, il tunnel che si
	# costruisce, la Risalita che si costruisce o si riaccende)
	return (is_instance_valid(_torre_nascosta) and _torre_nascosta.is_inside_tree() and not _torre_preparata) \
			or _accendendo_torre or _liberando \
			or (is_instance_valid(sala_sottomarino) and bool(sala_sottomarino.get(&"_costruendo"))) \
			or (get_node_or_null(^"Risalita") != null and get_node(^"Risalita").has_method(&"lavori_in_corso") \
				and bool(get_node(^"Risalita").call(&"lavori_in_corso")))


func _mostra_torre() -> void:
	if sala_torre or _torre_nascosta == null:
		return
	var t0 := Time.get_ticks_usec()
	sala_torre = _torre_nascosta
	_torre_nascosta = null
	# (riaccesa a pezzi: tutta insieme erano 2 s di gioco fermo; il portone intanto si sta aprendo)
	_accendi_torre()
	var t1 := Time.get_ticks_usec()
	sala_torre.visible = true
	var t2 := Time.get_ticks_usec()
	_completa_torre()
	if OS.has_environment("TORRE_TEMPI"):
		print("mostra torre: process %.1f ms, visible %.1f ms, completa %.1f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (Time.get_ticks_usec() - t2) / 1000.0])


## Riserva e ripartenze dentro la torre: la torre si mette subito, costruita tutta in una volta.
func _aggiungi_torre(scena: PackedScene) -> void:
	if sala_torre or scena == null:
		return
	if _torre_nascosta and is_instance_valid(_torre_nascosta):
		_torre_nascosta.queue_free()
		_torre_nascosta = null
	sala_torre = scena.instantiate()
	sala_torre.set(&"inseguimento_continua", sala_sottomarino_scena != "")
	add_child(sala_torre)
	_completa_torre()


func _completa_torre() -> void:
	AttesaZone.pronta(&"torre")
	# il guscio provvisorio dietro il portone (sala_architettura.glb) lascia il posto alla sala vera
	var guscio := find_child("sala_torre_guscio", true, false)
	if guscio:
		guscio.queue_free()
	if sala_torre.has_signal(&"discesa_finita"):
		sala_torre.connect(&"discesa_finita", _on_fine_torre)
	# il tunnel del viaggio sottomarino: si carica nel thread da adesso; le condotte lo chiamano dopo SB1
	if sala_sottomarino_scena != "":
		_precarica_sottomarino()
		var ins: Node3D = sala_torre.get(&"inseguimento")
		if ins:
			_collega_inseguimento(ins)
		elif sala_torre.has_signal(&"inseguimento_aggiunto"):
			sala_torre.connect(&"inseguimento_aggiunto", _collega_inseguimento)
	# appena oltre il portone, sulla passerella: si è entrati
	var entrata := Area3D.new()
	entrata.name = "EntrataTorre"
	entrata.collision_layer = 0
	entrata.collision_mask = Layers.PLAYER
	entrata.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 3.2)
	forma.shape = box
	entrata.add_child(forma)
	sala_torre.add_child(entrata)
	entrata.global_position = Vector3(22.4, 1.5, -15.0)
	entrata.body_entered.connect(func(corpo):
		if corpo is Player:
			_entra_in_torre(true))


## Dentro la torre: il portone si richiude alle spalle (niente ritorno: la soglia si chiude subito) e gli ambienti che
## non servono più (interni e tecnici, dopo la tappa 8) si scaricano per la memoria, col portone chiuso del tutto.
func _entra_in_torre(chiudi: bool) -> void:
	if _dentro_torre:
		return
	_dentro_torre = true
	if chiudi and portone and portone.has_method(&"chiudi"):
		portone.call(&"chiudi")
		# mentre l'anta scorre dalla soglia si vede ancora la sala: via quando è chiuso (prima andavano via subito, e
		# tornando indietro di corsa si restava nella sala senza; sonda del 29 ottobre)
		if portone.has_signal(&"chiuso") and float(portone.get(&"quanto")) > 0.0:
			portone.connect(&"chiuso", _scarica_ambienti, CONNECT_ONE_SHOT)
			return
	elif portone and portone.has_method(&"resta_chiuso"):
		portone.call(&"resta_chiuso")
	_scarica_ambienti.call_deferred()


## Interni e tecnici via, qualche frame dopo (chi ha chiamate in sospeso sulle loro luci le finisce prima).
func _scarica_ambienti() -> void:
	for i in 3:
		await get_tree().process_frame
	var via: Array = [tecnici, get_node_or_null(^"Interni")]
	tecnici = null
	risveglio = null
	# a pezzi, dalle foglie (tutti insieme erano 3 s di gioco fermo entrando nella torre)
	_liberando = true
	for n in via:
		if n and is_instance_valid(n):
			await AccensioneAPezzi.libera(n)
	_liberando = false


func _on_fine_torre() -> void:
	if demo_finished:
		return
	demo_finished = true
	_fine_della_demo(fine_torre_testo)


## La fine del tunnel del viaggio sottomarino (il portello chiuso, lo schianto, il nero): solo "FINE DEL CAPITOLO 1", senza
## la riga della torre (collaudo D4: "La discesa continua nel buio." lì non c'entra).
func _on_fine_tunnel() -> void:
	if demo_finished:
		return
	demo_finished = true
	_fine_della_demo("")


## Quanto resta la scritta della fine (secondi), e dopo quanto il gioco torna da solo al titolo.
const FINE_SCRITTA := 9.0
const FINE_AL_TITOLO := 9.5


## La scritta "FINE DEL CAPITOLO 1" e, finita la scritta, il ritorno al titolo da solo (scelta 12A dell'utente: prima restava
## il nero e bisognava premere Esc). Il timer si ferma con la pausa; se dalla pausa si torna al titolo prima, il livello
## non c'è più e il collegamento se ne va con lui: non scatta due volte.
func _fine_della_demo(testo: String) -> void:
	var hud := _hud()
	if hud:
		hud.show_banner("FINE DEL CAPITOLO 1", testo, FINE_SCRITTA)
	get_tree().create_timer(FINE_AL_TITOLO, false).timeout.connect(_torna_al_titolo)


func _torna_al_titolo() -> void:
	if is_inside_tree() and get_tree().current_scene == self:
		Game.return_to_title()


# --- Il tunnel del viaggio sottomarino ---------------------------------------------------------------------------------

func _precarica_sottomarino() -> void:
	if sala_sottomarino or _sottomarino_in_caricamento or Game.uscendo:
		return
	if _campioni_tunnel.is_empty():
		_campioni_tunnel = CampioniTunnel.carica()
	if Game.carica_in_thread(sala_sottomarino_scena, "PackedScene") == OK:
		_sottomarino_in_caricamento = true
		# e i file che il tunnel carica costruendosi (i modelli, lei)
		for r in SalaSottomarino.risorse():
			Game.carica_in_thread(r)


## Il thread ha finito: il tunnel entra nel livello (fermo, senza lei in giro) e si costruisce a pezzi.
func _aggiorna_sottomarino() -> void:
	var stato := Game.stato_thread(sala_sottomarino_scena)
	if stato == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	_sottomarino_in_caricamento = false
	if stato == ResourceLoader.THREAD_LOAD_LOADED and sala_sottomarino == null:
		_metti_sottomarino(ResourceLoader.load_threaded_get(sala_sottomarino_scena) as PackedScene, true)


func _metti_sottomarino(scena: PackedScene, a_pezzi: bool) -> void:
	if sala_sottomarino or scena == null:
		return
	sala_sottomarino = scena.instantiate() as Node3D
	sala_sottomarino.name = "SalaSottomarino"
	add_child(sala_sottomarino)
	sala_sottomarino.connect(&"prima_curva_passata", _libera_torre)
	sala_sottomarino.connect(&"fine_demo", _on_fine_tunnel)
	if a_pezzi:
		await sala_sottomarino.call(&"costruisci_a_pezzi")
	else:
		sala_sottomarino.call(&"costruisci")
	# costruito, riscaldato e con le forme dei tentacoli: la scaletta dopo SB1 si può aprire
	if is_instance_valid(sala_sottomarino) and sala_sottomarino.is_inside_tree():
		AttesaZone.pronta(&"tunnel")


func _collega_inseguimento(ins: Node3D) -> void:
	if ins.has_signal(&"sb1_finito") and not ins.is_connected(&"sb1_finito", _attiva_sottomarino):
		ins.connect(&"sb1_finito", _attiva_sottomarino)
	if ins.has_signal(&"sb1_in_attesa") and not ins.is_connected(&"sb1_in_attesa", _accelera_sottomarino):
		ins.connect(&"sb1_in_attesa", _accelera_sottomarino)


## SB1 aspetta il tunnel: che si carichi (se non è partito) e che si costruisca a pezzi più grandi.
func _accelera_sottomarino() -> void:
	if sala_sottomarino == null:
		if not _sottomarino_in_caricamento:
			_precarica_sottomarino()
	elif not bool(sala_sottomarino.get(&"costruita")):
		sala_sottomarino.call(&"costruisci_a_pezzi", 50.0)


## Dopo SB1: il tunnel entra nel gioco. Se il thread non ha ancora finito non si blocca più (prima: load e
## costruzione intera in un fotogramma): si aspetta il thread e la costruzione va avanti a pezzi più grandi (al più
## 50 ms per fotogramma); cosa si vede intanto lo decide AttesaZone. Solo col thread fallito si carica qui.
func _attiva_sottomarino() -> void:
	if sala_sottomarino == null or not bool(sala_sottomarino.get(&"costruita")):
		AttesaZone.attendi(&"tunnel")
	if sala_sottomarino == null and not _sottomarino_in_caricamento:
		_precarica_sottomarino()
	while sala_sottomarino == null:
		if not _sottomarino_in_caricamento:
			# il thread è finito senza il tunnel (fallito): l'unico caso che carica qui
			_metti_sottomarino(load(sala_sottomarino_scena) as PackedScene, true)
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if not bool(sala_sottomarino.get(&"costruita")):
		await sala_sottomarino.call(&"costruisci_a_pezzi", 50.0)
	AttesaZone.pronta(&"tunnel")
	sala_sottomarino.call(&"attiva_tunnel")


## Passata la prima curva del tunnel: la porta del bacino si chiude alle spalle e torre e condotte si liberano.
func _libera_torre() -> void:
	if _torre_liberata:
		return
	_torre_liberata = true
	if sala_sottomarino:
		sala_sottomarino.call(&"chiudi_porta_bacino")
	if sala_torre and is_instance_valid(sala_torre):
		sala_torre.queue_free()
	sala_torre = null


## Ripartenza da un checkpoint del tunnel: solo il tunnel (costruito tutto), lei dietro, gli ambienti di prima via.
func _ripristina_sottomarino() -> void:
	_torre_liberata = true
	_dentro_torre = true
	if portone and portone.has_method(&"resta_chiuso"):
		portone.call(&"resta_chiuso")
	_scarica_ambienti()
	_campioni_tunnel = CampioniTunnel.carica()
	_metti_sottomarino(load(sala_sottomarino_scena) as PackedScene, false)
	sala_sottomarino.call(&"chiudi_porta_bacino")
	var cp := String(GameState.snapshot.get("checkpoint", ""))
	var s := float(cp.get_slice("Checkpoint_", 1)) if cp.contains("Checkpoint_") else 6.0
	sala_sottomarino.call(&"riparti_da", s)

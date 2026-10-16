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
## Il testo sotto "FINE DELLA DEMO".
@export_multiline var fine_demo_testo := "La scia continua nel buio.\nGrazie per aver giocato!"
## La tappa 7, il ritorno al buio (RitornoAlBuio).
@export var ritorno: Node
## La tappa 8, lei che sbuca dal bordo della fossa nell'area bimbi (LeiSbuca).
@export var lei_sbuca: Node
## Il portone della sala della torre (PortoneTorre): la demo finisce lì, dopo la tappa 8.
@export var portone: Node
## Materiale del vetro della cupola (rivoli di pioggia, si accende coi lampi).
@export var dome_glass: Material
@export var show_controls_hint := true
## Litri nello zaino all'inizio della demo (se si parte già con lo zaino).
@export var start_water := 10.0
## Se falso si parte senza zaino: è sulla rastrelliera dei bagnini all'ingresso.
@export var start_with_pack := false

var demo_finished := false

# Il bersaglio del getto sulla faccia della medusa (_faccia_bagnabile).
var _faccia: WaterHitbox


func _ready() -> void:
	# Prima del primo frame: meno varianti di shader, a parità di aspetto (UnificaMateriali).
	UnificaMateriali.unifica(self)
	_setup_hall()
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
		if not start_with_pack and not p.has_item(&"zaino_pompa"):
			p.water_pack.set_equipped(false, false)
	# Con gli interni montati si parte dal risveglio nel corridoio (non quando si riparte da un
	# checkpoint o da un salvataggio).
	var interni := get_node_or_null(^"Interni")
	if p and interni and interni.has_method(&"fai_risveglio") and not GameState.is_restoring():
		interni.call(&"fai_risveglio", p)


## Ritocchi alla sala importata: lampada della statua, vetro della cupola, luci rosse.
func _setup_hall() -> void:
	_cordone_vasca()
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
	var hud := _hud()
	if hud:
		hud.show_hint("WASD muoviti · Shift corri · Ctrl abbassati · Spazio salta · E usa · F torcia · Esc pausa", 10.0)


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
	# sala (LEGGIMI degli ambienti tecnici): via, collisione compresa.
	var doppione := tecnici.get_node_or_null(^"Ambienti/CameraOnde/PORTELLO") as Node3D
	if doppione:
		doppione.visible = false
		for c in doppione.find_children("*", "CollisionObject3D", true, false):
			(c as CollisionObject3D).collision_layer = 0
			(c as CollisionObject3D).collision_mask = 0


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
	var hud := _hud()
	if hud:
		hud.show_banner("FINE DELLA DEMO", fine_demo_testo, 9.0)

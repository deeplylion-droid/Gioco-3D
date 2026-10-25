class_name LeiOblo
extends Node3D
## Lei dietro un grosso oblò (gli oblò della risalita e della torre, 24 ottobre: "pose diverse di Jilly ogni volta"):
## calma, a fauce chiusa, con la sua luce rosa, l'occhio che segue il giocatore (la testa resta nella posa); poi si stacca e sparisce
## lenta nel buio dell'acqua (2,6 s, indietro e giù).
## Le pose sono quelle di tools/blender/medusa_inseguimento.py ("inseguimento/oblo_<posa>" in ciclo e
## "inseguimento/oblo_<posa>_stacca"):
## - "schiacciata": la faccia e i due palmi sul vetro, ti fissa;
## - "sbircia": sbircia dal bordo dell'oblò con mezzo viso e una mano sola (dalla sua sinistra: a destra per chi guarda
##   dal corridoio); "sbircia_altro" dall'altro bordo;
## - "capovolta": a testa in giù, l'occhio rovesciato contro il vetro, i capelli e i tentacoli verso l'alto;
## - "occhio" (l'oblò della torre): arriva dal buio in 3 s ("inseguimento/oblo_occhio_arriva", la luce si accende
##   piano) e appoggia al vetro l'occhio, la testa piegata indietro, i palmi sul vetro a 0,42 m dal centro (dietro il
##   muro se il vetro è piccolo); fatta per un vetro di 0,2-0,25 m di raggio, va bene anche per quello grande.
##
## Chi la comanda (ObloLei, la logica dell'oblò):
## - mostra(centro_vetro, normale, posa): la mette dietro il vetro (centro_vetro: il centro della faccia del vetro dalla
##   parte dell'acqua; normale: orizzontale, dal vetro verso il corridoio);
## - stacca(): si stacca e sparisce (alla fine il segnale sparita e lei è nascosta); chiamata di nuovo mentre si stacca
##   non fa niente;
## - via(): la nasconde subito;
## - aggiungi_forme(scatole): le forme della vasca per i tentacoli morbidi ([Transform3D, mezze misure] per scatola, come
##   MorbidezzaLei.aggiungi_scatola), anche subito dopo mostra(); restano per le volte dopo;
## - lato_sbircia (+1 / -1, prima di mostra): da che bordo sbircia;
## - get_eye_position(), get_eye_direction(): l'occhio, per chi controlla che segua il giocatore.
## Per la memoria lei (il modello, le ossa morbide, la luce) c'è solo da mostra() a quando sparisce: via() e la fine di
## stacca() la liberano, la prossima mostra() la ricrea.
## Il vetro deve avere un raggio di almeno OBLO_R (le mani stanno dentro questo cerchio); dietro, lo spazio d'acqua per
## posa è scritto in docs/report/lei_oblo/LEGGIMI.md.

## Si è staccata ed è sparita (lei è nascosta).
signal sparita

const ANIM := "inseguimento/"
## Il piano del vetro davanti all'origine e il centro del vetro sopra (medusa_inseguimento.py, OBLO, come lo schianto).
const OBLO := Vector2(0.95, 4.62)
## Il raggio del vetro per cui sono fatte le pose (medusa_inseguimento.py, OBLO_R).
const OBLO_R := 0.55
const POSE: Array[String] = ["schiacciata", "sbircia", "sbircia_altro", "capovolta", "occhio"]
const ROSA := Color(1.0, 0.35, 0.6)

## Da che bordo sbircia nella posa "sbircia": +1 a destra per chi guarda dal corridoio, -1 a sinistra (ObloLei).
var lato_sbircia := 1

var lei: MedusaAffacciata
var morbidezza: MorbidezzaLei
var posa := ""
var _ap: AnimationPlayer
var _luce: OmniLight3D
var _tw: Tween
var _staccando := false
var _forme: Array = []


func _crea() -> void:
	if lei:
		return
	lei = MedusaAffacciata.new()
	lei.name = "Lei"
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.bell_material = load("res://assets/models/medusa/medusa_campana.tres")
	lei.material_map = {
		"M_capelli": load("res://assets/models/medusa/medusa_capelli_bagnata.tres"),
		"M_ciocche": load("res://assets/models/medusa/medusa_ciocche_bagnata.tres"),
		"M_mani": load("res://assets/models/medusa/medusa_mani_bagnata.tres"),
		"M_occhio_bulbo": load("res://assets/models/medusa/medusa_occhio.tres"),
		"M_orbita": load("res://assets/models/medusa/medusa_orbita_bagnata.tres"),
		"M_pelle": load("res://assets/models/medusa/medusa_pelle_bagnata.tres"),
		"M_tentacoli": load("res://assets/models/medusa/medusa_tentacoli_bagnata.tres"),
	}
	lei.animazioni_inseguimento = true
	lei.animazione = StringName(ANIM + "oblo_" + (posa if posa != "" else "schiacciata"))
	lei.morbidezza = 1.0
	lei.gocce = false
	add_child(lei)
	_luce = OmniLight3D.new()
	_luce.light_color = ROSA
	_luce.light_energy = 4.0
	_luce.omni_range = 7.0
	_luce.light_volumetric_fog_energy = 2.0
	_luce.shadow_enabled = true
	_luce.position = Vector3(0, 2.6, 0.4)
	_luce.set_meta(&"risveglio_ignora", true)
	lei.add_child(_luce)
	if not Engine.has_meta(&"morbidezza_spenta"):
		morbidezza = MorbidezzaLei.su(lei)
	_ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer \
			if lei.get_model_instance() else null


## La mette dietro il vetro nella [param p] (una di POSE), calma, che ti guarda.
func mostra(centro_vetro: Vector3, normale: Vector3, p := "schiacciata") -> void:
	assert(p in POSE, "LeiOblo: posa sconosciuta " + p)
	if _tw:
		_tw.kill()
	_staccando = false
	if p == "sbircia" and lato_sbircia < 0:
		p = "sbircia_altro"
	posa = p
	var n := -normale        # verso l'acqua, verso di lei
	n.y = 0.0
	n = n.normalized() if n.length() > 1e-3 else Vector3.BACK
	global_position = centro_vetro + n * OBLO.x - Vector3.UP * OBLO.y
	# il modello guarda verso +Z: verso il vetro, cioè verso il corridoio
	global_basis = Basis.looking_at(-n, Vector3.UP, true)
	_crea()
	_luce.light_energy = 4.0
	lei.visible = true
	if morbidezza:
		# i tentacoli non passano il muro dell'oblò (una scatola dalla parte del corridoio) né la vasca
		morbidezza.togli_forme_mondo()
		morbidezza.aggiungi_scatola(Transform3D(Basis.looking_at(-n, Vector3.UP, true), centro_vetro - n * 0.2), Vector3(4.0, 6.0, 0.2))
		for f in _forme:
			morbidezza.aggiungi_scatola(f[0], f[1])
		morbidezza.azzera()
		morbidezza.accendi(true)
	# solo l'occhio segue il giocatore: la testa no (girando, il viso premuto contro il vetro ci entrerebbe, e nella posa
	# dell'occhio la testa piegata indietro si raddrizzerebbe)
	lei.segui_con_la_testa(0.0, 0.01)
	if p == "occhio":
		_anima("oblo_occhio_arriva", 0.0)
		_ap.queue(StringName(ANIM + "oblo_occhio"))
		_luce.light_energy = 0.0
		_tw = create_tween()
		_tw.tween_property(_luce, "light_energy", 4.0, _durata("oblo_occhio_arriva")).set_ease(Tween.EASE_OUT)
	else:
		_anima("oblo_" + p, 0.0)


## Si stacca dal vetro e sparisce lenta nel buio; poi il segnale sparita.
func stacca() -> void:
	if posa == "" or lei == null or not lei.visible or _staccando:
		return
	_staccando = true
	_anima("oblo_" + posa + "_stacca", 0.3)
	var d := _durata("oblo_" + posa + "_stacca")
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_luce, "light_energy", 0.0, d).set_ease(Tween.EASE_IN)
	_tw.tween_callback(func():
		via()
		sparita.emit())


## Vero mentre si stacca.
func in_stacca() -> bool:
	return _staccando


## Le forme della vasca per i tentacoli: [Transform3D, Vector3 mezze misure] per scatola.
func aggiungi_forme(scatole: Array) -> void:
	_forme.append_array(scatole)
	if morbidezza and lei and lei.visible:
		for f in scatole:
			morbidezza.aggiungi_scatola(f[0], f[1])


## Dove sta l'occhio e dove guarda (coordinate del mondo; ZERO se lei non c'è).
func get_eye_position() -> Vector3:
	return lei.get_eye_position() if lei else Vector3.ZERO


func get_eye_direction() -> Vector3:
	return lei.get_eye_direction() if lei else Vector3.ZERO


## La nasconde subito (e libera il modello).
func via() -> void:
	if _tw:
		_tw.kill()
	_staccando = false
	posa = ""
	if lei:
		lei.queue_free()
	lei = null
	morbidezza = null
	_luce = null
	_ap = null


func _anima(nome: String, sfuma: float) -> void:
	if _ap:
		_ap.play(StringName(ANIM + nome), sfuma)
		if sfuma <= 0.0:
			_ap.advance(0.0)        # la posa dal primo fotogramma (non quella di riposo)


func _durata(nome: String) -> float:
	var a := _ap.get_animation(StringName(ANIM + nome)) if _ap else null
	return a.length if a else 2.6

class_name LeiOblo
extends Node3D
## Lei dietro un grosso oblò (gli oblò della risalita e della torre, 24 ottobre: "pose diverse di Jilly ogni volta"):
## calma, a fauce chiusa, con la sua luce rosa, l'occhio e la testa che seguono il giocatore; poi si stacca e sparisce
## lenta nel buio dell'acqua (2,6 s, indietro e giù).
## Le pose sono quelle di tools/blender/medusa_inseguimento.py ("inseguimento/oblo_<posa>" in ciclo e
## "inseguimento/oblo_<posa>_stacca"):
## - "schiacciata": la faccia e i due palmi sul vetro, ti fissa;
## - "sbircia": sbircia dal bordo dell'oblò con mezzo viso e una mano sola (dalla sua sinistra: a destra per chi guarda
##   dal corridoio); "sbircia_altro" dall'altro bordo;
## - "capovolta": a testa in giù, l'occhio rovesciato contro il vetro, i capelli e i tentacoli verso l'alto.
##
## Chi la comanda (la logica dell'oblò):
## - mostra(centro_vetro, normale, posa): la mette dietro il vetro (centro_vetro: il centro della faccia del vetro dalla
##   parte dell'acqua; normale: dal vetro verso l'acqua, cioè verso di lei);
## - stacca(): si stacca e sparisce (alla fine il segnale sparita e lei è nascosta);
## - via(): la nasconde subito.
## Il vetro deve avere un raggio di almeno OBLO_R (0,55 m: le mani stanno dentro questo cerchio). Dietro ci vuole acqua
## o buio per almeno 2,5 m di profondità e 5 m sotto il centro del vetro (lei è alta 5,3 m e nel distacco scende);
## sopra, per la "capovolta", 5,5 m.

## Si è staccata ed è sparita (lei è nascosta).
signal sparita

const ANIM := "inseguimento/"
## Il piano del vetro davanti all'origine e il centro del vetro sopra (medusa_inseguimento.py, OBLO, come lo schianto).
const OBLO := Vector2(0.95, 4.62)
## Il raggio del vetro per cui sono fatte le pose (medusa_inseguimento.py, OBLO_R).
const OBLO_R := 0.55
const POSE: Array[String] = ["schiacciata", "sbircia", "sbircia_altro", "capovolta"]
const ROSA := Color(1.0, 0.35, 0.6)

var lei: MedusaAffacciata
var morbidezza: MorbidezzaLei
var posa := ""
var _ap: AnimationPlayer
var _luce: OmniLight3D
var _tw: Tween


func _ready() -> void:
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
	lei.animazione = StringName(ANIM + "oblo_schiacciata")
	lei.morbidezza = 1.0
	lei.visible = false
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
	posa = p
	var n := normale
	n.y = 0.0
	n = n.normalized() if n.length() > 1e-3 else Vector3.BACK
	global_position = centro_vetro + n * OBLO.x - Vector3.UP * OBLO.y
	# il modello guarda verso +Z: verso il vetro, cioè contro la normale
	global_basis = Basis.looking_at(-n, Vector3.UP, true)
	if _tw:
		_tw.kill()
	_luce.light_energy = 4.0
	lei.visible = true
	if morbidezza:
		# i tentacoli non passano il muro dell'oblò: una scatola sottile dalla parte del corridoio
		morbidezza.togli_forme_mondo()
		morbidezza.aggiungi_scatola(Transform3D(Basis.looking_at(-n, Vector3.UP, true), centro_vetro - n * 0.2), Vector3(4.0, 6.0, 0.2))
		morbidezza.azzera()
		morbidezza.accendi(true)
	lei.segui_con_la_testa(1.0, 0.6)
	_anima("oblo_" + p, 0.0)


## Si stacca dal vetro e sparisce lenta nel buio; poi il segnale sparita.
func stacca() -> void:
	if posa == "" or not lei.visible:
		return
	lei.segui_con_la_testa(0.0, 0.8)
	_anima("oblo_" + posa + "_stacca", 0.3)
	var d := _durata("oblo_" + posa + "_stacca")
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_luce, "light_energy", 0.0, d).set_ease(Tween.EASE_IN)
	_tw.tween_callback(func():
		via()
		sparita.emit())


## La nasconde subito.
func via() -> void:
	if _tw:
		_tw.kill()
	lei.visible = false
	posa = ""
	if morbidezza:
		morbidezza.azzera()


func _anima(nome: String, sfuma: float) -> void:
	if _ap:
		_ap.play(StringName(ANIM + nome), sfuma)


func _durata(nome: String) -> float:
	var a := _ap.get_animation(StringName(ANIM + nome)) if _ap else null
	return a.length if a else 2.6

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
## - prepara(centro_vetro, normale, posa): la crea prima, nascosta e ferma (il modello, le ossa morbide, la luce), così
##   mostra() non istanzia niente; con [member tieni] vero via() e la fine di stacca() la nascondono e la fermano
##   (riponi) invece di liberarla, e la prossima mostra() la riusa (gli oblò: niente blocchi quando compare).
## Il modello e i materiali sono preload: si caricano con lo script (nel thread che carica la sala o la torre), mai al
## momento di comparire. Senza prepara(), mostra() la crea al momento (com'era prima) e via() la libera.
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

## Il modello e i materiali di lei (preload: si caricano col thread della zona, non al momento di comparire).
const MODELLO := preload("res://assets/models/medusa/medusa.glb")
const CAMPANA := preload("res://assets/models/medusa/medusa_campana.tres")
## (le animazioni dell'inseguimento, 6,5 MB: MedusaAffacciata le carica con load(), che così le trova già in memoria;
## caricate lì, al momento, costavano 300 ms in un fotogramma)
const ANIMAZIONI := preload("res://assets/models/medusa/medusa_inseguimento.res")
const MATERIALI := {
	"M_capelli": preload("res://assets/models/medusa/medusa_capelli_bagnata.tres"),
	"M_ciocche": preload("res://assets/models/medusa/medusa_ciocche_bagnata.tres"),
	"M_mani": preload("res://assets/models/medusa/medusa_mani_bagnata.tres"),
	"M_occhio_bulbo": preload("res://assets/models/medusa/medusa_occhio.tres"),
	"M_orbita": preload("res://assets/models/medusa/medusa_orbita_bagnata.tres"),
	"M_pelle": preload("res://assets/models/medusa/medusa_pelle_bagnata.tres"),
	"M_tentacoli": preload("res://assets/models/medusa/medusa_tentacoli_bagnata.tres"),
}
const PALPEBRE := preload("res://assets/models/medusa/medusa_palpebre_bagnata.tres")


## Tutti i materiali di lei negli oblò, per chi li compila prima (RiscaldamentoShader): quelli bagnati, la campana,
## la palpebra, quelli del modello (dal glb, senza istanziarlo) e la struttura interna abbassata (ObloLei,
## EMISSIONE_INTERNO). Lo scuro del distacco (ObloLei._scurisci) cambia solo dei valori su copie con gli stessi shader:
## niente varianti in più. Con [param crea] vero gli shader si creano subito (get_rid). Le pipeline dipendono anche dal
## formato dei vertici della mesh: per quelle vere si disegna lei (LeiOblo.new(), prepara(), mostra() in una vista).
static func materiali_campione(crea := false) -> Array[Material]:
	var out: Array[Material] = []
	for m in MATERIALI.values():
		out.append(m as Material)
	out.append(CAMPANA)
	out.append(PALPEBRE)
	var stato := MODELLO.get_state()
	for i in stato.get_node_count():
		for j in stato.get_node_property_count(i):
			var v = stato.get_node_property_value(i, j)
			if v is Mesh:
				for s in (v as Mesh).get_surface_count():
					var m := (v as Mesh).surface_get_material(s)
					if m and not m in out:
						out.append(m)
						if m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled \
								and (m as BaseMaterial3D).emission_energy_multiplier > ObloLei.EMISSIONE_INTERNO:
							var basso := m.duplicate() as BaseMaterial3D
							basso.emission_energy_multiplier = ObloLei.EMISSIONE_INTERNO
							out.append(basso)
	if crea:
		for m in out:
			m.get_rid()
	return out


## Vero: via() e la fine del distacco la nascondono e la fermano invece di liberarla (vedi [method prepara]).
var tieni := false
var lei: MedusaAffacciata
var morbidezza: MorbidezzaLei
var posa := ""
var _ap: AnimationPlayer
var _luce: OmniLight3D
var _tw: Tween
var _staccando := false
var _forme: Array = []


func _crea(con_morbidezza := true) -> void:
	if lei:
		return
	lei = MedusaAffacciata.new()
	lei.name = "Lei"
	lei.model = MODELLO
	lei.bell_material = CAMPANA
	lei.material_map = MATERIALI.duplicate()
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
	if con_morbidezza:
		prepara_morbidezza()
	_ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer \
			if lei.get_model_instance() else null


## La crea prima, nascosta e ferma, già al suo posto dietro il vetro (vedi [method mostra]): poi mostra() non istanzia
## niente. Mette anche [member tieni]. Con [param con_morbidezza] falso le ossa morbide si fanno dopo, in un altro
## fotogramma ([method prepara_morbidezza]: costano da sole qualche decina di ms).
func prepara(centro_vetro: Vector3, normale: Vector3, p := "schiacciata", con_morbidezza := true) -> void:
	tieni = true
	_metti(centro_vetro, normale, p)
	_crea(con_morbidezza)
	riponi()


## Le ossa morbide di lei (MorbidezzaLei), se non ci sono ancora.
func prepara_morbidezza() -> void:
	if lei and morbidezza == null and not Engine.has_meta(&"morbidezza_spenta"):
		morbidezza = MorbidezzaLei.su(lei)
		if morbidezza and not lei.visible:
			morbidezza.azzera()


## Nasconde e ferma lei senza liberarla (la prossima mostra() la riusa).
func riponi() -> void:
	if _tw:
		_tw.kill()
	_staccando = false
	if lei:
		lei.visible = false
		lei.process_mode = Node.PROCESS_MODE_DISABLED
		if morbidezza:
			morbidezza.azzera()


func _metti(centro_vetro: Vector3, normale: Vector3, p: String) -> String:
	if p == "sbircia" and lato_sbircia < 0:
		p = "sbircia_altro"
	posa = p
	var n := -normale        # verso l'acqua, verso di lei
	n.y = 0.0
	n = n.normalized() if n.length() > 1e-3 else Vector3.BACK
	global_position = centro_vetro + n * OBLO.x - Vector3.UP * OBLO.y
	# il modello guarda verso +Z: verso il vetro, cioè verso il corridoio
	global_basis = Basis.looking_at(-n, Vector3.UP, true)
	return p


## La mette dietro il vetro nella [param p] (una di POSE), calma, che ti guarda.
func mostra(centro_vetro: Vector3, normale: Vector3, p := "schiacciata") -> void:
	assert(p in POSE, "LeiOblo: posa sconosciuta " + p)
	if _tw:
		_tw.kill()
	_staccando = false
	p = _metti(centro_vetro, normale, p)
	var n := -normale
	n.y = 0.0
	n = n.normalized() if n.length() > 1e-3 else Vector3.BACK
	_crea()
	prepara_morbidezza()
	_luce.light_energy = 4.0
	lei.process_mode = Node.PROCESS_MODE_INHERIT
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


## La nasconde subito (e libera il modello; con [member tieni] la ripone soltanto).
func via() -> void:
	if tieni:
		riponi()
		return
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

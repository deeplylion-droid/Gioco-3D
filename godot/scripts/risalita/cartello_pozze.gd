class_name CartelloPozze
extends Node3D
## L'indizio della stanza delle pozze colorate (GDD, "La stanza delle pozze colorate", scelte dell'utente del 31 ottobre):
## il cartello di divieto d'accesso del parco con sopra i tre quadratini a pastello dei bambini, i colori da togliere
## (EnigmaPozze.GIUSTI; texture di assets_src/pozze_colorate/cartello.py). Lamiera smaltata a contatto col muro, all'altezza
## degli occhi, e sopra un faretto a soffitto con una lampadina bianca, stretto sul cartello.
## Dal 4 novembre (scelta B dell'utente, "spostiamolo più lontano, così è troppo facile") sta nel corridoio del personale
## prima dell'infermeria, lontano dalla sua porta (RisalitaGioco); prima era accanto alla porta nord dell'infermeria.
## I quadratini si devono leggere coi colori delle pozze (collaudo del 1 novembre): il faretto è bianco neutro, forte, a
## [member distanza_faretto] dal muro perché la luce arrivi di fronte e non di taglio; lo smalto è opaco, così non
## riflette quello che ha intorno. Misura: tests/collaudo/colori_cartello_pozze.gd.
## L'origine è il centro del cartello sulla faccia del muro: +Z esce dal muro verso chi guarda, +Y in alto.

## Lo strato del cartello (lastra e faccia): solo lui, così una luce colorata vicina può lasciarlo fuori
## ([method RisalitaGioco._lampada_rossa]): nel corridoio del personale la lampada rossa a 70 cm faceva il viola quasi rosa
## (tinta 319° invece di 257°, misura del 6 novembre) e il turchese verde. Le altre luci e le camere lo prendono.
const STRATO := 1 << 13
const MISURA := Vector2(0.34, 0.46)
const TEXTURE := "res://assets/pozze_colorate/cartello_divieto.png"
const SPESSORE := 0.008

## Quanto sta il soffitto sopra il centro del cartello (m).
@export var soffitto := 1.1
## A che distanza dal muro si avvita il faretto (m).
@export var distanza_faretto := 1.2
## La luce del faretto: forza e apertura del cono (gradi).
@export var energia := 5.0
@export var angolo := 15.0
## Il faretto fa ombra: la sua luce si ferma al muro del cartello e non accende quello che c'è dietro.
@export var ombra := false


func _ready() -> void:
	var lastra := MeshInstance3D.new()
	lastra.name = "CartelloPozze"
	var bm := BoxMesh.new()
	bm.size = Vector3(MISURA.x, MISURA.y, SPESSORE)
	lastra.mesh = bm
	var smalto := StandardMaterial3D.new()
	smalto.albedo_color = Color(0.62, 0.62, 0.6)
	smalto.metallic = 0.7
	smalto.roughness = 0.4
	lastra.material_override = smalto
	lastra.position = Vector3(0, 0, SPESSORE * 0.5)
	Strati.metti(lastra, STRATO)
	add_child(lastra)
	var faccia := MeshInstance3D.new()
	faccia.name = "CartelloPozzeFaccia"
	var q := QuadMesh.new()
	q.size = MISURA
	faccia.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEXTURE)
	m.roughness = 0.7
	faccia.material_override = m
	faccia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	faccia.position = Vector3(0, 0, SPESSORE + 0.0005)
	Strati.metti(faccia, STRATO)
	add_child(faccia)
	var f := FarettoSoffitto.monta(self, "FarettoCartelloPozze", Vector3(0, soffitto, distanza_faretto), Vector3(0, 0.02, 0),
			Vector3(0, soffitto, 0), Color(1.0, 1.0, 1.0), energia, angolo)
	(f.get_node(^"Luce") as SpotLight3D).shadow_enabled = ombra

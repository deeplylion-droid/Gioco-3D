class_name AtmosferaSqualo
extends Node3D
## La luce viola e la nebbia della scena dello squalo all'inizio (richiesta dell'utente del 24 ottobre sera, GDD
## "Luce viola e nebbia"): dalla porta tagliafuoco in fondo al corridoio, da dove arriva il boato di Jilly, entra una
## luce viola fortissima (il suo bagliore) che mette lo squalo in controluce: una sagoma scura col contorno, i denti e
## la bava che brillano ai bordi, ma non sparisce. Nel corridoio c'è una nebbia densa che il viola illumina (si vede il
## fascio). Quando la porta si chiude dietro di lui il viola si spegne di colpo; quando il giocatore riprende il
## controllo la nebbia si dirada in [member dirada] secondi, fino alla nebbia normale del gioco.
## Sta sotto RisveglioSqualo e ne legge lo stato (avviata, tempo, porta chiusa); la luce e la nebbia nascono subito
## (spente) col livello, così il loro shader e la loro pipeline sono pronti prima della scena (niente scatti).
## Le coordinate sono quelle degli interni (lo spazio del nodo della porta): il corridoio corre lungo x, la porta
## tagliafuoco ha il cardine a x 21,97 e dietro (x più grande) c'è la stanza da cui viene lei.

## Il colore del bagliore di Jilly nella sua versione viola (i fari viola della sua vasca, sala_pulita.gd).
@export var colore := Color(0.62, 0.36, 1.0)
## Il bagliore dalla porta: quanto è forte, fin dove arriva (si ferma prima del giocatore: l'inizio resta buio) e
## quanto illumina la nebbia (i raggi che entrano dalla porta).
@export var energia := 28.0
@export var portata := 8.5
@export var energia_nebbia := 4.0
## La controluce: un faro che sta dietro lo squalo (dalla parte della porta) e illumina solo lui (lo strato dello
## squalo): il bordo viola acceso, la faccia verso di te al buio. Non illumina la nebbia né le pareti.
@export var energia_bordo := 9.0
## Al richiamo di lei la luce cresce ancora un po' (il boato), poi torna.
@export var richiamo_in_piu := 0.35
## Quanto resta della luce della corsa (quella che illumina lo squalo di fronte) col viola acceso.
@export var luce_corsa := 0.15
## La nebbia densa del corridoio: densità e in quanti secondi si dirada quando torna il controllo.
@export var densita := 0.3
## La nebbia è più fitta in basso (cala con l'altezza) e sfuma verso i bordi del volume (verso il giocatore).
@export var cala_in_alto := 0.9
@export var sfuma := 0.7
@export var dirada := 4.0
## Il faro dietro la porta e la nebbia, nello spazio degli interni.
@export var faro := Vector3(25.2, 1.75, -1.3)
@export var mira := Vector3(16.0, 0.9, -1.3)
@export var nebbia_centro := Vector3(22.0, 1.5, -1.3)
@export var nebbia_misure := Vector3(12.0, 3.2, 3.0)

var luce: SpotLight3D
var bordo: SpotLight3D
var nebbia: FogVolume
var _mat: FogMaterial
var _r: RisveglioSqualo
var _acceso := false
var _luci_tolte: Array = []    # [luce, la sua cull_mask di prima]: le luci del corridoio che non toccano più lo squalo
var _sagoma_fatta := false
var _diradata := 0.0          # 0: densa; 1: sparita
var _dirada_t := -1.0
var _fermi := 0               # fotogrammi senza la scena (dopo FOTOGRAMMI_PRONTA il volume della nebbia si nasconde)

## Fotogrammi in cui il volume della nebbia si disegna a densità zero col livello (shader e pipeline pronti prima della
## scena); poi, finché la scena non c'è, e alla fine del diradamento, è nascosto: a densità zero costava lo stesso, per
## tutto il gioco (riscontro del coordinatore del 25 ottobre).
const FOTOGRAMMI_PRONTA := 10


func _ready() -> void:
	_r = get_parent() as RisveglioSqualo
	var spazio: Node3D = _r.porta.get_parent() as Node3D if _r and _r.porta else _r
	luce = SpotLight3D.new()
	luce.name = "LuceViola"
	luce.light_color = colore
	luce.light_energy = 0.0
	luce.spot_range = portata
	luce.spot_angle = 26.0
	luce.spot_angle_attenuation = 1.2
	luce.spot_attenuation = 1.6
	luce.shadow_enabled = true      # lo squalo fa ombra nei raggi della nebbia
	luce.shadow_blur = 1.5
	luce.light_volumetric_fog_energy = energia_nebbia
	luce.light_specular = 1.4
	# (niente luce indiretta: il viola non rimbalza sulle pareti fino alla faccia dello squalo)
	luce.light_indirect_energy = 0.0
	luce.light_bake_mode = Light3D.BAKE_DISABLED
	add_child(luce)
	bordo = SpotLight3D.new()
	bordo.name = "ControluceViola"
	bordo.light_color = colore
	bordo.light_energy = 0.0
	bordo.light_cull_mask = RisveglioSqualo.STRATO_SQUALO
	bordo.spot_range = 7.0
	bordo.spot_angle = 50.0
	bordo.spot_attenuation = 0.5
	bordo.shadow_enabled = false
	bordo.light_volumetric_fog_energy = 0.0
	bordo.light_indirect_energy = 0.0
	bordo.light_bake_mode = Light3D.BAKE_DISABLED
	bordo.light_specular = 2.0      # i bordi lucidi: denti, bava, pelle bagnata
	add_child(bordo)
	nebbia = FogVolume.new()
	nebbia.name = "NebbiaCorridoio"
	nebbia.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	nebbia.size = nebbia_misure
	_mat = FogMaterial.new()
	_mat.density = 0.0
	_mat.albedo = Color(0.78, 0.74, 0.86)
	_mat.edge_fade = sfuma
	_mat.height_falloff = cala_in_alto
	nebbia.material = _mat
	add_child(nebbia)
	if spazio:
		luce.global_position = spazio.to_global(faro)
		luce.look_at(spazio.to_global(mira), Vector3.UP)
		nebbia.global_transform = Transform3D(spazio.global_basis, spazio.to_global(nebbia_centro))
	# (accesi da subito ma a zero: shader e pipeline si fanno col livello, non alla prima scena)


func _process(delta: float) -> void:
	if _r == null:
		return
	var attivo: bool = _r.in_corso()
	if attivo or _acceso or _dirada_t >= 0.0:
		_fermi = 0
		nebbia.visible = true
	else:
		# senza la scena (finita, o mai partita: una ripartenza, una partenza F9) il volume non serve
		_fermi += 1
		if _fermi > FOTOGRAMMI_PRONTA and nebbia.visible:
			nebbia.visible = false
	if attivo and not _acceso and _dirada_t < 0.0:
		_acceso = true
		_diradata = 0.0
	if _acceso:
		var porta_chiusa := bool(_r.get(&"_porta_chiusa"))
		var t := float(_r.get(&"_t"))
		var rich: float = _r.tempi.get("richiamo", 5.4)
		# il boato: cresce in mezzo secondo e torna in uno e mezzo
		var boato := clampf((t - rich) / 0.5, 0.0, 1.0) * clampf(1.0 - (t - rich - 0.5) / 1.5, 0.0, 1.0)
		luce.light_energy = 0.0 if porta_chiusa else energia * (1.0 + richiamo_in_piu * boato)
		# la luce della corsa di mascotte (davanti a lui, solo sullo squalo) più bassa: col viola dietro resta una
		# sagoma, leggibile ma non illuminata di fronte (RisveglioSqualo la rifà a ogni fotogramma, prima di qui)
		_metti_bordo(porta_chiusa, boato)
		if not _sagoma_fatta and _r.squalo and is_instance_valid(_r.squalo):
			_sagoma()
		var lc := _r.get(&"_luce_corsa") as OmniLight3D
		if lc and is_instance_valid(lc) and not porta_chiusa:
			lc.light_energy *= luce_corsa
		_mat.density = densita
		if not attivo:
			# il giocatore ha ripreso il controllo: la luce è già spenta, la nebbia si dirada
			_acceso = false
			_dirada_t = 0.0
			luce.light_energy = 0.0
			bordo.light_energy = 0.0
			_rimetti_luci()
	elif _dirada_t >= 0.0:
		_dirada_t += delta
		_diradata = clampf(_dirada_t / dirada, 0.0, 1.0)
		# (prima piano, poi più svelta: la nebbia si apre davanti a te)
		_mat.density = densita * (1.0 - _diradata * _diradata * (3.0 - 2.0 * _diradata))
		if _diradata >= 1.0:
			_mat.density = 0.0
			_dirada_t = -1.0


## Quanto è diradata la nebbia (0 densa, 1 sparita); per i test.
func diradata() -> float:
	return _diradata


## La controluce dietro lo squalo: dalla parte della porta rispetto al giocatore, un po' in alto, puntata sulla sua
## schiena verso la camera; solo sullo squalo.
func _metti_bordo(porta_chiusa: bool, boato: float) -> void:
	var sq: Node3D = _r.squalo
	if porta_chiusa or sq == null or not is_instance_valid(sq) or not sq.visible or _r.get(&"_p") == null:
		bordo.light_energy = 0.0
		return
	var occhio: Vector3 = (_r.get(&"_p") as Player).camera.global_position
	var corpo: Vector3 = _r.call(&"_bone_mondo", "spina")
	var via := corpo - occhio
	via.y = 0.0
	via = via.normalized() if via.length() > 0.01 else Vector3.RIGHT
	var da := corpo + via * 2.2 + Vector3.UP * 1.1
	bordo.global_position = da
	if da.distance_to(occhio) > 0.1:
		bordo.look_at(occhio, Vector3.UP)
	bordo.light_energy = energia_bordo * (1.0 + richiamo_in_piu * boato)


## La sagoma: le luci del corridoio (le lampade rosse) non illuminano più lo squalo, che sta solo sul suo strato: lo
## toccano solo la controluce, il bagliore dalla porta e la luce della corsa (bassa). La faccia verso di te resta scura,
## col bordo acceso. Le luci tornano com'erano quando torna il controllo.
func _sagoma() -> void:
	_sagoma_fatta = true
	for vi in _r.squalo.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = RisveglioSqualo.STRATO_SQUALO
	var radice := get_tree().current_scene if get_tree().current_scene else _r.get_parent()
	for l in radice.find_children("*", "Light3D", true, false):
		var luce3 := l as Light3D
		if luce3 == luce or luce3 == bordo or luce3 == _r.get(&"_luce_corsa"):
			continue
		if luce3.light_cull_mask & RisveglioSqualo.STRATO_SQUALO:
			_luci_tolte.append([luce3, luce3.light_cull_mask])
			luce3.light_cull_mask &= ~RisveglioSqualo.STRATO_SQUALO


func _rimetti_luci() -> void:
	for e in _luci_tolte:
		if is_instance_valid(e[0]):
			(e[0] as Light3D).light_cull_mask = int(e[1])
	_luci_tolte.clear()
	_sagoma_fatta = false

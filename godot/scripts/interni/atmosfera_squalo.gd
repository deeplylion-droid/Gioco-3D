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
## Quanto è forte la luce viola (energia del faro) e quanto illumina la nebbia.
@export var energia := 28.0
@export var energia_nebbia := 6.0
## Al richiamo di lei la luce cresce ancora un po' (il boato), poi torna.
@export var richiamo_in_piu := 0.35
## La nebbia densa del corridoio: densità e in quanti secondi si dirada quando torna il controllo.
@export var densita := 0.32
@export var dirada := 4.0
## Il faro dietro la porta e la nebbia, nello spazio degli interni.
@export var faro := Vector3(25.2, 1.75, -1.3)
@export var mira := Vector3(16.0, 0.9, -1.3)
@export var nebbia_centro := Vector3(19.5, 1.5, -1.3)
@export var nebbia_misure := Vector3(14.0, 3.2, 3.0)

var luce: SpotLight3D
var nebbia: FogVolume
var _mat: FogMaterial
var _r: RisveglioSqualo
var _acceso := false
var _diradata := 0.0          # 0: densa; 1: sparita
var _dirada_t := -1.0


func _ready() -> void:
	_r = get_parent() as RisveglioSqualo
	var spazio: Node3D = _r.porta.get_parent() as Node3D if _r and _r.porta else _r
	luce = SpotLight3D.new()
	luce.name = "LuceViola"
	luce.light_color = colore
	luce.light_energy = 0.0
	luce.spot_range = 18.0
	luce.spot_angle = 38.0
	luce.spot_angle_attenuation = 0.8
	luce.spot_attenuation = 0.6
	luce.shadow_enabled = true      # lo squalo fa ombra verso di te: la sagoma
	luce.shadow_blur = 1.5
	luce.light_volumetric_fog_energy = energia_nebbia
	luce.light_specular = 1.4       # i bordi lucidi: denti, bava, pelle bagnata
	add_child(luce)
	nebbia = FogVolume.new()
	nebbia.name = "NebbiaCorridoio"
	nebbia.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	nebbia.size = nebbia_misure
	_mat = FogMaterial.new()
	_mat.density = 0.0
	_mat.albedo = Color(0.78, 0.74, 0.86)
	_mat.edge_fade = 0.35
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
		_mat.density = densita
		if not attivo:
			# il giocatore ha ripreso il controllo: la luce è già spenta, la nebbia si dirada
			_acceso = false
			_dirada_t = 0.0
			luce.light_energy = 0.0
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

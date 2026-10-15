extends Node
## Autoload "Audio": tutto il suono del gioco, che si collega da solo a quello che c'è.
##
## In project.godot basta una riga (dopo gli altri autoload):
##   Audio="*res://addons/audio/audio.gd"
##
## Cosa fa da solo:
##  - crea i bus Musica, Ambiente ed Effetti (più Mondo e Interfaccia, interni) con il
##    riverbero lungo della sala, il passa-basso per il sott'acqua e la pausa, il limitatore;
##  - carica e salva i volumi in user://settings.cfg, sezione [audio];
##  - suona i fondi (pioggia sulla cupola, vento, nave) e ogni tanto scricchiolii, gemiti
##    metallici, colpi lontani e la sirena d'allarme, intorno al giocatore;
##  - a ogni cambio di scena cerca i nodi che conosce e si collega ai loro segnali (o ne
##    legge lo stato): Tempesta, Neon, LuceEmergenza, Gocce, Torcia (addon grafica), effetto
##    sott'acqua e gocciolatoi (addon acqua), giocatore, zaino, pulsanti, turbine, porte,
##    portelli, ruota e secchio, vasche, Polaroid, statua della medusa, bambini, morte,
##    monitor a tubo e paratie della sala pompe;
##    le luci al neon e d'emergenza della sala (dal GLB) ronzano;
##  - aggiunge la scheda "Audio" al menu delle opzioni dell'addon grafica.
## API: suona(), suona_sigla(), musica_titolo(), ferma_musica(), imposta_volume(), volume().
## Vedi addons/audio/README.md.

signal volume_cambiato(chiave: String, valore: float)

const Catalogo := preload("res://addons/audio/catalogo.gd")

const BUS_MUSICA := &"Musica"
const BUS_AMBIENTE := &"Ambiente"
const BUS_EFFETTI := &"Effetti"
## Interno: Musica, Ambiente ed Effetti passano di qui (filtro sott'acqua e pausa).
const BUS_MONDO := &"Mondo"
## Interno: menu e Polaroid (niente riverbero né filtri); segue il volume degli Effetti.
const BUS_INTERFACCIA := &"Interfaccia"

const SEZIONE := "audio"
const PREDEFINITI := {"generale": 1.0, "musica": 0.8, "ambiente": 1.0, "effetti": 1.0}
const BUS_DEL_VOLUME := {"generale": &"Master", "musica": BUS_MUSICA, "ambiente": BUS_AMBIENTE,
	"effetti": BUS_EFFETTI}

## Taratura per cartella: [bus, volume dB, unit_size (0 = non posizionale), max_distance, variazione di tono (semitoni)].
const PER_CARTELLA := {
	"giocatore": [BUS_EFFETTI, 0.0, 0.0, 0.0, 0.5],
	"effetti": [BUS_EFFETTI, 0.0, 4.0, 45.0, 0.3],
	"ambiente": [BUS_AMBIENTE, 0.0, 10.0, 80.0, 0.6],
	"musica": [BUS_MUSICA, 0.0, 0.0, 0.0, 0.0],
	"interfaccia": [BUS_INTERFACCIA, 0.0, 0.0, 0.0, 0.3],
	"tecnici": [BUS_EFFETTI, 0.0, 6.0, 60.0, 0.2],
}
## Taratura dei singoli suoni (sovrascrive quella della cartella). Stessi campi.
const TARATURA := {
	&"passo_piastrelle": [BUS_EFFETTI, -2.0, 0.0, 0.0, 0.8],
	&"passo_bagnato": [BUS_EFFETTI, -2.0, 0.0, 0.0, 0.8],
	&"passo_acqua": [BUS_EFFETTI, -2.0, 0.0, 0.0, 0.8],
	&"passo_metallo": [BUS_EFFETTI, -3.0, 0.0, 0.0, 0.8],
	&"passo_scala": [BUS_EFFETTI, -4.0, 0.0, 0.0, 0.8],
	&"salto": [BUS_EFFETTI, -6.0, 0.0, 0.0, 0.8],
	&"zaino_sciabordio": [BUS_EFFETTI, -4.0, 0.0, 0.0, 0.8],
	&"tuono_vicino": [BUS_AMBIENTE, 0.0, 0.0, 0.0, 0.8],
	&"tuono_lontano": [BUS_AMBIENTE, -1.0, 0.0, 0.0, 0.8],
	&"sirena_lontana": [BUS_AMBIENTE, -7.0, 0.0, 0.0, 0.3],
	&"goccia_acqua": [BUS_EFFETTI, -6.0, 1.6, 26.0, 1.2],
	&"goccia_pavimento": [BUS_EFFETTI, -7.0, 1.6, 26.0, 1.2],
	&"nave_gemito": [BUS_AMBIENTE, -3.0, 14.0, 90.0, 0.8],
	&"nave_scricchiolio": [BUS_AMBIENTE, -5.0, 10.0, 80.0, 0.8],
	&"nave_tic": [BUS_AMBIENTE, -9.0, 8.0, 60.0, 1.0],
	&"nave_colpo_lontano": [BUS_AMBIENTE, -6.0, 14.0, 100.0, 0.6],
	&"neon_clic": [BUS_EFFETTI, -10.0, 1.2, 14.0, 1.0],
	&"neon_scintilla": [BUS_EFFETTI, -6.0, 2.0, 25.0, 0.8],
	&"faro_acceso": [BUS_EFFETTI, 0.0, 9.0, 70.0, 0.0],
	&"pulsante_premuto": [BUS_EFFETTI, -2.0, 4.0, 45.0, 0.2],
	&"pulsante_rilasciato": [BUS_EFFETTI, -6.0, 3.0, 30.0, 0.3],
	&"turbina_bloccata": [BUS_EFFETTI, -3.0, 4.0, 40.0, 0.8],
	&"gonfiabile_colpito": [BUS_EFFETTI, -4.0, 3.0, 35.0, 1.5],
	&"portello_apre": [BUS_EFFETTI, 0.0, 7.0, 70.0, 0.0],
	&"secchio_ribalta": [BUS_EFFETTI, 0.0, 9.0, 80.0, 0.0],
	&"secchio_ritorno": [BUS_EFFETTI, -3.0, 7.0, 60.0, 0.0],
	&"cancello_ruota": [BUS_EFFETTI, -2.0, 8.0, 70.0, 0.0],
	&"cancello_fine": [BUS_EFFETTI, 0.0, 8.0, 70.0, 0.2],
	&"quadro_scintille": [BUS_EFFETTI, 0.0, 7.0, 60.0, 0.3],
	&"vasca_svuotata": [BUS_EFFETTI, -2.0, 6.0, 50.0, 0.0],
	&"medusa_risveglio": [BUS_EFFETTI, 0.0, 10.0, 80.0, 0.0],
	&"tuffo": [BUS_EFFETTI, -3.0, 0.0, 0.0, 0.5],
	&"riemersione": [BUS_EFFETTI, -4.0, 0.0, 0.0, 0.5],
	&"polaroid_raccolta": [BUS_INTERFACCIA, -2.0, 0.0, 0.0, 0.0],
	&"polaroid_chiudi": [BUS_INTERFACCIA, -6.0, 0.0, 0.0, 0.5],
	&"stinger_bambini": [BUS_MUSICA, -2.0, 0.0, 0.0, 0.0],
	&"stinger_morte": [BUS_MUSICA, 0.0, 0.0, 0.0, 0.0],
	# ambienti tecnici (tappe 5-6)
	&"pompa_avvio": [BUS_EFFETTI, 0.0, 6.0, 60.0, 0.3],
	&"corrente_salta": [BUS_EFFETTI, 0.0, 0.0, 0.0, 0.0],
	# lontani: la distanza è già nel suono (riverbero, passa-basso); qui solo la direzione
	&"plastica_piega_lontano": [BUS_EFFETTI, 0.0, 40.0, 220.0, 0.0],
	&"tonfo_acqua_lontano": [BUS_EFFETTI, 0.0, 40.0, 220.0, 0.0],
	&"maniglione_bloccato": [BUS_EFFETTI, 0.0, 3.0, 35.0, 0.6],
	&"porta_ponte_apre": [BUS_EFFETTI, 0.0, 5.0, 50.0, 0.0],
}
## Loop sulle sorgenti: [volume dB, unit_size, max_distance].
const LOOP_3D := {
	&"neon_ronzio_loop": [-5.0, 0.9, 8.0],
	&"emergenza_ronzio_loop": [-6.0, 0.7, 7.0],
	&"emergenza_rotante_loop": [-8.0, 1.2, 12.0],
	&"faro_ronzio_loop": [-10.0, 1.5, 14.0],
	&"turbina_loop": [-2.0, 4.0, 40.0],
	&"porta_motore_loop": [-3.0, 4.0, 40.0],
	&"saracinesca_loop": [-3.0, 4.0, 45.0],
	&"ruota_pale_loop": [-3.0, 5.0, 50.0],
	&"scarico_loop": [-3.0, 4.0, 40.0],
	&"riempie_loop": [-4.0, 3.0, 35.0],
	&"scivolo_loop": [-4.0, 3.0, 40.0],
	&"medusa_presenza_loop": [-2.0, 1.4, 8.0],
	&"zaino_impatto_loop": [-2.0, 2.5, 30.0],
	&"zaino_impatto_acqua_loop": [-2.0, 2.5, 30.0],
	&"pompe_ruggito_loop": [0.0, 6.0, 60.0],
	&"paratia_scende_loop": [0.0, 12.0, 80.0],
	&"crt_neve_loop": [0.0, 2.0, 16.0],
}
## Volume (dB) dei fondi.
const FONDI := {
	&"pioggia_cupola_loop": 0.0,
	&"vento_loop": -2.0,
	&"nave_loop": 0.0,
	&"sottacqua_loop": 0.0,
}

## Il pavimento "generico" della sala è bagnato (passi con lo splat): se vero vale sempre;
## altrimenti solo se nella scena c'è un WetSurfaceConverter (addon acqua).
var pavimento_bagnato := false
## Clic su pulsanti, cursori e scelte dei menu.
var suoni_interfaccia := true
## Aggiunge la scheda "Audio" al menu delle opzioni dell'addon grafica.
var inietta_nel_menu := true
## Scricchiolii, gemiti, colpi lontani e sirena casuali.
var eventi_casuali := true
## Se falso i volumi non vengono scritti su disco (test automatici).
var salva_su_disco := true
var percorso_impostazioni := "user://settings.cfg"

## Volumi 0..1: generale, musica, ambiente, effetti.
var volumi := {}
## Nodi collegati per tipo (per i test e per capire cosa ha trovato).
var collegati := {}
## Quante volte è partito ogni suono.
var conteggio := {}
var ultimo_suono := &""
var sott_acqua := false

var _stream_cache := {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _fondi := {}                 # nome -> AudioLoop (non posizionale, continua anche in pausa)
var _da_esaminare: Array[Node] = []
var _attivi: Array = []          # oggetti con aggiorna(audio, delta) -> bool
var _scena: Node = null
var _tempo_scena := 0.0
var _tempesta: Node = null
var _giocatore: Node3D = null
var _morte := false
var _bagnato_scena := false
var _sigla: AudioStreamPlayer3D
var _musica: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _limite_tempo := {}          # chiave -> tempo dell'ultimo suono (per non ripeterli troppo)
var _orologio := 0.0
var _prossimo_evento := {}
var _salvataggio_pendente := -1.0
var _lpf: AudioEffectLowPassFilter
var _lpf_attuale := 20000.0
var _offset := {BUS_AMBIENTE: 0.0, BUS_EFFETTI: 0.0, BUS_MUSICA: 0.0}
var _ui_cursore_t := 0.0
var _neon_vicini: SorgentiVicine
var _emergenza_vicine: SorgentiVicine
var _loop: Array[AudioLoop] = []     # tutti i loop creati (per ferma_tutto)
var _ultimo_ascoltatore := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_args().has("--script"):
		salva_su_disco = false
	volumi = PREDEFINITI.duplicate()
	_crea_bus()
	carica_impostazioni()
	_crea_pool()
	_crea_fondi()
	_neon_vicini = SorgentiVicine.new(self, &"neon_ronzio_loop", 4)
	_emergenza_vicine = SorgentiVicine.new(self, &"emergenza_ronzio_loop", 3)
	_attivi.append(_neon_vicini)
	_attivi.append(_emergenza_vicine)
	get_tree().node_added.connect(_su_nodo_aggiunto)
	_collega_autoload.call_deferred()
	_esamina_albero.call_deferred(get_tree().root)


# =============================================================================================
# API
# =============================================================================================

## Suona un suono del catalogo. [param dove]: Vector3 (posizione nel mondo), Node3D (lo segue)
## o null (non posizionale). Restituisce il player usato, o null.
func suona(nome: StringName, dove: Variant = null, volume_db := 0.0, tono := 1.0) -> Node:
	var stream := stream_di(nome)
	if stream == null:
		return null
	var t := taratura(nome)
	var var_tono: float = t[4]
	var p_tono := tono * pow(2.0, randf_range(-var_tono, var_tono) / 12.0) if var_tono > 0.0 else tono
	var player: Node
	var in_3d: bool = float(t[2]) > 0.0 and dove != null
	if in_3d:
		var p3 := _prendi_3d()
		p3.unit_size = t[2]
		p3.max_distance = t[3]
		if dove is Node3D:
			p3.global_position = (dove as Node3D).global_position
			_attivi.append(Segui.new(p3, dove))
		else:
			p3.global_position = dove
		player = p3
	else:
		player = _prendi_2d(StringName(t[0]) == BUS_INTERFACCIA)
	player.stream = stream
	player.bus = t[0]
	player.volume_db = float(t[1]) + volume_db
	player.pitch_scale = clampf(p_tono, 0.05, 4.0)
	_avvia(player)
	conteggio[nome] = int(conteggio.get(nome, 0)) + 1
	ultimo_suono = nome
	return player


## Come suona(), ma non più di una volta ogni [param intervallo] secondi per la stessa chiave.
func suona_limitato(chiave: String, intervallo: float, nome: StringName, dove: Variant = null,
		volume_db := 0.0, tono := 1.0) -> Node:
	if _orologio - float(_limite_tempo.get(chiave, -1000.0)) < intervallo:
		return null
	_limite_tempo[chiave] = _orologio
	return suona(nome, dove, volume_db, tono)


## La sigla rovinata dall'altoparlante del piedistallo. Se [param statua] ha una pulsazione
## (MedusaStatue: _t e pulse_rate), la partenza aspetta il picco, così battiti e luce coincidono.
func suona_sigla(sorgente: Node3D, statua: Node = null) -> void:
	if sigla_in_corso() or sorgente == null:
		return
	var ritardo := 0.0
	if statua:
		var t = statua.get(&"_t")
		var rate = statua.get(&"pulse_rate")
		if (t is float) and (rate is float) and rate > 0.0:
			var fase := fposmod(float(t) * float(rate), 1.0)
			var al_picco := fposmod(0.25 - fase, 1.0) / float(rate)
			ritardo = fposmod(al_picco - Catalogo.SIGLA_ROVINATA_PRIMO_BATTITO, 1.0 / float(rate))
	if is_instance_valid(_sigla):
		_sigla.queue_free()
	_sigla = AudioStreamPlayer3D.new()
	_sigla.name = "Sigla"
	_sigla.stream = stream_di(&"sigla_rovinata")
	_sigla.bus = BUS_MUSICA
	_sigla.unit_size = 12.0
	_sigla.max_distance = 90.0
	_sigla.attenuation_filter_cutoff_hz = 9000.0
	_sigla.attenuation_filter_db = -12.0
	sorgente.add_child(_sigla)
	conteggio[&"sigla_rovinata"] = int(conteggio.get(&"sigla_rovinata", 0)) + 1
	ultimo_suono = &"sigla_rovinata"
	if ritardo > 0.01:
		_sigla.set_meta(&"in_attesa", true)
		var p := _sigla
		get_tree().create_timer(ritardo, false).timeout.connect(func():
			if is_instance_valid(p):
				p.remove_meta(&"in_attesa")
				_avvia(p))
	else:
		_avvia(_sigla)


func sigla_in_corso() -> bool:
	return is_instance_valid(_sigla) and (_sigla.playing or _sigla.has_meta(&"in_attesa") or _finto(_sigla))


## Ferma tutti i suoni (pool, musica, sigla, stinger, fondi e loop sulle sorgenti).
func ferma_tutto() -> void:
	var tutti: Array[Node] = []
	tutti.append_array(_pool_3d)
	tutti.append_array(_pool_2d)
	tutti.append_array(_pool_ui)
	tutti.append_array([_musica, _sigla, _stinger])
	for p in tutti:
		if is_instance_valid(p):
			p.call(&"stop")
			p.remove_meta(&"finto_fino")
	if is_instance_valid(_musica):
		_musica.set_meta(&"ripeti", false)
	for l in _loop:
		if is_instance_valid(l):
			l.ferma()


## Fa partire un player. Senza un'uscita audio vera (driver Dummy) non lo avvia davvero:
## segna solo fino a quando "suonerebbe" (vedi AudioLoop.riproduzione_attiva()).
func _avvia(p: Node) -> void:
	if AudioLoop.riproduzione_attiva():
		p.play()
	else:
		var s: AudioStream = p.get(&"stream")
		p.set_meta(&"finto_fino", _orologio + (s.get_length() if s else 0.0))


func _finto(p: Node) -> bool:
	return p.has_meta(&"finto_fino") and _orologio < float(p.get_meta(&"finto_fino"))


## La sigla pulita per la schermata del titolo (non posizionale, bus Musica).
func musica_titolo(ripeti := true) -> void:
	_musica.stream = stream_di(&"sigla_pulita")
	_musica.set_meta(&"ripeti", ripeti)
	_musica.volume_db = 0.0
	_avvia(_musica)
	conteggio[&"sigla_pulita"] = int(conteggio.get(&"sigla_pulita", 0)) + 1


## Ferma la musica (titolo, sigla e stinger) con una dissolvenza.
func ferma_musica(dissolvenza := 1.0) -> void:
	for p in [_musica, _sigla, _stinger]:
		if is_instance_valid(p) and p.playing:
			var tw := create_tween()
			tw.tween_property(p, ^"volume_db", -60.0, maxf(dissolvenza, 0.01))
			tw.tween_callback(p.stop)
	if is_instance_valid(_musica):
		_musica.set_meta(&"ripeti", false)


## Un suono di prova per il cursore di un volume (suona anche a gioco in pausa).
func prova_volume(chiave: String) -> void:
	var nome: StringName = {"generale": &"pulsante_premuto", "effetti": &"pulsante_premuto",
		"ambiente": &"nave_tic", "musica": &"sigla_pulita"}.get(chiave, &"ui_clic")
	if nome == &"sigla_pulita":
		if _musica.playing:
			return
		_musica.stream = stream_di(nome)
		_musica.set_meta(&"ripeti", false)
		_musica.volume_db = 0.0
		_avvia(_musica)
		var tw := create_tween()
		tw.tween_interval(2.5)
		tw.tween_property(_musica, ^"volume_db", -50.0, 0.8)
		tw.tween_callback(_musica.stop)
		return
	var p := _prendi_2d(true)
	p.stream = stream_di(nome)
	p.bus = taratura(nome)[0]
	p.volume_db = float(taratura(nome)[1])
	p.pitch_scale = 1.0
	_avvia(p)


func volume(chiave: String) -> float:
	return float(volumi.get(chiave, PREDEFINITI.get(chiave, 1.0)))


## Cambia un volume (0..1: generale, musica, ambiente, effetti), lo applica e lo salva.
func imposta_volume(chiave: String, valore: float) -> void:
	if not PREDEFINITI.has(chiave):
		push_warning("Audio: volume sconosciuto \"%s\"" % chiave)
		return
	valore = clampf(valore, 0.0, 1.0)
	if is_equal_approx(volume(chiave), valore):
		return
	volumi[chiave] = valore
	_applica_volumi()
	volume_cambiato.emit(chiave, valore)
	_salvataggio_pendente = 0.6


func ripristina_volumi() -> void:
	for k in PREDEFINITI:
		volumi[k] = PREDEFINITI[k]
		volume_cambiato.emit(k, PREDEFINITI[k])
	_applica_volumi()
	_salvataggio_pendente = 0.3


func carica_impostazioni() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(percorso_impostazioni) == OK:
		for k in PREDEFINITI:
			var v: Variant = cfg.get_value(SEZIONE, k, PREDEFINITI[k])
			if v is float or v is int:
				volumi[k] = clampf(float(v), 0.0, 1.0)
	_applica_volumi()


func salva_impostazioni() -> void:
	_salvataggio_pendente = -1.0
	if not salva_su_disco:
		return
	var cfg := ConfigFile.new()
	cfg.load(percorso_impostazioni)  # tiene le altre sezioni (grafica...)
	for k in PREDEFINITI:
		cfg.set_value(SEZIONE, k, volume(k))
	cfg.save(percorso_impostazioni)


## Lo stream di un suono (con le varianti, se ce ne sono più di una). null se non esiste.
func stream_di(nome: StringName) -> AudioStream:
	if _stream_cache.has(nome):
		return _stream_cache[nome]
	var percorsi: Array = Catalogo.SUONI.get(nome, [])
	if percorsi.is_empty():
		push_warning("Audio: suono sconosciuto \"%s\"" % nome)
		_stream_cache[nome] = null
		return null
	var streams: Array[AudioStream] = []
	for p in percorsi:
		var s := load(p) as AudioStream
		if s:
			if String(nome).ends_with("_loop") and s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			streams.append(s)
	var risultato: AudioStream = null
	if streams.size() == 1:
		risultato = streams[0]
	elif streams.size() > 1:
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		r.random_pitch = 1.0
		r.random_volume_offset_db = 0.0
		for i in streams.size():
			r.add_stream(i, streams[i])
		risultato = r
	_stream_cache[nome] = risultato
	return risultato


## [bus, volume dB, unit_size, max_distance, variazione di tono] per un suono.
func taratura(nome: StringName) -> Array:
	if TARATURA.has(nome):
		return TARATURA[nome]
	var percorsi: Array = Catalogo.SUONI.get(nome, [])
	if not percorsi.is_empty():
		var cartella: String = String(percorsi[0]).get_base_dir().get_file()
		if PER_CARTELLA.has(cartella):
			return PER_CARTELLA[cartella]
	return [BUS_EFFETTI, 0.0, 0.0, 0.0, 0.0]


## Crea un loop 3D (figlio di [param su]) con la taratura di LOOP_3D.
func crea_loop(nome: StringName, su: Node, bus := BUS_EFFETTI) -> AudioLoop:
	var stream := stream_di(nome)
	if stream == null or su == null:
		return null
	var t: Array = LOOP_3D.get(nome, [0.0, 3.0, 30.0])
	var l := AudioLoop.new()
	l.prepara(stream, bus, true, t[1], t[2])
	l.volume_db_base = t[0]
	su.add_child(l)
	_tieni(l)
	return l


## Crea un loop non posizionale (suoni del giocatore), figlio di [param su].
func crea_loop_2d(nome: StringName, su: Node, volume_db := 0.0, bus := BUS_EFFETTI) -> AudioLoop:
	var stream := stream_di(nome)
	if stream == null or su == null:
		return null
	var l := AudioLoop.new()
	l.prepara(stream, bus, false)
	l.volume_db_base = volume_db
	su.add_child(l)
	_tieni(l)
	return l


func _tieni(l: AudioLoop) -> void:
	var i := 0
	while i < _loop.size():
		if is_instance_valid(_loop[i]):
			i += 1
		else:
			_loop.remove_at(i)
	_loop.append(l)


func ascoltatore() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.is_inside_tree():
		_ultimo_ascoltatore = cam.global_position
	elif is_instance_valid(_giocatore) and _giocatore.is_inside_tree():
		_ultimo_ascoltatore = _giocatore.global_position
	return _ultimo_ascoltatore


func registra(tipo: String) -> void:
	collegati[tipo] = int(collegati.get(tipo, 0)) + 1


# =============================================================================================
# Bus, pool, fondi
# =============================================================================================

func _crea_bus() -> void:
	_assicura_bus(BUS_MONDO, &"Master")
	_assicura_bus(BUS_MUSICA, BUS_MONDO)
	_assicura_bus(BUS_AMBIENTE, BUS_MONDO)
	_assicura_bus(BUS_EFFETTI, BUS_MONDO)
	_assicura_bus(BUS_INTERFACCIA, &"Master")
	# riverbero della sala piastrellata (lungo) sugli effetti
	var ie := AudioServer.get_bus_index(BUS_EFFETTI)
	if _effetto(ie, "AudioEffectReverb") == null:
		var r := AudioEffectReverb.new()
		r.room_size = 0.86
		r.damping = 0.35
		r.spread = 0.85
		r.hipass = 0.12
		r.dry = 1.0
		r.wet = 0.26
		r.predelay_msec = 45.0
		r.predelay_feedback = 0.3
		AudioServer.add_bus_effect(ie, r)
	# passa-basso per sott'acqua e pausa
	var im := AudioServer.get_bus_index(BUS_MONDO)
	_lpf = _effetto(im, "AudioEffectLowPassFilter") as AudioEffectLowPassFilter
	if _lpf == null:
		_lpf = AudioEffectLowPassFilter.new()
		_lpf.cutoff_hz = 20000.0
		_lpf.resonance = 0.5
		AudioServer.add_bus_effect(im, _lpf)
	AudioServer.set_bus_effect_enabled(im, _indice_effetto(im, _lpf), false)
	# limitatore sul generale: tanti suoni insieme non saturano
	if _effetto(0, "AudioEffectHardLimiter") == null and ClassDB.class_exists(&"AudioEffectHardLimiter"):
		var l: AudioEffect = ClassDB.instantiate(&"AudioEffectHardLimiter")
		l.set(&"ceiling_db", -0.5)
		AudioServer.add_bus_effect(0, l)


func _assicura_bus(nome: StringName, manda_a: StringName) -> void:
	var i := AudioServer.get_bus_index(nome)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nome)
		AudioServer.set_bus_send(i, manda_a)


func _effetto(bus: int, classe: String) -> AudioEffect:
	for k in AudioServer.get_bus_effect_count(bus):
		var e := AudioServer.get_bus_effect(bus, k)
		if e and e.is_class(classe):
			return e
	return null


func _indice_effetto(bus: int, e: AudioEffect) -> int:
	for k in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, k) == e:
			return k
	return -1


func _applica_volumi() -> void:
	for k in BUS_DEL_VOLUME:
		var i := AudioServer.get_bus_index(BUS_DEL_VOLUME[k])
		if i < 0:
			continue
		var v := volume(k)
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)) + float(_offset.get(BUS_DEL_VOLUME[k], 0.0)))
	var iu := AudioServer.get_bus_index(BUS_INTERFACCIA)
	if iu >= 0:
		AudioServer.set_bus_mute(iu, volume("effetti") <= 0.001)
		AudioServer.set_bus_volume_db(iu, linear_to_db(maxf(volume("effetti"), 0.001)))


func _crea_pool() -> void:
	for i in 28:
		var p := AudioStreamPlayer3D.new()
		p.name = "Pool3D_%d" % i
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		p.max_db = 0.0
		p.attenuation_filter_cutoff_hz = 6000.0
		p.attenuation_filter_db = -20.0
		add_child(p)
		_pool_3d.append(p)
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.name = "Pool2D_%d" % i
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_pool_2d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.name = "PoolUI_%d" % i
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool_ui.append(p)
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.bus = BUS_MUSICA
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	_musica.finished.connect(func():
		if _musica.get_meta(&"ripeti", false):
			_musica.play())
	add_child(_musica)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "Stinger"
	_stinger.bus = BUS_MUSICA
	_stinger.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_stinger)


func _prendi_3d() -> AudioStreamPlayer3D:
	var migliore: AudioStreamPlayer3D = null
	var piu_vecchio := INF
	for p in _pool_3d:
		if not p.playing and not p.has_meta(&"segue"):
			p.set_meta(&"partito", _orologio)
			return p
		var t: float = p.get_meta(&"partito", 0.0)
		if t < piu_vecchio:
			piu_vecchio = t
			migliore = p
	migliore.stop()
	migliore.remove_meta(&"segue")
	migliore.set_meta(&"partito", _orologio)
	return migliore


func _prendi_2d(ui: bool) -> AudioStreamPlayer:
	var pool := _pool_ui if ui else _pool_2d
	var migliore: AudioStreamPlayer = null
	var piu_vecchio := INF
	for p in pool:
		if not p.playing:
			p.set_meta(&"partito", _orologio)
			return p
		var t: float = p.get_meta(&"partito", 0.0)
		if t < piu_vecchio:
			piu_vecchio = t
			migliore = p
	migliore.stop()
	migliore.set_meta(&"partito", _orologio)
	return migliore


func _crea_fondi() -> void:
	for nome in FONDI:
		var s := stream_di(nome)
		if s == null:
			continue
		var l := AudioLoop.new()
		l.prepara(s, BUS_AMBIENTE, false)
		l.name = "Fondo_" + String(nome)
		l.volume_db_base = FONDI[nome]
		l.rapidita_volume = 0.6
		add_child(l)
		_fondi[nome] = l
		_tieni(l)


# =============================================================================================
# Ciclo
# =============================================================================================

func _process(delta: float) -> void:
	_orologio += delta
	_tempo_scena += delta
	var scena := get_tree().current_scene
	if scena != _scena:
		_scena = scena
		_su_scena_cambiata()
	if not _da_esaminare.is_empty():
		var lista := _da_esaminare
		_da_esaminare = []
		for n in lista:
			if is_instance_valid(n) and n.is_inside_tree():
				_esamina(n)
	var i := 0
	while i < _attivi.size():
		var a = _attivi[i]
		if a.aggiorna(self, delta):
			i += 1
		else:
			_attivi.remove_at(i)
	_aggiorna_fondi()
	_aggiorna_bus(delta)
	_aggiorna_eventi(delta)
	_ui_cursore_t = maxf(0.0, _ui_cursore_t - delta)
	if _salvataggio_pendente > 0.0:
		_salvataggio_pendente -= delta
		if _salvataggio_pendente <= 0.0:
			salva_impostazioni()


func _su_scena_cambiata() -> void:
	_tempo_scena = 0.0
	_tempesta = null
	_bagnato_scena = false
	_prossimo_evento = {
		"gemito": randf_range(12.0, 25.0), "scricchiolio": randf_range(6.0, 14.0),
		"tic": randf_range(9.0, 20.0), "colpo": randf_range(40.0, 80.0),
		"sirena": randf_range(70.0, 120.0)}
	if is_instance_valid(_sigla) and not _sigla.is_inside_tree():
		_sigla = null


func _aggiorna_fondi() -> void:
	var c_e_giocatore := is_instance_valid(_giocatore) and _giocatore.is_inside_tree()
	var tempesta := is_instance_valid(_tempesta) and _tempesta.is_inside_tree()
	var v := {&"pioggia_cupola_loop": 0.0, &"vento_loop": 0.0, &"nave_loop": 0.0, &"sottacqua_loop": 0.0}
	if c_e_giocatore:
		v[&"nave_loop"] = 1.0
		v[&"pioggia_cupola_loop"] = 1.0 if tempesta else 0.22
		v[&"vento_loop"] = 1.0 if tempesta else 0.3
	if sott_acqua:
		v[&"sottacqua_loop"] = 1.0
		v[&"pioggia_cupola_loop"] *= 0.4
		v[&"vento_loop"] *= 0.3
	for k in v:
		if _fondi.has(k):
			(_fondi[k] as AudioLoop).volume = v[k]


func _aggiorna_bus(delta: float) -> void:
	var pausa := get_tree().paused
	var taglio := 20000.0
	var amb := 0.0
	var eff := 0.0
	if sott_acqua:
		taglio = 600.0
		amb -= 3.0
	if pausa:
		taglio = minf(taglio, 900.0)
		amb -= 5.0
	if _morte:
		amb -= 12.0
		eff -= 14.0
	var k := 1.0 - exp(-4.0 * delta)
	_lpf_attuale = exp(lerpf(log(_lpf_attuale), log(taglio), 1.0 - exp(-(10.0 if pausa else 5.0) * delta)))
	var im := AudioServer.get_bus_index(BUS_MONDO)
	if _lpf and im >= 0:
		_lpf.cutoff_hz = _lpf_attuale
		AudioServer.set_bus_effect_enabled(im, _indice_effetto(im, _lpf), _lpf_attuale < 19000.0)
	var cambiato := false
	for bus in [[BUS_AMBIENTE, amb], [BUS_EFFETTI, eff]]:
		var vecchio: float = _offset[bus[0]]
		var nuovo := lerpf(vecchio, bus[1], k)
		if absf(nuovo - vecchio) > 0.01:
			_offset[bus[0]] = nuovo
			cambiato = true
	if cambiato:
		_applica_volumi()


func _aggiorna_eventi(delta: float) -> void:
	if not eventi_casuali or _morte or not is_instance_valid(_giocatore) or get_tree().paused:
		return
	for chiave in _prossimo_evento.keys():
		_prossimo_evento[chiave] -= delta
		if _prossimo_evento[chiave] > 0.0:
			continue
		var centro := ascoltatore()
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		match chiave:
			"gemito":
				suona(&"nave_gemito", centro + dir * randf_range(12.0, 22.0) + Vector3.UP * randf_range(2.0, 9.0))
				_prossimo_evento[chiave] = randf_range(16.0, 34.0)
			"scricchiolio":
				suona(&"nave_scricchiolio", centro + dir * randf_range(8.0, 18.0) + Vector3.UP * randf_range(3.0, 10.0))
				_prossimo_evento[chiave] = randf_range(9.0, 22.0)
			"tic":
				suona(&"nave_tic", centro + dir * randf_range(6.0, 16.0) + Vector3.UP * randf_range(4.0, 11.0))
				_prossimo_evento[chiave] = randf_range(12.0, 30.0)
			"colpo":
				suona(&"nave_colpo_lontano", centro + dir * randf_range(25.0, 40.0) + Vector3.DOWN * 3.0)
				_prossimo_evento[chiave] = randf_range(55.0, 110.0)
			"sirena":
				suona(&"sirena_lontana")
				_prossimo_evento[chiave] = randf_range(110.0, 200.0)


# =============================================================================================
# Collegamenti con la scena
# =============================================================================================

func _su_nodo_aggiunto(n: Node) -> void:
	_da_esaminare.append(n)


func _esamina_albero(radice: Node) -> void:
	_esamina(radice)
	for c in radice.get_children():
		_esamina_albero(c)


func _collega_autoload() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs:
		if gs.has_signal(&"player_died") and not gs.is_connected(&"player_died", _su_morte):
			gs.connect(&"player_died", _su_morte)
		if gs.has_signal(&"player_respawned") and not gs.is_connected(&"player_respawned", _su_ripartenza):
			gs.connect(&"player_respawned", _su_ripartenza)
		registra("GameState")
	var g := get_node_or_null(^"/root/Game")
	if g and g.has_signal(&"paused_changed") and not g.is_connected(&"paused_changed", _su_pausa):
		g.connect(&"paused_changed", _su_pausa)
		registra("Game")


## Il nome della classe (class_name) del nodo o della prima classe base che lo ha.
static func classe_di(n: Node) -> String:
	var s: Script = n.get_script()
	while s:
		var g := String(s.get_global_name())
		if g != "":
			return g
		s = s.get_base_script()
	return ""


func _esamina(n: Node) -> void:
	if n == self or n.has_meta(&"_audio"):
		return
	var classe := classe_di(n)
	var fatto := true
	match classe:
		"Tempesta": _collega_tempesta(n)
		"Neon": _collega_neon(n)
		"LuceEmergenza": _collega_emergenza(n)
		"Gocce": _collega_gocce(n)
		"Torcia": _collega_torcia(n)
		"UnderwaterEffect": _collega_sottacqua(n)
		"WaterDripEmitter": _attivi.append(Gocciolatoio.new(self, n))
		"WaterInlet": _attivi.append(Bocchetta.new(self, n))
		"SlideWater": _attivi.append(Scivolo.new(self, n))
		"WetSurfaceConverter": _bagnato_scena = true
		"Player": _collega_giocatore(n)
		"WaterPack": _attivi.append(Zaino.new(self, n))
		"WaterButton": _collega_pulsante(n)
		"Turbine": _attivi.append(Turbina.new(self, n))
		"StuckInflatable": _collega_gonfiabile(n)
		"PoweredDoor": _attivi.append(Porta.new(self, n))
		"HingedHatch": _collega_portello(n)
		"BucketWheel": _attivi.append(Ruota.new(self, n))
		"WaterTank": _attivi.append(Vasca.new(self, n))
		"FlickerLight": _attivi.append(Lampada.new(self, n))
		"MedusaStatue", "MedusaAffacciata": _attivi.append(Statua.new(self, n))
		"KidSighting": _collega_bambini(n)
		"PackPickup": _collega_zaino_raccolto(n)
		"PolaroidPhoto", "Collectible": _collega_collezionabile(n)
		"DeathSequence": _collega_sequenza_morte(n)
		"MenuOpzioni": _inietta_menu(n)
		"MonitorCrt": _attivi.append(AudioMonitor.new(self, n))
		"Paratia": _attivi.append(AudioParatia.new(self, n))
		_:
			fatto = _esamina_senza_classe(n)
	if fatto:
		n.set_meta(&"_audio", true)
		if classe != "":
			registra(classe)


func _esamina_senza_classe(n: Node) -> bool:
	# la scena della sala: il pulsante della sigla e la statua
	if n == get_tree().current_scene and (&"jingle_button" in n):
		var b = n.get(&"jingle_button")
		if b is Node and (b as Node).has_signal(&"pressed"):
			var statua = n.get(&"statue")
			(b as Node).connect(&"pressed", func():
				if is_instance_valid(b):
					suona_sigla(b, statua if is_instance_valid(statua) else null))
			registra("sigla")
			return true
	# luci importate dal GLB della sala
	if n is SpotLight3D and String(n.name).begins_with("luce_neon"):
		_neon_vicini.aggiungi(n)
		registra("luci_neon")
		return true
	if n is OmniLight3D and String(n.name).begins_with("luce_emergenza"):
		_emergenza_vicine.aggiungi(n)
		registra("luci_emergenza")
		return true
	# il visore delle Polaroid (senza class_name)
	var s: Script = n.get_script()
	if s and s.resource_path.ends_with("photo_viewer.gd"):
		n.tree_exiting.connect(func(): suona(&"polaroid_chiudi"))
		registra("visore_polaroid")
		return true
	if suoni_interfaccia and n is Control:
		return _collega_controllo(n)
	return false


func _collega_controllo(n: Control) -> bool:
	if n is OptionButton:
		(n as OptionButton).item_selected.connect(func(_i): suona(&"ui_scatto"))
		(n as OptionButton).pressed.connect(func(): suona(&"ui_clic"))
		return true
	if n is BaseButton:
		var b := n as BaseButton
		if b.toggle_mode:
			b.toggled.connect(func(_v): suona(&"ui_scatto"))
		else:
			b.pressed.connect(func(): suona(&"ui_clic"))
		return true
	if n is Slider:
		(n as Slider).value_changed.connect(func(_v):
			if _ui_cursore_t <= 0.0 and (n as Slider).is_visible_in_tree():
				_ui_cursore_t = 0.05
				suona(&"ui_cursore"))
		return true
	return false


# --- addon grafica --------------------------------------------------------------------------

func _collega_tempesta(n: Node) -> void:
	_tempesta = n
	n.connect(&"tuono", func(intensita: float, distanza_km: float):
		var nome := &"tuono_vicino" if distanza_km < 1.3 else &"tuono_lontano"
		suona(nome, null, linear_to_db(clampf(intensita, 0.12, 1.4))))


func _collega_neon(n: Node) -> void:
	var l := crea_loop(&"neon_ronzio_loop", n)
	n.connect(&"acceso_cambiato", func(_acceso: bool):
		suona_limitato("neon%d" % n.get_instance_id(), 0.12, &"neon_clic", n.global_position))
	n.connect(&"scintilla", func(): suona(&"neon_scintilla", (n as Node3D).global_position))
	_attivi.append(Funzione.new(n, func(_d: float):
		if l:
			l.volume = clampf(float(n.get(&"livello")), 0.0, 1.0)))


func _collega_emergenza(n: Node) -> void:
	var ronzio := crea_loop(&"emergenza_ronzio_loop", n)
	var giro := crea_loop(&"emergenza_rotante_loop", n)
	var omni: OmniLight3D = null
	for c in n.get_children():
		if c is OmniLight3D:
			omni = c
	var energia := float(n.get(&"energia"))
	_attivi.append(Funzione.new(n, func(_d: float):
		var modo := int(n.get(&"modalita"))
		var acceso := modo != 3  # SPENTA
		var liv := 1.0
		if modo == 1 and omni and energia > 0.0:   # PULSANTE: segue la luce
			liv = clampf(omni.light_energy / energia, 0.0, 1.0)
		if ronzio:
			ronzio.volume = (0.35 + 0.65 * liv) if acceso else 0.0
		if giro:
			giro.volume = 1.0 if modo == 2 else 0.0))


func _collega_gocce(n: Node) -> void:
	n.connect(&"goccia_caduta", func(pos: Vector3): suona(_nome_goccia(pos), pos))


func _nome_goccia(pos: Vector3) -> StringName:
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm and wm.has_method(&"get_body_at"):
		var b = wm.call(&"get_body_at", pos, 0.05)
		if b and not b.call(&"is_empty") and float(b.get(&"level")) >= pos.y - 0.1:
			return &"goccia_acqua"
	if pavimento_bagnato or _bagnato_scena:
		return &"goccia_acqua" if randf() < 0.55 else &"goccia_pavimento"
	return &"goccia_pavimento"


func _collega_torcia(n: Node) -> void:
	n.connect(&"accesa_cambiata", func(accesa: bool): suona(&"torcia_accesa" if accesa else &"torcia_spenta"))


# --- addon acqua -----------------------------------------------------------------------------

func _collega_sottacqua(n: Node) -> void:
	n.connect(&"entered_water", func():
		sott_acqua = true
		suona(&"tuffo"))
	n.connect(&"exited_water", func():
		sott_acqua = false
		suona(&"riemersione"))
	_attivi.append(Funzione.new(n, func(_d: float):
		sott_acqua = bool(n.get(&"is_underwater"))))


# --- giocatore e meccanismi ----------------------------------------------------------------

func _collega_giocatore(n: Node) -> void:
	_giocatore = n as Node3D
	_morte = false
	n.connect(&"footstep", func(superficie: StringName, bagnato: bool, intensita: float):
		var v := clampf(0.35 + 0.5 * intensita, 0.3, 1.25)
		suona(_nome_passo(superficie, bagnato), null, linear_to_db(v)))
	n.connect(&"landed", func(superficie: StringName, bagnato: bool, velocita: float):
		var nome := String(_nome_passo(superficie, bagnato)).replace("passo_", "atterraggio_")
		if nome == "atterraggio_scala":
			nome = "atterraggio_metallo"
		suona(StringName(nome), null, linear_to_db(clampf(velocita / 8.0, 0.35, 1.2)))
		_sciabordio(clampf(velocita / 6.0, 0.3, 1.0)))
	n.connect(&"jumped", func():
		suona(&"salto")
		_sciabordio(0.5))


func _nome_passo(superficie: StringName, bagnato: bool) -> StringName:
	match superficie:
		&"acqua":
			return &"passo_acqua"
		&"scala":
			return &"passo_scala"
		&"metallo", &"lamiera", &"grata":
			return &"passo_metallo"
	if bagnato or pavimento_bagnato or _bagnato_scena:
		return &"passo_bagnato"
	return &"passo_piastrelle"


## Lo sciabordio dell'acqua nel serbatoio dello zaino (più forte se è mezzo pieno).
func _sciabordio(forza: float) -> void:
	if not is_instance_valid(_giocatore):
		return
	var pack = _giocatore.get(&"water_pack")
	if pack == null or not bool(pack.get(&"equipped")):
		return
	var cap := maxf(float(pack.get(&"tank_capacity")), 0.001)
	var pieno := float(pack.get(&"tank_amount")) / cap
	if pieno < 0.05:
		return
	var v := forza * (1.0 - absf(pieno - 0.5) * 0.8)
	suona_limitato("sciabordio", 0.35, &"zaino_sciabordio", null, linear_to_db(clampf(v, 0.05, 1.0)))


func _collega_pulsante(n: Node) -> void:
	n.connect(&"pressed", func(): suona(&"pulsante_premuto", (n as Node3D).global_position))
	n.connect(&"released", func(): suona(&"pulsante_rilasciato", (n as Node3D).global_position))


func _collega_gonfiabile(n: Node) -> void:
	n.connect(&"released", func(): suona(&"gonfiabile_libero", (n as Node3D).global_position))


func _collega_portello(n: Node) -> void:
	var bersaglio: Node3D = null
	var path = n.get(&"target_path")
	if path is NodePath and not (path as NodePath).is_empty():
		bersaglio = n.get_node_or_null(path) as Node3D
	n.connect(&"opened", func():
		var dove: Node3D = bersaglio if is_instance_valid(bersaglio) else n as Node3D
		suona(&"portello_apre", dove.global_position))


func _collega_bambini(n: Node) -> void:
	n.connect(&"seen", func(): suona(&"stinger_bambini"))


func _collega_zaino_raccolto(n: Node) -> void:
	n.connect(&"interacted", func(_by): suona(&"zaino_preso"))


func _collega_collezionabile(n: Node) -> void:
	n.connect(&"interacted", func(_by): suona(&"polaroid_raccolta"))


# --- morte, pausa, menu ----------------------------------------------------------------------

func _su_morte(_causa: StringName) -> void:
	_morte = true
	if is_instance_valid(_sigla) and _sigla.playing:
		var tw := create_tween()
		tw.tween_property(_sigla, ^"volume_db", -60.0, 0.8)
		tw.tween_callback(_sigla.stop)
	_stinger.stream = stream_di(&"stinger_morte")
	_stinger.volume_db = 0.0
	_avvia(_stinger)
	conteggio[&"stinger_morte"] = int(conteggio.get(&"stinger_morte", 0)) + 1
	ultimo_suono = &"stinger_morte"


func _su_ripartenza() -> void:
	_morte = false


func _collega_sequenza_morte(n: Node) -> void:
	n.connect(&"finished", func(saltata: bool):
		if saltata and _stinger.playing:
			var tw := create_tween()
			tw.tween_property(_stinger, ^"volume_db", -50.0, 0.35)
			tw.tween_callback(_stinger.stop))


func _su_pausa(in_pausa: bool) -> void:
	suona(&"ui_pausa" if in_pausa else &"ui_chiudi")


func _inietta_menu(menu: Node) -> void:
	if not inietta_nel_menu:
		return
	var tabs := menu.find_children("*", "TabContainer", true, false)
	if tabs.is_empty():
		return
	var tc := tabs[0] as TabContainer
	if tc.has_node(^"Audio"):
		return
	var sc := ScrollContainer.new()
	sc.name = "Audio"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p := PannelloAudio.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(p)
	tc.add_child(sc)
	registra("menu_audio")


# =============================================================================================
# Oggetti seguiti a ogni fotogramma (aggiorna() -> false quando non servono più)
# =============================================================================================

## Un suono del pool che segue un nodo che si muove.
class Segui:
	var p: AudioStreamPlayer3D
	var n: Node3D
	var gettone := 0.0

	func _init(player: AudioStreamPlayer3D, nodo: Node3D) -> void:
		p = player
		n = nodo
		gettone = p.get_meta(&"partito", 0.0)
		p.set_meta(&"segue", true)

	func aggiorna(_a, _d: float) -> bool:
		if float(p.get_meta(&"partito", -1.0)) != gettone:
			return false          # il player è stato riusato per un altro suono
		if not is_instance_valid(n) or not n.is_inside_tree() or not p.playing:
			p.remove_meta(&"segue")
			return false
		p.global_position = n.global_position
		return true


## Una funzione chiamata a ogni fotogramma finché il nodo esiste.
class Funzione:
	var n: Node
	var f: Callable

	func _init(nodo: Node, funzione: Callable) -> void:
		n = nodo
		f = funzione

	func aggiorna(_a, d: float) -> bool:
		if not is_instance_valid(n) or not n.is_inside_tree():
			return false
		f.call(d)
		return true


## Tante sorgenti uguali (le luci della sala): i loop vanno solo sulle K più vicine.
class SorgentiVicine:
	var audio
	var nome: StringName
	var sorgenti: Array[Node3D] = []
	var loop: Array[AudioLoop] = []
	var assegnate: Array = []
	var visibili := {}
	var massimi := {}      # energia massima vista per ogni luce (le pulsanti seguono la luce)
	var t := 0.0

	func _init(a, nome_loop: StringName, quante: int) -> void:
		audio = a
		nome = nome_loop
		var holder := Node3D.new()
		holder.name = "Vicine_" + String(nome_loop)
		holder.process_mode = Node.PROCESS_MODE_PAUSABLE
		a.add_child(holder)
		for i in quante:
			var l: AudioLoop = a.crea_loop(nome_loop, holder)
			if l:
				l.rapidita_volume = 30.0
				loop.append(l)
				assegnate.append(null)

	func aggiungi(n: Node3D) -> void:
		sorgenti.append(n)

	func aggiorna(a, delta: float) -> bool:
		var i := 0
		while i < sorgenti.size():
			if is_instance_valid(sorgenti[i]):
				i += 1
			else:
				sorgenti.remove_at(i)
		t -= delta
		var centro: Vector3 = a.ascoltatore()
		if t <= 0.0:
			t = 0.3
			var ordinate := sorgenti.filter(func(x: Node3D): return x.is_inside_tree())
			ordinate.sort_custom(func(x: Node3D, y: Node3D):
				return x.global_position.distance_squared_to(centro) < y.global_position.distance_squared_to(centro))
			for k in loop.size():
				var s: Node3D = ordinate[k] if k < ordinate.size() else null
				if s != assegnate[k]:
					assegnate[k] = s
					loop[k].salta(0.0)
					if s and loop[k].is_inside_tree():
						loop[k].global_position = s.global_position
		for k in loop.size():
			var s = assegnate[k]
			if not is_instance_valid(s) or not s.is_inside_tree():
				loop[k].volume = 0.0
				continue
			var energia: float = (s as Light3D).light_energy
			var acceso: bool = s.is_visible_in_tree() and energia > 0.01
			var id: int = s.get_instance_id()
			massimi[id] = maxf(float(massimi.get(id, 0.0)), energia)
			loop[k].volume = clampf(energia / maxf(massimi[id], 0.001), 0.3, 1.0) if acceso else 0.0
			# sfarfallio: un clic quando la luce vicina si accende o si spegne
			if visibili.has(id) and visibili[id] != acceso and s.global_position.distance_to(centro) < 9.0:
				if acceso and randf() < 0.12:
					a.suona_limitato("scintilla%d" % id, 1.5, &"neon_scintilla", s.global_position, -4.0)
				else:
					a.suona_limitato("sfarfallio%d" % id, 0.25, &"neon_clic", s.global_position, -4.0)
			visibili[id] = acceso
		return true


## Lo zaino-pompa: getto, aspirazione, ricarica, impatto del getto, serbatoio.
class Zaino:
	var audio
	var pack: Node
	var getto: AudioLoop
	var aspira: AudioLoop
	var ricarica: AudioLoop
	var impatto: AudioLoop
	var impatto_acqua: AudioLoop
	var ultimo_serbatoio := -1.0
	var ricarica_t := 0.0
	var inizio_aspira := 0.0

	func _init(a, n: Node) -> void:
		audio = a
		pack = n
		getto = a.crea_loop_2d(&"zaino_getto_loop", n, 0.0)
		aspira = a.crea_loop_2d(&"zaino_aspira_loop", n, -1.0)
		ricarica = a.crea_loop_2d(&"zaino_ricarica_loop", n, -4.0)
		var holder := Node3D.new()
		holder.name = "ImpattoGetto"
		holder.top_level = true
		n.add_child(holder)
		impatto = a.crea_loop(&"zaino_impatto_loop", holder)
		impatto_acqua = a.crea_loop(&"zaino_impatto_acqua_loop", holder)
		for l in [getto, aspira]:
			if l:
				l.rapidita_volume = 14.0
		n.connect(&"spray_started", func(): a.suona(&"zaino_getto_inizio"))
		n.connect(&"spray_stopped", func(): a.suona(&"zaino_getto_fine"))
		n.connect(&"suck_started", func():
			inizio_aspira = float(n.get(&"tank_amount"))
			a.suona(&"zaino_aspira_inizio"))
		n.connect(&"suck_stopped", func():
			a.suona(&"zaino_aspira_fine")
			# dopo una bella sorsata la pompa mette in pressione il serbatoio
			if float(n.get(&"tank_amount")) - inizio_aspira > 3.0:
				a.get_tree().create_timer(0.45, false).timeout.connect(func(): a.suona(&"zaino_pompata")))
		n.connect(&"tank_full", func(): a.suona_limitato("pieno", 1.0, &"zaino_pieno"))
		n.connect(&"tank_empty", func(): a.suona_limitato("vuoto", 0.5, &"zaino_vuoto"))
		n.connect(&"jet_hit", _su_colpo)

	func _su_colpo(collider: Object, punto: Vector3, _normale: Vector3) -> void:
		var nodo := collider as Node
		for i in 4:
			if nodo == null:
				return
			if (&"jammed" in nodo) and bool(nodo.get(&"jammed")):
				audio.suona_limitato("turbina_bloccata", 0.4, &"turbina_bloccata", punto)
				return
			if nodo.has_method(&"is_stuck") and bool(nodo.call(&"is_stuck")):
				audio.suona_limitato("gonfiabile", 0.3, &"gonfiabile_colpito", punto)
				return
			nodo = nodo.get_parent()

	func aggiorna(_a, delta: float) -> bool:
		if not is_instance_valid(pack):
			return false
		if not pack.is_inside_tree():
			return true
		var spruzza := bool(pack.get(&"is_spraying"))
		var flusso := float(pack.get(&"flow"))
		var aspirando := bool(pack.get(&"is_sucking"))
		if getto:
			getto.volume = clampf(flusso, 0.0, 1.0) if spruzza else 0.0
			getto.tono = 0.94 + 0.06 * flusso
		if aspira:
			aspira.volume = 1.0 if aspirando else 0.0
		# dove il getto colpisce
		var colpisce := spruzza and bool(pack.get(&"has_hit"))
		var in_acqua := false
		if colpisce:
			var c = pack.get(&"hit_collider")
			in_acqua = c is Node and (c as Node).is_in_group(&"water_catchers")
			var holder: Node3D = impatto.get_parent() if impatto else null
			if holder:
				var p: Vector3 = pack.get(&"hit_point")
				holder.global_position = p if not impatto.is_suonando() else holder.global_position.lerp(p, 1.0 - exp(-20.0 * delta))
		if impatto:
			impatto.volume = flusso if colpisce and not in_acqua else 0.0
		if impatto_acqua:
			impatto_acqua.volume = flusso if colpisce and in_acqua else 0.0
		# ricarica nell'acqua che scorre: il serbatoio sale senza aspirare
		var livello := float(pack.get(&"tank_amount"))
		if ultimo_serbatoio >= 0.0 and livello > ultimo_serbatoio + 0.0001 and not aspirando:
			ricarica_t = 0.25
		ultimo_serbatoio = livello
		ricarica_t = maxf(0.0, ricarica_t - delta)
		if ricarica:
			ricarica.volume = 1.0 if ricarica_t > 0.0 else 0.0
			var cap := maxf(float(pack.get(&"tank_capacity")), 0.001)
			ricarica.tono = 0.85 + 0.35 * livello / cap
		return true


## Turbina: il loop segue l'energia (volume) e la velocità (tono).
class Turbina:
	var n: Node
	var l: AudioLoop

	func _init(a, nodo: Node) -> void:
		n = nodo
		l = a.crea_loop(&"turbina_loop", nodo)

	func aggiorna(_a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		var e := clampf(float(n.get(&"energy")), 0.0, 1.0)
		if l:
			l.volume = smoothstep(0.0, 0.25, e) * (0.5 + 0.5 * e)
			l.tono = 0.35 + 0.8 * e
		return true


## Porta alimentata: motore mentre si muove, colpo a fine corsa. Se sale in verticale è una saracinesca.
class Porta:
	var n: Node
	var l: AudioLoop
	var serranda := false
	var prima := -1.0

	func _init(a, nodo: Node) -> void:
		n = nodo
		var off = nodo.get(&"open_offset")
		if off is Vector3:
			var o: Vector3 = off
			serranda = absf(o.y) > maxf(absf(o.x), absf(o.z))
		l = a.crea_loop(&"saracinesca_loop" if serranda else &"porta_motore_loop", nodo)
		if l:
			l.position = Vector3(0, 1.2, 0)
		var fine := &"saracinesca_fine" if serranda else &"porta_aperta"
		nodo.connect(&"opened", func(): a.suona(fine, (nodo as Node3D).global_position + Vector3.UP * 1.2))
		nodo.connect(&"closed", func():
			a.suona(&"saracinesca_fine" if serranda else &"porta_chiusa", (nodo as Node3D).global_position + Vector3.UP * 1.2))

	func aggiorna(_a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		var ora := float(n.get(&"open_amount"))
		var muove := prima >= 0.0 and absf(ora - prima) > 0.00001
		prima = ora
		if l:
			l.volume = 1.0 if muove else 0.0
		return true


## Ruota a pale, secchio, cancello e quadro elettrico dell'area bimbi.
class Ruota:
	var n: Node
	var l: AudioLoop

	func _init(a, nodo: Node) -> void:
		n = nodo
		var ruota := _nodo(nodo, &"wheel_path")
		l = a.crea_loop(&"ruota_pale_loop", ruota if ruota else nodo)
		var secchio := _nodo(nodo, &"bucket_path")
		var cancello := _nodo(nodo, &"gate_path")
		var ruota_cancello := _nodo(nodo, &"gate_wheel_path")
		var quadro := _nodo(nodo, &"panel_path")
		nodo.connect(&"bucket_tipped", func():
			if is_instance_valid(secchio):
				a.suona(&"secchio_ribalta", secchio.global_position)
			a.get_tree().create_timer(0.7, false).timeout.connect(func():
				var dove: Node3D = ruota_cancello if is_instance_valid(ruota_cancello) else cancello
				if is_instance_valid(dove):
					a.suona(&"cancello_ruota", dove.global_position))
			a.get_tree().create_timer(2.5, false).timeout.connect(func():
				if is_instance_valid(secchio):
					a.suona(&"secchio_ritorno", secchio.global_position)))
		nodo.connect(&"gate_opened", func():
			if is_instance_valid(cancello):
				a.suona(&"cancello_fine", cancello.global_position))
		nodo.connect(&"panel_shorted", func():
			if is_instance_valid(quadro):
				a.suona(&"quadro_scintille", quadro.global_position + Vector3.UP * 1.5))

	static func _nodo(nodo: Node, prop: StringName) -> Node3D:
		var p = nodo.get(prop)
		if p is NodePath and not (p as NodePath).is_empty():
			return nodo.get_node_or_null(p) as Node3D
		return null

	func aggiorna(_a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		var v := float(n.get(&"angular_speed"))
		var vmax := maxf(float(n.get(&"max_angular_speed")), 0.001)
		var k := clampf(v / vmax, 0.0, 1.0)
		if l:
			l.volume = smoothstep(0.0, 0.15, k) * (0.4 + 0.6 * k)
			l.tono = 0.45 + 0.6 * k
		return true


## Vasca: gorgoglio dello scarico mentre si svuota, scroscio mentre si riempie da sola.
class Vasca:
	var audio
	var n: Node
	var scarico: AudioLoop
	var riempie: AudioLoop
	var cercato := false
	var prima := -1.0
	var svuotava := 0.0

	func _init(a, nodo: Node) -> void:
		audio = a
		n = nodo
		nodo.connect(&"emptied", func():
			if svuotava > 0.0 and scarico:
				a.suona(&"vasca_svuotata", scarico.global_position))

	func _prepara() -> void:
		cercato = true
		# lo scarico: il gorgo (DrainVortex) collegato a questa vasca, se c'è
		var dove: Node3D = n as Node3D
		var scena: Node = n.get_tree().current_scene
		if scena:
			for g in scena.find_children("*", "MeshInstance3D", true, false):
				if g.get(&"tank") == n:
					dove = g
					break
		var holder := Node3D.new()
		holder.name = "AudioScarico"
		dove.add_child(holder)
		scarico = audio.crea_loop(&"scarico_loop", holder)
		riempie = audio.crea_loop(&"riempie_loop", n)

	func aggiorna(_a, delta: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		if not cercato:
			_prepara()
		var fill := float(n.get(&"fill"))
		var drena := bool(n.call(&"is_draining")) and fill > 0.001
		var forza := float(n.call(&"get_drain_strength")) if drena else 0.0
		svuotava = 1.0 if drena else maxf(0.0, svuotava - delta)
		if scarico:
			scarico.volume = (0.4 + 0.6 * forza) if drena else 0.0
		var sorgenti = n.get(&"fill_sources")
		var da_sola := false
		if sorgenti is Array:
			for s in sorgenti:
				if is_instance_valid(s) and bool(s.get(&"powered")):
					da_sola = true
		if riempie:
			riempie.volume = 1.0 if da_sola and fill < float(n.get(&"max_fill")) - 0.002 else 0.0
		prima = fill
		return true


## Lampada che sfarfalla (FlickerLight): colpo all'accensione e ronzio che segue la luce.
class Lampada:
	var audio
	var n: Node
	var l: AudioLoop
	var era_accesa := true

	func _init(a, nodo: Node) -> void:
		audio = a
		n = nodo
		era_accesa = bool(nodo.get(&"is_on"))

	func aggiorna(a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		var luce = n.get(&"light")
		if not (luce is Light3D) or not is_instance_valid(luce):
			return true
		if l == null:
			l = a.crea_loop(&"faro_ronzio_loop", luce)
		var accesa := bool(n.get(&"is_on"))
		if accesa and not era_accesa:
			a.suona(&"faro_acceso", (luce as Light3D).global_position)
		era_accesa = accesa
		var base := maxf(float(n.get(&"base_energy")), 0.001)
		if l:
			l.volume = clampf((luce as Light3D).light_energy / base, 0.0, 1.0) if accesa else 0.0
		return true


## La statua della medusa: un respiro umido appena udibile da vicino; il risveglio.
class Statua:
	var n: Node
	var l: AudioLoop
	var sveglia := false
	var ap: AnimationPlayer
	var cerca_t := 0.0

	func _init(a, nodo: Node) -> void:
		n = nodo
		var holder := Node3D.new()
		holder.name = "AudioMedusa"
		holder.position = Vector3(0, 1.6, 0)
		nodo.add_child(holder)
		l = a.crea_loop(&"medusa_presenza_loop", holder)
		if l:
			l.volume = 1.0

	func aggiorna(a, delta: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		if not sveglia:
			if not is_instance_valid(ap):
				cerca_t -= delta
				if cerca_t > 0.0:
					return true
				cerca_t = 2.0
				ap = n.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if ap == null:
					return true
			if ap.is_playing() and ap.current_animation == &"sveglia":
				sveglia = true
				a.suona(&"medusa_risveglio", (n as Node3D).global_position + Vector3.UP * 2.0)
				if l:
					l.volume = 0.0
		return true


## Gocciolatoio dell'addon acqua: niente segnale, si guarda quando una goccia sparisce.
class Gocciolatoio:
	var audio
	var n: Node
	var visibili := {}

	func _init(a, nodo: Node) -> void:
		audio = a
		n = nodo

	func aggiorna(a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		for c in n.get_children():
			if c is MeshInstance3D:
				var id: int = c.get_instance_id()
				var vis: bool = c.visible
				if visibili.get(id, false) and not vis:
					var p: Vector3 = (c as MeshInstance3D).global_position
					a.suona(a._nome_goccia(p), p)
				visibili[id] = vis
		return true


## Bocchetta dell'addon acqua: scroscio quando versa.
class Bocchetta:
	var n: Node
	var l: AudioLoop

	func _init(a, nodo: Node) -> void:
		n = nodo
		l = a.crea_loop(&"riempie_loop", nodo)

	func aggiorna(_a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		var versa := false
		for c in n.get_children():
			if c is GPUParticles3D:
				versa = (c as GPUParticles3D).emitting
				break
		if l:
			l.volume = 1.0 if versa else 0.0
		return true


## Acqua negli scivoli: il loop sta nel punto del tubo più vicino a chi ascolta.
class Scivolo:
	var n: Node3D
	var l: AudioLoop
	var t := 0.0

	func _init(a, nodo: Node) -> void:
		n = nodo
		var holder := Node3D.new()
		holder.name = "AudioScivolo"
		holder.top_level = true
		nodo.add_child(holder)
		l = a.crea_loop(&"scivolo_loop", holder)
		if l:
			l.volume = 1.0

	func aggiorna(a, delta: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		t -= delta
		if t > 0.0 or l == null:
			return true
		t = 0.2
		var curva = n.get(&"curve")
		if curva is Curve3D and (curva as Curve3D).point_count > 1:
			var locale := n.to_local(a.ascoltatore())
			l.get_parent().global_position = n.to_global((curva as Curve3D).get_closest_point(locale))
		return true


## Il monitor a tubo della sala pompe (MonitorCrt): la neve frusciante quando non c'è più segnale.
class AudioMonitor:
	var n: Node
	var l: AudioLoop

	func _init(a, nodo: Node) -> void:
		n = nodo
		var dove: Node = null
		for prop in [&"schermo_path", &"luce_path"]:
			var path = nodo.get(prop)
			if path is NodePath and not (path as NodePath).is_empty():
				dove = nodo.get_node_or_null(path)
				if dove is Node3D:
					break
		if dove is Node3D and nodo.has_method(&"mostra_neve_attiva"):
			l = a.crea_loop(&"crt_neve_loop", dove)

	func aggiorna(_a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		if l:
			l.volume = 1.0 if bool(n.call(&"mostra_neve_attiva")) else 0.0
		return true


## Le paratie della camera delle onde (Paratia): motore e catene mentre scende, colpo in fondo.
class AudioParatia:
	var n: Node
	var l: AudioLoop
	var pannello: Node3D

	func _init(a, nodo: Node) -> void:
		n = nodo
		var path = nodo.get(&"pannello_path")
		if path is NodePath and not (path as NodePath).is_empty():
			pannello = nodo.get_node_or_null(path) as Node3D
		if pannello:
			l = a.crea_loop(&"paratia_scende_loop", pannello)
		if nodo.has_signal(&"chiusa"):
			nodo.connect(&"chiusa", func():
				if is_instance_valid(pannello) and pannello.is_inside_tree():
					# il colpo in fondo: più grave e forte di una porta (si sente fino alla sala pompe)
					a.suona(&"porta_chiusa", pannello.global_position, 6.0, 0.7))

	func aggiorna(_a, _d: float) -> bool:
		if not is_instance_valid(n):
			return false
		if not n.is_inside_tree():
			return true
		if l:
			l.volume = 1.0 if bool(n.get(&"in_movimento")) else 0.0
		return true

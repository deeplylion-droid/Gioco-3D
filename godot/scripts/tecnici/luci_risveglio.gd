class_name LuciRisveglio
extends Node
## Luci di riserva del risveglio (tappa 6): le luci di tutto il livello seguono GameState.luci.
## - prima del risveglio: come sono;
## - flash: per un secondo tutte le luci molto più forti (le pompe ripartono, torna la corrente);
## - blackout: si spengono tutte, tranne le rosse d'emergenza (e i lampi, la luna e il
##   monitor della sala pompe, che va a batteria).
## Le luci finali le fa l'addon grafica (LookSala, LookTecnici, LookInterni) agganciandosi allo
## stesso stato: quando le sue gestiscono il risveglio, questo nodo si spegne con [member attivo].

## Se falso non tocca niente (le luci del risveglio le fa la grafica).
@export var attivo := true
## Di quanto si moltiplicano le luci nel flash.
@export var forza_flash := 3.0

# luce -> [energia, visibile] com'erano prima del risveglio
var _originali := {}
var _neon_spenti := {}   # neon -> modalità che aveva


func _ready() -> void:
	GameState.luci_cambiate.connect(_applica)
	# Si riparte (o si carica la scena) con le luci già cambiate: si applicano subito, dopo che
	# le luci del livello sono state preparate (LuciSala lo fa in differita).
	_applica_dopo.call_deferred()


func _applica_dopo() -> void:
	await get_tree().process_frame
	if GameState.luci != GameState.Luci.PRIMA_DEL_RISVEGLIO:
		_applica(GameState.luci)


func _applica(fase: GameState.Luci) -> void:
	if not attivo or not is_inside_tree():
		return
	match fase:
		GameState.Luci.PRIMA_DEL_RISVEGLIO:
			_ripristina()
		GameState.Luci.FLASH:
			for l in _luci():
				_ricorda(l)
				l.visible = true
				l.light_energy = float(_originali[l][0]) * forza_flash
		GameState.Luci.BLACKOUT:
			for l in _luci():
				_ricorda(l)
				if _di_emergenza(l):
					l.visible = bool(_originali[l][1])
					l.light_energy = float(_originali[l][0])
				else:
					l.visible = false
			for n in get_tree().current_scene.find_children("*", "Neon", true, false):
				var neon := n as Neon
				if neon and neon.modalita != Neon.Modalita.SPENTO:
					_neon_spenti[neon] = neon.modalita
					# Con la scintilla: salta la corrente, sfarfallano un attimo e restano spenti.
					neon.spegni(true)
			for f in get_tree().current_scene.find_children("*", "FlickerLight", true, false):
				(f as FlickerLight).turn_off()


func _ripristina() -> void:
	for l in _originali:
		if is_instance_valid(l):
			(l as Light3D).light_energy = float(_originali[l][0])
			(l as Light3D).visible = bool(_originali[l][1])
	_originali.clear()
	for n in _neon_spenti:
		if is_instance_valid(n):
			(n as Neon).accendi(_neon_spenti[n])
	_neon_spenti.clear()


func _ricorda(l: Light3D) -> void:
	if not _originali.has(l):
		_originali[l] = [l.light_energy, l.visible]


## Le luci del livello che seguono il risveglio: niente luci del giocatore, niente luci
## direzionali (luna e lampi), niente monitor della sala pompe.
func _luci() -> Array[Light3D]:
	var out: Array[Light3D] = []
	var scena := get_tree().current_scene
	if scena == null:
		return out
	var giocatore := GameState.player
	for n in scena.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D:
			continue
		if giocatore and giocatore.is_ancestor_of(l):
			continue
		if l.has_meta(&"risveglio_ignora"):
			continue
		out.append(l)
	return out


## Rossa d'emergenza: una LuceEmergenza (addon grafica), una luce che si chiama così o una
## luce rossa.
static func _di_emergenza(l: Light3D) -> bool:
	if l.get_parent() is LuceEmergenza:
		return true
	var nome := String(l.name).to_lower()
	if nome.contains("emergenza") or nome.contains("rossa"):
		return true
	var c := l.light_color
	return c.r > 0.6 and c.g < 0.3 and c.b < 0.3

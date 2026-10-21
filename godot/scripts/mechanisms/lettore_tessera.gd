class_name LettoreTessera
extends Interactable
## Il lettore della keycard accanto alla serranda del magazzino (scelta dell'utente del 18 ottobre: la
## serranda che riporta nella sala grande si apre solo passando la keycard presa nella cassaforte
## dell'infermeria). Si usa con E. Se il giocatore ha [member oggetto] il lettore diventa verde, fa il
## suo suono e si sblocca ([signal sbloccato]); se no lampeggia rosso. È illuminato e si vede al buio:
## rosso finché è bloccato, verde dopo. Lo stato si salva con i checkpoint.
## Grafica provvisoria (una scatoletta con la spia): l'aspetto vero lo propone enigma-ambiente.

signal sbloccato
signal rifiutato

## L'oggetto dell'inventario che apre.
@export var oggetto: StringName = &"keycard"
@export var colore_bloccato := Color(1.0, 0.08, 0.05)
@export var colore_sbloccato := Color(0.1, 1.0, 0.25)
## I suoni (del catalogo dell'addon audio): letta e rifiutata. Per ora quelli che ci sono già.
@export var suono_ok: StringName = &"pulsante_premuto"
@export var suono_no: StringName = &"maniglione_bloccato"
## Se falso non disegna la scatoletta provvisoria (quando c'è il modello vero).
@export var mostra_segnaposto := true
## L'aspetto vero (di solito un figlio con scripts/risalita/lettore_vero.gd): lo colora e lo fa
## lampeggiare chiamando i suoi metodi colora(verde) e luce(k). Con l'aspetto vero la spia
## provvisoria non si accende.
@export var aspetto: Node

var aperto := false

var _spia: OmniLight3D
var _mat: StandardMaterial3D
var _lampo := 0.0


func _init() -> void:
	super()
	prompt = "Passa la keycard"


func _ready() -> void:
	add_to_group(&"persist")
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	if mostra_segnaposto:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.22, 0.05)
		mi.mesh = box
		mi.material_override = _mat
		add_child(mi)
	_spia = OmniLight3D.new()
	_spia.name = "Spia"
	_spia.omni_range = 1.6
	_spia.light_energy = 0.8
	_spia.position = Vector3(0.0, 0.0, 0.12)
	# Si vede al buio: il blackout non la spegne.
	_spia.set_meta(&"risveglio_ignora", true)
	add_child(_spia)
	_colora()


func get_prompt(by: Node) -> String:
	if aperto:
		return ""
	return prompt if _ha_tessera(by) else "Serve una keycard"


func can_interact(by: Node) -> bool:
	return enabled and not aperto and by is Player


func _on_interact(by: Node) -> void:
	if _ha_tessera(by):
		aperto = true
		_colora()
		_suona(suono_ok)
		sbloccato.emit()
	else:
		_lampo = 0.6
		_suona(suono_no)
		rifiutato.emit()


func _ha_tessera(by: Node) -> bool:
	return by != null and by.has_method(&"has_item") and bool(by.call(&"has_item", oggetto))


func _process(delta: float) -> void:
	if _lampo > 0.0:
		_lampo -= delta
		var on := fmod(_lampo, 0.2) > 0.1
		_spia.light_energy = 1.6 if on else 0.2
		if aspetto and aspetto.has_method(&"luce"):
			_spia.light_energy = 0.0
			aspetto.call(&"luce", 1.0 if on else 0.15)
		if _lampo <= 0.0:
			_colora()


func _colora() -> void:
	var c := colore_sbloccato if aperto else colore_bloccato
	_mat.albedo_color = c * 0.4
	_mat.emission = c
	_mat.emission_energy_multiplier = 2.0
	_spia.light_color = c
	_spia.light_energy = 0.8
	if aspetto and aspetto.has_method(&"colora"):
		_spia.light_energy = 0.0
		_spia.visible = false
		aspetto.call(&"colora", aperto)


func _suona(nome: StringName) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio and audio.has_method(&"suona"):
		audio.call(&"suona", nome, global_position)


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"aperto": aperto}


func load_state(data: Dictionary) -> void:
	aperto = bool(data.get("aperto", false))
	_lampo = 0.0
	_colora()

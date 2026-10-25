class_name Collectible
extends Interactable
## Oggetto da collezione (per esempio le Polaroid). Raccolto, fa salire il contatore della
## sua collezione in GameState e non ricompare più. Il totale è il numero di collezionabili
## della stessa collezione presenti nei livelli visti. Il contenuto (foto, testo) lo decide
## l'utente: [member image] e [member text] sono segnaposto per un futuro visore.

@export var collection: StringName = &"polaroid"
## Identificatore unico nella collezione (vuoto = nome del nodo).
@export var entry_id: StringName = &""
@export var display_name := "Polaroid"
@export var image: Texture2D
@export_multiline var text := ""


func _init() -> void:
	super()
	prompt = "Raccogli"
	one_shot = true


func _ready() -> void:
	GameState.register_collectible(collection, get_entry())
	if GameState.has_collectible(collection, get_entry()):
		queue_free()


func get_entry() -> StringName:
	return entry_id if entry_id != &"" else StringName(name)


func get_prompt(_by: Node) -> String:
	return "%s %s" % [tr(prompt), tr(display_name)]


func _on_interact(_by: Node) -> void:
	GameState.collect(collection, get_entry())
	queue_free()

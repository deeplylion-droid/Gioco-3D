class_name Saracinesca
extends PoweredDoor
## La saracinesca tra il corridoio lava-piedi e la sala principale: una PoweredDoor che invece
## del pannello grigio muove il modello vero (origine in basso al centro del vano, come la porta).
## Il pannello di collisione della PoweredDoor resta e sale insieme al modello.

## Il modello della saracinesca (nodo del glTF degli spogliatoi).
@export var modello: NodePath

var _modello: Node3D
var _base: Vector3


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_modello = get_node_or_null(modello) as Node3D
	if _modello:
		_base = _modello.position
		# Si vede solo il modello: del graybox resta solo la collisione del pannello. Le sue mesh si tolgono (non solo
		# nascoste: niente in memoria e niente nel controllo di posizionamento); la spia la usa PoweredDoor, al suo
		# posto una mesh vuota.
		var finta := MeshInstance3D.new()
		finta.name = "SpiaVuota"
		add_child(finta)
		var mesh_graybox: Array[Node] = find_children("*", "MeshInstance3D", true, false)
		for c in get_children(true):
			mesh_graybox.append_array(c.find_children("*", "MeshInstance3D", true, false))
		for m in mesh_graybox:
			if m != finta and not m.is_queued_for_deletion():
				m.queue_free()
		_lamp_mesh = finta


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _modello:
		_modello.position = _base + open_offset * _ease(open_amount)

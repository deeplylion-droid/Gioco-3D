class_name AgnelloFluorescente
extends Node
## Proposta (17 ottobre, idea dell'utente): la medusa ha modificato l'agnellino con i suoi geni, come le pecore
## rese fluorescenti col gene di una medusa, e ora brilla al buio col rosa dei suoi tentacoli. Si mette come figlio
## di un Bambino (l'agnellino): ai materiali dei modelli Calmo e Rivelato (copie, il modello non cambia) aggiunge
## un'emissione rosa attraverso una maschera, con una pulsazione lenta facoltativa e una luce rosa debole intorno.
## Solo proposta: nel gioco non c'è.

## Maschera dell'emissione sul modello calmo (stesse UV della texture del colore).
@export var maschera_calmo: Texture2D
## Maschera dell'emissione sul modello rivelato.
@export var maschera_rivelato: Texture2D
## Il grande occhio del modello rivelato brilla tutto.
@export var occhio_grande := true
## Il rosa dei tentacoli della medusa.
@export var colore := Color(1.0, 0.18, 0.66)
@export var energia := 3.0
## Secondi di un respiro (0: luce fissa).
@export var pulsazione := 0.0
## Nel respiro, quanto resta acceso nel punto più basso (0..1).
@export_range(0.0, 1.0) var minimo := 0.25
## La luce rosa intorno (energia della OmniLight, 0: niente luce).
@export var luce := 0.0

var _materiali: Array[BaseMaterial3D] = []
var _luce: OmniLight3D
var _t := 0.0


func _ready() -> void:
	var b := get_parent()
	for nome in ["Calmo", "Rivelato"]:
		var m := b.get_node_or_null(NodePath(nome))
		if m:
			_prepara(m, maschera_calmo if nome == "Calmo" else maschera_rivelato)
	if luce > 0.0:
		_luce = OmniLight3D.new()
		_luce.light_color = colore
		_luce.light_energy = luce
		_luce.omni_range = 1.8
		_luce.position = Vector3(0, 0.7, 0.25)
		b.add_child.call_deferred(_luce)
	_aggiorna()


func _prepara(radice: Node, maschera: Texture2D) -> void:
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var orig := m3.get_active_material(i) as BaseMaterial3D
			if orig == null:
				continue
			var mat := orig.duplicate() as BaseMaterial3D
			var occhio := "bulbo" in String(orig.resource_name).to_lower()
			if occhio and not occhio_grande:
				continue
			mat.emission_enabled = true
			mat.emission = colore
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # colore × maschera (con ADD la maschera si somma al colore)
			mat.emission_texture = null if occhio else maschera
			mat.set_meta(&"piena", energia * (0.6 if occhio else 1.0))
			m3.set_surface_override_material(i, mat)
			_materiali.append(mat)


func _process(delta: float) -> void:
	if pulsazione <= 0.0:
		return
	_t += delta
	_aggiorna()


func _aggiorna() -> void:
	var k := 1.0
	if pulsazione > 0.0:
		k = minimo + (1.0 - minimo) * (0.5 - 0.5 * cos(TAU * _t / pulsazione))
	for m in _materiali:
		m.emission_energy_multiplier = float(m.get_meta(&"piena")) * k
	if _luce:
		_luce.light_energy = luce * k

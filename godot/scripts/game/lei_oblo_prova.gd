class_name LeiObloProva
extends Node3D
## Una lei di prova per l'oblò (ObloLei) finché non c'è quella vera di mascotte (LeiOblo, res://scripts/game/lei_oblo.gd):
## una testa rosa luminosa con la sua luce, che guarda il giocatore e si stacca piano verso il fondo della vasca. Ha
## gli stessi metodi: [method mostra], [method stacca], il segnale [signal sparita], [method get_eye_position] e
## [method get_eye_direction]. Serve ai test e agli scatti di prova, non entra nel gioco.

signal sparita

const DURATA_STACCA := 2.6

var lato_sbircia := 1.0
var _testa: MeshInstance3D
var _luce: OmniLight3D
var _normale := Vector3.BACK
var _via := false


func mostra(centro_vetro: Vector3, normale: Vector3, _posa: String) -> void:
	_normale = normale
	if _testa == null:
		_testa = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		_testa.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.55, 0.8)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.35, 0.7)
		m.emission_energy_multiplier = 1.5
		_testa.material_override = m
		add_child(_testa)
		_luce = OmniLight3D.new()
		_luce.light_color = Color(1.0, 0.4, 0.75)
		_luce.light_energy = 2.0
		_luce.omni_range = 5.0
		add_child(_luce)
	global_position = centro_vetro - normale * 0.32
	_luce.position = Vector3.ZERO
	visible = true


func _process(_delta: float) -> void:
	var p := GameState.player
	if _testa and p and is_instance_valid(p) and p.camera and not _via:
		_testa.look_at(p.camera.global_position, Vector3.UP)


func get_eye_position() -> Vector3:
	return _testa.global_position if _testa else global_position


func get_eye_direction() -> Vector3:
	return -_testa.global_basis.z if _testa else -_normale


func stacca() -> void:
	if _via:
		return
	_via = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", global_position - _normale * 2.0 + Vector3.DOWN * 2.5, DURATA_STACCA)
	tw.tween_property(_luce, "light_energy", 0.0, DURATA_STACCA)
	tw.chain().tween_callback(func(): sparita.emit())

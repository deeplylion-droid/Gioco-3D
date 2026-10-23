class_name JillySpot
extends MedusaAffacciata
## Jilly nello spot della crociera (GDD, "Lo spot della crociera Jubilee"): in piedi sui tentacoli sul piedistallo
## (posa "statua": il piano del piedistallo è all'origine del nodo), saluta e, nel finale, l'occhio pulsa.
## La regia (ambienti-2, scenes/spot/spot_inquadrature.json) la cerca per nome ("Jilly") e chiama, a tempi fissi:
## - saluta(durata): il saluto (tools/blender/medusa_spot.py, libreria medusa_spot.res: spot/saluta_su, spot/saluta
##   in ciclo per [param durata] secondi, spot/saluta_giu), poi di nuovo ferma;
## - pupilla_battito(durata): il finale. Se nella scena c'è l'OcchioIpnotico di enigmi lo collega al suo occhio e gli
##   fa salire il progresso da 0 a 1 in [param durata] secondi (battito, pupilla e vene li guida lui); se no, un
##   battito semplice che accelera, sulla pupilla (instance uniform "pupilla" di medusa_occhio.gdshader).
## Tutto va col tempo del motore (AnimationPlayer, Tween, _process): con il Movie Maker a 30 fps fissi torna giusto.

const SPOT := "res://assets/models/medusa/medusa_spot.res"

var _battito_t := -1.0
var _battito_durata := 0.0
var _fase := 0.0
var _tw_saluto: Tween


func _init() -> void:
	animazione = &"statua"
	gocce = false


func _dopo_rebuild() -> void:
	super._dopo_rebuild()
	var ap := _player()
	if ap and not ap.has_animation_library(&"spot") and ResourceLoader.exists(SPOT):
		ap.add_animation_library(&"spot", load(SPOT) as AnimationLibrary)


func _player() -> AnimationPlayer:
	if get_model_instance() == null:
		return null
	return get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer


## La MeshInstance del bulbo dell'occhio (quella con gli instance uniform "pupilla" e "vene").
func occhio() -> GeometryInstance3D:
	if get_model_instance() == null:
		return null
	return get_model_instance().find_child("Medusa_Occhio", true, false) as GeometryInstance3D


## Il saluto: alza il braccio, saluta per [param durata] secondi, lo riabbassa e torna ferma.
func saluta(durata := 4.0) -> void:
	var ap := _player()
	if ap == null or not ap.has_animation(&"spot/saluta"):
		push_warning("JillySpot: manca la libreria del saluto (" + SPOT + ")")
		return
	if _tw_saluto and _tw_saluto.is_valid():
		_tw_saluto.kill()
	ap.play(&"spot/saluta_su")
	ap.queue(&"spot/saluta")
	var su := ap.get_animation(&"spot/saluta_su").length
	_tw_saluto = create_tween()
	_tw_saluto.tween_interval(su + maxf(durata, 0.0))
	_tw_saluto.tween_callback(func():
		ap.play(&"spot/saluta_giu")
		ap.queue(animazione))


## Il finale: l'occhio che pulsa per [param durata] secondi, col battito che accelera.
func pupilla_battito(durata := 5.0) -> void:
	var oi := _occhio_ipnotico()
	if oi:
		oi.set(&"occhio", occhio())
		oi.set(&"usa_pupilla", true)
		oi.set(&"usa_vene", true)
		oi.set(&"progresso", 0.0)
		var tw := create_tween()
		tw.tween_property(oi, ^"progresso", 1.0, maxf(durata, 0.01))
		return
	_battito_t = 0.0
	_battito_durata = maxf(durata, 0.01)
	_fase = 0.0


func _occhio_ipnotico() -> Node:
	var radice := get_tree().current_scene if get_tree().current_scene else get_tree().root
	for n in radice.find_children("*", "ColorRect", true, false):
		if n.get_script() and String((n.get_script() as Script).get_global_name()) == "OcchioIpnotico":
			return n
	return null


func _process(delta: float) -> void:
	super._process(delta)
	if _battito_t < 0.0:
		return
	_battito_t += delta
	var p := clampf(_battito_t / _battito_durata, 0.0, 1.0)
	# il battito (lub-dub) da 72 a 200 al minuto: la pupilla si allarga a ogni colpo, sempre di più
	_fase = fmod(_fase + delta * lerpf(72.0, 200.0, p * p) / 60.0, 1.0)
	var colpo := clampf(exp(-_fase * 14.0) + 0.6 * exp(-absf(_fase - 0.28) * 18.0) * float(_fase > 0.22), 0.0, 1.0)
	var o := occhio()
	if o:
		o.set_instance_shader_parameter(&"pupilla", minf(2.0, 1.0 + 0.8 * colpo * (0.4 + 0.6 * p)))
		o.set_instance_shader_parameter(&"vene", smoothstep(0.12, 0.75, p) * (0.85 + 0.15 * colpo))
	if p >= 1.0:
		_battito_t = -1.0

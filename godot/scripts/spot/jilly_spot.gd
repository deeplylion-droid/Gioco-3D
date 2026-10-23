class_name JillySpot
extends MedusaAffacciata
## Jilly nello spot della crociera (GDD, "Lo spot della crociera Jubilee"): in piedi sui tentacoli sul piedistallo
## (posa "statua": il piano del piedistallo è all'origine del nodo), saluta e, nel finale, l'occhio pulsa.
## La regia (ambienti-2, scenes/spot/spot_inquadrature.json) la cerca per nome ("Jilly") e chiama, a tempi fissi:
## - saluta(durata): il saluto (tools/blender/medusa_spot.py, libreria medusa_spot.res: spot/saluta_su, spot/saluta
##   in ciclo per [param durata] secondi, spot/saluta_giu), poi di nuovo ferma. Mentre saluta sorride (scelta
##   dell'utente del 23 ottobre, "c"): l'occhio a mezzaluna (instance uniform "sorriso" di medusa_occhio.gdshader: la
##   palpebra di sotto che sale) e la campana che pulsa allegra; le spalle su e la testa inclinata sono nel saluto;
## - pupilla_battito(durata): il finale. Se nella scena c'è l'OcchioIpnotico di enigmi lo collega al suo occhio (pupilla e
##   vene); il progresso lo fa salire la regia (chiave "occhio" del JSON, la stessa del lettore: così l'effetto sullo
##   schermo e l'occhio vero battono insieme). Se non c'è, un battito semplice che accelera in [param durata] secondi,
##   sulla pupilla e sulle vene (instance uniform di medusa_occhio.gdshader).
## Tutto va col tempo del motore (AnimationPlayer, Tween, _process): con il Movie Maker a 30 fps fissi torna giusto.

const SPOT := "res://assets/models/medusa/medusa_spot.res"
## Il materiale dell'occhio con pupilla, vene e sorriso (instance uniform): sempre, anche senza material_map.
const OCCHIO := "res://assets/models/medusa/medusa_occhio.tres"

var _battito_t := -1.0
var _battito_durata := 0.0
var _fase := 0.0
var _tw_saluto: Tween
var _tw_sorriso: Tween
var _sorriso := 0.0          # 0..1: l'occhio a mezzaluna e la campana che pulsa
var _campana_t := 0.0
var _campana: Array[MeshInstance3D] = []
var _contrai_scritto := false


func _init() -> void:
	animazione = &"statua"
	gocce = false


func _dopo_rebuild() -> void:
	super._dopo_rebuild()
	_campana.clear()
	var o := occhio() as MeshInstance3D
	if o and o.mesh and not o.get_active_material(0) is ShaderMaterial:
		for i in o.mesh.get_surface_count():
			o.set_surface_override_material(i, load(OCCHIO))
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
	_sorridi(1.0, su * 0.6)
	_tw_saluto = create_tween()
	_tw_saluto.tween_interval(su + maxf(durata, 0.0))
	_tw_saluto.tween_callback(func():
		ap.play(&"spot/saluta_giu")
		ap.queue(animazione)
		_sorridi(0.0, ap.get_animation(&"spot/saluta_giu").length))


## Il sorriso (0..1) in [param secondi].
func _sorridi(verso: float, secondi: float) -> void:
	if _tw_sorriso and _tw_sorriso.is_valid():
		_tw_sorriso.kill()
	_tw_sorriso = create_tween()
	_tw_sorriso.tween_property(self, ^"_sorriso", verso, maxf(secondi, 0.01)).set_trans(Tween.TRANS_SINE)


## Il finale: collega l'occhio all'OcchioIpnotico (il progresso lo guida la regia), o se non c'è un battito semplice
## che accelera per [param durata] secondi.
func pupilla_battito(durata := 5.0) -> void:
	var oi := _occhio_ipnotico()
	if oi:
		oi.set(&"occhio", occhio())
		oi.set(&"usa_pupilla", true)
		oi.set(&"usa_vene", true)
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
	# il sorriso: l'occhio a mezzaluna e la campana che pulsa (si contrae appena, due volte al secondo)
	var o := occhio()
	if o:
		o.set_instance_shader_parameter(&"sorriso", _sorriso)
	_campana_t += delta
	var contrai := _sorriso * 0.18 * (0.5 + 0.5 * sin(_campana_t * TAU * 2.0))
	if contrai > 0.0001 or _contrai_scritto:
		_contrai_scritto = contrai > 0.0001
		if _campana.is_empty() and get_model_instance():
			for mi in get_model_instance().find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).find_blend_shape_by_name(&"campana_contrai") >= 0:
					_campana.append(mi)
		for mi: MeshInstance3D in _campana:
			if is_instance_valid(mi):
				mi.set_blend_shape_value(mi.find_blend_shape_by_name(&"campana_contrai"), contrai)
	if _battito_t < 0.0:
		return
	_battito_t += delta
	var p := clampf(_battito_t / _battito_durata, 0.0, 1.0)
	# il battito (lub-dub) da 72 a 200 al minuto: la pupilla si allarga a ogni colpo, sempre di più
	_fase = fmod(_fase + delta * lerpf(72.0, 200.0, p * p) / 60.0, 1.0)
	var colpo := clampf(exp(-_fase * 14.0) + 0.6 * exp(-absf(_fase - 0.28) * 18.0) * float(_fase > 0.22), 0.0, 1.0)
	if o:
		o.set_instance_shader_parameter(&"pupilla", minf(2.0, 1.0 + 0.8 * colpo * (0.4 + 0.6 * p)))
		o.set_instance_shader_parameter(&"vene", smoothstep(0.12, 0.75, p) * (0.85 + 0.15 * colpo))
	if p >= 1.0:
		_battito_t = -1.0

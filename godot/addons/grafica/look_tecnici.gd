class_name LookTecnici
extends Node3D
## Luci degli ambienti tecnici (camera delle onde, sala pompe, raccordo: scenes/tecnici/tecnici.tscn)
## in tre stati, richiamati da un punto solo con [method imposta_stato]:
## - PRIMA_DEL_RISVEGLIO: luci di servizio fioche e fredde (neon bassi, qualcuno che sfarfalla),
##   faretti sui quadri e sui manometri, lampade d'emergenza spente, la vasca di raccolta nera;
## - FLASH: per un attimo si accende tutto (anche la sala grande, se c'è una LookSala), poi si
##   passa da solo allo stato dopo (di serie il BLACKOUT): vedi [method flash];
## - BLACKOUT: restano solo le luci rosse d'emergenza e il monitor che fa neve.
## Il VoxelGI si cuoce SENZA emissioni e le luci restano dinamiche: il rimbalzo lo calcola il
## motore dalle luci accese in quel momento, quindi nel blackout non resta luce cotta.
## Va messo come figlio della radice di tecnici.tscn (scenes/tecnici/luci_tecnici.tscn).

signal stato_cambiato(stato: Stato)

enum Stato { PRIMA_DEL_RISVEGLIO, FLASH, BLACKOUT }

const NEON_SCRIPT := preload("res://addons/grafica/neon.gd")

## La radice di tecnici.tscn (con Ambienti/ dentro). Vuoto: il genitore.
@export var percorso_tecnici := NodePath()
@export var stato_iniziale := Stato.PRIMA_DEL_RISVEGLIO
@export var durata_flash := 1.0
@export_group("Illuminazione globale")
@export var crea_gi := true
## Dati del VoxelGI cotti, uno per stanza (<cartella>/<stanza>.res). Vedi [method cuoci_gi].
@export_dir var cartella_gi := "res://scenes/tecnici/gi"
@export_group("Prima del risveglio")
@export var colore_servizio := Color(0.55, 0.85, 1.0)     # fluorescente freddo
@export var energia_servizio := 0.9
@export var emissione_servizio := 0.35                     # i tubi restano fiochi
@export var energia_quadri := 1.6
@export var ambiente_servizio := 0.1
@export_group("Flash")
@export var colore_flash := Color(0.92, 0.97, 1.0)
@export var energia_flash := 7.0
@export var ambiente_flash := 0.6
@export_group("Blackout")
@export var energia_emergenza := 2.4
@export var portata_emergenza := 7.0
@export var colore_emergenza := Color(1.0, 0.05, 0.03)
@export var energia_monitor := 0.5
@export var ambiente_blackout := 0.0

var stato := Stato.PRIMA_DEL_RISVEGLIO
var ambiente: Environment

var _tecnici: Node3D
var _neon: Array[Node3D] = []            # Neon dell'addon (uno per tubo, anche quelli prima spenti)
var _emergenza: Array[Light3D] = []      # luci rosse (lampade a muro, nicchie, paratie)
var _energie_emergenza: Array[float] = []
var _vetri_emergenza: Array[BaseMaterial3D] = []
var _emissioni_servizio: Array = []      # [materiale, emissione piena]
var _quadri: Array[SpotLight3D] = []
var _portello: Light3D
var _schermo: MeshInstance3D
var _luce_monitor: OmniLight3D
var _neve: ShaderMaterial
var _flash_resta := 0.0
var _dopo_flash := Stato.BLACKOUT
var _zona := AABB()
var _dentro := false
var _cam_env_prima: Environment
var _sale_flash: Array = []


func _ready() -> void:
	_tecnici = (get_parent() if percorso_tecnici.is_empty() else get_node(percorso_tecnici)) as Node3D
	# tecnici.gd prepara materiali e luci segnaposto nel suo _ready: si lavora dopo.
	_prepara.call_deferred()


func _prepara() -> void:
	var ambienti := _tecnici.get_node_or_null(^"Ambienti") as Node3D
	if ambienti == null:
		push_warning("LookTecnici: niente Ambienti/ in %s" % _tecnici.get_path())
		return
	_zona = _aabb(ambienti).grow(0.5)
	_crea_ambiente()
	_prepara_neon(ambienti)
	_prepara_emergenza(ambienti)
	_prepara_quadri(ambienti)
	_prepara_monitor(ambienti)
	_prepara_emissioni(ambienti)
	if crea_gi:
		for stanza in ambienti.get_children():
			if stanza is Node3D and _aabb(stanza).size != Vector3.ZERO:
				_crea_gi(stanza)
	imposta_stato(stato_iniziale)


## Il punto unico da cui si cambia lo stato delle luci.
func imposta_stato(nuovo: Stato) -> void:
	if nuovo == Stato.FLASH:
		flash()
		return
	stato = nuovo
	_flash_resta = 0.0
	var prima := nuovo == Stato.PRIMA_DEL_RISVEGLIO
	for i in _neon.size():
		var n := _neon[i]
		_energia_neon(n, energia_servizio, colore_servizio, emissione_servizio)
		if prima:
			# Uno su tre sfarfalla, gli altri fermi e bassi.
			n.call(&"accendi", 1 if i % 3 == 1 else 0)
		else:
			n.call(&"spegni", false)
	for i in _emergenza.size():
		var l := _emergenza[i]
		l.visible = not prima
		l.light_energy = _energie_emergenza[i]
	for m in _vetri_emergenza:
		m.emission_energy_multiplier = 0.02 if prima else m.get_meta(&"piena", 14.0)
	for q in _quadri:
		q.visible = prima
		q.light_energy = energia_quadri
	if _portello:
		_portello.visible = prima
		_portello.light_energy = _portello.get_meta(&"servizio", 1.0)
	for e in _emissioni_servizio:
		(e[0] as BaseMaterial3D).emission_energy_multiplier = e[1] * (0.6 if prima else 0.0)
	_monitor(not prima)
	ambiente.ambient_light_energy = ambiente_servizio if prima else ambiente_blackout
	ambiente.volumetric_fog_density = 0.02 if prima else 0.03
	stato_cambiato.emit(stato)


## Un attimo in cui si accende tutto, poi [param poi]. Se nella scena c'è una LookSala,
## si accende anche la sala grande.
func flash(durata := durata_flash, poi := Stato.BLACKOUT) -> void:
	stato = Stato.FLASH
	_flash_resta = durata
	_dopo_flash = poi
	for n in _neon:
		_energia_neon(n, energia_flash, colore_flash, 1.0)
		n.call(&"accendi", 0)
		n.call(&"_applica", 1.0)
	for i in _emergenza.size():
		_emergenza[i].visible = true
		_emergenza[i].light_energy = _energie_emergenza[i] * 1.5
	for m in _vetri_emergenza:
		m.emission_energy_multiplier = m.get_meta(&"piena", 14.0)
	for q in _quadri:
		q.visible = true
		q.light_energy = energia_quadri * 2.0
	if _portello:
		_portello.visible = true
		_portello.light_energy = _portello.get_meta(&"servizio", 1.0) * 4.0
	for e in _emissioni_servizio:
		(e[0] as BaseMaterial3D).emission_energy_multiplier = e[1]
	_monitor(false)
	ambiente.ambient_light_energy = ambiente_flash
	for s in get_tree().get_nodes_in_group(&"look_sala"):
		if s.has_method(&"flash"):
			s.call(&"flash", durata)
	stato_cambiato.emit(stato)


func _process(delta: float) -> void:
	if _flash_resta > 0.0:
		_flash_resta -= delta
		if _flash_resta <= 0.0:
			imposta_stato(_dopo_flash)
	if _luce_monitor and _luce_monitor.visible:
		_luce_monitor.light_energy = energia_monitor * randf_range(0.6, 1.0)
	_aggiorna_zona()


# --- Preparazione -----------------------------------------------------------------------------

func _prepara_neon(ambienti: Node3D) -> void:
	# I tubi che tecnici.gd ha già fatto diventare Neon...
	for n in ambienti.find_children("*", "Node3D", true, false):
		if n.get_script() == NEON_SCRIPT or (n.get_script() and String(n.get_script().get_global_name()) == "Neon"):
			_neon.append(n)
	# ...e quelli spenti del modello (*_tubi): diventano Neon anche loro, col diffusore emissivo.
	var diffusore := StandardMaterial3D.new()
	diffusore.albedo_color = Color(0.85, 0.9, 0.9)
	diffusore.emission_enabled = true
	diffusore.emission = Color(0.82, 1.0, 0.92)
	diffusore.emission_energy_multiplier = 10.0
	for tubo in ambienti.find_children("neon_*_tubi", "MeshInstance3D", true, false):
		var neon: Node3D = NEON_SCRIPT.new()
		neon.name = String(tubo.name).replace("_tubi", "_neon")
		neon.set(&"modalita", 0)
		neon.transform = (tubo as Node3D).transform
		var genitore := tubo.get_parent()
		genitore.remove_child(tubo)
		tubo.transform = Transform3D.IDENTITY
		(tubo as MeshInstance3D).material_override = diffusore.duplicate()
		neon.add_child(tubo)
		var luce := OmniLight3D.new()
		luce.position = Vector3(0, -0.2, 0)
		neon.add_child(luce)
		genitore.add_child(neon)
		_neon.append(neon)
	for n in _neon:
		for l in n.find_children("*", "Light3D", true, false):
			var luce := l as Light3D
			luce.shadow_enabled = true
			luce.shadow_blur = 1.5
			luce.light_volumetric_fog_energy = 0.4
			luce.light_specular = 0.4
			if luce is OmniLight3D:
				(luce as OmniLight3D).omni_range = 8.0
				(luce as OmniLight3D).omni_attenuation = 1.3
		# Le plafoniere non fanno ombra alla loro stessa luce (vedi LookInterni).
		for m in n.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _energia_neon(n: Node3D, energia: float, colore: Color, emissione: float) -> void:
	var energie: Array[float] = []
	for l in n.find_children("*", "Light3D", true, false):
		(l as Light3D).light_color = colore
		energie.append(energia)
	n.set(&"_energie", energie)
	var materiali: Array = n.get(&"_materiali")
	var emissioni: Array[float] = []
	for m in materiali:
		if not (m as Resource).has_meta(&"piena"):
			m.set_meta(&"piena", (m as BaseMaterial3D).emission_energy_multiplier)
		emissioni.append(float(m.get_meta(&"piena")) * emissione)
	n.set(&"_emissioni", emissioni)


func _prepara_emergenza(ambienti: Node3D) -> void:
	# Le LuceEmergenza dell'addon (da LUCE_rossa_*) e le luci rosse nude (nicchie, paratie).
	for n in ambienti.find_children("*", "Node3D", true, false):
		if n.get_script() and String(n.get_script().get_global_name()) == "LuceEmergenza":
			n.set(&"modalita", 0)
			n.set_process(false)
			for l in n.find_children("*", "Light3D", true, false):
				_aggiungi_emergenza(l as Light3D)
	for l in ambienti.find_children("LUCE_*", "Light3D", true, false):
		var nome := String(l.name)
		if nome.begins_with("LUCE_nicchia") or nome.begins_with("LUCE_paratia"):
			_aggiungi_emergenza(l as Light3D)
		elif nome == "LUCE_portello":
			_portello = l as Light3D
			_portello.light_color = colore_servizio
			_portello.set_meta(&"servizio", 1.2)
			_portello.shadow_enabled = true
	# I vetri rossi delle lampade a muro e le cupole: si accendono con le luci d'emergenza.
	var fatti := {}
	for mi in ambienti.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count() if m3.mesh else 0:
			var m := m3.get_active_material(i) as BaseMaterial3D
			if m == null or not m.emission_enabled:
				continue
			if m.resource_name in ["hq_lampada_muro_vetro", "luce_emergenza"] or "_vetro" in String(m3.name):
				if not fatti.has(m):
					var copia := m.duplicate() as BaseMaterial3D
					copia.set_meta(&"piena", m.emission_energy_multiplier)
					fatti[m] = copia
					_vetri_emergenza.append(copia)
				m3.set_surface_override_material(i, fatti[m])


func _aggiungi_emergenza(l: Light3D) -> void:
	l.light_color = colore_emergenza
	l.light_energy = energia_emergenza
	l.light_volumetric_fog_energy = 2.0
	l.light_specular = 0.6
	if l is OmniLight3D:
		(l as OmniLight3D).omni_range = portata_emergenza
		(l as OmniLight3D).omni_attenuation = 1.8
	_emergenza.append(l)
	_energie_emergenza.append(l.light_energy)


func _prepara_quadri(ambienti: Node3D) -> void:
	# Un faretto freddo dall'alto su ogni quadro: manometri e lancette si leggono.
	for nome in ["QUADRO_strumenti", "QUADRO_elettrico"]:
		var q := ambienti.find_child(nome, true, false) as Node3D
		if q == null:
			continue
		var box := _aabb(q)
		var centro := box.get_center()
		# Il quadro sta su un muro: la luce va dal lato della stanza (verso il centro della sala).
		var sala := _aabb(q.get_parent() as Node3D).get_center()
		var fuori := Vector3(sala.x - centro.x, 0, sala.z - centro.z)
		var verso := Vector3(0, 0, signf(fuori.z)) if absf(fuori.z) > absf(fuori.x) else Vector3(signf(fuori.x), 0, 0)
		var s := SpotLight3D.new()
		s.name = "Faretto_" + nome
		add_child(s)
		s.global_position = centro + verso * 1.1 + Vector3.UP * (box.size.y * 0.5 + 0.9)
		s.look_at(centro, Vector3.UP if absf(verso.y) < 0.9 else Vector3.FORWARD)
		s.light_color = Color(0.75, 0.9, 1.0)
		s.light_energy = energia_quadri
		s.spot_range = 4.0
		s.spot_angle = 32.0
		s.spot_angle_attenuation = 1.3
		s.shadow_enabled = true
		s.light_size = 0.05
		s.light_specular = 0.6
		s.light_volumetric_fog_energy = 0.3
		_quadri.append(s)


func _prepara_monitor(ambienti: Node3D) -> void:
	_schermo = ambienti.find_child("SCHERMO_CRT", true, false) as MeshInstance3D
	if _schermo == null:
		return
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform float energia = 1.4;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 cella = floor(UV * vec2(160.0, 120.0));
	float t = floor(TIME * 24.0);
	float n = h(cella + t * 13.1);
	float riga = 0.85 + 0.15 * sin(UV.y * 600.0 + TIME * 40.0);
	float banda = smoothstep(0.0, 0.05, abs(fract(UV.y - TIME * 0.3) - 0.5)) * 0.25 + 0.75;
	ALBEDO = vec3(n * riga * banda) * energia * vec3(0.85, 0.95, 1.0);
}
"""
	_neve = ShaderMaterial.new()
	_neve.shader = sh
	_luce_monitor = OmniLight3D.new()
	_luce_monitor.name = "LuceMonitor"
	add_child(_luce_monitor)
	var box := _aabb(_schermo)
	var crt := ambienti.find_child("MONITOR_CRT", true, false) as Node3D
	var dietro := _aabb(crt).get_center() if crt else box.get_center()
	var avanti := (box.get_center() - dietro)
	avanti.y = 0.0
	_luce_monitor.global_position = box.get_center() + (avanti.normalized() * 0.35 if avanti.length() > 0.01 else Vector3.ZERO)
	_luce_monitor.light_color = Color(0.75, 0.85, 1.0)
	_luce_monitor.omni_range = 2.5
	_luce_monitor.omni_attenuation = 1.6
	_luce_monitor.shadow_enabled = false
	_luce_monitor.light_volumetric_fog_energy = 0.8


func _monitor(neve: bool) -> void:
	if _schermo:
		_schermo.material_override = _neve if neve else null
	if _luce_monitor:
		_luce_monitor.visible = neve


func _prepara_emissioni(ambienti: Node3D) -> void:
	# Le altre parti emissive (insegna azzurra della sala pompe...): accese solo prima e nel flash.
	var fatti := {}
	for mi in ambienti.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3 == _schermo or _neon.any(func(n): return n.is_ancestor_of(m3)):
			continue
		for i in m3.mesh.get_surface_count() if m3.mesh else 0:
			var m := m3.get_active_material(i) as BaseMaterial3D
			if m == null or not m.emission_enabled or m in _vetri_emergenza:
				continue
			if not fatti.has(m):
				var copia := m.duplicate() as BaseMaterial3D
				fatti[m] = copia
				_emissioni_servizio.append([copia, m.emission_energy_multiplier])
			m3.set_surface_override_material(i, fatti[m])


func _crea_ambiente() -> void:
	ambiente = AmbienteHorror.crea(false)
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color.BLACK
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.35, 0.55, 0.65)
	ambiente.ambient_light_energy = ambiente_servizio


func _aggiorna_zona() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _zona.size == Vector3.ZERO:
		return
	var dentro := _zona.has_point(cam.global_position)
	if dentro == _dentro:
		return
	_dentro = dentro
	if dentro:
		_cam_env_prima = cam.environment
		cam.environment = ambiente
	else:
		cam.environment = _cam_env_prima
	if is_instance_valid(Grafica):
		Grafica.aggiorna_environment()


# --- Illuminazione globale --------------------------------------------------------------------

func _crea_gi(stanza: Node3D) -> void:
	var box := _aabb(stanza).grow(0.3)
	var gi := VoxelGI.new()
	gi.name = "GI_" + stanza.name
	gi.subdiv = VoxelGI.SUBDIV_128
	add_child(gi)
	gi.global_position = box.get_center()
	gi.size = box.size
	gi.set_meta(&"stanza", stanza)
	var percorso := cartella_gi.path_join(String(stanza.name) + ".res")
	if ResourceLoader.exists(percorso):
		gi.data = load(percorso)


## Cuoce il GI di ogni stanza e lo salva in [member cartella_gi]. Le emissioni si spengono
## prima: nel blackout non deve restare la luce delle lampade cotta nei muri.
func cuoci_gi() -> void:
	var spente := LookInterni.spegni_emissioni(_tecnici)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cartella_gi))
	for gi in find_children("GI_*", "VoxelGI", false, false):
		var v := gi as VoxelGI
		v.bake(v.get_meta(&"stanza"))
		var percorso := cartella_gi.path_join(String(v.name).trim_prefix("GI_") + ".res")
		print("GI ", v.name, " -> ", percorso, " ", ResourceSaver.save(v.data, percorso))
	LookInterni.ripristina_emissioni(spente)


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	return box

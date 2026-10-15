class_name LookSala
extends Node3D
## Look della sala principale (capitolo 1): luci, illuminazione globale, sonde di
## riflessione, nebbia, lampi e particelle. Si attacca al Node3D che contiene le
## istanze dei GLB della sala (tutte in 0,0,0), AL POSTO di sala_luci_ambiente.gd.
## Le luci arrivano da sala_luci.glb e vengono riconosciute dal nome.
## L'Environment e gli attributi della camera sono risorse .tres riutilizzabili
## (grafica/sala/), ritoccabili nell'editor.

@export var ambiente: Environment = preload("res://grafica/sala/ambiente_sala.tres")
@export var attributi_camera: CameraAttributesPractical = preload("res://grafica/sala/attributi_camera_sala.tres")
@export_group("Luci")
@export var energia_emergenza := 7.0
@export var portata_emergenza := 9.0
@export var energia_neon := 2.6
@export var energia_lampione := 3.5
@export var energia_luna := 0.6
## Luci del monumento: faretti bassi (0,6) come provato dall'integratore; fari a 5,5 e lampione
## a 3,5 perché il busto in vinile lucido resti leggibile senza bruciarsi.
@export var energia_fari := 5.5
@export var energia_faretti := 0.6
@export var energia_plafoniere := 1.8
@export var energia_insegne := 1.3
@export var colore_emergenza := Color(1.0, 0.035, 0.02)
@export var colore_neon := Color(0.78, 1.0, 0.9)        # fluorescente freddo, verso il verde
@export var colore_lampione := Color(1.0, 0.66, 0.36)   # sodio caldo: il contrasto caldo della sala
@export_group("Parti da creare")
@export var crea_gi := true
@export var crea_sonde := true
@export var crea_tempesta := true
@export var crea_effetti := true
## Neon che nel GLB sono "a metà": sfarfallano o sono guasti.
@export var neon_difettosi: PackedInt32Array = [1, 3, 4, 6, 7, 11, 13, 14, 17, 24, 25]

@export_group("Volume della sala")
## Centro e dimensioni della sala in coordinate Godot (da sala_dati.json: x -20..20,
## z -24..20, pavimento 0, soffitto 11,5, cupola fino a ~17). Usati da VoxelGI,
## sonde di riflessione, nebbia bassa e pulviscolo.
@export var sala_centro := Vector3(0, 7.5, -2.0)
@export var sala_dimensioni := Vector3(41, 21, 45)
@export_group("Statua sul monumento")
## Centro del monumento e altezza della statua (per il controluce).
@export var monumento := Vector3(0, 0, 10)
@export var altezza_statua := 4.5
@export var crea_controluce := true
## Se impostato, il vetro della cupola si accende con i lampi (es. un ShaderMaterial
## con vetro_cupola.gdshader, assegnato anche ai vetri della cupola).
@export var vetro_cupola: ShaderMaterial

var tempesta: Tempesta
var _sfarfallanti: Array = []   # [luce, energia, modalità, attesa, raffica]


func _ready() -> void:
	_imposta_ambiente()
	_regola_luci(self)
	if crea_gi:
		_crea_voxel_gi()
	if crea_sonde:
		_crea_sonde()
	if crea_tempesta:
		tempesta = Tempesta.new()
		tempesta.name = "Tempesta"
		tempesta.energia_lampo = 7.0
		if vetro_cupola:
			tempesta.materiali = [vetro_cupola]
		add_child(tempesta)
		tempesta.luce.light_angular_distance = 0.2  # ombre dei costoloni nitide anche col lampo
	if crea_effetti:
		_crea_effetti()
	if crea_controluce:
		_crea_controluce()


## Controluce freddo dall'alto, dietro la statua: stacca la sagoma dal fondo buio
## quando si entra dal vano sud.
func _crea_controluce() -> void:
	var c := SpotLight3D.new()
	c.name = "ControluceStatua"
	c.light_color = Color(0.62, 0.78, 1.0)
	c.light_energy = 5.0
	c.spot_range = 14.0
	c.spot_angle = 16.0
	c.spot_angle_attenuation = 1.4
	c.light_specular = 0.6
	c.light_volumetric_fog_energy = 0.5
	c.shadow_enabled = false
	add_child(c)
	var cima := monumento + Vector3(0, 1.15 + altezza_statua * 0.7, 0)
	c.look_at_from_position(monumento + Vector3(0, 9.6, -4.2), cima)


func _imposta_ambiente() -> void:
	var we: WorldEnvironment = null
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		we = n
	if we == null:
		we = WorldEnvironment.new()
		we.name = "AmbienteSala"
		add_child(we)
	we.environment = ambiente
	we.camera_attributes = attributi_camera


func _regola_luci(n: Node) -> void:
	var nome := String(n.name)
	if n is Light3D:
		var l := n as Light3D
		l.light_volumetric_fog_energy = 1.0
		if nome.begins_with("luce_emergenza"):
			var o := l as OmniLight3D
			o.light_color = colore_emergenza
			o.light_energy = energia_emergenza
			o.omni_range = portata_emergenza
			o.omni_attenuation = 1.3
			o.light_volumetric_fog_energy = 2.5
			o.light_specular = 0.7
			# Ombre solo su alcune (costano: sono omnidirezionali).
			var k := nome.get_slice("_", 2).to_int()
			o.shadow_enabled = k % 3 == 0
			o.shadow_bias = 0.08
			o.set_meta("grafica_priorita_ombra", 2)
			if k % 5 == 1:
				_sfarfallanti.append([o, o.light_energy, "pulsa", 0.0, 0.0])
		elif nome.begins_with("luce_neon"):
			l.light_color = colore_neon
			l.light_energy = energia_neon
			l.light_volumetric_fog_energy = 0.8
			l.shadow_enabled = false
			if l is SpotLight3D:
				var s := l as SpotLight3D
				s.spot_range = 10.0
				s.spot_angle = 75.0
				s.spot_angle_attenuation = 0.5
				s.spot_attenuation = 0.9
			elif l is OmniLight3D:
				(l as OmniLight3D).omni_range = 9.0
			var k := nome.get_slice("_", 2).to_int()
			if k in neon_difettosi:
				var modo: String = ["guasto", "sfarfalla", "morente"][k % 3]
				_sfarfallanti.append([l, l.light_energy, modo, randf_range(0.5, 4.0), 0.0])
		elif nome.begins_with("luce_faro"):
			# Luce principale della statua: dall'alto e davanti (fari sulla ringhiera sud).
			var s := l as SpotLight3D
			s.light_color = Color(1.0, 0.9, 0.8)
			s.light_energy = energia_fari
			s.spot_range = 16.0
			s.spot_angle = 13.0
			s.spot_angle_attenuation = 1.6   # bordo morbido
			s.spot_attenuation = 0.6
			s.shadow_enabled = true
			s.light_size = 0.06
			s.light_specular = 0.45           # niente riflessi bruciati sul vinile lucido
			s.light_volumetric_fog_energy = 1.6
			s.set_meta("grafica_priorita_ombra", 1)
		elif nome.begins_with("luce_monumento_basso"):
			# Faretti caldi dal basso: ombre in su sul viso, effetto "monumento di notte".
			var s := l as SpotLight3D
			s.light_color = Color(1.0, 0.7, 0.42)
			s.light_energy = energia_faretti
			s.spot_range = 7.0
			s.spot_angle = 24.0
			s.spot_angle_attenuation = 1.2
			s.spot_attenuation = 1.2
			s.light_specular = 0.3
			s.light_volumetric_fog_energy = 0.6
			# Ombre solo sui due davanti (verso la porta, +Z): il viso proietta le ombre in alto.
			var k := nome.get_slice("_", 3).to_int()
			s.shadow_enabled = k >= 2
			s.shadow_bias = 0.03
			s.set_meta("grafica_priorita_ombra", 2)
		elif nome == "luce_lampione":
			var s := l as SpotLight3D
			s.light_color = colore_lampione
			s.light_energy = energia_lampione
			s.light_specular = 0.5
			s.spot_range = 11.0
			s.spot_angle = 50.0
			s.spot_angle_attenuation = 0.8
			s.shadow_enabled = true
			s.light_size = 0.12
			s.light_volumetric_fog_energy = 3.0   # il cono si vede nella nebbia
			s.set_meta("grafica_priorita_ombra", 1)
			_sfarfallanti.append([s, s.light_energy, "guasto", 3.0, 0.0])
		elif nome.begins_with("luce_subacquea"):
			var o := l as OmniLight3D
			o.light_energy = 3.0
			o.omni_range = 6.0
			o.light_volumetric_fog_energy = 1.5
		elif nome.begins_with("luce_insegna"):
			# Insegne al neon colorate (rosa, onda, stella): pozze di colore saturo, stile B.
			var o := l as OmniLight3D
			o.light_energy = energia_insegne * (2.0 if nome == "luce_insegna_rosa" else 1.0)
			o.omni_range = 5.5 if nome != "luce_insegna_rosa" else 8.0
			o.light_volumetric_fog_energy = 2.0
		elif nome.begins_with("luce_calda"):
			# Plafoniere navali a incandescenza: le poche luci calde per il contrasto col rosso e il blu.
			var o := l as OmniLight3D
			o.light_color = Color(1.0, 0.66, 0.36)
			o.light_energy = energia_plafoniere
			o.omni_range = 7.5
			o.omni_attenuation = 1.2
			o.light_volumetric_fog_energy = 1.4
			o.shadow_enabled = false
		elif nome == "luce_area_bimbi":
			var o := l as OmniLight3D
			o.light_color = Color(1.0, 0.74, 0.42)
			o.light_energy = 4.0
			o.omni_range = 10.0
			o.shadow_enabled = true
			o.light_volumetric_fog_energy = 1.5
		elif l is DirectionalLight3D:
			var d := l as DirectionalLight3D
			d.light_color = Color(0.55, 0.66, 1.0)
			d.light_energy = energia_luna
			d.shadow_enabled = true
			d.light_angular_distance = 0.0  # con 0,6° i costoloni sottili spariscono dal pavimento
			d.light_volumetric_fog_energy = 0.35
			d.shadow_bias = 0.05
	for c in n.get_children():
		_regola_luci(c)


func _process(delta: float) -> void:
	for s in _sfarfallanti:
		var l: Light3D = s[0]
		var base: float = s[1]
		match s[2]:
			"pulsa":
				var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0035 + base)
				l.light_energy = base * lerpf(0.25, 1.0, p * p)
				continue
		s[3] -= delta
		if s[4] > 0.0:   # raffica in corso
			s[4] -= delta
			l.visible = randf() > 0.5
			if s[4] <= 0.0:
				l.visible = s[2] != "morente" or randf() < 0.3
			continue
		if s[3] <= 0.0:
			match s[2]:
				"guasto":
					s[4] = randf_range(0.08, 0.35)
					s[3] = randf_range(3.0, 10.0)
				"sfarfalla":
					s[4] = randf_range(0.3, 1.4)
					s[3] = randf_range(1.0, 4.0)
				"morente":
					s[4] = randf_range(0.2, 0.8)
					s[3] = randf_range(1.5, 5.0)


func _crea_voxel_gi() -> void:
	var gi := VoxelGI.new()
	gi.name = "VoxelGI_Sala"
	gi.size = sala_dimensioni
	gi.position = sala_centro
	gi.subdiv = VoxelGI.SUBDIV_256
	add_child(gi)


func _crea_sonde() -> void:
	var sala := ReflectionProbe.new()
	sala.name = "Sonda_Sala"
	sala.size = Vector3(sala_dimensioni.x - 1.0, 13, sala_dimensioni.z - 1.0)
	sala.position = Vector3(sala_centro.x, 4.0, sala_centro.z)
	sala.origin_offset = Vector3(0, -2.0, 0)
	sala.box_projection = true
	sala.interior = true
	sala.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	sala.max_distance = 60.0
	sala.intensity = 0.5   # piena, il riflesso uniforme del soffitto copriva le ombre sul pavimento
	add_child(sala)
	var vasca := ReflectionProbe.new()
	vasca.name = "Sonda_Piscina"
	vasca.size = Vector3(14.5, 4.0, 18.5)
	vasca.position = Vector3(0, 0.0, 4.0)
	vasca.origin_offset = Vector3(0, -0.8, 0)
	vasca.box_projection = true
	vasca.interior = true
	vasca.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	vasca.blend_distance = 0.5
	add_child(vasca)


func _crea_effetti() -> void:
	# Nebbia bassa sul pavimento e nella piscina vuota.
	var nebbia := FogVolume.new()
	nebbia.name = "NebbiaBassa"
	nebbia.size = Vector3(sala_dimensioni.x - 1.0, 2.6, sala_dimensioni.z - 1.0)
	nebbia.position = Vector3(sala_centro.x, -1.0, sala_centro.z)
	var fm := FogMaterial.new()
	fm.density = 0.018
	fm.height_falloff = 2.5
	fm.edge_fade = 0.15
	fm.albedo = Color(0.78, 0.84, 0.86)
	var rumore := FastNoiseLite.new()
	rumore.frequency = 0.06
	var n3 := NoiseTexture3D.new()
	n3.noise = rumore
	n3.width = 48
	n3.height = 16
	n3.depth = 48
	n3.seamless = true
	fm.density_texture = n3
	nebbia.material = fm
	add_child(nebbia)
	var polvere := Pulviscolo.new()
	polvere.volume = Vector3(sala_dimensioni.x - 3.0, 9, sala_dimensioni.z - 3.0)
	polvere.densita = 0.5
	polvere.position = Vector3(sala_centro.x, 4.5, sala_centro.z)
	add_child(polvere)
	for p in [Vector3(6.5, 11.4, -3.0), Vector3(-9.0, 11.4, 4.5), Vector3(1.2, 11.4, 6.0), Vector3(14.0, 11.4, -9.0)]:
		var g := Gocce.new()
		g.position = p
		var sopra_piscina: bool = absf(p.x) < 7.0 and p.z > -13.0 and p.z < 5.0
		g.altezza = p.y + (2.0 if sopra_piscina else 0.0)
		add_child(g)

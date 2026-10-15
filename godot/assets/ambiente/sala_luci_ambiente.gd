extends Node3D
## Da attaccare al Node3D che contiene le istanze dei GLB della sala (tutte in 0,0,0).
## Regola le luci importate da sala_luci.glb (le unità glTF non coincidono con Godot),
## fa sfarfallare i neon a metà e, se manca, crea un WorldEnvironment notturno con nebbia.
## Valori provati in Godot 4.7.2 (Forward+). Si possono cambiare dall'ispettore.

@export var energia_emergenza := 3.0
@export var energia_neon := 2.5
@export var energia_lampione := 10.0
@export var energia_luna := 0.35
@export var energia_fari := 9.0
@export var energia_faretti_bassi := 2.5
@export var crea_ambiente := true
@export var neon_che_sfarfallano := 4

var _sfarfallio: Array[Light3D] = []
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	_rnd.randomize()
	_regola(self)
	if crea_ambiente and get_tree().root.find_children("*", "WorldEnvironment", true, false).is_empty():
		add_child(_ambiente())


func _regola(n: Node) -> void:
	if n is OmniLight3D:
		var o := n as OmniLight3D
		o.shadow_enabled = false
		if o.name.begins_with("luce_emergenza"):
			o.light_energy = energia_emergenza
			o.omni_range = 8.0
		elif o.name.begins_with("luce_subacquea"):
			o.light_energy = 3.0
			o.omni_range = 5.0
		else:
			o.light_energy = 2.0
			o.omni_range = 9.0
	elif n is SpotLight3D:
		var s := n as SpotLight3D
		if s.name.begins_with("luce_faro"):
			# fari sulla ringhiera della galleria sud: illuminano la statua come un monumento
			s.light_energy = energia_fari
			s.spot_range = 16.0
			s.spot_angle = 13.0
			s.spot_angle_attenuation = 0.6
			s.shadow_enabled = true
		elif s.name.begins_with("luce_monumento_basso"):
			# faretti incassati nel gradino: la statua dal basso
			s.light_energy = energia_faretti_bassi
			s.spot_range = 6.5
			s.spot_angle = 26.0
			s.shadow_enabled = false
		elif s.name == "luce_lampione":
			s.light_energy = energia_lampione
			s.spot_range = 9.0
			s.spot_angle = 55.0
			s.shadow_enabled = true
		else:
			s.light_energy = energia_neon
			s.spot_range = 7.0
			s.spot_angle = 70.0
			s.shadow_enabled = false
			if _sfarfallio.size() < neon_che_sfarfallano and _rnd.randf() < 0.3:
				_sfarfallio.append(s)
	elif n is DirectionalLight3D:
		var d := n as DirectionalLight3D
		d.light_energy = energia_luna
		d.shadow_enabled = true
	for c in n.get_children():
		_regola(c)


func _process(_delta: float) -> void:
	for l in _sfarfallio:
		if _rnd.randf() < 0.08:
			l.visible = _rnd.randf() > 0.35


func _ambiente() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.4)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.6, 0.66, 0.72)
	var we := WorldEnvironment.new()
	we.environment = env
	return we

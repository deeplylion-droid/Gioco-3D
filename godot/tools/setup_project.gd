extends SceneTree
## Imposta project.godot con le API di Godot, così il formato (soprattutto la mappa degli input)
## è esatto. Uso: godot --headless --path godot --script res://tools/setup_project.gd

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e

func _mouse(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e

func _action(name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + name, {"deadzone": 0.2, "events": events})

func _init() -> void:
	var s := ProjectSettings
	s.set_setting("application/config/name", "Splash Lagoon")
	s.set_setting("application/config/description", "Horror in prima persona (mascot horror) sull'acquapark di una nave da crociera abbandonata. Titolo provvisorio.")
	s.set_setting("application/config/version", "0.3.0")
	s.set_setting("application/run/main_scene", "res://scenes/ui/menu_principale.tscn")
	s.set_setting("application/config/icon", "res://icon.svg")
	s.set_setting("application/boot_splash/bg_color", Color(0, 0, 0, 1))
	s.set_setting("application/boot_splash/show_image", false)
	# Autoload: prima la grafica (impostazioni, preset, post-processing), poi il gioco.
	for a in ["Grafica", "Game", "GameState", "Audio"]:
		if s.has_setting("autoload/" + a):
			s.clear("autoload/" + a)
	if s.has_setting("autoload/WaterManager"):
		s.clear("autoload/WaterManager")
	s.set_setting("autoload/Grafica", "*res://addons/grafica/impostazioni_grafiche.gd")
	s.set_setting("autoload/WaterManager", "*res://addons/acqua/scripts/water_manager.gd")
	s.set_setting("autoload/Game", "*res://scripts/game/game.gd")
	s.set_setting("autoload/GameState", "*res://scripts/game/game_state.gd")
	s.set_setting("autoload/Audio", "*res://addons/audio/audio.gd")
	# Variabili globali degli shader dell'acqua (le registra anche l'autoload: qui servono
	# all'editor, vedi addons/acqua/shader_globals.txt).
	var globali := {
		"water_time": {"type": "float", "value": 0.0},
		"water_body_count": {"type": "int", "value": 0},
		"water_bodies_tex": {"type": "sampler2D", "value": ""},
		"water_caustics_tex": {"type": "sampler3D", "value": "res://addons/acqua/textures/caustics_3d.png"},
		"water_noise_tex": {"type": "sampler2D", "value": "res://addons/acqua/textures/noise_rgba.png"},
		"water_ripple_tex": {"type": "sampler2D", "value": ""},
		"water_ripple_rect": {"type": "vec4", "value": Vector4(0, 0, 0, 0)},
		"water_drops_tex": {"type": "sampler2D", "value": ""},
		"water_drop_count": {"type": "int", "value": 0},
		"water_quality": {"type": "int", "value": 2},
		"water_glow_tex": {"type": "sampler2D", "value": ""},
		"water_glow_count": {"type": "int", "value": 0},
	}
	for k in globali:
		s.set_setting("shader_globals/" + k, globali[k])

	# Finestra: 1280x720 di base, l'interfaccia scala con la finestra.
	s.set_setting("display/window/size/viewport_width", 1280)
	s.set_setting("display/window/size/viewport_height", 720)
	s.set_setting("display/window/stretch/mode", "canvas_items")
	s.set_setting("display/window/stretch/aspect", "expand")

	# Fisica: Jolt, 60 tick, interpolazione per movimenti fluidi anche oltre i 60 Hz.
	s.set_setting("physics/3d/physics_engine", "Jolt Physics")
	s.set_setting("physics/common/physics_ticks_per_second", 60)
	s.set_setting("physics/common/physics_interpolation", true)

	# Rendering (Forward+): MSAA 4x + SMAA, debanding (nebbia scura), anisotropico 16x.
	s.set_setting("rendering/renderer/rendering_method", "forward_plus")
	s.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2)
	s.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 2)
	s.set_setting("rendering/anti_aliasing/quality/use_debanding", true)
	s.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 4)
	s.set_setting("rendering/environment/defaults/default_clear_color", Color(0.02, 0.02, 0.025, 1))
	s.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 3)
	s.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 3)
	# Consigliate dall'addon grafica (il resto lo imposta il preset a runtime).
	s.set_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
	s.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 4096)
	s.set_setting("rendering/environment/volumetric_fog/use_filter", 1)
	s.set_setting("rendering/global_illumination/voxel_gi/quality", 0)

	# Nomi dei livelli fisici (devono coincidere con scripts/game/layers.gd).
	var fisici := ["mondo", "giocatore", "nemici", "oggetti", "interazione", "bersagli_acqua", "volumi_acqua", "scale"]
	for i in fisici.size():
		s.set_setting("layer_names/3d_physics/layer_%d" % (i + 1), fisici[i])
	s.set_setting("layer_names/3d_render/layer_1", "mondo")
	s.set_setting("layer_names/3d_render/layer_2", "viewmodel")

	# Mappa degli input (tasti fisici: funzionano anche con tastiere non QWERTY).
	_action("move_forward", [_key(KEY_W)])
	_action("move_back", [_key(KEY_S)])
	_action("move_left", [_key(KEY_A)])
	_action("move_right", [_key(KEY_D)])
	_action("sprint", [_key(KEY_SHIFT)])
	_action("crouch", [_key(KEY_CTRL)])
	_action("jump", [_key(KEY_SPACE)])
	_action("interact", [_key(KEY_E)])
	_action("spray", [_mouse(MOUSE_BUTTON_LEFT)])
	_action("suck", [_mouse(MOUSE_BUTTON_RIGHT)])
	_action("skip", [_key(KEY_SPACE), _key(KEY_E), _key(KEY_ENTER)])
	if s.has_setting("input/flashlight"):
		s.clear("input/flashlight")
	if s.has_setting("input/torcia"):
		s.clear("input/torcia")  # la torcia non c'è più (18 ottobre)
	# Esc mette in pausa (Game); il menu delle opzioni si apre dalla pausa.
	_action("menu_opzioni", [])
	_action("pause", [_key(KEY_ESCAPE)])

	var err := s.save()
	print("salvato: ", err)
	quit(err)

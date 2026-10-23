extends SceneTree
## Prova del filtro VHS dello spot (shaders/spot/vhs.gdshader) su un'immagine vera del gioco, sullo schermo (1280x720).
## Uso: godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/spot/prova_vhs.gd -- \
##     <immagine> <cartella> [video]
## Senza "video" salva gli scatti delle prove (normale, PLAY sul blu, guasto a metà e pieno); con "video" fa andare il
## guasto da 0 a 1 in 8 s, da registrare col Movie Maker (--write-movie <file>.avi --fixed-fps 30).

const PROVE := [
	["normale", {"guasto": 0.0}],
	["blu_play", {"schermo_blu": 1.0, "play": 1.0}],
	["play", {"play": 1.0}],
	["guasto_mezzo", {"guasto": 0.5}],
	["guasto_pieno", {"guasto": 1.0}],
]

var mat: ShaderMaterial
var video := false
var t0 := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(1280, 720)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/spot/vhs.gdshader")
	tr.material = mat
	root.add_child(tr)
	video = a.size() > 2 and a[2] == "video"
	if video:
		process_frame.connect(_passo)
	else:
		_scatti.call_deferred(a[1])


func _passo() -> void:
	t0 += 1.0 / 30.0
	# 0-1,5 s il blu col PLAY, poi l'immagine pulita, dal 4° secondo il guasto sale fino a 1 all'8°
	mat.set_shader_parameter(&"schermo_blu", 1.0 if t0 < 1.5 else 0.0)
	mat.set_shader_parameter(&"play", 1.0 if t0 < 3.5 else 0.0)
	mat.set_shader_parameter(&"guasto", clampf((t0 - 4.0) / 4.0, 0.0, 1.0))


func _scatti(cartella: String) -> void:
	DirAccess.make_dir_recursive_absolute(cartella)
	for p in PROVE:
		for k in ["guasto", "schermo_blu", "play"]:
			mat.set_shader_parameter(k, 0.0)
		for k in p[1]:
			mat.set_shader_parameter(k, p[1][k])
		for i in 8:
			await process_frame
		var im := root.get_texture().get_image()
		im.save_jpg(cartella.path_join(p[0] + ".jpg"), 0.9)
		print("salvato ", p[0])
	quit()

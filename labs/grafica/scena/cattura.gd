extends Node
## Regia per screenshot e video senza schermo. Si attiva con argomenti dopo "--":
##   --preset=ultra  --inq=sala  --torcia=0  --buio=1  --lampo=40  --frames=60
##   --out=../../docs/report/render_grafica/x.jpg  --menu=2  --calibrazione=1
##   --set=ombre:0,gi:2  --seme=3  --tempesta=0  --video=1
## Con --video=1 non salva niente: si usa con --write-movie e chiude dopo --frames.

const INQUADRATURE := {
	# posizione occhi, yaw, pitch (gradi)
	"sala": [Vector3(9.5, 1.65, 11.0), 38.0, 10.0],
	"piscina": [Vector3(-8.5, 1.65, 6.5), -62.0, -8.0],
	"cupola": [Vector3(-2.0, 1.65, 9.0), 10.0, 48.0],
	"piedistallo": [Vector3(4.2, 1.65, -3.0), 32.0, 12.0],
	"corridoio": [Vector3(18.8, 1.65, 0.6), -90.0, 1.0],
	"buio": [Vector3(-11.0, 1.65, 6.0), -150.0, -4.0],
	"buio_statua": [Vector3(1.6, 1.65, -5.0), 10.0, 14.0],
	"nebbia": [Vector3(12.0, 1.65, 9.0), 55.0, 6.0],
}

var _arg := {}
var _frame := 0
var _frames := 60
var _scena: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_arg[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_scena = get_parent()
	seed(int(_arg.get("seme", "7")))
	_frames = int(_arg.get("frames", "60"))
	if _arg.has("preset"):
		Grafica.applica_preset(_arg["preset"])
	if _arg.has("set"):
		for coppia in String(_arg["set"]).split(","):
			var kv := coppia.split(":")
			var v: Variant = str_to_var(kv[1])
			Grafica.imposta(kv[0], v)
	var t: Tempesta = _scena.tempesta
	t.automatica = _arg.get("tempesta", "0") == "1"
	var inq: Array = INQUADRATURE.get(_arg.get("inq", "sala"))
	_scena.giocatore.imposta_vista(inq[0], inq[1], inq[2])
	_scena.giocatore.set_physics_process(false)
	_scena.torcia.accesa = _arg.get("torcia", "0") == "1"
	if _arg.get("buio", "0") == "1":
		_scena.blackout(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	_frame += 1
	if _arg.has("lampo") and _frame == int(_arg["lampo"]):
		_scena.tempesta.lampo_ora(float(_arg.get("forza_lampo", "1.3")), 1.0,
			deg_to_rad(float(_arg["azimut"])) if _arg.has("azimut") else NAN)
	if _arg.has("disturbo") and _frame == 1:
		_scena.torcia.disturbo = float(_arg["disturbo"])
	if _arg.has("menu") and _frame == _frames - 6:
		var m: MenuOpzioni = _scena.apri_menu()
		m.mostra_scheda.call_deferred(int(_arg["menu"]))
	if _arg.has("calibrazione") and _frame == _frames - 6:
		var m: MenuOpzioni = _scena.apri_menu()
		m.apri_calibrazione()
	if _frame >= _frames:
		if _arg.get("video", "0") != "1":
			var img := get_viewport().get_texture().get_image()
			var out: String = _arg.get("out", "user://cattura.jpg")
			if out.ends_with(".png"):
				img.save_png(out)
			else:
				img.save_jpg(out, 0.92)
			print("salvato ", out)
		get_tree().quit()

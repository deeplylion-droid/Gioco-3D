extends "res://tests/collaudo/partita_tunnel.gd"
## Collaudo dell'inseguimento con cuore, ritmo ed effetti (canto-inseguimento e inseguimento-effetti): la partita intera
## del tunnel di partita_tunnel.gd, e intanto a ogni fotogramma:
## - i suoni: ogni battito del cuore (cuore_battito), colpo del ritmo (inseguimento_colpo) e frase del canto
##   (lei_tunnel_canto) quando parte, con il volume del lettore, il bus e la distanza di lei;
## - gli effetti (EffettiInseguimento): i bordi scuri, la luce rosa (accesa, energia, dove guarda), il tremito della camera;
## - le compilazioni di pipeline del fotogramma, con la fase di lei.
## Scrive <cartella>/suoni.csv e <cartella>/effetti.csv. Con NO_OSCILLAZIONE=1 l'oscillazione della camera è spenta
## (come nelle opzioni): il tremito non ci deve essere.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_effetti.gd <cartella>

const NOMI := [&"cuore_battito", &"inseguimento_colpo", &"lei_tunnel_canto"]
var _suoni: FileAccess
var _eff: FileAccess
var _conta := {}
var _effetti: Node
var _pip := 0
var _audio: Node
var _no_osc := false


func _ready() -> void:
	super._ready()
	_no_osc = OS.get_environment("NO_OSCILLAZIONE") == "1"
	_audio = get_node_or_null(^"/root/Audio")


func _process(_d: float) -> void:
	if cart == "" or sott == null or not is_instance_valid(sott):
		return
	if _suoni == null:
		_suoni = FileAccess.open(cart.path_join("suoni.csv"), FileAccess.WRITE)
		_suoni.store_line("t;suono;volume_db;bus;bus_db;gap;lei")
		_eff = FileAccess.open(cart.path_join("effetti.csv"), FileAccess.WRITE)
		_eff.store_line("t;lei;gap;bordi_forza;bordi_alfa;luce_forza;luce_visibile;luce_energia;luce_dist_giocatore;tremito_gradi;pipeline;morsi;prese")
	if _no_osc and p and is_instance_valid(p):
		p.head_bob_enabled = false
	var gap := -1.0
	var stato := "-"
	if sott:
		stato = String(SalaSottomarino.Lei.keys()[sott.lei_stato])
		gap = float(sott._s_bersaglio - sott.lei_s) if sott.lei_tunnel else -1.0
	# i suoni partiti in questo fotogramma
	var conteggio = _audio.get(&"conteggio") if _audio else null
	if conteggio is Dictionary:
		for nome in NOMI:
			var c := int(conteggio.get(nome, 0))
			if c > int(_conta.get(nome, 0)):
				for k in c - int(_conta.get(nome, 0)):
					var pl := _lettore(nome)
					var vol := float(pl.get(&"volume_db")) if pl else 0.0
					var bus := String(pl.get(&"bus")) if pl else "-"
					var bi := AudioServer.get_bus_index(bus)
					_suoni.store_line("%.3f;%s;%.1f;%s;%.1f;%.2f;%s" % [_t(), nome, vol, bus, AudioServer.get_bus_volume_db(bi) if bi >= 0 else 0.0, gap, stato])
				_conta[nome] = c
	# gli effetti
	if _effetti == null or not is_instance_valid(_effetti):
		_effetti = null
		for n in sott.find_children("*", "", true, false):
			if n.get_script() and String((n.get_script() as Script).resource_path).ends_with("effetti_inseguimento.gd"):
				_effetti = n
				break
	var pip := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE))
	var nuove := pip - _pip
	_pip = pip
	var tr := 0.0
	if p and is_instance_valid(p) and p.camera:
		tr = rad_to_deg(p.camera.rotation.length())
	if _effetti:
		var luce: SpotLight3D = _effetti.get(&"luce")
		var bordi: Control = _effetti.get(&"bordi")
		var dl := -1.0
		if luce and p and is_instance_valid(p):
			dl = luce.global_position.distance_to(p.global_position)
		_eff.store_line("%.3f;%s;%.2f;%.3f;%.3f;%.3f;%s;%.1f;%.1f;%.3f;%d;%d;%d" % [_t(), stato, gap, float(_effetti.get(&"forza_bordi")),
			bordi.modulate.a if bordi and bordi.visible else 0.0, float(_effetti.get(&"forza_luce")), luce.visible if luce else false,
			luce.light_energy if luce else 0.0, dl, tr, nuove, morsi, prese])


## Il lettore partito per ultimo con il suono [param nome] (quello appena avviato).
func _lettore(nome: StringName) -> Node:
	var stream = _audio.call(&"stream_di", nome) if _audio.has_method(&"stream_di") else null
	var migliore: Node = null
	var pos := 99.0
	for n in _audio.find_children("*", "", true, false):
		if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.get(&"stream") == stream and n.get(&"playing"):
			var q := float(n.call(&"get_playback_position"))
			if q < pos:
				pos = q
				migliore = n
	return migliore

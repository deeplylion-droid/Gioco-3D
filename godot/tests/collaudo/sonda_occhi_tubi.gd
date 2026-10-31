extends Node
## Sonda (non in CI): il giocatore vero scivola in ogni tubo dell'inseguimento fino alla vasca d'arrivo; a ogni
## fotogramma l'altezza dell'occhio (la camera) rispetto al pelo dell'acqua sotto di lui. Stampa il minimo per tubo:
## sotto zero, da lì si vedrebbe l'acqua da sotto (correzioni della 0.3.17).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_occhi_tubi.gd [tubi]

const PLAYER := "res://scenes/player/player.tscn"
## tubo: [indice da cui partire, pelo d'arrivo (coordinate di Blender: z)]
var TUBI := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	add_child(torre)
	for i in 20:
		await get_tree().physics_frame
	var ins := torre.inseguimento as SalaInseguimento
	var d := ins.dati
	var arrivi := {"ins_A_tubo_0": d["vasche"][0], "ins_A_tubo_1": d["vasche"][1], "ins_A_tubo_2": d["vasche"][2],
		"ins_A_tubo_3": d["bacino"], "ins_A_scolo_0": d["scolo"][0], "ins_A_scolo_1": d["scolo"][1], "ins_A_scolo_2": d["scolo"][2]}
	var solo := OS.get_cmdline_user_args().slice(1)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	for i in 5:
		await get_tree().physics_frame
	var peggio := 0.0
	for nome in arrivi:
		if not solo.is_empty() and not solo.has(nome):
			continue
		if ins.lei:
			ins.lei.visible = false
		var linea := PackedVector3Array()
		for q in d["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var pelo := float(arrivi[nome]["acqua"])
		var da := maxi(0, linea.size() - 14)
		p.teleport(linea[da] + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1))
		await get_tree().physics_frame
		p.velocity = (linea[da + 2] - linea[da]).normalized() * 4.0
		Input.action_press(&"move_forward")
		var minimo := INF
		var dove := Vector3.ZERO
		for f in 60 * 6:
			await get_tree().physics_frame
			var occhi := p.get_viewport().get_camera_3d().global_position
			# solo sopra l'acqua d'arrivo (nel tubo, prima, l'acqua non c'è)
			var r: Array = arrivi[nome]["rett"]
			var bx := Vector2(occhi.x, -occhi.z)
			if bx.x > r[0] and bx.x < r[2] and bx.y > r[1] and bx.y < r[3]:
				if occhi.y - pelo < minimo:
					minimo = occhi.y - pelo
					dove = occhi
		Input.action_release(&"move_forward")
		print("OCCHI %s: minimo %.3f m sopra il pelo (%.2f), a %s" % [nome, minimo, pelo, dove])
		if nome.begins_with("ins_A_tubo"):
			peggio = minf(peggio, minimo)
	print("RISULTATO: occhio sotto il pelo nei tubi giusti: %s (peggio %.3f)" % ["sì" if peggio < 0.0 else "no", peggio])
	get_tree().quit()

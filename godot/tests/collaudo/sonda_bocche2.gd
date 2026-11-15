extends Node
## Collaudo dei ritocchi di ambienti-2: come sonda_bocche, ma la parete d'acqua di ogni bocca scelta per coordinate
## locali (quella che ha l'inizio del tubo a |x| < 1,2 e z vicino a 0), e a ogni fotogramma una riga in un file:
## quanto dentro (l.z dalla parete, m), piedi, l'occhio naturale (piedi + altezza occhi, senza il limite), il limite,
## la camera, il soffitto del tubo lì (centro della linea più vicina + R_TUBO), tutti rispetto al pelo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_bocche2.gd <file.tsv>

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.luci = GameState.Luci.BLACKOUT
	var out := FileAccess.open(OS.get_cmdline_user_args()[1], FileAccess.READ_WRITE if FileAccess.file_exists(OS.get_cmdline_user_args()[1]) else FileAccess.WRITE)
	out.seek_end()
	out.store_line("bocca\tmodo\tf\tlz\tpiedi\tocchio_nat\tlimite\tcamera\tsoffitto\talzata")
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _frames(20)
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	await _frames(240)
	var veli := ins.find_children(SalaInseguimento.NOME_VELO + "*", "MeshInstance3D", true, false)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	var args := OS.get_cmdline_user_args()
	var bocche := ["ins_A_tubo_1", "ins_A_scolo_0", "ins_A_tubo_2", "ins_A_scolo_1", "ins_A_tubo_3", "ins_A_scolo_2"]
	if args.size() > 2:
		bocche = Array(args[2].split(","))
	var modi := ["entra", "torna"]
	if args.size() > 3:
		modi = Array(args[3].split(","))
	for nome: String in bocche:
		if ins.lei:
			ins.lei.visible = false
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var velo: MeshInstance3D = null
		var meglio := INF
		for v in veli:
			var l := (v as Node3D).global_transform.affine_inverse() * linea[0]
			var l3 := (v as Node3D).global_transform.affine_inverse() * linea[3]
			if absf(l.x) < 1.2 and l3.z > l.z and absf(l.z) < meglio:
				meglio = absf(l.z)
				velo = v
		if velo == null:
			print("BOCCA2: %s: nessuna parete d'acqua" % nome)
			continue
		var pelo := float(velo.get_meta(&"pelo"))
		print("BOCCA2: %s: parete %s, inizio linea a l.z %.2f, pelo %.2f" % [nome, velo.name, meglio, pelo])
		for modo in modi:
			var dir := linea[3] - linea[0]
			dir.y = 0.0
			dir = dir.normalized()
			p.teleport(linea[0] - dir * 2.0 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1) + Vector3.UP * 0.5)
			await _frames(20)
			p.velocity = Vector3.ZERO
			Input.action_press(&"crouch")
			await _frames(20)
			Input.action_press(&"move_forward")
			var ultimo := 0
			var indietro := false
			var t_ind := 0
			var cy_prec := []
			var max_salto := 0.0
			var dove_salto := 0.0
			var min_sotto_soff := INF
			var dove_soff := 0.0
			var min_filo := INF
			var dove_filo := 0.0
			var max_alzata := 0.0
			var sotto_davanti := 0
			var min_lz_sotto := INF
			var altro_pelo := 0
			var passaggi := []
			var min_sopra := INF
			var dove_sopra := 0.0
			var lz_min_torna := INF
			for f in 60 * 14:
				var piedi := p.global_position
				var iv := ultimo
				for i in range(ultimo, mini(ultimo + 12, linea.size())):
					if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
						iv = i
				ultimo = iv
				if not indietro:
					var g := linea[mini(iv + 4, linea.size() - 1)] - piedi
					g.y = 0.0
					if g.length() > 0.2:
						p.set_look(atan2(-g.x, -g.z), -0.15)
				else:
					p.set_look(atan2(dir.x, dir.z), -0.25)
				await get_tree().process_frame
				var cy := p.camera.global_position.y
				var lz := (velo.global_transform.affine_inverse() * p.camera.global_position).z
				var nat := p.global_position.y + float(p.get(&"_eye_height"))
				var soff := linea[iv].y + SalaInseguimento.R_TUBO
				# (dopo il ritocco 0fc590e9: sopra il pelo almeno occhi_sopra, sotto almeno occhi_sotto sotto)
				var lim := -INF
				if p.occhi_pelo > -1e9:
					lim = p.occhi_pelo + p.occhi_sopra if nat >= p.occhi_pelo else p.occhi_pelo - p.occhi_sotto
				if p.occhi_pelo > -1e9 and absf(p.occhi_pelo - pelo) > 0.001:
					altro_pelo += 1
				var dal_pelo := cy - pelo
				if lz > -0.6 and lz < 3.0:
					if absf(dal_pelo) < min_filo:
						min_filo = absf(dal_pelo)
						dove_filo = lz
					max_alzata = maxf(max_alzata, absf(p.occhi_alzati))
					if dal_pelo < 0.0 and lz < 0.05:
						sotto_davanti += 1
					if dal_pelo < 0.0 and lz < min_lz_sotto:
						min_lz_sotto = lz
					if cy_prec.size() >= 1 and (cy_prec[-1] - pelo) * dal_pelo < 0.0:
						passaggi.append("%.2f m (%s)" % [lz, "giù" if dal_pelo < 0.0 else "su"])
				if lz > -0.7 and lz < 3.3:
					out.store_line("%s\t%s\t%d\t%.3f\t%.3f\t%.3f\t%s\t%.3f\t%.3f\t%.3f" % [nome, modo, f, lz, piedi.y - pelo, nat - pelo,
							("%.3f" % (lim - pelo)) if lim > -1e9 else "-", cy - pelo, soff - pelo, p.occhi_alzati])
					if lz < 2.0 and cy - pelo < min_sopra:
						min_sopra = cy - pelo
						dove_sopra = lz
					if lz > 0.3 and soff - cy < min_sotto_soff:
						min_sotto_soff = soff - cy
						dove_soff = lz
				cy_prec.append(cy)
				if cy_prec.size() >= 2 and lz > -0.7 and lz < 3.3:
					var d := absf(cy_prec[-1] - cy_prec[-2])
					if d > max_salto:
						max_salto = d
						dove_salto = lz
				if indietro:
					lz_min_torna = minf(lz_min_torna, lz)
				if modo == "entra" and lz > 3.3:
					break
				if modo == "torna" and not indietro and lz > 1.2:
					indietro = true
					Input.action_release(&"move_forward")
					Input.action_press(&"move_back")
				if indietro:
					t_ind += 1
					if t_ind > 180:
						break
			Input.action_release(&"move_forward")
			Input.action_release(&"move_back")
			Input.action_release(&"crouch")
			print("BOCCA2: %s, %s: camera dal pelo al minimo %.3f m (a %.2f m); spostata dall'occhio naturale al massimo %.1f cm; passa il pelo a %s; sotto il pelo al più presto a %.2f m dentro, %d fotogrammi sotto il pelo dal lato della vasca (l.z < 0,05); %d fotogrammi con un altro pelo" % [
					nome, modo, min_filo, dove_filo, max_alzata * 100.0, ", ".join(passaggi), min_lz_sotto, sotto_davanti, altro_pelo])
			print("BOCCA2: %s, %s: morto %s, piedi a %s" % [nome, modo, GameState.is_dying, p.global_position.snapped(Vector3.ONE * 0.01)])
			print("BOCCA2: %s, %s: nei primi 2 m camera sopra il pelo al minimo %.3f (a %.2f m); passo più grande della camera in un fotogramma %.0f mm (a %.2f m); camera sotto il soffitto del tubo al minimo %.3f m (a %.2f m)%s" % [
					nome, modo, min_sopra, dove_sopra, max_salto * 1000.0, dove_salto, min_sotto_soff, dove_soff,
					("; tornando indietro arrivata a %.2f m" % lz_min_torna) if modo == "torna" else ""])
			await _frames(20)
	out.close()
	print("BOCCA2: finito")
	get_tree().quit()

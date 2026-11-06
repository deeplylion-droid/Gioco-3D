extends Node
## L'acqua non si vede mai da sotto (riscontri dell'utente sulla 0.3.16 e sulla 0.3.19: "si vede ancora sotto l'acqua
## nella zona delle vasche con gli scivoli"). Tutte le acque della torre e dell'inseguimento (le mesh acqua*: le vasche
## di raccolta e del fondo della torre, le vasche dei bivi, gli scoli, il bacino, il fondo allagato), col giocatore vero:
## 1. la profondità: l'occhio di chi sta accovacciato nel punto più basso (Player.crouch_eye_height meno l'abbassamento
##    dell'atterraggio e del passo) resta sopra il pelo più il piano vicino della camera;
## 2. in ogni acqua, accovacciati, atterrando da 1 m e camminando: l'occhio sempre sopra il pelo;
## 3. ogni tubo e ogni scolo, partendo nell'acqua della vasca da cui escono (le paratie aperte) e scivolando fino in
##    fondo: in nessun fotogramma l'occhio sta sotto il pelo di un'acqua che vede (da lì l'acqua si vedrebbe da sotto),
##    né a meno di [constant TUBI_SOPRA] sopra (ritocco del capitolo 1, scelta A dell'utente: prima passava a 1 mm;
##    lo tiene su SalaInseguimento.occhi_minimo).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_occhio_sopra_acque.gd

const PLAYER := "res://scenes/player/player.tscn"
## Quanto l'occhio deve stare sopra il pelo, oltre al piano vicino della camera (m).
const MARGINE := 0.02
## Nei tubi e negli scoli, quanto l'occhio resta almeno sopra il pelo delle acque che vede, oltre a quanto sopra (m).
const TUBI_SOPRA := 0.03
## Di quanto può cambiare in un fotogramma lo spostamento della camera nelle bocche (m): quando l'occhio scende sotto il
## pelo la camera passa da 3,5 cm sopra a 2 cm sotto, in un fotogramma, mentre si scivola giù (ricontrollo del collaudo:
## il limite di prima teneva la camera sopra il soffitto e la lasciava cadere di 65-96 cm).
const SALTO_MAX := 0.1

var _ok := 0
var _ko := 0
var p: Player
var acque := []
var near := 0.05
## Le pareti d'acqua nelle bocche dei tubi (SalaInseguimento._veli_bocche): coprono la superficie vista da sotto.
var veli: Array[MeshInstance3D] = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok   ", cosa)
	else:
		_ko += 1
		print("  KO   ", cosa)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	add_child(torre)
	for i in 20:
		await get_tree().physics_frame
	var ins := torre.inseguimento as SalaInseguimento
	# le paratie aperte (i bersagli verdi colpiti), lei che non prende e non si vede
	ins.tempo_presa = 9999.0
	# (e non sale dagli scoli: lì, nel gioco, prende chi ci cade)
	ins.set(&"_scolo", true)
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	for i in 240:
		await get_tree().physics_frame
	if ins.lei:
		ins.lei.visible = false
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	for i in 5:
		await get_tree().physics_frame
	near = p.camera.near
	for m in torre.find_children("acqua*", "MeshInstance3D", true, false):
		if String(m.name).begins_with(SalaInseguimento.NOME_VELO):
			continue
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		acque.append({"nome": String(mi.name), "pelo": box.end.y, "box": box})
	for v in ins.find_children(SalaInseguimento.NOME_VELO + "*", "MeshInstance3D", false, false):
		veli.append(v as MeshInstance3D)
	check(veli.size() == 6, "le pareti d'acqua nelle bocche dei 6 tubi che partono sotto il pelo (%d)" % veli.size())
	check(acque.size() >= 16, "le acque della torre e dell'inseguimento ci sono tutte (%d)" % acque.size())

	print("1. La profondità di ogni acqua")
	var basso := p.crouch_eye_height - p.land_dip_max - p.head_bob_vertical
	for a in acque:
		var prof := _profondita(a)
		check(basso - prof >= near + MARGINE, "%s: profonda %.2f m, l'occhio accovacciato più in basso %.2f m sopra il fondo: %.3f sopra il pelo (almeno %.2f)" % [
			a["nome"], prof, basso, basso - prof, near + MARGINE])

	print("2. Accovacciati in ogni acqua, atterrando da 1 m e camminando")
	for a in acque:
		var minimo := await _accovacciato(a)
		check(minimo >= near + MARGINE, "%s: l'occhio al più basso %.3f m sopra il pelo" % [a["nome"], minimo])

	print("3. Ogni tubo e scolo, dalla vasca di partenza fino in fondo")
	for nome: String in ins.dati["tubi"]:
		for indietro in [false, true]:
			var r: Dictionary = await _tubo(ins, nome, indietro)
			var tag := nome + (", tornando verso la vasca" if indietro else "")
			var peggio: Array = r["peggio"]
			check(peggio[0] >= TUBI_SOPRA or peggio[1] == "", "%s: l'occhio sempre almeno %.2f m sopra il pelo delle acque che vede (margine più piccolo %.3f m, %s)" % [
				tag, TUBI_SOPRA, peggio[0], peggio[1] if peggio[1] != "" else "nessuna"])
			check(r["soffitto"][0] >= near + 0.02, "%s: la camera sempre sotto il soffitto del tubo, piano vicino compreso (al più vicino %.3f m, %s)" % [
				tag, r["soffitto"][0], r["soffitto"][1]])
			check(r["salto"][0] <= SALTO_MAX, "%s: la camera spostata per l'acqua (Player.occhi_alzati) al più %.3f m, cambia al più di %.3f m in un fotogramma (al più %.2f, %s)" % [
				tag, r["alzata"], r["salto"][0], SALTO_MAX, r["salto"][1]])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## La profondità massima dell'acqua [param a]: dal pelo al fondo, su una griglia di raggi verso il basso.
func _profondita(a: Dictionary) -> float:
	var box: AABB = a["box"]
	var sp := p.get_world_3d().direct_space_state
	var prof := 0.0
	for i in 9:
		for j in 9:
			var x := lerpf(box.position.x + 0.3, box.end.x - 0.3, i / 8.0)
			var z := lerpf(box.position.z + 0.3, box.end.z - 0.3, j / 8.0)
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, a["pelo"] + 0.5, z), Vector3(x, a["pelo"] - 3.0, z), Layers.WORLD)
			q.exclude = [p.get_rid()]
			var r := sp.intersect_ray(q)
			# (più giù di 1,6 m è un pozzo, non un fondo dove si sta: lì si nuota)
			if not r.is_empty() and a["pelo"] - (r["position"] as Vector3).y < 1.6:
				prof = maxf(prof, a["pelo"] - (r["position"] as Vector3).y)
	return prof


## Il giocatore accovacciato che atterra da 1 m nel mezzo dell'acqua [param a] e poi cammina 1 s: l'occhio più basso
## sopra il pelo (dove i piedi stanno nell'acqua).
func _accovacciato(a: Dictionary) -> float:
	var box: AABB = a["box"]
	# (a un terzo fra il centro e un angolo: in mezzo allo scolo 2 c'è il foro da cui sale lei)
	var c := box.get_center().lerp(box.position, 0.35)
	var sp := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, a["pelo"] + 0.5, c.z), Vector3(c.x, a["pelo"] - 3.0, c.z), Layers.WORLD)
	q.exclude = [p.get_rid()]
	var r := sp.intersect_ray(q)
	if r.is_empty():
		return INF
	var fondo: Vector3 = r["position"]
	if a["pelo"] - fondo.y >= 1.6:
		return INF
	Input.action_press(&"crouch")
	var al_centro := box.get_center() - c
	p.teleport(fondo + Vector3.UP * 1.0, atan2(-al_centro.x, -al_centro.z))
	var minimo := INF
	for f in 150:
		if f == 60:
			Input.action_press(&"move_forward")
		if f == 100:
			Input.action_release(&"move_forward")
		await get_tree().physics_frame
		var occhi := p.camera.global_position
		if OS.has_environment("TRACCIA") and f % 20 == 0:
			print("    %s f%d piedi %s a terra %s fondo %s" % [a["nome"], f, p.global_position, p.is_on_floor(), fondo])
		if occhi.x > box.position.x + 0.2 and occhi.x < box.end.x - 0.2 and occhi.z > box.position.z + 0.2 \
				and occhi.z < box.end.z - 0.2 and p.is_on_floor() and p.global_position.y > a["pelo"] - 1.5:
			minimo = minf(minimo, occhi.y - a["pelo"])
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")
	for f in 30:
		await get_tree().physics_frame
	_vivo(a["nome"])
	return minimo


## Se il giocatore è morto (caduto in un foro), lo dice e lo rimette in piedi per il resto della prova.
func _vivo(dove: String) -> void:
	check(not GameState.is_dying, "%s: il giocatore resta vivo (%s)" % [dove, GameState.last_death_cause if GameState.is_dying else "-"])
	if GameState.is_dying:
		var seq: Variant = GameState.get(&"_death_sequence")
		if seq is Node and is_instance_valid(seq):
			(seq as Node).queue_free()
		GameState.is_dying = false
		p.input_enabled = true


## Il giocatore che parte nell'acqua 2 m prima della bocca del tubo [param nome] e scivola fino in fondo, guardando
## avanti lungo il tubo; con [param indietro] messo lungo la linea, 4 cm alla volta, da 3 m dentro il tubo fino a
## 2 m nella vasca, guardando verso la vasca (su per il tubo non si sale). Ritorna "peggio": l'occhio
## più basso rispetto al pelo di un'acqua che vede ([method _vede]) [altezza, dove]; "soffitto": quanto la camera sta
## al più vicino sotto il soffitto del tubo [distanza, dove]; "salto": il cambio più grande dell'alzata della camera
## (Player.occhi_alzati) da un fotogramma all'altro [m, dove]; "alzata": l'alzata più grande.
func _tubo(ins: SalaInseguimento, nome: String, indietro := false) -> Dictionary:
	var linea := PackedVector3Array()
	for q in ins.dati["tubi"][nome]:
		linea.append(SalaInseguimento.b(q))
	var dir := linea[3] - linea[0]
	dir.y = 0.0
	dir = dir.normalized()
	var ultimo := 0
	if indietro:
		# 3 m dentro il tubo (in pianta), coi piedi sul fondo, voltati verso la bocca
		var k := 0
		while k < linea.size() - 1 and Vector2(linea[k].x - linea[0].x, linea[k].z - linea[0].z).length() < 3.0:
			k += 1
		ultimo = k
		p.teleport(linea[k] + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.2))
	else:
		p.teleport(linea[0] - dir * 2.0 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1) + Vector3.UP * 0.5)
	for i in 20:
		await get_tree().physics_frame
	p.velocity = Vector3.ZERO
	print("  %s%s: parte da %s (bocca %s), muore %s" % [nome, " (indietro)" if indietro else "", p.global_position, linea[0], GameState.is_dying])
	if not indietro:
		Input.action_press(&"move_forward")
	# (indietro su per il tubo non si sale: il giocatore va messo lungo la linea, 4 cm alla volta, dai 3 m alla bocca)
	var passi := PackedVector3Array()
	if indietro:
		for i in range(ultimo, 0, -1):
			var n := ceili(linea[i].distance_to(linea[i - 1]) / 0.04)
			for j in n:
				passi.append(linea[i].lerp(linea[i - 1], float(j) / n) + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.02))
		for j in 50:
			passi.append(linea[0] - dir * 0.04 * j + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.15))
	var peggio := [INF, ""]
	var soffitto := [INF, "-"]
	var salto := [0.0, "-"]
	var alzata := 0.0
	var alzati_prima := p.occhi_alzati
	var arrivato := 0
	for f in (passi.size() if indietro else 60 * 14):
		if indietro:
			p.global_position = passi[f]
			p.velocity = Vector3.ZERO
		await get_tree().physics_frame
		var piedi := p.global_position
		var iv := ultimo
		if indietro:
			for i in range(maxi(ultimo - 12, 0), ultimo + 1):
				if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
					iv = i
		else:
			for i in range(ultimo, mini(ultimo + 12, linea.size())):
				if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
					iv = i
		ultimo = iv
		var verso := linea[mini(iv + 4, linea.size() - 1)]
		if indietro:
			verso = linea[iv - 4] if iv >= 4 else linea[0] - dir * 2.0
		var g := verso - piedi
		g.y = 0.0
		if g.length() > 0.2:
			p.set_look(atan2(-g.x, -g.z), -0.2)
		var occhi := p.camera.global_position
		var dove := "a %s, indice %d/%d" % [occhi, iv, linea.size()]
		if OS.has_environment("TRACCIA") and f % 30 == 0:
			print("    f%d piedi %s indice %d occhi %s alzati %.3f" % [f, piedi, iv, occhi, p.occhi_alzati])
		for a in acque:
			# (sotto il pelo un'acqua che si vede è sempre un errore; sopra, a meno di 30 cm dalla superficie ci vuole anche
			# il piano vicino della camera, che se no la taglia; più lontano basta stare sopra, la si vede di taglio)
			var box: AABB = a["box"]
			var dx := maxf(maxf(box.position.x - occhi.x, occhi.x - box.end.x), 0.0)
			var dz := maxf(maxf(box.position.z - occhi.z, occhi.z - box.end.z), 0.0)
			var serve := near + MARGINE if Vector2(dx, dz).length() < 0.3 else 0.0
			var h: float = occhi.y - a["pelo"] - serve
			if h < peggio[0] and h > -3.0 and _vede(occhi, a):
				peggio = [h, "%s %s" % [a["nome"], dove]]
		# (passando la parete d'acqua della bocca l'occhio dev'essere sopra il pelo, piano vicino compreso)
		for v in veli:
			var l := v.global_transform.affine_inverse() * occhi
			var mezzo := (v.mesh as QuadMesh).size / 2.0
			if absf(l.z) < near + 0.05 and absf(l.x) <= mezzo.x and l.y <= mezzo.y + near:
				var h := l.y - mezzo.y
				if h < peggio[0]:
					peggio = [h, "passando %s %s" % [v.name, dove]]
		var sf := _sotto_soffitto(linea, occhi)
		if sf < soffitto[0]:
			soffitto = [sf, dove]
		var ds := absf(p.occhi_alzati - alzati_prima)
		if ds > salto[0]:
			salto = [ds, "da %.3f a %.3f, %s" % [alzati_prima, p.occhi_alzati, dove]]
		alzati_prima = p.occhi_alzati
		alzata = maxf(alzata, absf(p.occhi_alzati))
		if not indietro and iv >= linea.size() - 2:
			arrivato += 1
			if arrivato > 90:
				break
	Input.action_release(&"move_forward")
	if indietro:
		p.velocity = Vector3.ZERO
		for i in 20:
			await get_tree().physics_frame
	_vivo(nome)
	return {"peggio": peggio, "soffitto": soffitto, "salto": salto, "alzata": alzata}


## Quanto [param occhi] sta sotto il soffitto del tubo lungo [param linea] (il centro del tratto più vicino in pianta,
## fra quelli a meno di 1,2 m in altezza, più il raggio; il primo mezzo metro dalla bocca no: lì sopra c'è il muro della
## vasca). INF fuori dal tubo.
func _sotto_soffitto(linea: PackedVector3Array, occhi: Vector3) -> float:
	var out := INF
	var lungo := 0.0
	for i in linea.size() - 1:
		var a := linea[i]
		var b := linea[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(occhi.x - a.x, occhi.z - a.z).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var dist := Vector2(occhi.x - a.x - ab.x * t, occhi.z - a.z - ab.y * t).length()
		var y := lerpf(a.y, b.y, t)
		if lungo + ab.length() * t > 0.5 and dist < SalaInseguimento.R_TUBO * 0.5 and absf(occhi.y - y) < 1.2:
			out = minf(out, y + SalaInseguimento.R_TUBO - occhi.y)
		lungo += ab.length()
	return out


## Vero se dagli [param occhi] si vede la superficie dell'acqua [param a]: sopra la sua pianta, o accanto (2 m) con
## la superficie in vista (nessun muro in mezzo fino al bordo più vicino).
func _vede(occhi: Vector3, a: Dictionary) -> bool:
	var box: AABB = a["box"]
	# (il punto della superficie più vicino all'occhio, 5 cm dentro il bordo: la parete d'acqua sta sul bordo)
	var dentro := Rect2(box.position.x + 0.05, box.position.z + 0.05, box.size.x - 0.1, box.size.z - 0.1)
	var pr := Vector3(clampf(occhi.x, dentro.position.x, dentro.end.x), a["pelo"], clampf(occhi.z, dentro.position.y, dentro.end.y))
	if Vector2(occhi.x - pr.x, occhi.z - pr.z).length() > 2.0:
		return false
	# (fino a 1 cm prima della superficie, dalla parte dell'occhio: un fondo o un muro in mezzo la nasconde)
	var verso := pr - occhi
	if verso.length() < 0.02:
		return true
	var fine := pr - verso.normalized() * 0.01
	for v in veli:
		if _attraversa(v, occhi, fine):
			return false
	var q := PhysicsRayQueryParameters3D.create(occhi, fine, Layers.WORLD)
	q.exclude = [p.get_rid()]
	var libero := p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	if libero and OS.has_environment("TRACCIA") and occhi.y < a["pelo"]:
		var dettagli := []
		for v in veli:
			var inv := v.global_transform.affine_inverse()
			dettagli.append("%s la %s lb %s" % [v.name, inv * occhi, inv * fine])
		print("    VEDE %s da %s fino a %s: %s" % [a["nome"], occhi, fine, dettagli])
	return libero


## Vero se il segmento da [param a] a [param b] passa attraverso la parete d'acqua [param v] (un quad).
func _attraversa(v: MeshInstance3D, a: Vector3, b: Vector3) -> bool:
	var inv := v.global_transform.affine_inverse()
	var la := inv * a
	var lb := inv * b
	if signf(la.z) == signf(lb.z):
		return false
	var t := la.z / (la.z - lb.z)
	var x := la + (lb - la) * t
	var mezzo := (v.mesh as QuadMesh).size / 2.0
	return absf(x.x) <= mezzo.x and absf(x.y) <= mezzo.y

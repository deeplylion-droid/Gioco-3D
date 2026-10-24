extends Node
## Collaudo dell'ambiente del tunnel del viaggio sottomarino (squadra collaudo): scatti dagli occhi del giocatore lungo
## un tratto della strada (sulle due banchine e dall'acqua) e ravvicinati di ogni oggetto piccolo appeso o appoggiato
## del tratto, con i materiali veri e la luce del gioco (l'ambiente della sala, come scatti_sottomarino.gd), senza torcia.
## Lei e i gommoni non si guardano (lei è nascosta, i gommoni fermi).
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --script res://tests/run.gd -- res://tests/collaudo/giro_tunnel.gd <cartella> <da s> <a s> <cosa> [nomi]
## <cosa>:
##  - strada: ogni 8 m dal mezzo di ogni banchina (dove non è crollata) avanti, verso l'approdo; ogni 16 m di traverso
##    verso il muro di fronte e la volta, ogni 24 m anche indietro; dall'acqua (in piedi sul fondo, sull'asse) ogni 12 m avanti;
##  - oggetti: per ogni oggetto piccolo del tratto (lampade, oblò, mensole e quello che c'è sopra, l'ancora e le sue
##    staffe, il salvagente, il forziere, il palombaro, i pezzi degli ostacoli e delle gallerie, i pali del parapetto) due
##    ravvicinati: di fronte, un po' dal basso come lo vede il giocatore, e di traverso lungo il muro (si vede lo spazio fra
##    il retro e il muro o la mensola). Con una luce debole sulla camera (COLLAUDO_LUCE, predefinita 0,6) perché si veda il
##    contatto; scrive anche <cartella>/oggetti.csv con quanto sta in alto ogni oggetto e quanto sporge dal muro;
##  - retro: le viste di "strada" col materiale chiaro senza luce e le facce viste dal retro in rosso (come
##    SCATTI_DEBUG=retro di scatti_sottomarino.gd): dove c'è rosso, da quel lato la faccia non si vede.
##  - punti: gli scatti della lista nel file COLLAUDO_PUNTI, una riga per scatto: "nome px py pz vx vy vz campo"
##    (la camera in p guarda v, coordinate del mondo), con la luce degli oggetti (COLLAUDO_LUCE=0 la spegne).
## [nomi]: solo gli scatti che cominciano con uno di questi (separati da virgole).

const PASSO_STRADA := 8.0
const PASSO_ACQUA := 12.0
const PASSO_INDIETRO := 24.0
const PASSO_MURO := 16.0
const OCCHI := 1.6

var cartella := ""
var da := 0.0
var a := 240.0
var cosa := "strada"
var solo := PackedStringArray()
var sala: SalaSottomarino
var cam: Camera3D


func _ready() -> void:
	var x := OS.get_cmdline_user_args()
	cartella = x[1]
	da = float(x[2])
	a = float(x[3])
	cosa = x[4]
	if x.size() > 5 and x[5] != "":
		solo = x[5].split(",", false)
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	if cosa == "strada":
		env.environment.sdfgi_enabled = true
		env.environment.sdfgi_cascades = 3
		env.environment.volumetric_fog_density = 0.009
	else:
		env.environment.sdfgi_enabled = false
		env.environment.volumetric_fog_enabled = false
	add_child(env)
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	sala.set_physics_process(false)
	sala.ferma_gommoni(0.0)
	if sala.lei_tunnel:
		sala.lei_tunnel.visible = false
	if cosa == "retro":
		_materiali_retro()
	cam = Camera3D.new()
	cam.near = 0.03
	add_child(cam)
	cam.current = true
	if cosa in ["oggetti", "punti"] and OS.get_environment("COLLAUDO_LUCE") != "0":
		var luce := OmniLight3D.new()
		luce.light_energy = float(OS.get_environment("COLLAUDO_LUCE")) if OS.get_environment("COLLAUDO_LUCE") != "" else 0.6
		luce.omni_range = 6.0
		luce.omni_attenuation = 1.0
		luce.shadow_enabled = false
		cam.add_child(luce)
	for i in 30:
		await get_tree().process_frame
	var scatti := _oggetti() if cosa == "oggetti" else (_punti() if cosa == "punti" else _strada())
	var attesa := 12 if cosa == "strada" else 6
	var prima := true
	for nome: String in scatti:
		if not solo.is_empty() and not Array(solo).any(func(p): return nome.begins_with(p)):
			continue
		var f := cartella.path_join(nome + ".jpg")
		if FileAccess.file_exists(f):
			continue   # (già fatto: si riprende da dove ci si era fermati)
		var sc: Array = scatti[nome]
		cam.fov = sc[2]
		cam.look_at_from_position(sc[0], sc[1])
		for i in (50 if prima else attesa):
			await get_tree().process_frame
		prima = false
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()


## Un punto a [param s], [param u] metri di lato dall'asse (a destra positivo), alla quota [param y].
func _qui(s: float, u: float, y: float) -> Vector3:
	return sala._al(sala.punto(s), sala.destra(s), Vector2(u, y))


func _banchina_c(s: float, lato: float) -> float:
	return lato * (sala.canale + sala.banchina * 0.5)


## Le viste lungo la strada: nome -> [da, verso, campo visivo].
func _strada() -> Dictionary:
	var out := {}
	var s := da
	while s <= a + 0.01:
		for lato: float in [-1.0, 1.0]:
			if sala._lato(s, lato)["crollo"]:
				continue
			var n := "s%03d_%s" % [int(s), "sx" if lato < 0.0 else "dx"]
			var occhi := _qui(s, _banchina_c(s, lato), sala.piano + OCCHI)
			out[n + "_avanti"] = [occhi, _qui(s + 10.0, lato * (sala.canale + 0.6), sala.piano + 1.3), 75.0]
			if fmod(s - da, PASSO_MURO) < 0.01:
				out[n + "_muro_di_fronte"] = [occhi, _qui(s + 2.5, -lato * sala.muro, sala.piano + 2.6), 75.0]
			if fmod(s - da, PASSO_INDIETRO) < 0.01:
				out[n + "_indietro"] = [occhi, _qui(s - 10.0, lato * (sala.canale + 0.6), sala.piano + 1.3), 75.0]
		if fmod(s - da, PASSO_ACQUA) < 0.01 or fmod(s - da, PASSO_ACQUA) > PASSO_ACQUA - 0.01:
			var occhi := _qui(s, 0.0, sala.fondo_a(s) + OCCHI)
			if s < SalaSottomarino.PRESA_FINO:
				occhi.y = sala.acqua + 0.3   # (nella presa profonda si nuota: gli occhi appena sopra il pelo)
			out["s%03d_acqua_avanti" % int(s)] = [occhi, _qui(s + 10.0, 0.0, sala.piano + 1.0), 75.0]
		s += PASSO_STRADA
	# la testa del tunnel, dalla porta del bacino (dove si entra)
	if da <= 0.0:
		var porta := _qui(SalaSottomarino.PORTA_S, -(sala.canale + 0.6), sala.piano + OCCHI)
		out["s000_porta_bacino_testa"] = [porta, _qui(-SalaSottomarino.TESTA, 0.0, sala.piano + 0.5), 80.0]
		out["s000_porta_bacino_avanti"] = [porta, _qui(12.0, 0.0, sala.piano + 1.0), 80.0]
		out["s000_porta_bacino_di_fronte"] = [porta, _qui(SalaSottomarino.PORTA_S, sala.muro, sala.piano + 1.5), 80.0]
	return out


## Gli scatti da una lista (vedi "punti" sopra).
func _punti() -> Dictionary:
	var out := {}
	for r in FileAccess.get_file_as_string(OS.get_environment("COLLAUDO_PUNTI")).split("\n", false):
		var c := r.strip_edges().split(" ", false)
		if c.size() < 8 or c[0].begins_with("#"):
			continue
		out[c[0]] = [Vector3(float(c[1]), float(c[2]), float(c[3])), Vector3(float(c[4]), float(c[5]), float(c[6])), float(c[7])]
	return out


# --- gli oggetti --------------------------------------------------------------------------------------------------------

## I gruppi degli arredi e degli ostacoli: i loro figli diretti sono gli oggetti.
func _gruppi() -> Array:
	var out: Array = []
	for n in sala.get_children():
		var nome := String(n.name)
		if nome in ["Luci", "Coralli", "Relitto", "SalaPalombaro", "ParapettoPresa", "Testa", "ArrediA1"] \
				or nome.begins_with("Ostacolo_") or nome.begins_with("Galleria_"):
			out.append(n)
	return out


## Il box nel mondo delle mesh sotto [param n] (senza le collisioni).
func _box(n: Node) -> AABB:
	var b := AABB()
	var primo := true
	var mis: Array = [n] if n is MeshInstance3D else []
	mis.append_array(n.find_children("*", "MeshInstance3D", true, false))
	for m in mis:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var bb := mi.global_transform * mi.mesh.get_aabb()
		b = bb if primo else b.merge(bb)
		primo = false
	return b


## Il punto più basso sopra il piano e quanto sporge verso l'asse dal muro (in m), coi vertici veri.
func _misure(n: Node, lato: float) -> Array:
	var basso := INF
	var u_min := INF
	var c := _box(n).get_center()
	var s0: float = sala.proietta(c)[0]
	var p0 := sala.punto(s0)
	var r0 := sala.destra(s0)
	var mis: Array = [n] if n is MeshInstance3D else []
	mis.append_array(n.find_children("*", "MeshInstance3D", true, false))
	for m in mis:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := mi.global_transform
		for v in mi.mesh.get_faces():
			var w := xf * v
			basso = minf(basso, w.y - sala.piano)
			u_min = minf(u_min, (w - p0).dot(r0) * lato)
	return [basso, sala.muro - u_min]


## I ravvicinati: nome -> [da, verso, campo visivo]. Scrive anche oggetti.csv.
func _oggetti() -> Dictionary:
	var out := {}
	var csv := FileAccess.open(cartella.path_join("oggetti.csv"), FileAccess.WRITE)
	csv.store_line("nome;nodo;s;lato;basso sopra il piano (m);sporge dal muro (m);diagonale (m)")
	var k := 0
	for g in _gruppi():
		for n in g.get_children():
			var mensola := n.get_node_or_null(^"struttura_mensola") != null
			if not n is Node3D or n is Light3D or n is CollisionObject3D and not mensola:
				continue
			var nome_n := String(n.name)
			if nome_n.begins_with("struttura_"):
				continue
			var b := _box(n)
			if b.size == Vector3.ZERO:
				continue
			var c := b.get_center()
			var pr: Array = sala.proietta(c)
			var s: float = pr[0]
			if s < da - 1.0 or s > a + 1.0:
				continue
			var diag := b.size.length()
			# i pali del parapetto sì, i correnti no (si vedono con i pali)
			if String(g.name) == "ParapettoPresa" and b.size.y < 0.9:
				continue
			var lato := signf(float(pr[1]))
			var mis := _misure(n, lato) if diag < 8.0 else [b.position.y - sala.piano, 0.0]
			k += 1
			var nome := "o%03d_s%03d_%s_%s" % [k, int(s), "sx" if lato < 0.0 else "dx", "mensola" if mensola else _nome_breve(g, n)]
			csv.store_line("%s;%s;%.2f;%d;%.3f;%.3f;%.2f" % [nome, String(sala.get_path_to(n)), s, int(lato), mis[0], mis[1], diag])
			if diag > 8.0:
				continue
			# fuori dal muro (verso l'asse), lungo la strada, su
			var fuori := -sala.destra(s) * lato
			var lungo := sala.direzione(s)
			var dist := clampf(diag * 1.3, 0.55, 2.2)
			# le staffe dell'ancora (figlie dell'ancora), ognuna da vicino
			# (la seconda, con lo stesso nome, Godot la rinomina: si prendono le scatole figlie dell'ancora)
			var prima_sf := true
			for sf in n.find_children("*", "MeshInstance3D", true, false):
				if not (String(sf.name).contains("Staffa") or nome_n == "Ancora" and (sf as MeshInstance3D).mesh is BoxMesh):
					continue
				var cs := (sf as MeshInstance3D).global_position
				if prima_sf:
					k += 1
				var ns := "o%03d_s%03d_%s_staffa%s" % [k, int(s), "sx" if lato < 0.0 else "dx", "" if prima_sf else "2"]
				prima_sf = false
				var ms := _misure(sf, lato)
				csv.store_line("%s;%s;%.2f;%d;%.3f;%.3f;%.2f" % [ns, String(sala.get_path_to(sf)), s, int(lato), ms[0], ms[1], _box(sf).size.length()])
				out[ns + "_a"] = [cs + fuori * 0.5 + lungo * 0.25 - Vector3.UP * 0.15, cs, 50.0]
				out[ns + "_b"] = [cs + fuori * 0.15 - lungo * 0.6 + Vector3.UP * 0.05, cs, 50.0]
			var dentro_galleria := absf(float(pr[1])) > sala.muro + 0.1
			if dentro_galleria:
				# (dentro una galleria di servizio: si guarda da dentro, dal basso)
				out[nome + "_a"] = [c + lungo * dist * 0.8 - Vector3.UP * 0.5 + fuori * 0.2, c, 55.0]
				out[nome + "_b"] = [c - lungo * dist * 0.8 - Vector3.UP * 0.5 - fuori * 0.2, c, 55.0]
				continue
			out[nome + "_a"] = [c + fuori * dist * 0.85 + lungo * dist * 0.35 - Vector3.UP * dist * 0.25, c, 50.0]
			out[nome + "_b"] = [c + fuori * dist * 0.28 - lungo * dist + Vector3.UP * 0.04, c, 50.0]
	csv.close()
	# le lastre dei crolli (una mesh sola con le quattro lastre): ognuna dall'acqua, di traverso, e dalla banchina prima
	for o in sala.ostacoli:
		if o["tipo"] != "crollo" or sala._sotto_galleria(o) or float(o["s"]) < da - 1.0 or float(o["s"]) > a + 1.0:
			continue
		var lato: float = o["lato"]
		var lato_n := "sx" if lato < 0.0 else "dx"
		for q in 4:
			var sk: float = float(o["s"]) + float(o["lungo"]) * (float(q) + 0.5) / 4.0
			var c := _qui(sk, lato * (sala.muro - 0.75 - 0.25 * float(q % 2)), sala.fondo + 0.42)
			k += 1
			var nome := "o%03d_s%03d_%s_crollo_lastra%d" % [k, int(sk), lato_n, q + 1]
			out[nome + "_a"] = [_qui(sk - 0.8, lato * 1.2, sala.piano + 0.6), c, 55.0]
			out[nome + "_b"] = [_qui(float(o["s"]) - 1.0, lato * (sala.muro - 1.0), sala.piano + OCCHI), c, 45.0]
	return out


func _nome_breve(g: Node, n: Node) -> String:
	var gn := String(g.name).to_lower()
	var nn := String(n.name).to_lower()
	var lampada := n.find_child("globo", true, false) != null
	if gn == "luci":
		return "lampada" if lampada else "oblo"
	if lampada:
		return gn.split("_")[0] + "_lampada"
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh:
		return gn.split("_")[0] + ("_plafoniera" if ((n as MeshInstance3D).mesh as BoxMesh).size.y < 0.1 else "_fascia")
	if nn.begins_with("meshinstance") or nn.begins_with("@"):
		return gn + "_pezzo"
	return gn.split("_")[0] + "_" + nn.split("@")[0].rstrip("0123456789")


# --- il controllo delle facce dal retro -----------------------------------------------------------------------------------

func _materiali_retro() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.8, 0.8)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mr := StandardMaterial3D.new()
	mr.albedo_color = Color(0.9, 0.1, 0.1)
	mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mr.cull_mode = BaseMaterial3D.CULL_FRONT
	m.next_pass = mr
	for mi in sala.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		# (le superfici dell'acqua restano com'erano: sono piatte e si vedono solo da sopra)
		if String(g.name).to_lower().begins_with("acqua") or String(g.get_parent().name).to_lower().begins_with("acqua"):
			continue
		g.material_override = m
	var we := find_children("*", "WorldEnvironment", false, false)
	if not we.is_empty():
		var e := (we[0] as WorldEnvironment).environment
		e.volumetric_fog_enabled = false
		e.fog_enabled = false
		e.sdfgi_enabled = false
		e.glow_enabled = false
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		e.adjustment_enabled = false

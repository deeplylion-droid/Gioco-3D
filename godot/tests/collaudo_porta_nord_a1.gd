extends Node
## (copia per il collaudo di ambienti-1 della porta nord, 25 ottobre: stato "apertura" = il colpo sul pulsantone, scatti
## dopo SCATTI_ATTESA secondi; le camere porta_*) Scatti di controllo dell'infermeria del gioco (scenes/risalita/infermeria.tscn), da sola con una
## luce d'ambiente come quella della proposta. Lo stato: "chiusa" (come la trovi arrivando), "luce" (il pulsante
## colpito), "cassetti" (anche tutti i cassetti tirati) o "risolta" (anche la radiografia sul negatoscopio e la
## cassaforte aperta, come lo stato risalita_dopo del controllo di posizionamento). Le luci bianche sono quelle del gioco,
## al 40% (LuciBianche); la torcia non c'è più (23 ottobre).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_infermeria_gioco.gd <cartella> [stato] [camere separate da virgole]
## Con INFERMERIA_BUIA=1 nell'ambiente: la variante A della luce dopo il pulsante (stanza buia anche dopo).

const CAMERE := {
	"stanza": [Vector3(1.6, 1.65, 3.0), Vector3(-0.6, 1.0, -2.0)],
	"negatoscopio": [Vector3(0.5, 1.6, -1.2), Vector3(0.5, 1.4, -3.2)],
	"schedario": [Vector3(-1.4, 1.6, -0.4), Vector3(-3.0, 0.8, -1.1)],
	"cassaforte": [Vector3(2.0, 1.55, -0.6), Vector3(3.2, 1.3, -1.05)],
	"dentro": [Vector3(2.55, 1.5, -0.7), Vector3(3.25, 1.15, -1.05)],   # la keycard e la Polaroid della pecora
	# il giro dagli occhi del giocatore (1,6 m)
	"ingresso": [Vector3(1.6, 1.6, 2.7), Vector3(-0.5, 1.0, -2.5)],
	"lettino": [Vector3(1.2, 1.6, 0.6), Vector3(2.75, 0.7, 2.1)],
	"armadietto": [Vector3(1.0, 1.6, 0.0), Vector3(3.2, 1.1, 0.35)],
	"lavandino": [Vector3(-0.6, 1.6, 1.0), Vector3(-0.6, 0.6, 3.2)],
	"pronto_soccorso": [Vector3(-1.0, 1.6, 0.6), Vector3(-3.2, 1.2, 0.35)],
	"porta_nord": [Vector3(-1.0, 1.6, -0.5), Vector3(-2.2, 1.0, -3.2)],
	# le rotelle della cassaforte davanti, da vicino come quando si girano (23 ottobre: la cifra davanti non era quella vera)
	"rotelle": [Vector3(2.45, 1.5, -1.05), Vector3(3.2, 1.3, -1.05)],
	"rotelle_fianco": [Vector3(2.55, 1.45, -0.55), Vector3(3.15, 1.3, -1.05)],
	# lo schedario col cassetto giusto: entrando dalla porta sud e da vicino (23 ottobre: la melma di Jilly sul cassetto)
	"schedario_lontano": [Vector3(0.9, 1.6, 2.3), Vector3(-2.85, 0.9, -1.3)],
	"cassetto_vicino": [Vector3(-2.05, 1.45, -1.2), Vector3(-2.85, 0.88, -1.33)],
	"cassetto_aperto": [Vector3(-1.7, 1.4, -1.05), Vector3(-2.5, 0.9, -1.33)],   # (stato cassetti: il frontale tirato di 38 cm)
	# le porte con le ante aperte fino al muro (23 ottobre): la sud da dentro, la nord mentre ci si passa, e l'adesivo
	# sopra l'anta della nord da dove ci si può avvicinare di più (contro l'anta)
	"porta_sud": [Vector3(0.9, 1.6, 1.3), Vector3(1.7, 1.0, 3.2)],
	"porta_nord_passaggio": [Vector3(-2.2, 1.6, -1.6), Vector3(-2.2, 1.2, -3.6)],
	"adesivo_nord": [Vector3(-1.25, 1.6, -2.72), Vector3(-1.25, 2.45, -3.2)],
	# collaudo di ambienti-1 (25 ottobre): i faretti a soffitto, i cavi, le scatole, il pulsante, il pannello rosa, l'uscita
	"faretto_negatoscopio": [Vector3(0.95, 2.2, -1.2), Vector3(0.3, 2.95, -2.0)],
	"faretto_negatoscopio_lato": [Vector3(-0.4, 2.5, -1.7), Vector3(0.3, 2.95, -2.0)],
	"cavo_negatoscopio": [Vector3(0.75, 2.2, -2.0), Vector3(0.3, 2.95, -3.1)],
	"faretto_cassaforte": [Vector3(1.55, 2.2, 0.15), Vector3(2.3, 2.95, -0.55)],
	"faretto_cassaforte_lato": [Vector3(2.3, 2.45, 0.5), Vector3(2.3, 2.95, -0.55)],
	"cavo_cassaforte": [Vector3(2.3, 2.2, 0.1), Vector3(3.15, 2.95, -0.55)],
	"pulsante": [Vector3(1.35, 1.6, -2.2), Vector3(1.35, 1.25, -3.2)],
	"pannello_rosa": [Vector3(-1.9, 1.7, 1.45), Vector3(-3.2, 1.85, 1.45)],
	"pannello_rosa_fianco": [Vector3(-2.9, 1.85, 0.55), Vector3(-3.2, 1.85, 1.45)],
	"pannello_rosa_vicino": [Vector3(-2.3, 1.85, 1.45), Vector3(-3.2, 1.85, 1.45)],
	"pannello_rosa_radente": [Vector3(-3.08, 1.85, 0.75), Vector3(-3.19, 1.85, 1.45)],
	"pannello_rosa_radente_alto": [Vector3(-3.06, 2.45, 1.45), Vector3(-3.19, 1.85, 1.45)],
	"uscita": [Vector3(-2.2, 1.6, -1.6), Vector3(-2.2, 2.38, -3.15)],
	"rotelle_buio": [Vector3(1.5, 1.6, -0.4), Vector3(3.2, 1.3, -1.05)],
	# la porta nord (collaudo del 25 ottobre sera): chiusa, aperta, i cardini (asse a x -1,762, z -3,122), la maniglia, le
	# fessure con gli stipiti e la traversa, e dal punto da cui si colpisce il pulsantone
	"porta_davanti": [Vector3(-2.2, 1.6, -1.4), Vector3(-2.2, 1.1, -3.15)],
	"porta_cardine_basso": [Vector3(-1.35, 0.7, -2.55), Vector3(-1.76, 0.35, -3.12)],
	"porta_cardine_alto": [Vector3(-1.35, 1.95, -2.55), Vector3(-1.76, 1.75, -3.12)],
	"porta_maniglia": [Vector3(-2.15, 1.35, -2.5), Vector3(-2.54, 1.05, -3.09)],
	"porta_fessura_lato": [Vector3(-1.25, 1.2, -2.95), Vector3(-2.3, 1.2, -3.14)],
	"porta_fessura_lato_ovest": [Vector3(-3.1, 1.2, -2.95), Vector3(-2.1, 1.2, -3.14)],
	"porta_fessura_alto": [Vector3(-2.2, 2.45, -2.55), Vector3(-2.2, 2.09, -3.14)],
	"porta_fessura_basso": [Vector3(-2.2, 0.35, -2.45), Vector3(-2.2, 0.0, -3.14)],
	"porta_aperta_davanti": [Vector3(-1.3, 1.6, -1.5), Vector3(-1.3, 1.0, -3.1)],
	"porta_aperta_cardini": [Vector3(-2.15, 1.1, -2.55), Vector3(-1.76, 1.0, -3.12)],
	"porta_aperta_radente": [Vector3(-0.45, 1.3, -2.85), Vector3(-1.6, 1.2, -3.14)],
	"porta_aperta_sopra": [Vector3(-1.3, 2.6, -2.6), Vector3(-1.3, 2.0, -3.15)],
	"porta_dal_pulsante": [Vector3(1.4, 1.6, 0.4), Vector3(1.35, 1.25, -3.2)],
	"porta_dal_pulsante_verso": [Vector3(1.4, 1.6, 0.4), Vector3(-2.2, 1.1, -3.2)],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var stato: String = a[2] if a.size() > 2 else "chiusa"
	var passo := ["chiusa", "luce", "cassetti", "risolta"].find(stato)
	var apertura := stato == "apertura"
	var lista: PackedStringArray = a[3].split(",") if a.size() > 3 else PackedStringArray(CAMERE.keys())
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.015
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	# INFERMERIA_BUIA=1: la variante A della luce dopo il pulsante (buia_dopo_pulsante)
	if OS.get_environment("INFERMERIA_BUIA") == "1":
		f.set(&"buia_dopo_pulsante", true)
	get_tree().root.add_child(f)
	await get_tree().process_frame
	if passo >= 1:
		(f.get_node("Interruttore") as WaterButton).powered = true
	if passo >= 2:
		for c in f.find_children("*", "CassettoSchedario", true, false):
			c.call(&"load_state", {"aperto": true})
	# SCATTI_ROTELLE="4,1,7": le rotelle su quelle cifre, senza aprire (per vedere che davanti c'è proprio quella cifra)
	var rot := OS.get_environment("SCATTI_ROTELLE")
	if rot != "" and passo < 3:
		var cifre := []
		for c in rot.split(","):
			cifre.append(int(c))
		(f.get_node("Cassaforte") as CassaforteRotelle).load_state({"cifre": cifre, "aperta": false})
	if passo >= 3:
		(f.get_node("Negatoscopio") as Negatoscopio).con_radiografia = true
		var cassa := f.get_node("Cassaforte") as CassaforteRotelle
		cassa.load_state({"cifre": [4, 1, 7], "aperta": true})
	if apertura:
		# il colpo sul pulsantone: acceso e premuto (come al getto), l'anta si apre in 2,6 s
		var inter := f.get_node("Interruttore") as WaterButton
		inter.powered = true
		inter.pressed.emit()
		var attesa := float(OS.get_environment("SCATTI_ATTESA")) if OS.get_environment("SCATTI_ATTESA") != "" else 1.3
		await get_tree().create_timer(attesa).timeout
		f.process_mode = Node.PROCESS_MODE_DISABLED     # (l'anta ferma a metà per gli scatti)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	get_tree().root.add_child(cam)
	cam.make_current()
	# COLLAUDO_LUCE=1: una luce bianca provvisoria sulla camera, solo negli scatti (per vedere com'è attaccato un oggetto
	# al buio), non nel gioco
	var luce_collaudo: OmniLight3D = null
	if OS.get_environment("COLLAUDO_LUCE") == "1":
		luce_collaudo = OmniLight3D.new()
		luce_collaudo.light_energy = 1.5
		luce_collaudo.omni_range = 4.0
		luce_collaudo.shadow_enabled = true
		get_tree().root.add_child(luce_collaudo)
	for nome in lista:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		if luce_collaudo:
			luce_collaudo.global_position = cam.global_position + Vector3.UP * 0.15
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("infermeria_%s_%s.jpg" % [stato, nome]), 0.9)
		print("salvato ", nome)
	get_tree().quit()

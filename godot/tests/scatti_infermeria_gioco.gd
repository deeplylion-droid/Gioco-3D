extends Node
## Scatti di controllo dell'infermeria del gioco (scenes/risalita/infermeria.tscn), da sola con una
## luce d'ambiente come quella della proposta. Lo stato: "chiusa" (come la trovi arrivando), "luce" (il pulsante
## colpito), "cassetti" (anche tutti i cassetti tirati) o "risolta" (anche la radiografia sul negatoscopio e la
## cassaforte aperta, come lo stato risalita_dopo del controllo di posizionamento). Le luci bianche sono quelle del gioco,
## al 40% (LuciBianche); la torcia non c'è più (23 ottobre).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1600x900 --script res://tests/run.gd \
##        -- res://tests/scatti_infermeria_gioco.gd <cartella> [stato] [camere separate da virgole]
## Con INFERMERIA_BUIA=0 nell'ambiente: la variante B scartata della luce dopo il pulsante (stanza chiara dopo).

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
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var stato: String = a[2] if a.size() > 2 else "chiusa"
	var passo := ["chiusa", "luce", "cassetti", "risolta"].find(stato)
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
	# INFERMERIA_BUIA=0: la variante B scartata della luce dopo il pulsante (per i confronti; di serie c'è la A)
	if OS.get_environment("INFERMERIA_BUIA") == "0":
		f.set(&"buia_dopo_pulsante", false)
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
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	get_tree().root.add_child(cam)
	cam.make_current()
	for nome in lista:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("infermeria_%s_%s.jpg" % [stato, nome]), 0.9)
		print("salvato ", nome)
	get_tree().quit()

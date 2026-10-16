extends Node3D
## La sala principale vera (GLB di assets_src/ambiente/glb/sala, copiati da
## strumenti/prepara_sala_reale.sh) con due look da confrontare:
##   --look=prima  luci e ambiente di sala_luci_ambiente.gd (quello di partenza)
##   --look=dopo   LookSala (grafica/look_sala.gd) con i preset di grafica/sala/
## Altri argomenti dopo "--": --vista=ingresso|piscina|area_bimbi|torre|panoramica
##   --preset=ultra --frames=40 --out=percorso.jpg --lampo=FOTOGRAMMA --set=gi:2

const GLB := ["sala_architettura", "sala_monumento", "sala_cupola", "sala_piscina", "sala_area_bimbi",
	"sala_torre_scivoli", "sala_oggetti", "sala_interattivi", "sala_acqua", "sala_luci"]

## Inquadrature da sala_dati.json (coordinate Blender: posizione, punto guardato, lente in mm).
const VISTE := {
	"ingresso": [Vector3(0.35, -19.2, 1.65), Vector3(0.0, -10.0, 3.1), 18.0],
	"monumento": [Vector3(3.6, -14.9, 1.55), Vector3(0.0, -10.0, 1.9), 24.0],
	"piscina": [Vector3(5.6, -6.9, 1.9), Vector3(-0.6, -0.4, -1.1), 18.0],
	"area_bimbi": [Vector3(-12.2, 5.4, 0.95), Vector3(-12.9, 12.5, 1.9), 20.0],
	"torre": [Vector3(12.3, 16.6, 10.25), Vector3(-4.0, 6.0, -3.0), 17.0],
	"panoramica": [Vector3(16.5, -10.0, 6.4), Vector3(-3.0, 8.0, 2.0), 16.0],
}

var _arg := {}
var _frame := 0
var look: Node3D
var camera: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_arg[kv[0]] = kv[1] if kv.size() > 1 else "1"
	seed(int(_arg.get("seme", "3")))
	Grafica.salva_su_disco = false
	Grafica.applica_preset(_arg.get("preset", "ultra"))
	if _arg.has("set"):
		for coppia in String(_arg["set"]).split(","):
			var kv := coppia.split(":")
			Grafica.imposta(kv[0], str_to_var(kv[1]))
	look = Node3D.new()
	look.name = "SalaPrincipale"
	for nome in GLB:
		var scena: PackedScene = load("res://sala_reale/glb/%s.glb" % nome)
		look.add_child(scena.instantiate())
	if _arg.get("look", "dopo") == "prima":
		# Com'era prima, senza il post-processing dell'addon.
		for k in ["grana", "vignetta", "aberrazione"]:
			Grafica.imposta(k, false)
		Grafica.imposta("color_grading", 0)
		look.set_script(load("res://sala_reale/glb/sala_luci_ambiente.gd"))
	else:
		look.set_script(LookSala)
		# Per le prove: --param=energia_fari:5,crea_controluce:false
		if _arg.has("param"):
			for coppia in String(_arg["param"]).split(","):
				var kv := coppia.split(":")
				look.set(kv[0], str_to_var(kv[1]))
	add_child(look)
	# La medusa del gioco sul monumento, alta 4,5 m, rivolta verso la porta (+Z).
	var medusa: Node3D = load("res://sala_reale/glb/medusa/medusa.glb").instantiate()
	medusa.scale = Vector3.ONE * (4.5 / 2.7)
	medusa.position = Vector3(0, 1.15, 10)
	add_child(medusa)
	for mi in medusa.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Medusa":
			mi.set_surface_override_material(2, load("res://sala_reale/glb/medusa/medusa_campana.tres"))
		elif mi.name == "Medusa_Tentacoli":
			# Vene dei tentacoli al 22%: piene, con i faretti dal basso, bruciavano (prova dell'integratore).
			var t: StandardMaterial3D = load("res://sala_reale/glb/medusa/medusa_tentacoli.tres").duplicate()
			# Il .tres non ha emission_operator = Multiply (il GLB sì): con "Add" il bianco
			# dell'emissione si somma alla texture e i tentacoli escono bianchi.
			t.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			t.emission_energy_multiplier *= float(_arg.get("vene", "1.0"))
			if _arg.has("tent_glb"):  # per le prove: il materiale del GLB invece del .tres
				t = mi.mesh.surface_get_material(0).duplicate()
				t.emission_energy_multiplier *= float(_arg.get("vene", "0.22"))
				print("GLB tentacoli: emissione ", t.emission, " tex ", t.emission_texture, " x", t.emission_energy_multiplier, " op ", t.emission_operator)
			if _arg.has("tent_semplice"):  # per le prove
				t = StandardMaterial3D.new()
				t.albedo_color = Color(0.8, 0.1, 0.5)
			if _arg.has("spegni"):  # per le prove: --spegni=clearcoat_enabled,rim_enabled
				for k in String(_arg["spegni"]).split("+"):
					t.set(k, false)
			if _arg.has("no_sss"):  # per le prove
				t.subsurf_scatter_enabled = false
			mi.set_surface_override_material(0, t)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.set_meta("grafica_fov_fisso", true)
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	var v: Array = VISTE.get(_arg.get("vista", "ingresso"))
	var pos := _da_blender(v[0])
	camera.fov = rad_to_deg(2.0 * atan(18.0 / float(v[2])))  # sensore 36 mm, campo orizzontale
	camera.look_at_from_position(pos, _da_blender(v[1]))
	camera.current = true


static func _da_blender(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, -p.y)


func _process(_delta: float) -> void:
	_frame += 1
	if _arg.has("lampo") and _frame == int(_arg["lampo"]) and look is LookSala:
		(look as LookSala).tempesta.lampo_ora(1.3, 1.0, deg_to_rad(float(_arg.get("azimut", "160"))))
	if _arg.has("out") and _frame >= int(_arg.get("frames", "40")):
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(_arg["out"], 0.92)
		print("salvato ", _arg["out"])
		get_tree().quit()

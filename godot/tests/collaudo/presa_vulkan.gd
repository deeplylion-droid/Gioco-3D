extends "res://tests/test_presa_vera.gd"
## test_presa_vera col renderer vero (llvmpipe), dove la sala intera non sta nella memoria della macchina: le parti
## lontane dalla fossa dell'area bimbi restano nascoste e ferme (non si disegnano, quindi le loro pipeline non si
## compilano), alla prima entrata e dopo la ripartenza. Con l'argomento "corto": dal risveglio subito alla scia.
## Uso (cache degli shader vuota, sotto il render.lock):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/collaudo/presa_vulkan.gd corto

const NASCOSTE := ["Interni", "Tecnici", "Risalita", "Piscina", "Polaroid", "BambiniBalconata", "Sala/Cupola", "Sala/Piscina",
		"Sala/TorreScivoli", "Sala/Oggetti", "Sala/Dettagli", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "Sala/VascaCentrale"]


func _ready() -> void:
	get_tree().node_added.connect(_su_nodo)
	super._ready()


func _su_nodo(n: Node) -> void:
	var sala := n.get_parent()
	if sala == null:
		return
	var nome := String(n.name)
	if sala.name == &"Sala" and sala.get_parent() and sala.get_parent().get_parent() == get_tree().root:
		nome = "Sala/" + nome
	elif sala.get_parent() != get_tree().root or sala.scene_file_path != LEVEL:
		return
	if nome in NASCOSTE and n is Node3D:
		(n as Node3D).visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED

extends MultiMeshInstance3D
## Le lampadine e i portalampade del portone (MultiMesh di genera_risorse.gd). Il buffer delle istanze si salvava tutto a
## zero (lo script gira senza disegnare niente, e il server grafico lo restituisce vuoto): nel gioco le lampadine non si
## vedevano. Le trasformazioni giuste sono anche nel meta "trasformazioni" della risorsa: qui si rimettono all'avvio.


func _ready() -> void:
	if multimesh == null:
		return
	var tr: Array = multimesh.get_meta(&"trasformazioni", [])
	for i in mini(tr.size(), multimesh.instance_count):
		multimesh.set_instance_transform(i, tr[i])

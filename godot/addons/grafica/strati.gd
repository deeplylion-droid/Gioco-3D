class_name Strati
## Il solo modo di cambiare gli strati ([member VisualInstance3D.layers]) e la maschera delle luci
## ([member Light3D.light_cull_mask]) di un nodo che è già nella scena (controllo della CI: tools/ci/strati_luci.py).
##
## Perché: il motore (Godot 4.7.2, renderer_scene_cull.cpp) stacca una mesh da una luce solo se ADESSO
## light_cull_mask & layers combaciano. In Forward+ cambiare i layers di una mesh non la stacca prima dalle luci (lo fa
## solo il renderer Mobile), e cambiare la light_cull_mask di una luce non stacca mai le mesh: se dopo il cambio non
## combaciano più, la mesh resta nella lista della luce anche quando viene liberata. In debug, alla liberazione della
## luce: "BUG, indexing did not unpair geometries from light"; in release, se la luce si usa ancora (le ombre), un
## puntatore a una mesh già liberata, cioè il segfault delle ripartenze della 0.3.17 (pila di debug del 31 ottobre).
##
## Qui il nodo si nasconde al motore (instance_set_visible: stacca tutto con le maschere vecchie), si cambia, e si
## rimostra com'era davvero (si riaccoppia con le nuove al prossimo aggiornamento). Ai nodi non arriva nessuna notifica
## e sullo schermo non cambia niente: è tutto nello stesso fotogramma.


## Mette gli strati [param valore] a [param vi] (una mesh, una luce, una decal...).
static func metti(vi: VisualInstance3D, valore: int) -> void:
	if vi == null or vi.layers == valore:
		return
	if not vi.is_inside_tree():
		vi.layers = valore   # (fuori dalla scena il motore non l'ha accoppiata a niente)
		return
	var rid := vi.get_instance()
	RenderingServer.instance_set_visible(rid, false)
	vi.layers = valore
	RenderingServer.instance_set_visible(rid, vi.is_visible_in_tree())


## Mette la maschera [param valore] alla luce [param luce].
static func maschera_luce(luce: Light3D, valore: int) -> void:
	if luce == null or luce.light_cull_mask == valore:
		return
	if not luce.is_inside_tree():
		luce.light_cull_mask = valore
		return
	var rid := luce.get_instance()
	RenderingServer.instance_set_visible(rid, false)
	luce.light_cull_mask = valore
	RenderingServer.instance_set_visible(rid, luce.is_visible_in_tree())

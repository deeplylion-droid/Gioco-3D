extends Node
## Sonda: il tuffo di lei fotogramma per fotogramma (campana, testa, dita, punte più alte e più basse).
const LEVEL := "res://scenes/sala_principale.tscn"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lei := get_tree().current_scene.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	lei.distanza_presa = 0.0
	lei.call(&"_affaccia")
	for i in 10:
		await get_tree().physics_frame
	lei.call(&"_scivola")
	var sk := lei.medusa.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for f in 150:
		await get_tree().physics_frame
		if f % 4 != 0:
			continue
		var pp := lei.punti_corpo()
		var camp := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("campana")).origin
		var basse := 99.0
		var alte := -99.0
		for i in range(3, pp.size()):
			basse = minf(basse, pp[i].y)
			alte = maxf(alte, pp[i].y)
		var mi := lei.medusa.global_transform.affine_inverse()
		if pp.size() > 2:
			print("L %.2f testa %s dita L %s R %s" % [lei.get(&"_t"), (mi * pp[0]).snapped(Vector3.ONE * 0.01), (mi * pp[1]).snapped(Vector3.ONE * 0.01), (mi * pp[2]).snapped(Vector3.ONE * 0.01)])
		print("T %.2f fase %d campana %s testa %s dita %.2f/%.2f punte %.2f..%.2f entrata %s" % [lei.get(&"_t"), lei.fase, camp, pp[0] if pp.size() > 0 else Vector3.INF, pp[1].y if pp.size() > 2 else 0.0, pp[2].y if pp.size() > 2 else 0.0, basse, alte, lei.get(&"_testa_entrata")])
	get_tree().quit()

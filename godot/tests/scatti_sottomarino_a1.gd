extends "res://tests/scatti_sottomarino.gd"
## Scatti degli arredi di ambienti-1 nel tunnel sottomarino (tartaruga, reti, abisso, approdo), per il collaudo e i
## controlli della squadra. Come scatti_sottomarino.gd:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_sottomarino_a1.gd <cartella> [scatti separati da virgole]


func _init() -> void:
	# le scelte ancora aperte, per provarle (SCELTA_PESCI=A|B, SCELTA_ABISSO=A|B): di base spente
	SottomarinoArrediA1.scelta_pesci = OS.get_environment("SCELTA_PESCI")
	SottomarinoArrediA1.scelta_abisso = OS.get_environment("SCELTA_ABISSO")
	SCATTI = {
		"a1_pesci": [244.0, -1.0, 1.6, 262.0, 0.0, 2.4, 75.0],
		"a1_pesci_curva": [270.0, 1.0, 1.6, 290.0, 0.0, 2.4, 75.0],
		"a1_pesce_vicino": [246.0, 1.0, 1.6, 250.0, -1.0, 2.8, 60.0],
		"a1_oblo_grandi": [395.0, 0.0, 1.6, 412.0, 0.0, 2.6, 75.0],
		"a1_buco_volta": [343.0, 1.0, 1.6, 349.6, 1.0, 6.3, 70.0],
		"a1_buco_sotto": [349.6, -0.3, 1.6, 349.6, 1.0, 7.0, 75.0],
		"a1_tartaruga_arrivo": [352.0, 1.0, 1.6, 366.0, 0.0, 6.5, 75.0],
		"a1_tartaruga_sotto": [362.0, -1.0, 1.6, 366.0, 0.0, 6.4, 75.0],
		"a1_tartaruga_catene": [365.0, 0.0, 4.5, 366.0, 0.0, 7.3, 60.0],
		"a1_reti": [318.0, 1.0, 1.6, 326.0, -1.0, 2.6, 70.0],
		"a1_rete_vicino": [331.0, 1.0, 1.6, 333.5, 1.0, 2.7, 60.0],
		"a1_abisso": [392.0, -1.0, 1.6, 412.0, 0.0, 1.0, 75.0],
		"a1_abisso_curva": [440.0, 1.0, 1.6, 455.0, 0.0, 1.0, 75.0],
		"a1_approdo": [489.0, 1.0, 1.6, 505.0, 0.0, 1.8, 75.0],
		"a1_cartello": [488.0, 1.0, 1.6, 494.0, 1.0, 2.6, 60.0],
		"a1_bitta": [513.0, -1.0, 1.6, 517.0, -0.9, 0.0, 60.0],
		"a1_fanali": [520.0, 0.0, 1.6, 531.0, 0.0, 3.0, 75.0],
		"a1_salvagente": [505.0, 1.0, 1.6, 510.0, 1.0, 2.7, 60.0],
		"a1_vetrina_vuota": [476.0, -1.0, 1.6, 482.2, -1.0, 2.5, 70.0],
	}
	LEI = {}

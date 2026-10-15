extends Node
## Sequenza animata per Movie Maker (sala di prova): carrellate sulla vasca d'arrivo scura,
## la pozza che si svuota con il gorgo, la vasca bimbi che si riempie con la luce rosa sotto.
## Uso: godot --path labs/acqua --write-movie out.png --fixed-fps 24 --quit-after <fotogrammi>
##      -- --sequence=main

const CUTS := [
	# [inizio (s), posizione da, guarda da, posizione a, guarda a]
	[0.0, Vector3(10.0, 0.7, 4.2), Vector3(12.0, 0.0, -6.0), Vector3(11.0, 0.45, 2.0), Vector3(12.6, 0.0, -6.5)],
	[4.5, Vector3(-3.6, 1.9, 4.0), Vector3(0.0, -1.7, -3.6), Vector3(-1.4, 1.2, 0.8), Vector3(0.0, -1.75, -3.6)],
	[9.5, Vector3(-7.4, 1.0, 2.8), Vector3(-10.4, 0.1, -0.2), Vector3(-7.9, 0.75, 1.6), Vector3(-10.4, 0.1, -0.1)],
	[14.0, Vector3(10.6, -1.3, 2.4), Vector3(12.6, -0.9, -5.0), Vector3(11.4, -1.5, 0.4), Vector3(12.4, 0.2, -3.0)],
]
const LENGTH := 18.0

var t := 0.0
var demo: Node


func _ready() -> void:
	demo = get_parent()
	demo.flicker_enabled = true
	demo._next_flash = 2.0
	# stato iniziale: pozza piena, vasca bimbi vuota
	demo.kids.level = demo.kids.bottom + 0.02
	demo.puddle.level = -1.5
	var cam: Camera3D = demo.cam
	cam.enabled = false


func _process(delta: float) -> void:
	t += delta
	var cut: Array = CUTS[0]
	var next_start := LENGTH
	for i in CUTS.size():
		if t >= CUTS[i][0]:
			cut = CUTS[i]
			next_start = CUTS[i + 1][0] if i + 1 < CUTS.size() else LENGTH
	var k := clampf((t - float(cut[0])) / (next_start - float(cut[0])), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var pos: Vector3 = (cut[1] as Vector3).lerp(cut[3], k)
	var look: Vector3 = (cut[2] as Vector3).lerp(cut[4], k)
	demo.cam.global_position = pos
	demo.cam.look_at(look, Vector3.UP)
	# eventi
	if t > 5.0 and not demo.puddle.is_draining() and demo.puddle.level > demo.puddle.bottom + 0.05:
		demo.puddle.drain(0.03)
	if t > 9.6 and not demo.kids.is_filling() and demo.kids.level < demo.kids.max_level - 0.02:
		demo.kids.fill(0.05)
	if t > 1.0 and t < 1.1:
		demo.throw_ball(Vector3(11.6, 1.6, -1.0), Vector3(0.4, 1.0, -1.6))

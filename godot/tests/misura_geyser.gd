extends Node
## Quanto pesa in memoria la sequenza del geyser V1 (GeyserMesh.sequenza): memoria statica, memoria video
## e RSS del processo, prima e dopo. Serve il renderer vero per la memoria video.
## Uso: xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/misura_geyser.gd


func _ready() -> void:
	_run.call_deferred()


func _rss() -> float:
	var t := FileAccess.get_file_as_string("/proc/self/status")
	for r in t.split("\n"):
		if r.begins_with("VmRSS:"):
			return float(r.split_floats(" ", false)[0]) / 1024.0
	return 0.0


func _run() -> void:
	for i in 5:
		await get_tree().process_frame
	var s0 := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var v0 := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var r0 := _rss()
	var t0 := Time.get_ticks_msec()
	var seq := GeyserMesh.sequenza()
	var ms := Time.get_ticks_msec() - t0
	for i in 5:
		await get_tree().process_frame
	var vert := 0
	for m in seq:
		vert += (m as ArrayMesh).surface_get_array_len(0)
	print("MISURA %d fotogrammi, %d vertici, lettura %d ms: statica +%.1f MB, video +%.1f MB, RSS +%.1f MB" % [seq.size(), vert, ms,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0 - s0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0 - v0, _rss() - r0])
	get_tree().quit()

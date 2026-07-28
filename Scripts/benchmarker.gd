class_name Benchmarker
extends Node

# measures the performance of the simulation and saves the results

@export var output_path: String = "res://Benchmarking/benchmark.csv"

var recording: bool = false
var frame_times: Array[float] = []

func is_recording() -> bool:
	return recording

func start_new_measurement() -> void:
	recording = true
	frame_times.clear()

func measure(delta: float) -> void:
	if recording:
		frame_times.append(delta)

func stop_curr_measurement() -> void:
	recording = false
	save_csv()
	print_summary()

func save_csv() -> void:
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	file.store_line("frame,time_ms,fps")
	for i in range(frame_times.size()):
		var dt: float = frame_times[i]
		file.store_line("%d,%.6f,%.2f" % [i, dt * 1000.0, 1.0 / dt])

func print_summary() -> void:
	var total: float = 0.0
	var min_dt: float = INF
	var max_dt: float = 0.0
	
	for dt in frame_times:
		total += dt
		min_dt = min(min_dt, dt)
		max_dt = max(max_dt, dt)
	
	var avg_dt: float = total / frame_times.size()
	
	print()
	print("Frames:", frame_times.size())
	print("Average FPS:", 1.0 / avg_dt)
	print("Minimum FPS:", 1.0 / max_dt)
	print("Maximum FPS:", 1.0 / min_dt)

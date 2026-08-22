class_name Benchmarker
extends Node

# measures the performance and stability of the simulation and saves the results

@export var output_path_performance: String = "res://Benchmarking/benchmark-performance.csv"
@export var output_path_stability: String = "res://Benchmarking/benchmark-stability.csv"

var recording_performance: bool = false
var recording_stability: bool = false

var frame_times: Array[float] = []
var max_speeds: Array[float] = []
var avg_speeds: Array[float] = []
var speeds_percent_above_thres: Array[float] = []
var invalid_speed_values: Array[int] = []
var max_densities: Array[float] = []
var invalid_density_values: Array[int] = []

var STABILITY_TIMESTEP: float = 1.0 / 960.0
var STABILITY_SUBSTEPS: float = 8.0
var STABILITY_SPEED_THRES: float = 10.0

func is_recording_performance() -> bool:
	return recording_performance

func is_recording_stability() -> bool:
	return recording_stability

func start_new_performance_measurement() -> void:
	recording_performance = true
	frame_times.clear()

func start_new_stability_measurement() -> void:
	recording_stability = true
	max_speeds.clear()
	avg_speeds.clear()
	speeds_percent_above_thres.clear()
	invalid_speed_values.clear()
	max_densities.clear()
	invalid_density_values.clear()

func measure_performance(delta: float) -> void:
	if recording_performance:
		frame_times.append(delta)

func measure_stability(velocities: PackedVector2Array, densities: PackedFloat32Array) -> void:
	if recording_stability:
		var speed_count: int = velocities.size()
		var speed_sum: float = 0.0
		var speeds_above_thres: int = 0
		var max_speed: float = 0.0
		var invalid_speeds: int = 0
		var max_density: float = -INF
		var invalid_densities: int = 0
		
		for velocity in velocities:
			if is_nan(velocity.x) or is_inf(velocity.x) or is_nan(velocity.y) or is_inf(velocity.y):
				invalid_speeds += 1
				continue
			
			var speed: float = velocity.length()
			
			max_speed = max(max_speed, speed)
			speed_sum += speed
			
			if speed > STABILITY_SPEED_THRES:
				speeds_above_thres += 1
		
		for density in densities:
			if is_nan(density) or is_inf(density):
				invalid_densities += 1
				continue
			
			max_density = max(max_density, density)
		
		var average_speed: float = (speed_sum / speed_count) if (speed_count > 0) else 0.0
		
		var percent_above_thres: float = (100.0 * speeds_above_thres / speed_count) if (speed_count > 0) else 0.0
		
		max_speeds.append(max_speed)
		avg_speeds.append(average_speed)
		speeds_percent_above_thres.append(percent_above_thres)
		invalid_speed_values.append(invalid_speeds)
		max_densities.append(max_density)
		invalid_density_values.append(invalid_densities)

func stop_curr_performance_measurement() -> void:
	recording_performance = false
	save_performance_csv()
	print_performance_summary()

func stop_curr_stability_measurement() -> void:
	recording_stability = false
	save_stability_csv()
	print_stability_summary()

func save_performance_csv() -> void:
	var file: FileAccess = FileAccess.open(output_path_performance, FileAccess.WRITE)
	file.store_line("frame,time_ms,fps")
	for i in range(frame_times.size()):
		var dt: float = frame_times[i]
		file.store_line("%d,%.6f,%.2f" % [i, dt * 1000.0, 1.0 / dt])

func save_stability_csv() -> void:
	var file: FileAccess = FileAccess.open(output_path_stability, FileAccess.WRITE)
	file.store_line("invocation,max_speed,avg_speed,speed_percent_above_thres,invalid_speeds,max_density,invalid_densities")
	for i in range(max_speeds.size()):
		file.store_line("%d,%.6f,%.6f,%.6f,%d,%.6f,%d" % [i, max_speeds[i], avg_speeds[i], speeds_percent_above_thres[i], invalid_speed_values[i], max_densities[i], invalid_density_values[i]])

func print_performance_summary() -> void:
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

func print_stability_summary() -> void:
	print()
	print("Actual evaluated time: ", float(max_speeds.size()) * STABILITY_TIMESTEP * STABILITY_SUBSTEPS, " s")
	print("Max detected speed: ", max_speeds.max())
	print("Max detected density: ", max_densities.max())

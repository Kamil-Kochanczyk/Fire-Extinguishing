class_name FireExtinguishing
extends Node

@onready var fire_smoke: FireSmokeCompatible = $FireSmokeCompatible
@onready var water: WaterCompatible = $WaterCompatible
@onready var extinguish_mask_overlay: Sprite2D = $ExtinguishMaskOverlay

@export var eng_max_fps: int = 120

var fire_smoke_viewports: Array[SubViewport]
var water_viewports: Array[SubViewport]

func _ready() -> void:
	print("Max allowed FPS: ", eng_max_fps, "\n")
	Engine.max_fps = eng_max_fps
	
	#var plancks_law_image: Image = fire_smoke.generate_blackbody_lookup(512, 300.0, 2000.0, 1.0, 1e7, "res://Fire Color Spectrum/plancks_law_0.png")
	#plancks_law_texture_rect.texture = ImageTexture.create_from_image(plancks_law_image)
	
	fire_smoke.fire_smoke_ready()
	water.set_grid_to_particles_connection(fire_smoke.get_grid_to_particles_connection())
	
	water.water_ready()
	fire_smoke.set_particles_to_grid_connection(water.get_particles_to_grid_connection())
	
	fire_smoke.set_obstacle(water.get_obstacle())
	water.set_obstacle_sampler(fire_smoke.get_obstacle_sampler())
	
	fire_smoke.set_extinguishing_data(water.get_extinguishing_data())
	
	assert(water.viewport_size.x == fire_smoke.viewport_size.x and water.viewport_size.y == fire_smoke.viewport_size.y, "Fire, Smoke and Water must have the same viewport size")
	assert(water.pg_gp_size == fire_smoke.pg_gp_size, "Fire, Smoke and Water must have the same particles->grid and grid->particles viewports sizes (same PG/GP communication grid sizes)")
	assert((water.particle_temp_ambient == fire_smoke.smoke_temp_ambient) and (fire_smoke.smoke_temp_ambient == fire_smoke.fire_temp_ambient), "Ambient temperatures of fire, smoke and water must match")
	
	water.canvas_layer.visible = false
	
	extinguish_mask_overlay.texture = fire_smoke.extinguish_mask_overlay_viewport.get_texture()
	
	fire_smoke_viewports = fire_smoke.get_viewports()
	water_viewports = water.get_viewports()
	
	print("\nFire/Smoke viewports:")
	for v in fire_smoke_viewports:
		print(v.name)
		#v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	print("\nWater viewports:")
	for v in water_viewports:
		print(v.name)
		#v.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
	fire_smoke.fire_smoke_process(delta)
	
	# here we only want to await the rendering of fire/smoke viewports
	# but water contains viewports as well
	# and currently Godot only allows to await the rendering of all viewports
	# it doesn't allow to choose a subset of viewports to await for
	# thus awaiting means water viewports will be updates as well
	# but water viewports should be updated later
	# it means that we see water as it was in the previous frame
	# TODO: wait until Godot provides a mechanism to manually trigger chosen viewport's updates
	set_process(false)
	await RenderingServer.frame_post_draw
	#await get_tree().create_timer(1).timeout
	set_process(true)
	
	water.get_grid_data()
	water.water_process(delta)
	
	#benchmarker.measure_performance(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 or event.keycode == KEY_2 or event.keycode == KEY_3:
			fire_smoke.canvas_layer.visible = true
			water.canvas_layer.visible = false
		elif event.keycode == KEY_4:
			fire_smoke.canvas_layer.visible = false
			water.canvas_layer.visible = true
		elif event.keycode == KEY_V:
			extinguish_mask_overlay.visible = not extinguish_mask_overlay.visible
		#elif event.keycode == KEY_B:
			#if not benchmarker.is_recording_performance():
				#benchmarker.start_new_performance_measurement()
			#else:
				#benchmarker.stop_curr_performance_measurement()
		elif event.keycode == KEY_Q:
			get_tree().quit()

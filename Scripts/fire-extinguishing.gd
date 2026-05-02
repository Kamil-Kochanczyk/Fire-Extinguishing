class_name FireExtinguishing
extends Node

@onready var water: WaterCompatible = $WaterCompatible
@onready var fire_smoke: FireSmokeCompatible = $FireSmokeCompatible

@onready var tmp_display: Sprite2D = $TmpDisplay

func _ready() -> void:
	assert(water.viewport_size.x == fire_smoke.viewport_size.x and water.viewport_size.y == fire_smoke.viewport_size.y, "Fire, Smoke and Water must have the same viewport size")
	
	fire_smoke.fire_smoke_ready()
	water.set_grid_to_particles_connection(fire_smoke.get_grid_to_particles_connection())
	water.water_ready()
	fire_smoke.set_particles_to_grid_connection(water.get_particles_to_grid_connection())
	
	water.canvas_layer.visible = false
	
	tmp_display.texture = fire_smoke.particles_to_grid_viewport.get_texture()
	#tmp_display.texture = fire_smoke.grid_to_particles_viewport.get_texture()

func _process(delta: float) -> void:
	fire_smoke.fire_smoke_process(delta)
	await RenderingServer.frame_post_draw
	water.get_grid_data()
	water.water_process(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			fire_smoke.canvas_layer.visible = true
			water.canvas_layer.visible = false
		elif event.keycode == KEY_4:
			fire_smoke.canvas_layer.visible = false
			water.canvas_layer.visible = true

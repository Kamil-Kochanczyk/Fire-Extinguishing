class_name FireExtinguishing
extends Node

@onready var water: WaterCompatible = $WaterCompatible
@onready var fire_smoke: FireSmokeCompatible = $FireSmokeCompatible

func _ready() -> void:
	water.canvas_layer.visible = false

func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			fire_smoke.canvas_layer.visible = true
			water.canvas_layer.visible = false
		elif event.keycode == KEY_4:
			fire_smoke.canvas_layer.visible = false
			water.canvas_layer.visible = true

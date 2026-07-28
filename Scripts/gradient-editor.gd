class_name GradientEditor
extends Control

# position of a handle is expressed by the position of its top-left corner
# so we need to use an additional offset to make its position visually "centered"
# this offset is equal to the halfsize of the handle

@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var texture_rect: TextureRect = $HBoxContainer/VBoxContainer/TextureRect
@onready var handles_container: Control = $HBoxContainer/VBoxContainer/HandlesContainer
@onready var color_picker_button: ColorPickerButton = $HBoxContainer/MarginContainer/ColorPickerButton

var gradient: Gradient
var gradient_texture: GradientTexture1D
var gradient_texture_width: int = 256

var max_handles: int = 5
var handles: Array[CheckBox] = []
var curr_selected_handle: CheckBox = null

# gradient points are just indices
# if a handle jumps over another handle, then its corresponding index changes
# we need to keep track of the original index and the current index to update the gradient accordingly
var orig_gradient_point: int = -1
var curr_gradient_point: int = -1

# determines the number of handles that can be created/deleted at any given time
# deleted handles = inivisible handles
var total_invisible_handles: int = 0

var pos_x_min: float = -1.0
var pos_x_max: float = -1.0

var left_button_clicked: bool = false
var picking_color: bool = false
var spawn_queued: bool = false

@export var size_multiplier: float = 1.0

func _ready() -> void:
	assert(max_handles >= 2, "At least two handles are needed")
	
	texture_rect.custom_minimum_size *= size_multiplier
	texture_rect.size *= size_multiplier
	color_picker_button.custom_minimum_size *= size_multiplier
	color_picker_button.size *= size_multiplier
	
	pos_x_min = texture_rect.position.x
	pos_x_max = pos_x_min + texture_rect.size.x
	
	var handle_spacing: float = (pos_x_max - pos_x_min) / (max_handles - 1)
	
	var handle_0: CheckBox = CheckBox.new()
	handle_0.name = "Handle0"
	handle_0.button_group = ButtonGroup.new()
	handle_0.position = Vector2(0.0, 0.0)
	handle_0.position += get_centered_position_offset(handle_0)
	handles_container.add_child(handle_0)
	handles.append(handle_0)
	
	for i in range(1, max_handles):
		var handle_i: CheckBox = handle_0.duplicate()
		handle_i.name = "Handle" + str(i)
		handle_i.position = Vector2(0.0, 0.0)
		handle_i.position += get_centered_position_offset(handle_i)
		handle_i.position.x += i * handle_spacing
		handles_container.add_child(handle_i)
		handles.append(handle_i)
	
	for child: CheckBox in handles_container.get_children():
		child.toggled.connect(Callable(self, "_on_checkbox_toggled").bind(child))
		#print(child.name)
	#print()
	
	h_box_container.resized.connect(_on_hboxcontainer_resized)
	
	color_picker_button.focus_entered.connect(_on_colorpickerbutton_focus_entered)
	color_picker_button.focus_exited.connect(_on_colorpickerbutton_focus_exited)
	color_picker_button.color_changed.connect(_on_colorpickerbutton_color_changed)
	
	gradient = Gradient.new()
	
	#print(gradient.interpolation_color_space == Gradient.ColorSpace.GRADIENT_COLOR_SPACE_SRGB)
	#print(gradient.interpolation_mode == Gradient.InterpolationMode.GRADIENT_INTERPOLATE_LINEAR)
	#print()
	#
	#print(gradient.colors)
	#print(gradient.offsets)
	#print(gradient.get_point_count())
	#print()
	#
	#gradient.add_point(0.5, Color(0.0, 1.0, 0.0, 1.0))
	#
	#print(gradient.get_color(1))
	#print(gradient.get_offset(1))
	#print(gradient.colors)
	#print(gradient.offsets)
	#print(gradient.get_point_count())
	#print()
	#
	#gradient.remove_point(1)
	#
	#print(gradient.get_color(1))
	#print(gradient.get_offset(1))
	#print(gradient.colors)
	#print(gradient.offsets)
	#print(gradient.get_point_count())
	#print()
	
	gradient.set_color(0, Color(randf(), randf(), randf(), 1.0))
	gradient.set_offset(0, get_gradient_offset(handles[0]))
	
	for i in range(1, max_handles - 1):
		gradient.add_point(get_gradient_offset(handles[i]), Color(randf(), randf(), randf(), 1.0))
	
	gradient.set_color(max_handles - 1, Color(randf(), randf(), randf(), 1.0))
	gradient.set_offset(max_handles - 1, get_gradient_offset(handles[max_handles - 1]))
	
	#print(gradient.colors)
	#print(gradient.offsets)
	#print(gradient.get_point_count())
	#print()
	
	gradient_texture = GradientTexture1D.new()
	gradient_texture.width = gradient_texture_width
	gradient_texture.gradient = gradient
	
	texture_rect.texture = gradient_texture
	
	if size_multiplier == 1.0:
		# even if size hasn't changed, we force the root node to resize itself
		h_box_container.emit_signal("resized")

func _process(_delta: float) -> void:
	if left_button_clicked and (curr_selected_handle != null) and (not picking_color):
		var local_mouse_x = get_global_mouse_position().x - handles_container.get_global_rect().position.x
		curr_selected_handle.position.x = get_corrected_position_x(curr_selected_handle, local_mouse_x) + get_centered_position_offset(curr_selected_handle).x
		
		curr_gradient_point = get_gradient_point(curr_selected_handle)
		
		if curr_gradient_point != orig_gradient_point:
			# handle jumped over another handle
			# gradient needs to be updated accordingly
			
			#print("Jumped over!")
			#print()
			
			# save the colors and offsets before swapping
			# _orig_offset guy is actually reduntant as it will be forgotten
			
			var orig_color = gradient.get_color(orig_gradient_point)
			var _orig_offset = gradient.get_offset(orig_gradient_point)
			
			var curr_color = gradient.get_color(curr_gradient_point)
			var curr_offset = gradient.get_offset(curr_gradient_point)
			
			# update the gradient
			# do it by swapping the colors and setting the correct offsets
			
			gradient.set_color(curr_gradient_point, orig_color)
			gradient.set_offset(curr_gradient_point, get_gradient_offset(curr_selected_handle))
			
			gradient.set_color(orig_gradient_point, curr_color)
			gradient.set_offset(orig_gradient_point, curr_offset)
			
			orig_gradient_point = curr_gradient_point
		else:
			gradient.set_offset(curr_gradient_point, get_gradient_offset(curr_selected_handle))
	else:
		if spawn_queued:
			#print('Trying to spawn...')
			
			for handle in handles:
				if not handle.visible:
					# found some invisible (unused) handle -> spawn possible
					var local_mouse_x = get_global_mouse_position().x - handles_container.get_global_rect().position.x
					handle.position.x = get_corrected_position_x(handle, local_mouse_x) + get_centered_position_offset(handle).x
					var handle_offset = get_gradient_offset(handle)
					var handle_color = gradient.sample(handle_offset)
					gradient.add_point(handle_offset, handle_color)
					handle.visible = true
					total_invisible_handles -= 1
					break
			
			spawn_queued = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			left_button_clicked = true
			if curr_selected_handle != null:
				var cursor_within_1: bool = curr_selected_handle.get_global_rect().has_point(get_global_mouse_position())
				var cursor_within_2: bool = color_picker_button.get_global_rect().has_point(get_global_mouse_position())
				if (not cursor_within_1) and (not cursor_within_2):
					# deselect currently selected handle
					curr_selected_handle.button_pressed = false
			else:
				if texture_rect.get_global_rect().has_point(get_global_mouse_position()):
					# try to spawn a new handle
					spawn_queued = true
		else:
			left_button_clicked = false
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_DELETE:
			if (curr_selected_handle != null) and (total_invisible_handles < max_handles - 1):
				# at least one handle should always remain
				gradient.remove_point(get_gradient_point(curr_selected_handle))
				curr_selected_handle.visible = false
				curr_selected_handle.button_pressed = false
				total_invisible_handles += 1

func _on_hboxcontainer_resized() -> void:
	# resize the root node for its proper positioning inside other, external containers
	self.custom_minimum_size = h_box_container.size
	self.size = h_box_container.size

func _on_checkbox_toggled(toggled_on: bool, checkbox: CheckBox) -> void:
	if toggled_on:
		curr_selected_handle = checkbox
		orig_gradient_point = get_gradient_point(curr_selected_handle)
		curr_gradient_point = orig_gradient_point
		color_picker_button.color = gradient.sample(get_gradient_offset(curr_selected_handle))
		#print("Selected: " + checkbox.name)
	else:
		if checkbox == curr_selected_handle:
			curr_selected_handle = null
			#print("It's the currently selected handle!")
		#print("Deselected: " + checkbox.name)
	#print()

func _on_colorpickerbutton_focus_entered() -> void:
	picking_color = true

func _on_colorpickerbutton_focus_exited() -> void:
	picking_color = false

func _on_colorpickerbutton_color_changed(color: Color) -> void:
	color_picker_button.color = color
	if curr_selected_handle != null:
		gradient.set_color(get_gradient_point(curr_selected_handle), color)

func get_corrected_position_x(handle: CheckBox, uncorrected_position_x: float) -> float:
	var new_pos_x: float = min(max(uncorrected_position_x, pos_x_min), pos_x_max)
	
	for h in handles:
		if (h != handle) and h.visible:
			var left_bound: float = h.position.x
			var right_bound: float = h.position.x + h.size.x
			
			if (new_pos_x >= left_bound) and (new_pos_x <= right_bound):
				# handles overlapping -> do something about it
				
				var middle_bound: float = left_bound + (0.5 * (right_bound - left_bound))
				
				if new_pos_x < middle_bound:
					# snap to the left side
					if (left_bound >= pos_x_min) and (left_bound <= pos_x_max):
						new_pos_x = left_bound
				elif new_pos_x > middle_bound:
					# snap to the right side
					if (right_bound >= pos_x_min) and (right_bound <= pos_x_max):
						new_pos_x = right_bound
				else:
					# special case, needs to be handled separately to avoid overlapping at the boundaries of the gradient editor
					if get_gradient_offset(h) < 0.5:
						new_pos_x = right_bound
					else:
						new_pos_x = left_bound
	
	return new_pos_x

func get_gradient_offset(handle: CheckBox) -> float:
	return (handle.position.x - get_centered_position_offset(handle).x) / (pos_x_max - pos_x_min)

func get_centered_position_offset(handle: CheckBox) -> Vector2:
	return handle.size * (-0.5)

func get_gradient_point(handle: CheckBox) -> int:
	var point: int = 0
	for h in handles:
		if h.visible and (h.position.x < handle.position.x):
			point += 1
	return point

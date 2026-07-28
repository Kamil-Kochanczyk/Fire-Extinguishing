class_name GridVisualizer
extends Node2D

# visualizes the SPH neighborhood search grid and PG/GP communication grid
# useful for debugging if the intersection between the grids works as expected

func draw_grid(canvas: CanvasItem, grid_size: Vector2i, viewport_rect: Rect2, color: Color, line_width: float, draw_center_connections: bool = false) -> void:
	var cell_size_x = viewport_rect.size.x / grid_size.x
	var cell_size_y = viewport_rect.size.y / grid_size.y
	
	# vertical lines
	for x in range(grid_size.x + 1):
		var px = viewport_rect.position.x + x * cell_size_x
		canvas.draw_line(
			Vector2(px, viewport_rect.position.y),
			Vector2(px, viewport_rect.position.y + viewport_rect.size.y),
			color,
			line_width
		)
	
	# horizontal lines
	for y in range(grid_size.y + 1):
		var py = viewport_rect.position.y + y * cell_size_y
		canvas.draw_line(
			Vector2(viewport_rect.position.x, py),
			Vector2(viewport_rect.position.x + viewport_rect.size.x, py),
			color,
			line_width
		)
	
	# connections between neighboring cell centers
	if draw_center_connections:
		
		# horizontal center-to-center lines
		for y in range(grid_size.y):
			var cy = viewport_rect.position.y + (y + 0.5) * cell_size_y
			for x in range(grid_size.x - 1):
				var cx1 = viewport_rect.position.x + (x + 0.5) * cell_size_x
				var cx2 = viewport_rect.position.x + (x + 1.5) * cell_size_x
				canvas.draw_line(
					Vector2(cx1, cy),
					Vector2(cx2, cy),
					Color(1.0, 1.0, 0.0, 1.0),
					line_width
				)
		
		# vertical center-to-center lines
		for x in range(grid_size.x):
			var cx = viewport_rect.position.x + (x + 0.5) * cell_size_x
			for y in range(grid_size.y - 1):
				var cy1 = viewport_rect.position.y + (y + 0.5) * cell_size_y
				var cy2 = viewport_rect.position.y + (y + 1.5) * cell_size_y
				canvas.draw_line(
					Vector2(cx, cy1),
					Vector2(cx, cy2),
					Color(1.0, 1.0, 0.0, 1.0),
					line_width
				)

func _draw():
	var main_node = get_parent()
	var viewport_size = main_node.water.viewport_size
	var viewport_rect = Rect2(0.0, 0.0, viewport_size.x, viewport_size.y)
	var h = main_node.water.smoothing_radius
	var nsg_size_xy = int(floor(1.0 / h))
	var nsg_size = Vector2i(nsg_size_xy, nsg_size_xy)
	var pggpcg_size = main_node.water.pg_gp_size
	
	# neighborhood search grid
	draw_grid(self, nsg_size, viewport_rect, Color(1.0, 0.0, 0.0, 1.0), 1.0, false)
	
	# PG/GP communication grid
	draw_grid(self, pggpcg_size, viewport_rect, Color(0.0, 1.0, 0.0, 0.0), 1.0, true)    # only center connections
	#draw_grid(self, pggpcg_size, viewport_rect, Color(0.0, 1.0, 0.0, 1.0), 1.0, false)    # default

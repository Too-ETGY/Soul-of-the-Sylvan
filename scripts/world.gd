extends Node2D

## World rendering — draws fixed island terrain grid and manages 2x2 ecosystem visuals.

var _terrain_colors: Dictionary = {
	GridManager.Terrain.GRASS: Color(0.32, 0.58, 0.22),         # Grass green
	GridManager.Terrain.DIRT: Color(0.50, 0.38, 0.24),          # Dirt brown
	GridManager.Terrain.WATER_SOURCE: Color(0.22, 0.48, 0.62),   # Water blue
	GridManager.Terrain.ROCK: Color(0.38, 0.36, 0.35),          # Rock gray
}

# Preloaded ecosystem textures
var _ecosystem_textures: Dictionary = {}

@onready var ecosystem_container: Node2D = $EcosystemContainer


func _ready() -> void:
	# Preload ecosystem textures
	for eco_type in EcosystemData.get_all_types():
		var def := EcosystemData.get_def(eco_type)
		if def.texture_path != "":
			_ecosystem_textures[eco_type] = load(def.texture_path)

	# Connect signals
	GridManager.ecosystem_placed.connect(_on_ecosystem_placed)
	GridManager.ecosystem_removed.connect(_on_ecosystem_removed)

	# Force redraw for terrain
	queue_redraw()


func _draw() -> void:
	var cell_size := GridManager.CELL_SIZE

	for x in range(GridManager.GRID_WIDTH):
		for y in range(GridManager.GRID_HEIGHT):
			var cell := Vector2i(x, y)
			var terrain := GridManager.get_terrain(cell)
			var color: Color = _terrain_colors.get(terrain, Color.BLACK)

			# Per-cell natural variation
			var variation := (sin(float(x) * 3.7 + float(y) * 7.3) * 0.02)
			color = color.lightened(variation)

			var rect := Rect2(
				x * cell_size,
				y * cell_size,
				cell_size,
				cell_size
			)
			draw_rect(rect, color)

	# Draw subtle grid lines
	var grid_color := Color(0.0, 0.0, 0.0, 0.06)
	for x in range(GridManager.GRID_WIDTH + 1):
		var x_pos := float(x * cell_size)
		draw_line(
			Vector2(x_pos, 0),
			Vector2(x_pos, GridManager.GRID_HEIGHT * cell_size),
			grid_color, 1.0
		)
	for y in range(GridManager.GRID_HEIGHT + 1):
		var y_pos := float(y * cell_size)
		draw_line(
			Vector2(0, y_pos),
			Vector2(GridManager.GRID_WIDTH * cell_size, y_pos),
			grid_color, 1.0
		)


func _on_ecosystem_placed(cell: Vector2i, instance: EcosystemData.EcosystemInstance) -> void:
	var world_pos := GridManager.cell_to_world_2x2(cell)

	if instance.type == EcosystemData.Type.POND:
		# Procedural 2x2 pond visual
		var pond_node := Node2D.new()
		pond_node.position = world_pos
		pond_node.set_script(preload("res://scripts/pond_visual.gd"))
		ecosystem_container.add_child(pond_node)
		instance.node = pond_node
	else:
		# Sprite-based ecosystem covering 2x2 cells (128x128px)
		var sprite := Sprite2D.new()
		sprite.texture = _ecosystem_textures.get(instance.type)
		sprite.position = world_pos

		if sprite.texture:
			var tex_size := sprite.texture.get_size()
			var target_size := float(GridManager.CELL_SIZE) * 1.8
			var scale_factor := target_size / maxf(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)

		ecosystem_container.add_child(sprite)
		instance.node = sprite


func _on_ecosystem_removed(cell: Vector2i) -> void:
	var world_pos := GridManager.cell_to_world_2x2(cell)
	for child in ecosystem_container.get_children():
		if child.position.distance_to(world_pos) < 1.0:
			child.queue_free()
			break

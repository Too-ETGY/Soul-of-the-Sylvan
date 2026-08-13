extends Node2D

## World rendering — draws flat tilled dirt ground and transforms tiles to grass.
##
## TILESET CONFIGURATION:
const TILLED_DIRT_TEXTURE_PATH: String = "res://Asset/Tilesets/Tilled_Dirt_block.png"
const FOREST_TERRAIN_TEXTURE_PATH: String = "res://Asset/Pixel Lands Forest Demo/forest_demo_terrain.png"

# Color fallbacks if textures are not loaded
var _dirt_color: Color = Color(0.55, 0.42, 0.28)
var _grass_color: Color = Color(0.36, 0.62, 0.24)

var _dirt_texture: Texture2D
var _terrain_texture: Texture2D

@onready var ecosystem_container: Node2D = $EcosystemContainer


func _ready() -> void:
	# Load tileset textures if available
	if ResourceLoader.exists(TILLED_DIRT_TEXTURE_PATH):
		_dirt_texture = load(TILLED_DIRT_TEXTURE_PATH)
	if ResourceLoader.exists(FOREST_TERRAIN_TEXTURE_PATH):
		_terrain_texture = load(FOREST_TERRAIN_TEXTURE_PATH)

	# Connect signals
	GridManager.ecosystem_placed.connect(_on_ecosystem_placed)
	GridManager.ecosystem_removed.connect(_on_ecosystem_removed)
	GridManager.terrain_changed.connect(_on_terrain_changed)

	var tree := get_tree().root.find_child("SacredTree", true, false)
	if tree and tree.has_signal("restoration_changed"):
		tree.restoration_changed.connect(func(_p, _l): queue_redraw())

	queue_redraw()


func _draw() -> void:
	var cell_size := GridManager.CELL_SIZE

	var tree_restoration := 10.0
	var tree := get_tree().root.find_child("SacredTree", true, false)
	if tree and tree.has_method("get_restoration_percent"):
		tree_restoration = tree.get_restoration_percent()

	var dark_overlay := Color(0.0, 0.0, 0.0, 0.45)

	# Calculate source region for grass if terrain texture is loaded (16x16 frames)
	var src_rect_grass := Rect2()
	if _terrain_texture:
		var tex_w := _terrain_texture.get_width()
		var tex_h := _terrain_texture.get_height()
		var frame_w := tex_w / 16.0
		var frame_h := tex_h / 16.0
		src_rect_grass = Rect2(0.0, 0.0, frame_w, frame_h)

	for x in range(GridManager.GRID_WIDTH):
		for y in range(GridManager.GRID_HEIGHT):
			var cell := Vector2i(x, y)
			var terrain := GridManager.get_terrain(cell)
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)

			if terrain == GridManager.Terrain.GRASS:
				if _terrain_texture:
					draw_texture_rect_region(_terrain_texture, rect, src_rect_grass)
				else:
					draw_rect(rect, _grass_color)
			else:
				if _dirt_texture:
					draw_texture_rect(_dirt_texture, rect, false)
				else:
					draw_rect(rect, _dirt_color)

			# Darken unplantable locked cells
			if not GridManager.is_cell_in_allowed_region(cell, tree_restoration):
				draw_rect(rect, dark_overlay)

	# Subtle grid lines
	var grid_color := Color(0.0, 0.0, 0.0, 0.06)
	for x in range(GridManager.GRID_WIDTH + 1):
		var x_pos := float(x * cell_size)
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, GridManager.GRID_HEIGHT * cell_size), grid_color, 1.0)
	for y in range(GridManager.GRID_HEIGHT + 1):
		var y_pos := float(y * cell_size)
		draw_line(Vector2(0, y_pos), Vector2(GridManager.GRID_WIDTH * cell_size, y_pos), grid_color, 1.0)


func _on_terrain_changed(_cell: Vector2i, _new_terrain: GridManager.Terrain) -> void:
	queue_redraw()


func _on_ecosystem_placed(cell: Vector2i, instance: EcosystemData.EcosystemInstance, is_loading: bool = false) -> void:
	var pos := GridManager.cell_to_world_footprint(cell, instance.footprint_size)

	if is_loading:
		# Direct instant spawn for loaded game progress
		var scene_path: String = ""
		match instance.type:
			EcosystemData.Type.FOREST_GROVE:
				scene_path = "res://scenes/ecosystems/forest_grove.tscn"
			EcosystemData.Type.POND:
				scene_path = "res://scenes/ecosystems/pond.tscn"
			EcosystemData.Type.WILDFLOWERS:
				scene_path = "res://scenes/ecosystems/wildflowers.tscn"
			EcosystemData.Type.DENSE_FOREST:
				scene_path = "res://scenes/ecosystems/dense_forest.tscn"

		if scene_path != "" and ResourceLoader.exists(scene_path):
			var eco_scene: PackedScene = load(scene_path)
			var eco_node: Node2D = eco_scene.instantiate()
			eco_node.instance = instance
			eco_node.position = pos
			ecosystem_container.add_child(eco_node)
			instance.node = eco_node
	else:
		# Instantiate building site first for delay/progress bar during live gameplay
		var building_site_scene: PackedScene = load("res://scenes/building_site.tscn")
		if building_site_scene:
			var site: Node2D = building_site_scene.instantiate()
			site.position = pos
			site.setup(instance)
			ecosystem_container.add_child(site)


func _on_ecosystem_removed(cell: Vector2i) -> void:
	for child in ecosystem_container.get_children():
		if "instance" in child and child.instance == GridManager.get_ecosystem_at(cell):
			child.queue_free()
			break
		elif child.position.distance_to(GridManager.cell_to_world(cell)) < 64.0:
			child.queue_free()
			break

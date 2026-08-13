extends Node2D

## Handles 2x2 ecosystem placement — preview, 2x2 footprint, rule area overlay visual, validation, and confirmation.

var _selected_type: EcosystemData.Type = EcosystemData.Type.FOREST_GROVE
var _is_placing: bool = false
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _is_valid_placement: bool = false

@onready var preview_sprite: Sprite2D = $PreviewSprite
@onready var preview_pond: Node2D = $PreviewPond

# Preloaded textures for preview
var _preview_textures: Dictionary = {}

signal placement_completed(cell: Vector2i, eco_type: EcosystemData.Type)
signal placement_cancelled()


func _ready() -> void:
	# Preload textures
	for eco_type in EcosystemData.get_all_types():
		var def := EcosystemData.get_def(eco_type)
		if def.texture_path != "":
			_preview_textures[eco_type] = load(def.texture_path)

	preview_sprite.visible = false
	preview_pond.visible = false

	if preview_pond and preview_pond.get_child_count() == 0:
		var pond_scene: PackedScene = load("res://scenes/ecosystems/pond.tscn")
		if pond_scene:
			var pond_inst := pond_scene.instantiate()
			preview_pond.add_child(pond_inst)


func start_placement(eco_type: EcosystemData.Type) -> void:
	_selected_type = eco_type
	_is_placing = true
	_update_preview_texture()
	queue_redraw()


func stop_placement() -> void:
	_is_placing = false
	preview_sprite.visible = false
	preview_pond.visible = false
	queue_redraw()
	placement_cancelled.emit()


func is_placing() -> bool:
	return _is_placing


func _update_preview_texture() -> void:
	if _selected_type == EcosystemData.Type.POND:
		preview_sprite.visible = false
		preview_pond.visible = true
	else:
		preview_pond.visible = false
		preview_sprite.visible = true
		preview_sprite.texture = _preview_textures.get(_selected_type)
		if preview_sprite.texture:
			var tex_size := preview_sprite.texture.get_size()
			var target_size := float(GridManager.CELL_SIZE) * 1.8
			var scale_factor := target_size / maxf(tex_size.x, tex_size.y)
			preview_sprite.scale = Vector2(scale_factor, scale_factor)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_placing:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _is_valid_placement:
				_confirm_placement()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				stop_placement()


func _process(_delta: float) -> void:
	if not _is_placing:
		return

	var def := EcosystemData.get_def(_selected_type)

	# Get mouse position in world space
	var mouse_world := get_global_mouse_position()
	# Top-left anchor cell based on footprint offset
	var cell := GridManager.world_to_cell(mouse_world - Vector2((def.footprint_size.x * GridManager.CELL_SIZE) / 2.0, (def.footprint_size.y * GridManager.CELL_SIZE) / 2.0))

	if cell != _hovered_cell:
		_hovered_cell = cell
		_validate_current_cell()
		queue_redraw()

	# Center position of NxM ecosystem footprint
	var center_pos := GridManager.cell_to_world_footprint(cell, def.footprint_size)
	preview_sprite.global_position = center_pos
	preview_pond.global_position = center_pos

	# Color tinting based on validity
	var tint: Color
	if _is_valid_placement:
		tint = Color(0.4, 1.0, 0.4, 0.75)  # Green = valid
	else:
		tint = Color(1.0, 0.3, 0.3, 0.75)  # Red = invalid

	preview_sprite.modulate = tint
	preview_pond.modulate = tint


func _validate_current_cell() -> void:
	if not GridManager.is_valid_cell(_hovered_cell):
		_is_valid_placement = false
		return

	var tree_restoration := 10.0
	var tree := get_tree().root.find_child("SacredTree", true, false)
	if tree and tree.has_method("get_restoration_percent"):
		tree_restoration = tree.get_restoration_percent()

	var error := GridManager.validate_placement(_hovered_cell, _selected_type, tree_restoration)
	if error != "":
		_is_valid_placement = false
		return

	var def := EcosystemData.get_def(_selected_type)
	if not LifeForceManager.can_afford(def.life_force_cost):
		_is_valid_placement = false
		return

	_is_valid_placement = true


func _confirm_placement() -> void:
	var def := EcosystemData.get_def(_selected_type)

	if not LifeForceManager.spend(def.life_force_cost):
		return

	var instance := GridManager.place_ecosystem(_hovered_cell, _selected_type)
	if instance == null:
		LifeForceManager.add(def.life_force_cost)
		return

	placement_completed.emit(_hovered_cell, _selected_type)
	_validate_current_cell()
	queue_redraw()


## Draw the NxM cell placement footprint and checking area overlay rectangle.
func _draw() -> void:
	if not _is_placing or not GridManager.is_valid_cell(_hovered_cell):
		return

	var def := EcosystemData.get_def(_selected_type)
	var cell_size := float(GridManager.CELL_SIZE)
	var top_left := Vector2(_hovered_cell.x * cell_size, _hovered_cell.y * cell_size)
	var center_pos := GridManager.cell_to_world_footprint(_hovered_cell, def.footprint_size)

	# 1. Footprint (NxM cells rectangle)
	var foot_size := Vector2(def.footprint_size.x * cell_size, def.footprint_size.y * cell_size)
	var foot_color := Color(0.2, 0.9, 0.2, 0.25) if _is_valid_placement else Color(0.9, 0.2, 0.2, 0.25)
	var foot_border := Color(0.2, 0.9, 0.2, 0.8) if _is_valid_placement else Color(0.9, 0.2, 0.2, 0.8)

	draw_rect(Rect2(top_left, foot_size), foot_color)
	draw_rect(Rect2(top_left, foot_size), foot_border, false, 2.0)

	# 2. Rule / Grass Area overlay (Rectangle matching checking area)
	var area_top_left := Vector2(
		(_hovered_cell.x - def.margin_left) * cell_size,
		(_hovered_cell.y - def.margin_top) * cell_size
	)
	var area_span_x := float(def.footprint_size.x + def.margin_left + def.margin_right) * cell_size
	var area_span_y := float(def.footprint_size.y + def.margin_top + def.margin_bottom) * cell_size
	var area_rect := Rect2(area_top_left, Vector2(area_span_x, area_span_y))

	var area_color := Color(0.3, 0.8, 1.0, 0.1)
	var area_border := Color(0.3, 0.8, 1.0, 0.5)

	# Translucent rectangle showing the checking/grass area it takes
	draw_rect(area_rect, area_color)
	draw_rect(area_rect, area_border, false, 2.0)

	# Synergy connection lines to nearby existing ecosystems in range
	var nearby := GridManager.get_neighbors_for_type_at(_selected_type, _hovered_cell)
	for neighbor: EcosystemData.EcosystemInstance in nearby:
		var n_pos := GridManager.cell_to_world_footprint(neighbor.cell, neighbor.footprint_size)
		draw_line(center_pos, n_pos, Color(1.0, 0.9, 0.3, 0.6), 2.0)

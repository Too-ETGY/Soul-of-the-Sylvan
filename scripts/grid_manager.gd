extends Node

## Autoload: Manages world grid, flat dirt/grass terrain, 2x2 ecosystem placement,
## human occupation degradation, broken 3-day decay, and daily LF formula calculation.

const GRID_WIDTH: int = 48
const GRID_HEIGHT: int = 64
const CELL_SIZE: int = 64  # pixels per cell
const SACRED_TREE_CELL: Vector2i = Vector2i(24, 46)
const CITY_CELL: Vector2i = Vector2i(24, 16)
const CITY_RADIUS: float = 9.0

enum Terrain { TILLED_DIRT, GRASS, WATER, ASPHALT }

const TERRAIN_NAMES: Dictionary = {
	Terrain.TILLED_DIRT: "tilled_dirt",
	Terrain.GRASS: "grass",
	Terrain.WATER: "water",
	Terrain.ASPHALT: "asphalt",
}

## Grass transform area radius in cells around ecosystem anchor (default: 3).
## TO REVERT BACK TO 2x2, CHANGE GRASS_TRANSFORM_RADIUS TO 2.
const GRASS_TRANSFORM_RADIUS: int = 3

# Grid data: Vector2i -> Terrain type
var _terrain: Dictionary = {}
# Grid cell occupied mapping: Vector2i -> EcosystemData.EcosystemInstance
var _cell_ecosystem: Dictionary = {}
# Unique ecosystem instances: Vector2i (anchor cell) -> EcosystemData.EcosystemInstance
var _unique_ecosystems: Dictionary = {}

signal ecosystem_placed(cell: Vector2i, instance: EcosystemData.EcosystemInstance, is_loading: bool)
signal ecosystem_removed(cell: Vector2i)
signal ecosystem_broken(cell: Vector2i)
signal terrain_changed(cell: Vector2i, new_terrain: Terrain)


func _ready() -> void:
	_init_flat_dirt_map()
	DayCycle.day_passed.connect(_on_day_passed)


func _is_land_cell(cell: Vector2i) -> bool:
	var cx := float(GRID_WIDTH) / 2.0
	var dx := float(cell.x) - cx
	var y := float(cell.y)

	# Top border water
	if y < 4.0:
		return false

	# Bottom of island has no water - solid land all the way to the bottom edge
	if y >= 36.0:
		return true

	# From y=4 to y=36, land expands smoothly downwards
	var progress: float = (y - 4.0) / 32.0
	var max_half_width := 8.0 + 16.0 * sqrt(progress)

	if dx > 0.0:
		var right_limit := max_half_width * (0.88 + 0.12 * progress)
		return dx <= right_limit
	else:
		return absf(dx) <= max_half_width


func _init_flat_dirt_map() -> void:
	_terrain.clear()
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			if _is_land_cell(cell):
				if Vector2(cell).distance_to(Vector2(CITY_CELL)) <= CITY_RADIUS:
					_terrain[cell] = Terrain.ASPHALT
				else:
					_terrain[cell] = Terrain.TILLED_DIRT
			else:
				_terrain[cell] = Terrain.WATER


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func get_terrain(cell: Vector2i) -> Terrain:
	return _terrain.get(cell, Terrain.TILLED_DIRT) as Terrain


func get_terrain_name(cell: Vector2i) -> String:
	return TERRAIN_NAMES.get(get_terrain(cell), "tilled_dirt")


func is_cell_occupied(cell: Vector2i) -> bool:
	return _cell_ecosystem.has(cell)


func get_ecosystem_at(cell: Vector2i) -> EcosystemData.EcosystemInstance:
	return _cell_ecosystem.get(cell, null)


func get_all_ecosystems() -> Dictionary:
	return _unique_ecosystems


## Returns neighboring ecosystem instances within a given cell radius (from anchor cell).
func get_ecosystem_neighbors(anchor_cell: Vector2i, radius: int) -> Array:
	var results: Array = []
	var found_anchors: Dictionary = {}

	for dx in range(-radius, radius + 2):
		for dy in range(-radius, radius + 2):
			var check_cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if _cell_ecosystem.has(check_cell):
				var eco: EcosystemData.EcosystemInstance = _cell_ecosystem[check_cell]
				if eco.cell != anchor_cell and not found_anchors.has(eco.cell):
					found_anchors[eco.cell] = true
					results.append(eco)
	return results


## Returns all active (non-broken) ecosystem instances that overlap the given cell region.
func get_ecosystems_in_region(min_cell: Vector2i, max_cell: Vector2i, exclude_anchor: Vector2i) -> Array:
	var results: Array = []
	var found: Dictionary = {}
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if _cell_ecosystem.has(cell):
				var eco: EcosystemData.EcosystemInstance = _cell_ecosystem[cell]
				if eco.cell != exclude_anchor and not found.has(eco.cell):
					found[eco.cell] = true
					results.append(eco)
	return results


## Returns neighboring ecosystem instances within the checking area of the given instance.
func get_neighbors_for_instance(inst: EcosystemData.EcosystemInstance) -> Array:
	var def := EcosystemData.get_def(inst.type)
	var min_cell := Vector2i(inst.cell.x - def.margin_left, inst.cell.y - def.margin_top)
	var max_cell := Vector2i(inst.cell.x + def.footprint_size.x - 1 + def.margin_right, inst.cell.y + def.footprint_size.y - 1 + def.margin_bottom)
	return get_ecosystems_in_region(min_cell, max_cell, inst.cell)


## Returns neighboring ecosystem instances within the checking area of a hypothetical ecosystem type at cell.
func get_neighbors_for_type_at(type: EcosystemData.Type, cell: Vector2i) -> Array:
	var def := EcosystemData.get_def(type)
	var min_cell := Vector2i(cell.x - def.margin_left, cell.y - def.margin_top)
	var max_cell := Vector2i(cell.x + def.footprint_size.x - 1 + def.margin_right, cell.y + def.footprint_size.y - 1 + def.margin_bottom)
	return get_ecosystems_in_region(min_cell, max_cell, cell)


## Check if a cell is part of the 3x3 Sacred Tree footprint.
func is_cell_sacred_tree(cell: Vector2i) -> bool:
	return absi(cell.x - SACRED_TREE_CELL.x) <= 1 and absi(cell.y - SACRED_TREE_CELL.y) <= 1


## Get allowed plantable cell radius based on Sacred Tree restoration percent.
## < 40%: Level 0 (14 cells around Sacred Tree center)
## 40%..69%: Level 1 expansion (24 cells - covers full Sylvandrum Forest)
## >= 70%: Level 2 full access (999 cells)
func get_allowed_radius(restoration_percent: float) -> float:
	if restoration_percent >= 70.0:
		return 999.0  # Full forest up to city
	elif restoration_percent >= 40.0:
		return 24.0   # Level 1 expansion
	else:
		return 14.0   # Initial plantable forest area around Sacred Tree


func is_cell_in_allowed_region(cell: Vector2i, restoration_percent: float) -> bool:
	var terrain := get_terrain(cell)
	if terrain == Terrain.WATER or terrain == Terrain.ASPHALT:
		return false
	var allowed_r := get_allowed_radius(restoration_percent)
	if allowed_r >= 900.0:
		return true
	var tree_center := Vector2(SACRED_TREE_CELL)
	var dist := Vector2(cell).distance_to(tree_center)
	return dist <= allowed_r


## Check if an ecosystem can be placed starting at top-left anchor cell.
func validate_placement(anchor_cell: Vector2i, eco_type: EcosystemData.Type, tree_restoration: float = 10.0) -> String:
	var def := EcosystemData.get_def(eco_type)

	# Check Sacred Tree level unlock condition
	if tree_restoration < def.unlock_tree_percent:
		return "Requires Sacred Tree Restoration >= %.0f%%" % def.unlock_tree_percent

	var footprint := def.footprint_size

	for dx in range(footprint.x):
		for dy in range(footprint.y):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if not is_valid_cell(cell):
				return "Out of bounds"
			if is_cell_sacred_tree(cell):
				return "Cannot place on Sacred Tree"
			if get_terrain(cell) == Terrain.WATER:
				return "Cannot place on water"
			if get_terrain(cell) == Terrain.ASPHALT or Vector2(cell).distance_to(Vector2(CITY_CELL)) <= CITY_RADIUS:
				return "Cannot place inside Human City"
			if not is_cell_in_allowed_region(cell, tree_restoration):
				return "Area locked (Restore Sacred Tree to expand)"
			if is_cell_occupied(cell):
				return "Area is occupied"

	var min_dist := def.min_distance_same
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		if eco.type == eco_type and not eco.is_broken:
			var distance := Vector2(anchor_cell).distance_to(Vector2(eco.cell))
			if distance < float(min_dist + 1):
				return "Too close to another %s" % def.display_name

	return ""  # Valid


## Transform surrounding tilled dirt into grass around placed ecosystem based on its footprint and margins.
func _transform_surrounding_dirt_to_grass(anchor_cell: Vector2i, def: EcosystemData.EcosystemDef) -> void:
	for dx in range(-def.margin_left, def.footprint_size.x + def.margin_right):
		for dy in range(-def.margin_top, def.footprint_size.y + def.margin_bottom):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if is_valid_cell(cell):
				if get_terrain(cell) != Terrain.GRASS:
					_terrain[cell] = Terrain.GRASS
					terrain_changed.emit(cell, Terrain.GRASS)


## Check if a cell is covered by any active (non-broken) ecosystem's grass area that satisfies relationship rules.
func _is_cell_covered_by_any_active_ecosystem(cell: Vector2i) -> bool:
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		if eco.is_broken:
			continue
		var neighbors := get_neighbors_for_instance(eco)
		if not EcosystemData.has_valid_relationship(eco, neighbors):
			continue

		var def := EcosystemData.get_def(eco.type)
		var min_x := anchor.x - def.margin_left
		var max_x := anchor.x + def.footprint_size.x - 1 + def.margin_right
		var min_y := anchor.y - def.margin_top
		var max_y := anchor.y + def.footprint_size.y - 1 + def.margin_bottom

		if cell.x >= min_x and cell.x <= max_x and cell.y >= min_y and cell.y <= max_y:
			return true
	return false


## Revert grass tiles around an ecosystem back to tilled dirt if isolated.
func _revert_surrounding_grass_to_dirt(anchor_cell: Vector2i, def: EcosystemData.EcosystemDef) -> void:
	for dx in range(-def.margin_left, def.footprint_size.x + def.margin_right):
		for dy in range(-def.margin_top, def.footprint_size.y + def.margin_bottom):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if is_valid_cell(cell) and get_terrain(cell) == Terrain.GRASS:
				if not _is_cell_covered_by_any_active_ecosystem(cell):
					_terrain[cell] = Terrain.TILLED_DIRT
					terrain_changed.emit(cell, Terrain.TILLED_DIRT)


## Place an NxM ecosystem at anchor cell.
func place_ecosystem(anchor_cell: Vector2i, eco_type: EcosystemData.Type, is_loading: bool = false) -> EcosystemData.EcosystemInstance:
	var tree_restoration := 10.0
	var tree: Node = null
	if Engine.get_main_loop() is SceneTree:
		tree = (Engine.get_main_loop() as SceneTree).root.find_child("SacredTree", true, false)
	if tree and tree.has_method("get_restoration_percent"):
		tree_restoration = tree.get_restoration_percent()

	if not is_loading:
		var error := validate_placement(anchor_cell, eco_type, tree_restoration)
		if error != "":
			push_warning("Cannot place ecosystem: %s" % error)
			return null

	var def := EcosystemData.get_def(eco_type)
	var instance := EcosystemData.create_instance(eco_type, anchor_cell)
	_unique_ecosystems[anchor_cell] = instance

	for dx in range(def.footprint_size.x):
		for dy in range(def.footprint_size.y):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			_cell_ecosystem[cell] = instance

	var neighbors := get_neighbors_for_instance(instance)
	EcosystemData.apply_synergies(instance, neighbors)

	for neighbor: EcosystemData.EcosystemInstance in neighbors:
		var n_neighbors := get_neighbors_for_instance(neighbor)
		EcosystemData.apply_synergies(neighbor, n_neighbors)

	if is_loading:
		if EcosystemData.has_valid_relationship(instance, neighbors):
			_transform_surrounding_dirt_to_grass(anchor_cell, def)

	ecosystem_placed.emit(anchor_cell, instance, is_loading)
	return instance


## Called when ecosystem construction delay finishes.
## Checks relationship rules and transforms dirt to grass if satisfied.
func on_construction_completed(instance: EcosystemData.EcosystemInstance) -> void:
	if instance == null or instance.is_broken:
		return

	var neighbors := get_neighbors_for_instance(instance)
	var inst_def := EcosystemData.get_def(instance.type)

	# 1. Check if newly placed ecosystem satisfies relationship rules
	if EcosystemData.has_valid_relationship(instance, neighbors):
		_transform_surrounding_dirt_to_grass(instance.cell, inst_def)

	# 2. Check if any neighboring ecosystems NOW satisfy relationship rules
	for neighbor: EcosystemData.EcosystemInstance in neighbors:
		var n_neighbors := get_neighbors_for_instance(neighbor)
		if EcosystemData.has_valid_relationship(neighbor, n_neighbors):
			var n_def := EcosystemData.get_def(neighbor.type)
			_transform_surrounding_dirt_to_grass(neighbor.cell, n_def)


func restore_ecosystem_stats(inst: EcosystemData.EcosystemInstance) -> void:
	if inst == null:
		return
	inst.is_occupied_by_human = false
	inst.is_broken = false
	inst.days_broken = 0
	if inst.node:
		inst.node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var neighbors := get_neighbors_for_instance(inst)
	EcosystemData.apply_synergies(inst, neighbors)
	if EcosystemData.has_valid_relationship(inst, neighbors):
		var def := EcosystemData.get_def(inst.type)
		_transform_surrounding_dirt_to_grass(inst.cell, def)


func remove_ecosystem(anchor_cell: Vector2i) -> void:
	if not _unique_ecosystems.has(anchor_cell):
		return
	var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor_cell]
	var def := EcosystemData.get_def(eco.type)
	if eco.node and is_instance_valid(eco.node):
		eco.node.queue_free()
	_unique_ecosystems.erase(anchor_cell)

	for dx in range(def.footprint_size.x):
		for dy in range(def.footprint_size.y):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			_cell_ecosystem.erase(cell)

	_revert_surrounding_grass_to_dirt(anchor_cell, def)
	ecosystem_removed.emit(anchor_cell)


func clear_all() -> void:
	_unique_ecosystems.clear()
	_cell_ecosystem.clear()
	_init_flat_dirt_map()


## Handle daily ecosystem degradation, broken state, 3-day decay removal, and LF distribution.
func _on_day_passed(_day_number: int) -> void:
	var to_remove: Array[Vector2i] = []

	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]

		if eco.is_broken:
			eco.days_broken += 1
			if eco.days_broken >= 5:
				to_remove.append(anchor)
		elif eco.is_occupied_by_human:
			eco.biodiversity = max0(eco.biodiversity - 1)
			if eco.biodiversity <= 0 or eco.oxygen <= 0 or eco.water <= 0:
				eco.is_broken = true
				eco.is_occupied_by_human = false
				eco.days_broken = 0
				eco.oxygen = 0
				eco.water = 0
				eco.biodiversity = 0

				# Red visual tint for broken ecosystem
				if eco.node:
					eco.node.modulate = Color(0.9, 0.2, 0.2, 0.7)

				# Remove any human event targeting this ecosystem
				_cleanup_human_event_for_ecosystem(eco)

				# Revert grass if no valid relationship active
				var def := EcosystemData.get_def(eco.type)
				_revert_surrounding_grass_to_dirt(anchor, def)

				ecosystem_broken.emit(anchor)

	for anchor in to_remove:
		remove_ecosystem(anchor)

	# Distribute daily Life Force
	var daily_lf := calculate_daily_lf_generation()
	LifeForceManager.add(daily_lf)


func _cleanup_human_event_for_ecosystem(eco: EcosystemData.EcosystemInstance) -> void:
	var tree := Engine.get_main_loop()
	if tree and tree is SceneTree:
		var root := (tree as SceneTree).root
		var human_nodes := root.find_children("*", "Node2D", true, false)
		for node in human_nodes:
			if "target_ecosystem" in node and node.get("target_ecosystem") == eco:
				node.queue_free()


## Get accumulated forest stats from all active non-broken ecosystems.
func get_forest_stats() -> Dictionary:
	var stats := {"oxygen": 0, "water": 0, "biodiversity": 0}
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		if not eco.is_broken:
			stats["oxygen"] += eco.oxygen
			stats["water"] += eco.water
			stats["biodiversity"] += eco.biodiversity
	return stats


## Calculate total daily Life Force generation based on formula:
## Base 1 + (2 per active eco) + (2 per 20 stat pts) + (5 balance bonus if avg stat diff < 5)
func calculate_daily_lf_generation() -> int:
	var stats := get_forest_stats()
	var oxy: int = stats["oxygen"]
	var wat: int = stats["water"]
	var bio: int = stats["biodiversity"]

	var active_count: int = 0
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		if not eco.is_broken:
			active_count += 1

	var base_rate := 1
	var eco_bonus := active_count * 2
	var total_stat_pts := oxy + wat + bio
	@warning_ignore("integer_division")
	var stat_bonus := (total_stat_pts / 20) * 2

	var balance_bonus := 0
	if active_count > 0:
		var diff_ow := absf(float(oxy - wat))
		var diff_wb := absf(float(wat - bio))
		var diff_bo := absf(float(bio - oxy))
		var avg_diff := (diff_ow + diff_wb + diff_bo) / 3.0

		if avg_diff < 5.0:
			balance_bonus = 5

	return base_rate + eco_bonus + stat_bonus + balance_bonus


func get_total_lf_per_tick() -> int:
	return calculate_daily_lf_generation()


func max0(val: int) -> int:
	return val if val > 0 else 0


# --- Coordinate conversion ---
func world_to_cell(world_pos: Vector2) -> Vector2i:
	@warning_ignore("integer_division")
	var cx := int(world_pos.x) / CELL_SIZE
	@warning_ignore("integer_division")
	var cy := int(world_pos.y) / CELL_SIZE
	return Vector2i(cx, cy)


func cell_to_world_footprint(cell: Vector2i, footprint: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + float(footprint.x) / 2.0) * CELL_SIZE,
		(float(cell.y) + float(footprint.y) / 2.0) * CELL_SIZE
	)


func cell_to_world_2x2(cell: Vector2i) -> Vector2:
	return cell_to_world_footprint(cell, Vector2i(2, 2))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * CELL_SIZE) + float(CELL_SIZE) / 2.0,
		float(cell.y * CELL_SIZE) + float(CELL_SIZE) / 2.0
	)

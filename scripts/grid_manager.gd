extends Node

## Autoload: Manages world grid, flat dirt/grass terrain, 2x2 ecosystem placement,
## human occupation degradation, broken 3-day decay, and daily LF formula calculation.

const GRID_WIDTH: int = 64
const GRID_HEIGHT: int = 64
const CELL_SIZE: int = 64  # pixels per cell

enum Terrain { TILLED_DIRT, GRASS }

const TERRAIN_NAMES: Dictionary = {
	Terrain.TILLED_DIRT: "tilled_dirt",
	Terrain.GRASS: "grass",
}

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


func _init_flat_dirt_map() -> void:
	_terrain.clear()
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			_terrain[Vector2i(x, y)] = Terrain.TILLED_DIRT


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


## Get allowed plantable cell radius based on Sacred Tree restoration percent.
## < 40%: tiny radius (8 cells around center 32,32)
## 40%..69%: medium radius (18 cells)
## >= 70%: full map access
func get_allowed_radius(restoration_percent: float) -> float:
	if restoration_percent >= 70.0:
		return 999.0  # Full map
	elif restoration_percent >= 40.0:
		return 18.0
	else:
		return 8.0


func is_cell_in_allowed_region(cell: Vector2i, restoration_percent: float) -> bool:
	var allowed_r := get_allowed_radius(restoration_percent)
	if allowed_r >= 900.0:
		return true
	var tree_center := Vector2(32.0, 32.0)
	var dist := Vector2(cell).distance_to(tree_center)
	return dist <= allowed_r


## Check if a 2x2 ecosystem can be placed starting at top-left anchor cell.
func validate_placement(anchor_cell: Vector2i, eco_type: EcosystemData.Type, tree_restoration: float = 10.0) -> String:
	var def := EcosystemData.get_def(eco_type)

	for dx in range(2):
		for dy in range(2):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if not is_valid_cell(cell):
				return "Out of bounds"
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


## Transform surrounding tilled dirt into grass around placed ecosystem.
func _transform_surrounding_dirt_to_grass(anchor_cell: Vector2i, radius: int = 2) -> void:
	for dx in range(-radius, 2 + radius):
		for dy in range(-radius, 2 + radius):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if is_valid_cell(cell):
				if get_terrain(cell) != Terrain.GRASS:
					_terrain[cell] = Terrain.GRASS
					terrain_changed.emit(cell, Terrain.GRASS)


## Check if a cell is covered by any active (non-broken) ecosystem's grass area.
func _is_cell_covered_by_any_active_ecosystem(cell: Vector2i, radius: int = 2) -> bool:
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		if eco.is_broken:
			continue
		var min_x := anchor.x - radius
		var max_x := anchor.x + 1 + radius
		var min_y := anchor.y - radius
		var max_y := anchor.y + 1 + radius

		if cell.x >= min_x and cell.x <= max_x and cell.y >= min_y and cell.y <= max_y:
			return true
	return false


## Revert grass tiles around an ecosystem back to tilled dirt if isolated.
func _revert_surrounding_grass_to_dirt(anchor_cell: Vector2i, radius: int = 2) -> void:
	for dx in range(-radius, 2 + radius):
		for dy in range(-radius, 2 + radius):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if is_valid_cell(cell) and get_terrain(cell) == Terrain.GRASS:
				if not _is_cell_covered_by_any_active_ecosystem(cell, radius):
					_terrain[cell] = Terrain.TILLED_DIRT
					terrain_changed.emit(cell, Terrain.TILLED_DIRT)


## Place a 2x2 ecosystem at anchor cell.
func place_ecosystem(anchor_cell: Vector2i, eco_type: EcosystemData.Type, is_loading: bool = false) -> EcosystemData.EcosystemInstance:
	var error := validate_placement(anchor_cell, eco_type)
	if error != "":
		push_warning("Cannot place ecosystem: %s" % error)
		return null

	var instance := EcosystemData.create_instance(eco_type, anchor_cell)
	_unique_ecosystems[anchor_cell] = instance

	for dx in range(2):
		for dy in range(2):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			_cell_ecosystem[cell] = instance

	_transform_surrounding_dirt_to_grass(anchor_cell, 2)

	var neighbors := get_ecosystem_neighbors(anchor_cell, 4)
	EcosystemData.apply_synergies(instance, neighbors)

	for neighbor: EcosystemData.EcosystemInstance in neighbors:
		var n_neighbors := get_ecosystem_neighbors(neighbor.cell, 4)
		EcosystemData.apply_synergies(neighbor, n_neighbors)

	ecosystem_placed.emit(anchor_cell, instance, is_loading)
	return instance


func restore_ecosystem_stats(inst: EcosystemData.EcosystemInstance) -> void:
	if inst == null:
		return
	inst.is_occupied_by_human = false
	inst.is_broken = false
	inst.days_broken = 0
	if inst.node:
		inst.node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var neighbors := get_ecosystem_neighbors(inst.cell, 4)
	EcosystemData.apply_synergies(inst, neighbors)


func remove_ecosystem(anchor_cell: Vector2i) -> void:
	if not _unique_ecosystems.has(anchor_cell):
		return
	_unique_ecosystems.erase(anchor_cell)

	for dx in range(2):
		for dy in range(2):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			_cell_ecosystem.erase(cell)

	_revert_surrounding_grass_to_dirt(anchor_cell, 2)
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
			if eco.days_broken >= 3:
				to_remove.append(anchor)
		elif eco.is_occupied_by_human:
			eco.biodiversity = max0(eco.biodiversity - 1)
			if eco.biodiversity <= 0 or eco.oxygen <= 0 or eco.water <= 0:
				eco.is_broken = true
				eco.days_broken = 0
				# Visual tint for broken ecosystem
				if eco.node:
					eco.node.modulate = Color(0.8, 0.3, 0.3, 0.7)
				ecosystem_broken.emit(anchor)

	for anchor in to_remove:
		remove_ecosystem(anchor)

	# Distribute daily Life Force
	var daily_lf := calculate_daily_lf_generation()
	LifeForceManager.add(daily_lf)


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


func cell_to_world_2x2(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * CELL_SIZE) + float(CELL_SIZE),
		float(cell.y * CELL_SIZE) + float(CELL_SIZE)
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * CELL_SIZE) + float(CELL_SIZE) / 2.0,
		float(cell.y * CELL_SIZE) + float(CELL_SIZE) / 2.0
	)

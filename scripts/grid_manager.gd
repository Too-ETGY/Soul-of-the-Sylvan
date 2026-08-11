extends Node

## Autoload: Manages the world grid, fixed island terrain data, and 2x2 ecosystem placement.

const GRID_WIDTH: int = 64
const GRID_HEIGHT: int = 64
const CELL_SIZE: int = 64  # pixels per cell

# Cell terrain types
enum Terrain { GRASS, DIRT, WATER_SOURCE, ROCK }

const TERRAIN_NAMES: Dictionary = {
	Terrain.GRASS: "grass",
	Terrain.DIRT: "dirt",
	Terrain.WATER_SOURCE: "water_source",
	Terrain.ROCK: "rock",
}

# Grid data: Vector2i -> terrain type
var _terrain: Dictionary = {}
# Grid cell occupied mapping: Vector2i -> EcosystemData.EcosystemInstance
var _cell_ecosystem: Dictionary = {}
# Unique ecosystem instances: Vector2i (anchor cell) -> EcosystemData.EcosystemInstance
var _unique_ecosystems: Dictionary = {}

signal ecosystem_placed(cell: Vector2i, instance: EcosystemData.EcosystemInstance)
signal ecosystem_removed(cell: Vector2i)


func _ready() -> void:
	_generate_fixed_island_terrain()


## Generates a fixed, deterministic island map layout.
func _generate_fixed_island_terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 424242  # Fixed seed for consistent map layout
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.seed = 888888  # Fixed seed
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.04

	var center := Vector2(GRID_WIDTH / 2.0, GRID_HEIGHT / 2.0)
	var max_island_radius := 26.0

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			var dist := Vector2(x, y).distance_to(center)

			# Island boundary mask
			if dist > max_island_radius:
				_terrain[cell] = Terrain.ROCK
				continue

			var n: float = noise.get_noise_2d(float(x), float(y))
			var m: float = moisture_noise.get_noise_2d(float(x), float(y))

			# Guarantee Sacred Tree area (center) is buildable grass
			if dist < 4.0:
				_terrain[cell] = Terrain.GRASS
			elif n > 0.38:
				_terrain[cell] = Terrain.ROCK
			elif m > 0.25:
				_terrain[cell] = Terrain.WATER_SOURCE
			elif n > 0.05:
				_terrain[cell] = Terrain.DIRT
			else:
				_terrain[cell] = Terrain.GRASS


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func get_terrain(cell: Vector2i) -> Terrain:
	if _terrain.has(cell):
		return _terrain[cell] as Terrain
	return Terrain.ROCK


func get_terrain_name(cell: Vector2i) -> String:
	return TERRAIN_NAMES.get(get_terrain(cell), "rock")


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


## Check if a 2x2 ecosystem can be placed starting at top-left anchor cell.
func validate_placement(anchor_cell: Vector2i, eco_type: EcosystemData.Type) -> String:
	var def := EcosystemData.get_def(eco_type)

	# Check all 4 cells of the 2x2 footprint
	for dx in range(2):
		for dy in range(2):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			if not is_valid_cell(cell):
				return "Out of bounds"
			if is_cell_occupied(cell):
				return "Area is occupied"
			var t_name := get_terrain_name(cell)
			if not def.allowed_terrain.has(t_name):
				return "Requires %s land" % def.allowed_terrain[0]

	# Check minimum distance from same ecosystem type
	var min_dist := def.min_distance_same
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		if eco.type == eco_type:
			var distance := Vector2(anchor_cell).distance_to(Vector2(eco.cell))
			if distance < float(min_dist + 1):
				return "Too close to another %s" % def.display_name

	return ""  # Valid


## Place a 2x2 ecosystem at anchor cell.
func place_ecosystem(anchor_cell: Vector2i, eco_type: EcosystemData.Type) -> EcosystemData.EcosystemInstance:
	var error := validate_placement(anchor_cell, eco_type)
	if error != "":
		push_warning("Cannot place ecosystem: %s" % error)
		return null

	var instance := EcosystemData.create_instance(eco_type, anchor_cell)
	_unique_ecosystems[anchor_cell] = instance

	# Mark all 4 cells in 2x2 footprint
	for dx in range(2):
		for dy in range(2):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			_cell_ecosystem[cell] = instance

	# Apply synergies to the new ecosystem
	var neighbors := get_ecosystem_neighbors(anchor_cell, 4)
	EcosystemData.apply_synergies(instance, neighbors)

	# Recalculate synergies for nearby ecosystems
	for neighbor: EcosystemData.EcosystemInstance in neighbors:
		var n_neighbors := get_ecosystem_neighbors(neighbor.cell, 4)
		EcosystemData.apply_synergies(neighbor, n_neighbors)

	ecosystem_placed.emit(anchor_cell, instance)
	return instance


func remove_ecosystem(anchor_cell: Vector2i) -> void:
	if not _unique_ecosystems.has(anchor_cell):
		return
	_unique_ecosystems.erase(anchor_cell)

	for dx in range(2):
		for dy in range(2):
			var cell := Vector2i(anchor_cell.x + dx, anchor_cell.y + dy)
			_cell_ecosystem.erase(cell)

	ecosystem_removed.emit(anchor_cell)


## Get accumulated forest stats from all unique placed ecosystems.
func get_forest_stats() -> Dictionary:
	var stats := {"oxygen": 0, "water": 0, "biodiversity": 0}
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		stats["oxygen"] += eco.oxygen
		stats["water"] += eco.water
		stats["biodiversity"] += eco.biodiversity
	return stats


## Get total LF generation per tick from all unique ecosystems.
func get_total_lf_per_tick() -> int:
	var total := 0
	for anchor: Vector2i in _unique_ecosystems:
		var eco: EcosystemData.EcosystemInstance = _unique_ecosystems[anchor]
		total += eco.lf_per_tick
	return total


# --- Coordinate conversion ---
func world_to_cell(world_pos: Vector2) -> Vector2i:
	@warning_ignore("integer_division")
	var cx := int(world_pos.x) / CELL_SIZE
	@warning_ignore("integer_division")
	var cy := int(world_pos.y) / CELL_SIZE
	return Vector2i(cx, cy)


## World position for center of 2x2 ecosystem anchored at cell
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

class_name EcosystemData
extends RefCounted

## Defines all ecosystem types and their properties.

enum Type { FOREST_GROVE, POND, WILDFLOWERS }

# --- Ecosystem definition structure ---
class EcosystemDef:
	var type: Type
	var display_name: String
	var life_force_cost: int
	var allowed_terrain: Array[String]
	var min_distance_same: int
	var base_oxygen: int
	var base_water: int
	var base_biodiversity: int
	var lf_per_tick: int
	var texture_path: String

# --- Placed ecosystem instance ---
class EcosystemInstance:
	var type: Type
	var cell: Vector2i
	var oxygen: int
	var water: int
	var biodiversity: int
	var lf_per_tick: int
	var node: Node2D  # reference to visual node in world

	var is_occupied_by_human: bool = false
	var is_broken: bool = false
	var days_broken: int = 0

	func get_total_stats() -> Dictionary:
		if is_broken:
			return {"oxygen": 0, "water": 0, "biodiversity": 0}
		return {
			"oxygen": oxygen,
			"water": water,
			"biodiversity": biodiversity,
		}

# --- Static definitions ---
static var definitions: Dictionary = {}

static func _ensure_initialized() -> void:
	if definitions.size() > 0:
		return

	var grove := EcosystemDef.new()
	grove.type = Type.FOREST_GROVE
	grove.display_name = "Forest Grove"
	grove.life_force_cost = 15
	grove.allowed_terrain = ["grass", "tilled_dirt"]
	grove.min_distance_same = 2
	grove.base_oxygen = 7
	grove.base_water = 3
	grove.base_biodiversity = 5
	grove.lf_per_tick = 2
	grove.texture_path = "res://Asset/tree_assets/Curved_tree1.png"
	definitions[Type.FOREST_GROVE] = grove

	var pond := EcosystemDef.new()
	pond.type = Type.POND
	pond.display_name = "Pond"
	pond.life_force_cost = 20
	pond.allowed_terrain = ["grass", "tilled_dirt"]
	pond.min_distance_same = 3
	pond.base_oxygen = 3
	pond.base_water = 10
	pond.base_biodiversity = 6
	pond.lf_per_tick = 3
	pond.texture_path = ""
	definitions[Type.POND] = pond

	var flowers := EcosystemDef.new()
	flowers.type = Type.WILDFLOWERS
	flowers.display_name = "Wildflowers"
	flowers.life_force_cost = 10
	flowers.allowed_terrain = ["grass", "tilled_dirt"]
	flowers.min_distance_same = 1
	flowers.base_oxygen = 2
	flowers.base_water = 2
	flowers.base_biodiversity = 8
	flowers.lf_per_tick = 1
	flowers.texture_path = "res://Asset/tree_assets/Chanterelles1.png"
	definitions[Type.WILDFLOWERS] = flowers


static func get_def(type: Type) -> EcosystemDef:
	_ensure_initialized()
	return definitions[type]


static func get_all_types() -> Array:
	return [Type.FOREST_GROVE, Type.POND, Type.WILDFLOWERS]


static func create_instance(type: Type, cell: Vector2i) -> EcosystemInstance:
	_ensure_initialized()
	var def := get_def(type)
	var inst := EcosystemInstance.new()
	inst.type = type
	inst.cell = cell
	inst.oxygen = def.base_oxygen
	inst.water = def.base_water
	inst.biodiversity = def.base_biodiversity
	inst.lf_per_tick = def.lf_per_tick
	return inst


static func apply_synergies(inst: EcosystemInstance, neighbors: Array) -> void:
	if inst.is_broken:
		return

	_ensure_initialized()
	var def := get_def(inst.type)

	inst.oxygen = def.base_oxygen
	inst.water = def.base_water
	inst.biodiversity = def.base_biodiversity
	inst.lf_per_tick = def.lf_per_tick

	for neighbor: EcosystemInstance in neighbors:
		if neighbor.is_broken:
			continue
		match inst.type:
			Type.FOREST_GROVE:
				if neighbor.type == Type.POND:
					inst.biodiversity += 2
			Type.POND:
				if neighbor.type == Type.FOREST_GROVE:
					inst.water += 2
			Type.WILDFLOWERS:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE:
					inst.biodiversity += 3


## Checks if an ecosystem instance has satisfied relationship rules with any active neighbor.
static func has_valid_relationship(inst: EcosystemInstance, neighbors: Array) -> bool:
	if inst == null or inst.is_broken:
		return false

	for neighbor: EcosystemInstance in neighbors:
		if neighbor.is_broken:
			continue
		match inst.type:
			Type.FOREST_GROVE:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE:
					return true
			Type.POND:
				if neighbor.type == Type.FOREST_GROVE or neighbor.type == Type.WILDFLOWERS:
					return true
			Type.WILDFLOWERS:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE:
					return true
	return false

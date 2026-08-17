class_name EcosystemData
extends RefCounted

## Defines all ecosystem types and their properties.

enum Type { FOREST_GROVE, POND, WILDFLOWERS, DENSE_FOREST }

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

	# NxM Base Footprint and Rule Checking / Grass Area Margins
	var footprint_size: Vector2i = Vector2i(2, 2)
	var margin_left: int = 1
	var margin_right: int = 1
	var margin_top: int = 1
	var margin_bottom: int = 1

	# Progression & Info Card details
	var unlock_tree_percent: float = 0.0
	var description: String = ""
	var placement_rules: String = ""
	var relationships_info: String = ""

	func get_checking_area_size() -> Vector2i:
		return Vector2i(
			footprint_size.x + margin_left + margin_right,
			footprint_size.y + margin_top + margin_bottom
		)

# --- Placed ecosystem instance ---
class EcosystemInstance:
	var type: Type
	var cell: Vector2i
	var footprint_size: Vector2i = Vector2i(2, 2)
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

	# 1. Forest Grove (3x2 footprint, 5x4 checking area)
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
	grove.texture_path = "res://Asset/tree_assets/tree3.png"
	grove.footprint_size = Vector2i(3, 2)
	grove.margin_left = 1
	grove.margin_right = 1
	grove.margin_top = 1
	grove.margin_bottom = 1
	grove.unlock_tree_percent = 0.0
	grove.description = "A vibrant cluster of trees and vegetation that generates essential oxygen and supports local forest life."
	grove.placement_rules = "Must be placed on plantable land. Keep at least 2 cells away from another Forest Grove."
	grove.relationships_info = "• Near Pond → +2 Biodiversity\n• Near Dense Forest → +3 Oxygen\n• Near Forest Grove → Synergy growth"
	definitions[Type.FOREST_GROVE] = grove

	# 2. Pond (3x3 footprint, 5x5 checking area)
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
	pond.footprint_size = Vector2i(3, 3)
	pond.margin_left = 1
	pond.margin_right = 1
	pond.margin_top = 1
	pond.margin_bottom = 1
	pond.unlock_tree_percent = 0.0
	pond.description = "A tranquil body of fresh water sustaining aquatic flora, insects, and land animals."
	pond.placement_rules = "Requires open ground. Keep at least 3 cells away from another Pond."
	pond.relationships_info = "• Near Forest Grove → +2 Water\n• Near Wildflowers → +3 Biodiversity\n• Near Dense Forest → +3 Water"
	definitions[Type.POND] = pond

	# 3. Wildflowers (2x2 footprint, 4x4 checking area)
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
	flowers.texture_path = "res://Asset/tree_assets/flower.png"
	flowers.footprint_size = Vector2i(2, 2)
	flowers.margin_left = 1
	flowers.margin_right = 1
	flowers.margin_top = 1
	flowers.margin_bottom = 1
	flowers.unlock_tree_percent = 0.0
	flowers.description = "A colorful meadow patch attracting pollinators and boosting ecosystem biodiversity."
	flowers.placement_rules = "Requires open vegetation land. Keep at least 1 cell away from another Wildflower patch."
	flowers.relationships_info = "• Near Pond → +3 Biodiversity\n• Near Forest Grove → +2 Biodiversity\n• Near Dense Forest → +4 Biodiversity"
	definitions[Type.WILDFLOWERS] = flowers

	# 4. Dense Forest (4x4 footprint, 6x6 checking area, unlocked at 20% Sacred Tree)
	var dense := EcosystemDef.new()
	dense.type = Type.DENSE_FOREST
	dense.display_name = "Dense Forest"
	dense.life_force_cost = 35
	dense.allowed_terrain = ["grass", "tilled_dirt"]
	dense.min_distance_same = 3
	dense.base_oxygen = 14
	dense.base_water = 5
	dense.base_biodiversity = 12
	dense.lf_per_tick = 5
	dense.texture_path = "res://Asset/tree_assets/tree.png"
	dense.footprint_size = Vector2i(4, 4)
	dense.margin_left = 3
	dense.margin_right = 3
	dense.margin_top = 3
	dense.margin_bottom = 3
	dense.unlock_tree_percent = 20.0
	dense.description = "A mature, canopy-rich forest ecosystem generating massive Oxygen and Biodiversity. Unlocked at Sacred Tree Level 1 (20%)."
	dense.placement_rules = "Requires Sacred Tree restoration >= 20%.\nMust be placed on open forest land.\nKeep at least 3 cells away from another Dense Forest."
	dense.relationships_info = "• Near Pond → +4 Biodiversity\n• Near Forest Grove → +3 Oxygen\n• Near Dense Forest → +3 Oxygen"
	definitions[Type.DENSE_FOREST] = dense


static func get_def(type: Type) -> EcosystemDef:
	_ensure_initialized()
	return definitions[type]


static func get_all_types() -> Array:
	return [Type.FOREST_GROVE, Type.POND, Type.WILDFLOWERS, Type.DENSE_FOREST]


static func create_instance(type: Type, cell: Vector2i) -> EcosystemInstance:
	_ensure_initialized()
	var def := get_def(type)
	var inst := EcosystemInstance.new()
	inst.type = type
	inst.cell = cell
	inst.footprint_size = def.footprint_size
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
				elif neighbor.type == Type.DENSE_FOREST:
					inst.oxygen += 3
			Type.POND:
				if neighbor.type == Type.FOREST_GROVE:
					inst.water += 2
				elif neighbor.type == Type.DENSE_FOREST:
					inst.water += 3
			Type.WILDFLOWERS:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE:
					inst.biodiversity += 3
				elif neighbor.type == Type.DENSE_FOREST:
					inst.biodiversity += 4
			Type.DENSE_FOREST:
				if neighbor.type == Type.POND:
					inst.biodiversity += 4
				elif neighbor.type == Type.FOREST_GROVE or neighbor.type == Type.DENSE_FOREST:
					inst.oxygen += 3


## Checks if an ecosystem instance has satisfied relationship rules with any active neighbor.
static func has_valid_relationship(inst: EcosystemInstance, neighbors: Array) -> bool:
	if inst == null or inst.is_broken:
		return false

	for neighbor: EcosystemInstance in neighbors:
		if neighbor.is_broken:
			continue
		match inst.type:
			Type.FOREST_GROVE:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE or neighbor.type == Type.DENSE_FOREST:
					return true
			Type.POND:
				if neighbor.type == Type.FOREST_GROVE or neighbor.type == Type.WILDFLOWERS or neighbor.type == Type.DENSE_FOREST:
					return true
			Type.WILDFLOWERS:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE or neighbor.type == Type.DENSE_FOREST:
					return true
			Type.DENSE_FOREST:
				if neighbor.type == Type.POND or neighbor.type == Type.FOREST_GROVE or neighbor.type == Type.DENSE_FOREST:
					return true
	return false

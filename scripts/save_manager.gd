extends Node

## Autoload: Manages game state persistence (saving and loading to user://save_game.json).

const SAVE_FILE_PATH: String = "user://save_game.json"

signal game_saved()
signal game_loaded()
signal progress_reset()


func save_game() -> void:
	var save_data := {
		"life_force": LifeForceManager.get_life_force(),
		"day_number": DayCycle.get_day_number(),
		"sacred_tree_restoration": 0.0,
		"human_awareness": 0.0,
		"ecosystems": []
	}

	# Get Sacred Tree restoration % if available
	var tree := get_tree().root.find_child("SacredTree", true, false)
	if tree and tree.has_method("get_restoration_percent"):
		save_data["sacred_tree_restoration"] = tree.get_restoration_percent()

	# Get Human Awareness if available
	var main := get_tree().root.find_child("Main", true, false)
	if main and "human_awareness" in main:
		save_data["human_awareness"] = main.human_awareness

	# Serialize ecosystems
	var all_ecos := GridManager.get_all_ecosystems()
	for anchor: Vector2i in all_ecos:
		var eco: EcosystemData.EcosystemInstance = all_ecos[anchor]
		save_data["ecosystems"].append({
			"cell_x": anchor.x,
			"cell_y": anchor.y,
			"type": eco.type,
			"is_broken": eco.is_broken,
			"days_broken": eco.days_broken,
			"is_occupied_by_human": eco.is_occupied_by_human
		})

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(save_data, "  ")
		file.store_string(json_string)
		file.close()
		game_saved.emit()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return false

	var save_data: Dictionary = json.get_data()

	var main := get_tree().root.find_child("Main", true, false)

	# Restore Life Force
	if save_data.has("life_force"):
		LifeForceManager._life_force = int(save_data["life_force"])
		LifeForceManager.life_force_changed.emit(LifeForceManager._life_force)

	# Restore Day Number
	if save_data.has("day_number"):
		DayCycle._day_number = int(save_data["day_number"])
		DayCycle.day_passed.emit(DayCycle._day_number)

	# Restore Sacred Tree %
	var tree := get_tree().root.find_child("SacredTree", true, false)
	if tree and tree.has_method("restore") and save_data.has("sacred_tree_restoration"):
		tree._restoration_percent = float(save_data["sacred_tree_restoration"])
		tree._update_visual()
		tree.restoration_changed.emit(tree._restoration_percent, tree.get_spirit_level())

	# Restore Ecosystems
	GridManager.clear_all()
	if save_data.has("ecosystems"):
		for eco_data in save_data["ecosystems"]:
			var cell := Vector2i(int(eco_data["cell_x"]), int(eco_data["cell_y"]))
			var eco_type: EcosystemData.Type = int(eco_data["type"]) as EcosystemData.Type
			var is_broken := bool(eco_data.get("is_broken", false))
			var days_broken := int(eco_data.get("days_broken", 0))
			var is_occupied_by_human := bool(eco_data.get("is_occupied_by_human", false))

			var inst := GridManager.place_ecosystem(cell, eco_type, true)
			if inst:
				inst.is_broken = is_broken
				inst.days_broken = days_broken
				inst.is_occupied_by_human = is_occupied_by_human

				if is_broken:
					# Instantly clear stats to 0
					inst.oxygen = 0
					inst.water = 0
					inst.biodiversity = 0
					if inst.node:
						inst.node.modulate = Color(0.9, 0.2, 0.2, 0.7)

				if is_occupied_by_human:
					if main and main.has_method("spawn_human_event_on"):
						main.call_deferred("spawn_human_event_on", inst)

	# Restore Human Awareness
	if main and "human_awareness" in main and save_data.has("human_awareness"):
		main.human_awareness = float(save_data["human_awareness"])

	game_loaded.emit()
	return true


func reset_progress() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)

	# Reset managers
	LifeForceManager._life_force = LifeForceManager.STARTING_LIFE_FORCE
	LifeForceManager.life_force_changed.emit(LifeForceManager._life_force)

	DayCycle._day_number = 1
	DayCycle._timer = 0.0

	GridManager.clear_all()
	progress_reset.emit()

	get_tree().paused = false
	get_tree().reload_current_scene()

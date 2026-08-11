extends Node2D

## Main scene — connects World, Camera, PlacementSystem, HUD, PauseMenu, SaveManager,
## daily Human Awareness decay (70% start -> -15%/day), and human spawning >= 15% tree restoration.

var human_awareness: float = 70.0

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var placement_system: Node2D = $PlacementSystem
@onready var hud: CanvasLayer = $HUD
@onready var sacred_tree: Sprite2D = $World/SacredTree
@onready var pause_menu: CanvasLayer = $PauseMenu


func _ready() -> void:
	# Wire up HUD connections
	hud.setup(placement_system, sacred_tree)

	# Connect placement & day signals
	placement_system.placement_completed.connect(_on_placement_completed)
	placement_system.placement_cancelled.connect(_on_placement_cancelled)
	DayCycle.day_passed.connect(_on_day_passed)

	# Try to load existing save file
	if SaveManager.load_game():
		hud.tooltip_label.text = "Game progress loaded!"

	_update_awareness_ui()


func _on_day_passed(day_number: int) -> void:
	# Human Awareness Decay: reduces by 1% every 2 days
	if day_number % 2 == 0:
		human_awareness = maxf(human_awareness - 1.0, 0.0)
		_update_awareness_ui()

	# Gate: Humans only spawn if Sacred Tree restoration is >= 15%
	if sacred_tree and sacred_tree.get_restoration_percent() >= 15.0:
		_check_and_spawn_human_event()

	SaveManager.save_game()


func _check_and_spawn_human_event() -> void:
	var all_ecos := GridManager.get_all_ecosystems()

	# Find unoccupied non-broken ecosystems
	var eligible: Array[EcosystemData.EcosystemInstance] = []
	for anchor: Vector2i in all_ecos:
		var eco: EcosystemData.EcosystemInstance = all_ecos[anchor]
		if not eco.is_broken and not eco.is_occupied_by_human:
			eligible.append(eco)

	if eligible.size() == 0:
		return  # All ecosystems already occupied or none built

	# Determine maximum allowed spawns in one day:
	# If awareness < 40%, up to 2 humans can spawn at a time (if eligible ecosystems exist).
	var max_spawns: int = 1
	if human_awareness < 40.0:
		max_spawns = 2

	var spawn_chance: float = (100.0 - human_awareness) / 100.0
	var spawned_any: bool = false

	for _i in range(max_spawns):
		if eligible.size() == 0:
			break
		if randf() <= spawn_chance:
			var idx := randi() % eligible.size()
			var target_eco := eligible[idx]
			eligible.remove_at(idx)

			var spawn_pos := GridManager.cell_to_world_2x2(target_eco.cell)
			var human_scene: PackedScene = load("res://scenes/human_event.tscn")
			if human_scene:
				var human: Node2D = human_scene.instantiate()
				human.position = spawn_pos
				human.setup_target(target_eco)
				human.event_resolved.connect(_on_human_event_resolved)
				world.add_child(human)
				spawned_any = true

	if spawned_any:
		hud.tooltip_label.text = "⚠️ Human(s) occupied ecosystem(s)!"


func _on_human_event_resolved(awareness_gain: float) -> void:
	human_awareness = minf(human_awareness + awareness_gain, 100.0)
	_update_awareness_ui()
	SaveManager.save_game()


func _update_awareness_ui() -> void:
	hud.update_human_awareness(human_awareness)


func _on_placement_completed(_cell: Vector2i, _eco_type: EcosystemData.Type) -> void:
	hud.tooltip_label.text = "Ecosystem planting started!"
	SaveManager.save_game()


func _on_placement_cancelled() -> void:
	hud.tooltip_label.text = ""

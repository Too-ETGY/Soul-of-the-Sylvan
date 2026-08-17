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
@onready var tutorial_overlay: CanvasLayer = $TutorialOverlay


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

	# Start background music loop 5 seconds after game starts
	AudioManager.start_bgm_delayed(5.0)

	if not SaveManager.has_completed_tutorial_1:
		_start_tutorial_sequence_1()


func _start_tutorial_sequence_1() -> void:
	var steps: Array[Dictionary] = [
		{
			"text": "I need to focus on restoring the balance, not destroying... Let's restore the Sacred Tree.",
			"target_node_path": "SacredTreePanel"
		},
		{
			"text": "The Sacred Tree is the heart of our forest. To restore it, we need to spend Life Force here.",
			"target_node_path": "SacredTreePanel"
		},
		{
			"text": "Life Force is the main energy... We need to gather as much of this as possible every day.",
			"target_node_path": "LeftSidebar"
		},
		{
			"text": "To gain more Life Force, we need to plant ecosystems...",
			"target_node_path": "BottomCenterPalette"
		},
		{
			"text": "Each ecosystem has a different stat...",
			"target_node_path": "BottomCenterPalette"
		},
		{
			"text": "Each ecosystem has special placement rules and relationships... Complete the relationships to gain extra stats!",
			"target_node_path": "BottomCenterPalette"
		},
		{
			"text": "Each planted ecosystem's stat is accumulated to be overall Forest Stats.",
			"target_node_path": "StatsPanel"
		},
		{
			"text": "The more Forest Stats affect gaining more LF... If balanced, we can get a bonus!",
			"target_node_path": "StatsPanel"
		},
		{
			"text": "Every day there is a chance an environmental event appears...",
			"target_node_path": "RightSidebar"
		},
		{
			"text": "The chance is portrayed by Human Awareness... The lesser it is, the higher the chance!",
			"target_node_path": "RightSidebar"
		}
	]

	tutorial_overlay.call_deferred("start_sequence", 1, steps)


func _on_day_passed(day_number: int) -> void:
	# Human Awareness Decay:
	# - Base (< 20% Sacred Tree): -1% every day
	# - Level 1 (>= 20% Sacred Tree): -3% every day
	# - Level 2 (>= 70% Sacred Tree): -5% every day
	var tree_pct: float = sacred_tree.get_restoration_percent() if sacred_tree else 10.0
	var decay_rate := 1.0
	if tree_pct >= 70.0:
		decay_rate = 5.0
	elif tree_pct >= 20.0:
		decay_rate = 3.0
	else:
		decay_rate = 1.0

	human_awareness = maxf(human_awareness - decay_rate, 0.0)
	_update_awareness_ui()

	# Gate: Humans only spawn starting after Day 5
	if day_number >= 5:
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
	# If awareness <= 50%, up to 2 humans can spawn at a time (if eligible ecosystems exist).
	var max_spawns: int = 1
	if human_awareness <= 50.0:
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

			spawn_human_event_on(target_eco)
			spawned_any = true

	if spawned_any:
		hud.tooltip_label.text = "⚠️ Human(s) occupied ecosystem(s)!"


func spawn_human_event_on(target_eco: EcosystemData.EcosystemInstance) -> void:
	var spawn_pos := GridManager.cell_to_world_footprint(target_eco.cell, target_eco.footprint_size)
	var human_scene: PackedScene = load("res://scenes/human_event.tscn")
	if human_scene:
		var human: Node2D = human_scene.instantiate()
		human.position = spawn_pos
		human.setup_target(target_eco)
		human.event_resolved.connect(_on_human_event_resolved)
		world.add_child(human)


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

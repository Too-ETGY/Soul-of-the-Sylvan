extends Node2D

## Main scene — assembles the game world, camera, placement system, and HUD.

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var placement_system: Node2D = $PlacementSystem
@onready var hud: CanvasLayer = $HUD
@onready var sacred_tree: Sprite2D = $World/SacredTree


func _ready() -> void:
	# Wire up HUD connections
	hud.setup(placement_system, sacred_tree)

	# Connect placement signals for tooltip clearing
	placement_system.placement_completed.connect(_on_placement_completed)
	placement_system.placement_cancelled.connect(_on_placement_cancelled)


func _on_placement_completed(_cell: Vector2i, _eco_type: EcosystemData.Type) -> void:
	hud.tooltip_label.text = "Ecosystem placed!"


func _on_placement_cancelled() -> void:
	hud.tooltip_label.text = ""

extends Node2D

## Human Event (Level 1) — Intruding human occupying a specific ecosystem.
## Clicking opens the Intimidate / Enlighten interaction window.

signal event_resolved(awareness_gain: float)

var target_ecosystem: EcosystemData.EcosystemInstance

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var dialog: CanvasLayer = $EventDialog
@onready var intimidate_btn: Button = $EventDialog/Panel/VBox/IntimidateButton
@onready var enlighten_btn: Button = $EventDialog/Panel/VBox/EnlightenButton
@onready var ignore_btn: Button = $EventDialog/Panel/VBox/IgnoreButton


func setup_target(eco: EcosystemData.EcosystemInstance) -> void:
	target_ecosystem = eco
	if target_ecosystem:
		target_ecosystem.is_occupied_by_human = true


func _ready() -> void:
	dialog.visible = false
	area.input_event.connect(_on_area_input_event)

	intimidate_btn.pressed.connect(_on_intimidate_pressed)
	enlighten_btn.pressed.connect(_on_enlighten_pressed)
	ignore_btn.pressed.connect(_on_ignore_pressed)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dialog.visible = true


func _on_intimidate_pressed() -> void:
	if LifeForceManager.spend(10):
		dialog.visible = false
		if target_ecosystem:
			target_ecosystem.is_occupied_by_human = false
			# Restore ecosystem stats when human is removed/resolved
			GridManager.restore_ecosystem_stats(target_ecosystem)
		event_resolved.emit(5.0)
		queue_free()


func _on_enlighten_pressed() -> void:
	if LifeForceManager.spend(25):
		dialog.visible = false
		if target_ecosystem:
			target_ecosystem.is_occupied_by_human = false
			# Restore ecosystem stats when human is removed/resolved
			GridManager.restore_ecosystem_stats(target_ecosystem)
		event_resolved.emit(15.0)
		queue_free()


func _on_ignore_pressed() -> void:
	dialog.visible = false

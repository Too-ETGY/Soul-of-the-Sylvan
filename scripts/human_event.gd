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

	# Pick random character variant row (0, 1, or 2)
	var row := randi() % 3
	sprite.frame = row * 3

	# Danger warning red tint & pulse
	sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_property(sprite, "modulate", Color(1.3, 0.2, 0.2, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(sprite, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Idle chopping/walking animation loop
	var anim_tween := create_tween().set_loops()
	anim_tween.tween_callback(func(): sprite.frame = row * 3 + 1).set_delay(0.35)
	anim_tween.tween_callback(func(): sprite.frame = row * 3 + 2).set_delay(0.35)
	anim_tween.tween_callback(func(): sprite.frame = row * 3).set_delay(0.35)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dialog.visible = true
		if not SaveManager.has_completed_tutorial_2:
			_start_tutorial_sequence_2()


func _start_tutorial_sequence_2() -> void:
	var tutorial_overlay := get_tree().root.find_child("TutorialOverlay", true, false)
	if not tutorial_overlay:
		return

	var steps: Array[Dictionary] = [
		{
			"text": "A human intruder has appeared in our forest...",
			"target_node_path": "Panel"
		},
		{
			"text": "We need to decide what to do—Intimidate them away, or Enlighten them to teach harmony...",
			"target_node_path": "VBox"
		},
		{
			"text": "If we don't act, there might be consequences every day, damaging our ecosystem stats!",
			"target_node_path": "DescLabel"
		}
	]

	tutorial_overlay.call_deferred("start_sequence", 2, steps)


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

extends CanvasLayer

## TutorialOverlay — Interactive tutorial manager with cutout masking, Syva speech bubble, and skip button.

signal tutorial_sequence_finished(sequence_id: int)

@onready var top_mask: ColorRect = $DarkOverlay/TopMask
@onready var bottom_mask: ColorRect = $DarkOverlay/BottomMask
@onready var left_mask: ColorRect = $DarkOverlay/LeftMask
@onready var right_mask: ColorRect = $DarkOverlay/RightMask
@onready var highlight_frame: Panel = $DarkOverlay/HighlightFrame

@onready var syva_portrait: TextureRect = $DialogueArea/SyvaPortrait
@onready var message_label: Label = $DialogueArea/SpeechBubble/VBox/Margin/InnerVBox/MessageLabel
@onready var skip_button: Button = $SkipButton
@onready var dark_overlay: Control = $DarkOverlay

var _steps: Array[Dictionary] = []
var _current_step_idx: int = 0
var _sequence_id: int = 1
var _target_node: Control = null
var _is_active: bool = false


func _ready() -> void:
	visible = false
	skip_button.pressed.connect(_on_skip_pressed)


func start_sequence(sequence_id: int, steps: Array[Dictionary]) -> void:
	_sequence_id = sequence_id
	_steps = steps
	_current_step_idx = 0
	_is_active = true
	visible = true
	get_tree().paused = true
	_show_step(0)


func _process(_delta: float) -> void:
	if _is_active and is_instance_valid(_target_node):
		_update_cutout_for_node(_target_node)


func _show_step(idx: int) -> void:
	if idx >= _steps.size():
		_finish_sequence()
		return

	var step := _steps[idx]
	message_label.text = step.get("text", "")

	var target_path: String = step.get("target_node_path", "")
	_target_node = null

	if not target_path.is_empty():
		var found_node := get_tree().root.find_child(target_path, true, false)
		if found_node is Control and found_node.is_visible_in_tree():
			_target_node = found_node

	if is_instance_valid(_target_node):
		_update_cutout_for_node(_target_node)
	else:
		_show_full_darkness()


func _update_cutout_for_node(node: Control) -> void:
	var view_size := get_viewport().get_visible_rect().size
	var padding := 6.0
	var node_rect := node.get_global_rect()

	var rx := maxf(node_rect.position.x - padding, 0.0)
	var ry := maxf(node_rect.position.y - padding, 0.0)
	var rw := minf(node_rect.size.x + (padding * 2.0), view_size.x - rx)
	var rh := minf(node_rect.size.y + (padding * 2.0), view_size.y - ry)

	top_mask.position = Vector2(0, 0)
	top_mask.size = Vector2(view_size.x, ry)

	bottom_mask.position = Vector2(0, ry + rh)
	bottom_mask.size = Vector2(view_size.x, maxf(view_size.y - (ry + rh), 0.0))

	left_mask.position = Vector2(0, ry)
	left_mask.size = Vector2(rx, rh)

	right_mask.position = Vector2(rx + rw, ry)
	right_mask.size = Vector2(maxf(view_size.x - (rx + rw), 0.0), rh)

	highlight_frame.visible = true
	highlight_frame.position = Vector2(rx, ry)
	highlight_frame.size = Vector2(rw, rh)


func _show_full_darkness() -> void:
	var view_size := get_viewport().get_visible_rect().size
	top_mask.position = Vector2(0, 0)
	top_mask.size = view_size

	bottom_mask.size = Vector2.ZERO
	left_mask.size = Vector2.ZERO
	right_mask.size = Vector2.ZERO

	highlight_frame.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		_next_step()


func _next_step() -> void:
	_current_step_idx += 1
	if _current_step_idx < _steps.size():
		_show_step(_current_step_idx)
	else:
		_finish_sequence()


func _on_skip_pressed() -> void:
	_finish_sequence()


func _finish_sequence() -> void:
	if not _is_active:
		return
	_is_active = false
	visible = false
	get_tree().paused = false

	if _sequence_id == 1:
		SaveManager.has_completed_tutorial_1 = true
	elif _sequence_id == 2:
		SaveManager.has_completed_tutorial_2 = true

	SaveManager.save_game()
	tutorial_sequence_finished.emit(_sequence_id)

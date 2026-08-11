extends CanvasLayer

## Pause Menu modal — Continue, Reset Progress, Exit Game.

@onready var continue_btn: Button = $Panel/VBox/ContinueButton
@onready var reset_btn: Button = $Panel/VBox/ResetButton
@onready var exit_btn: Button = $Panel/VBox/ExitButton


func _ready() -> void:
	visible = false
	continue_btn.pressed.connect(_on_continue_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)


func open() -> void:
	visible = true
	get_tree().paused = true
	SaveManager.save_game()  # Auto-save when pausing


func close() -> void:
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()


func _on_continue_pressed() -> void:
	close()


func _on_reset_pressed() -> void:
	close()
	SaveManager.reset_progress()


func _on_exit_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()

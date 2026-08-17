extends Control

## StoryScene — Displays story pages dynamically named by numbers (1, 2, 3...) inside Pages container.
## Tapping/clicking anywhere (outside Skip button) advances to the next page.
## The Skip button immediately finishes the story sequence and launches the main game.

@export var next_scene_path: String = "res://scenes/main.tscn"

@onready var pages_container: Control = $Pages
@onready var skip_button: Button = $SkipButton

var _pages: Array[Node] = []
var _current_index: int = 0
var _is_transitioning: bool = false


func _ready() -> void:
	# Load save game to check if story has already been completed
	SaveManager.load_game()

	if SaveManager.has_seen_story:
		_start_main_game()
		return

	skip_button.pressed.connect(_on_skip_pressed)

	_collect_and_sort_pages()

	if _pages.size() > 0:
		_show_page(0)
	else:
		_finish_story()


func _collect_and_sort_pages() -> void:
	_pages.clear()
	var raw_children := pages_container.get_children()

	# Filter and sort by integer name if valid, else fallback to standard order
	var page_entries: Array[Dictionary] = []
	for child in raw_children:
		var name_str := str(child.name)
		if name_str.is_valid_int():
			page_entries.append({
				"num": name_str.to_int(),
				"node": child
			})
		else:
			page_entries.append({
				"num": 9999,
				"node": child
			})

	page_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["num"] < b["num"]
	)

	for entry in page_entries:
		var node: Node = entry["node"]
		_pages.append(node)
		if node is Control:
			node.visible = false
		elif node is CanvasItem:
			node.visible = false


func _gui_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_page()
	elif event is InputEventScreenTouch and event.pressed:
		_next_page()


func _next_page() -> void:
	_current_index += 1
	if _current_index < _pages.size():
		_show_page(_current_index)
	else:
		_finish_story()


func _show_page(index: int) -> void:
	for i in range(_pages.size()):
		var page_node := _pages[i]
		if page_node is CanvasItem:
			page_node.visible = (i == index)


func _on_skip_pressed() -> void:
	_finish_story()


func _finish_story() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	SaveManager.has_seen_story = true
	SaveManager.save_game()
	_start_main_game()


func _start_main_game() -> void:
		get_tree().change_scene_to_file(next_scene_path)

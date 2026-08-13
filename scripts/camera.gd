extends Camera2D

## Camera with middle-mouse panning and scroll-wheel zoom.

const ZOOM_MIN: float = 0.8
const ZOOM_MAX: float = 2.5
const ZOOM_STEP: float = 0.1
const ZOOM_SMOOTH_SPEED: float = 10.0

var _is_panning: bool = false
var _target_zoom: float = 1.0
var _world_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER

	_world_size = Vector2(
		GridManager.GRID_WIDTH * GridManager.CELL_SIZE,
		GridManager.GRID_HEIGHT * GridManager.CELL_SIZE
	)

	limit_left = 0
	limit_top = 0
	limit_right = int(_world_size.x)
	limit_bottom = int(_world_size.y)

	_target_zoom = 1.0
	zoom = Vector2(_target_zoom, _target_zoom)

	# Start camera centered at the Sacred Tree
	position = GridManager.cell_to_world(GridManager.SACRED_TREE_CELL)


func _unhandled_input(event: InputEvent) -> void:
	# Middle mouse button for panning
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed

		# Scroll wheel for zoom
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_zoom = minf(_target_zoom + ZOOM_STEP, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_zoom = maxf(_target_zoom - ZOOM_STEP, ZOOM_MIN)

	# Mouse motion for panning
	if event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		position -= mm.relative / zoom


func _process(delta: float) -> void:
	# Smooth zoom
	var current_zoom := zoom.x
	var new_zoom := lerpf(current_zoom, _target_zoom, delta * ZOOM_SMOOTH_SPEED)
	zoom = Vector2(new_zoom, new_zoom)

	# Clamp position strictly to world bounds so viewport never views outside map
	var viewport_size := get_viewport_rect().size / zoom
	var half_vp := viewport_size / 2.0

	var min_x := minf(half_vp.x, _world_size.x / 2.0)
	var max_x := maxf(_world_size.x - half_vp.x, _world_size.x / 2.0)
	var min_y := minf(half_vp.y, _world_size.y / 2.0)
	var max_y := maxf(_world_size.y - half_vp.y, _world_size.y / 2.0)

	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, min_y, max_y)

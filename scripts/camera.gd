extends Camera2D

## Camera with middle-mouse panning and scroll-wheel zoom.

const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 0.1
const ZOOM_SMOOTH_SPEED: float = 10.0
const PAN_MARGIN: float = 32.0  # extra margin at world edges

var _is_panning: bool = false
var _target_zoom: float = 1.0
var _world_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_world_size = Vector2(
		GridManager.GRID_WIDTH * GridManager.CELL_SIZE,
		GridManager.GRID_HEIGHT * GridManager.CELL_SIZE
	)
	_target_zoom = 1.0
	zoom = Vector2(_target_zoom, _target_zoom)

	# Start camera at center of the world
	position = _world_size / 2.0


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

	# Clamp position to world bounds
	var viewport_size := get_viewport_rect().size / zoom
	var half_vp := viewport_size / 2.0

	position.x = clampf(position.x, half_vp.x - PAN_MARGIN, _world_size.x - half_vp.x + PAN_MARGIN)
	position.y = clampf(position.y, half_vp.y - PAN_MARGIN, _world_size.y - half_vp.y + PAN_MARGIN)

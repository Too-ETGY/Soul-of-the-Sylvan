extends Sprite2D

## Sacred Tree — restoration logic and visual feedback.
## Uses Mega_tree1.png. Modulates from dim/gray at 0% to full brightness at 100%.

const LF_COST_PER_PERCENT: int = 10  # Life Force to add 1% restoration
const SACRED_TREE_CELL: Vector2i = Vector2i(32, 32)  # Center of the map

var _restoration_percent: float = 0.0
var _spirit_level: int = 0

signal restoration_changed(percent: float, spirit_level: int)


func _ready() -> void:
	# Position at the center of the world
	position = GridManager.cell_to_world(SACRED_TREE_CELL)

	# Load texture
	texture = load("res://Asset/tree_assets/Mega_tree1.png")

	# Scale it to be larger than regular ecosystems (3x3 cells worth)
	if texture:
		var tex_size := texture.get_size()
		var target_size := float(GridManager.CELL_SIZE) * 3.0
		var scale_factor := target_size / maxf(tex_size.x, tex_size.y)
		scale = Vector2(scale_factor, scale_factor)

	_update_visual()


func get_restoration_percent() -> float:
	return _restoration_percent


func get_spirit_level() -> int:
	return _spirit_level


## Try to restore the Sacred Tree by spending Life Force.
## Returns true if successful.
func restore(amount_percent: float = 1.0) -> bool:
	var lf_cost := int(amount_percent * LF_COST_PER_PERCENT)

	if not LifeForceManager.spend(lf_cost):
		return false

	_restoration_percent = minf(_restoration_percent + amount_percent, 100.0)
	_update_spirit_level()
	_update_visual()
	restoration_changed.emit(_restoration_percent, _spirit_level)
	return true


func _update_spirit_level() -> void:
	var old_level := _spirit_level
	if _restoration_percent >= 90.0:
		_spirit_level = 3
	elif _restoration_percent >= 60.0:
		_spirit_level = 2
	elif _restoration_percent >= 30.0:
		_spirit_level = 1
	else:
		_spirit_level = 0

	if _spirit_level != old_level:
		print("Spirit Level increased to %d!" % _spirit_level)


func _update_visual() -> void:
	# Interpolate from gray/dim to full brightness
	var t := _restoration_percent / 100.0
	var brightness := lerpf(0.3, 1.0, t)

	# Gray at 0%, full color at 100% with greenish glow
	var color := Color(brightness, brightness, brightness)
	color.g = lerpf(brightness, brightness * 1.15, t)
	modulate = color

extends Sprite2D

## Sacred Tree — restoration logic, scaling cost, and visual feedback.
## Uses Mega_tree1.png. Modulates from dim/gray at 0% to full brightness at 100%.

## SCALING RESTORE COST CONFIGURATION:
## Start at 10%. Going from 10% -> 11% costs 5 LF.
## Each +1% restoration increases the LF cost by 1.
const START_PERCENT: float = 10.0
const BASE_RESTORE_COST: int = 5
var _restoration_percent: float = START_PERCENT
var _spirit_level: int = 0

signal restoration_changed(percent: float, spirit_level: int)


func _ready() -> void:
	# Position at the center of the world
	position = GridManager.cell_to_world(GridManager.SACRED_TREE_CELL)
	z_index = 10

	# Load texture
	texture = load("res://Asset/tree_assets/sacred_tree.png")

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


## Calculate Life Force cost for the next +1% restoration increment.
## Starts at 6 (5 + 1) for 10%->11%, then +2 for 11%->12%, +3 for 12%->13%, etc.
func get_next_restore_cost() -> int:
	var step := int(maxf(_restoration_percent - START_PERCENT, 0.0))
	var additional := int(float((step + 1) * (step + 2)) / 2.0)
	return BASE_RESTORE_COST + additional - 1


## Try to restore the Sacred Tree by +1% spending Life Force.
func restore(amount_percent: float = 1.0) -> bool:
	if _restoration_percent >= 100.0:
		return false

	var lf_cost := get_next_restore_cost()

	if not LifeForceManager.spend(lf_cost):
		return false

	_restoration_percent = minf(_restoration_percent + amount_percent, 100.0)
	_update_spirit_level()
	_update_visual()
	restoration_changed.emit(_restoration_percent, _spirit_level)
	return true


func _update_spirit_level() -> void:
	var old_level := _spirit_level
	if _restoration_percent >= 70.0:
		_spirit_level = 2
	elif _restoration_percent >= 20.0:
		_spirit_level = 1
	else:
		_spirit_level = 0

	if _spirit_level != old_level:
		print("Spirit Level updated to %d!" % _spirit_level)


func _update_visual() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)

extends Node

## Autoload: Day/night timer that drives Life Force generation.

const DAY_DURATION: float = 10.0  # seconds per day

var _day_number: int = 1
var _timer: float = 0.0

signal day_passed(day_number: int)


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= DAY_DURATION:
		_timer -= DAY_DURATION
		_advance_day()


func _advance_day() -> void:
	_day_number += 1

	# Generate Life Force from all ecosystems
	var lf_generated := GridManager.get_total_lf_per_tick()
	if lf_generated > 0:
		LifeForceManager.add(lf_generated)

	day_passed.emit(_day_number)


func get_day_number() -> int:
	return _day_number


func get_day_progress() -> float:
	return _timer / DAY_DURATION

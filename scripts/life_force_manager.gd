extends Node

## Autoload: Manages the Life Force resource.

const STARTING_LIFE_FORCE: int = 30

var _life_force: int = STARTING_LIFE_FORCE

signal life_force_changed(new_amount: int)
signal life_force_added(amount: int)


func _ready() -> void:
	life_force_changed.emit(_life_force)


func get_life_force() -> int:
	return _life_force


func spend(amount: int) -> bool:
	if amount > _life_force:
		return false
	_life_force -= amount
	life_force_changed.emit(_life_force)
	return true


func add(amount: int) -> void:
	_life_force += amount
	life_force_changed.emit(_life_force)
	life_force_added.emit(amount)


func can_afford(amount: int) -> bool:
	return _life_force >= amount

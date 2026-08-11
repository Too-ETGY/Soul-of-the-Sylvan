extends Node2D

## Building site — plays a 2.5s planting delay with a progress bar before spawning the real ecosystem scene.

const BUILD_TIME: float = 2.5

var _timer: float = 0.0
var _instance: EcosystemData.EcosystemInstance

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label


func setup(instance: EcosystemData.EcosystemInstance) -> void:
	_instance = instance


func _ready() -> void:
	progress_bar.max_value = BUILD_TIME
	progress_bar.value = 0.0
	label.text = "Planting..."


func _process(delta: float) -> void:
	_timer += delta
	progress_bar.value = _timer

	if _timer >= BUILD_TIME:
		_finish_building()


func _finish_building() -> void:
	set_process(false)

	# Instantiate the real ecosystem scene
	var scene_path: String = ""
	match _instance.type:
		EcosystemData.Type.FOREST_GROVE:
			scene_path = "res://scenes/ecosystems/forest_grove.tscn"
		EcosystemData.Type.POND:
			scene_path = "res://scenes/ecosystems/pond.tscn"
		EcosystemData.Type.WILDFLOWERS:
			scene_path = "res://scenes/ecosystems/wildflowers.tscn"

	if scene_path != "" and ResourceLoader.exists(scene_path):
		var eco_scene: PackedScene = load(scene_path)
		var eco_node: Node2D = eco_scene.instantiate()
		eco_node.position = position
		get_parent().add_child(eco_node)
		_instance.node = eco_node

	# Check relationship rules and trigger grass transformation after planting finishes
	GridManager.on_construction_completed(_instance)

	queue_free()

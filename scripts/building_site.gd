extends Node2D

## Building site — plays a 2.5s planting delay with a progress bar before spawning the real ecosystem scene.

const BUILD_TIME: float = 2.5

var _timer: float = 0.0
var _instance: EcosystemData.EcosystemInstance

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label


var syva_sprite: Sprite2D
var _base_scale := Vector2(1, 1)
var _hover_time: float = 0.0
var _ripple_timer: float = 0.0
var _ripples: Array = []


func setup(instance: EcosystemData.EcosystemInstance) -> void:
	_instance = instance


func _ready() -> void:
	progress_bar.max_value = BUILD_TIME
	progress_bar.value = 0.0
	label.text = "Growing..."
	
	# Reposition and style the label to float above Syva
	label.position = Vector2(-50, -75)
	var settings := LabelSettings.new()
	settings.font_size = 12
	settings.font_color = Color(0.4, 0.9, 0.5)
	settings.outline_color = Color(0.0, 0.1, 0.0, 0.8)
	settings.outline_size = 3
	label.label_settings = settings

	# Create Syva sprite dynamically
	syva_sprite = Sprite2D.new()
	var tex := load("res://Asset/Syva.png") as Texture2D
	if tex:
		syva_sprite.texture = tex
		var tex_size := tex.get_size()
		var target_h: float = 56.0
		var scale_factor := target_h / tex_size.y
		_base_scale = Vector2(scale_factor, scale_factor)
		syva_sprite.scale = _base_scale
	
	# Center and position Syva slightly upward so she hovers above cell center
	syva_sprite.position = Vector2(0, -20)
	add_child(syva_sprite)

	# Fade in Syva sprite
	syva_sprite.modulate.a = 0.0
	var spawn_tween := create_tween()
	spawn_tween.tween_property(syva_sprite, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	_timer += delta
	progress_bar.value = _timer

	# 1. Float/hover & breathing animations for Syva
	_hover_time += delta
	if syva_sprite:
		# Hover up and down
		syva_sprite.position.y = -20.0 + sin(_hover_time * 5.0) * 6.0
		# Breathing scale pulse
		var scale_pulse := 1.0 + sin(_hover_time * 8.0) * 0.04
		syva_sprite.scale = Vector2(_base_scale.x * scale_pulse, _base_scale.y * scale_pulse)

	# 2. Nature magic ripples
	_ripple_timer += delta
	if _ripple_timer >= 0.6:
		_ripple_timer = 0.0
		_ripples.append({"radius": 8.0, "alpha": 0.8})

	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i].radius += delta * 35.0
		_ripples[i].alpha -= delta * 0.75
		if _ripples[i].alpha <= 0.0:
			_ripples.remove_at(i)

	# Redraw for custom nature magic ripples on ground
	queue_redraw()

	if _timer >= BUILD_TIME:
		_finish_building()


func _draw() -> void:
	# Draw magic ripples on the ground
	for ripple in _ripples:
		var col := Color(0.3, 0.9, 0.4, ripple.alpha) # green nature magic
		draw_arc(Vector2.ZERO, ripple.radius, 0.0, TAU, 32, col, 2.0)


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
		EcosystemData.Type.DENSE_FOREST:
			scene_path = "res://scenes/ecosystems/dense_forest.tscn"

	if scene_path != "" and ResourceLoader.exists(scene_path):
		var eco_scene: PackedScene = load(scene_path)
		var eco_node: Node2D = eco_scene.instantiate()
		eco_node.instance = _instance
		eco_node.position = position
		get_parent().add_child(eco_node)
		_instance.node = eco_node

	# Check relationship rules and trigger grass transformation after planting finishes
	GridManager.on_construction_completed(_instance)

	queue_free()

extends Node2D

## Dense Forest ecosystem scene — high density mature tree canopy.

var instance: EcosystemData.EcosystemInstance

func _ready() -> void:
	LifeForceManager.life_force_added.connect(_on_life_force_added)


func _on_life_force_added(_amount: int) -> void:
	if instance and not instance.is_broken and not instance.is_occupied_by_human:
		play_generation_effect()


func play_generation_effect() -> void:
	# 1. Scale bounce effect
	var tween_scale := create_tween()
	tween_scale.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_scale.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Color glow flash
	var tween_color := create_tween()
	var flash_color := Color(1.2, 1.8, 1.2, 1.0)
	tween_color.tween_property(self, "modulate", flash_color, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_color.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 3. Spawn floating +LF text
	_spawn_floating_text()


func _spawn_floating_text() -> void:
	var label := Label.new()
	label.text = "+%d" % (instance.lf_per_tick if instance else 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings := LabelSettings.new()
	settings.font_size = 20
	settings.font_color = Color(0.1, 1.0, 0.4)
	settings.outline_color = Color(0.0, 0.1, 0.0, 0.8)
	settings.outline_size = 5
	label.label_settings = settings
	
	label.position = Vector2(-20, -60)
	add_child(label)
	
	var label_tween := create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 65.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	label_tween.chain().tween_callback(label.queue_free)

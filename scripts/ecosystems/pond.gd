extends Node2D

## Pond ecosystem scene — 2x2 water body with aquatic foliage.

var instance: EcosystemData.EcosystemInstance

func _ready() -> void:
	#queue_redraw()
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
	label.text = "+%d" % (instance.lf_per_tick if instance else 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Settings for label style (green, outline, outline color)
	var settings := LabelSettings.new()
	settings.font_size = 18
	settings.font_color = Color(0.2, 0.9, 0.3)
	settings.outline_color = Color(0.0, 0.1, 0.0, 0.8)
	settings.outline_size = 4
	label.label_settings = settings
	
	# Position above center of the node
	label.position = Vector2(-20, -50)
	add_child(label)
	
	# Tween the label floating up and fading out
	var label_tween := create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 60.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	label_tween.chain().tween_callback(label.queue_free)


#func _draw() -> void:
	#var radius := float(GridManager.CELL_SIZE) * 0.85
	## Main water body
	#draw_circle(Vector2.ZERO, radius, Color(0.196, 0.463, 0.659, 0.9))
	## Highlight
	#draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.35, Color(0.35, 0.6, 0.8, 0.5))
	## Edge
	#draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.12, 0.30, 0.50, 0.6), 3.0)
#

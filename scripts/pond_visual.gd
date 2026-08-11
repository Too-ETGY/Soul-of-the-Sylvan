extends Node2D

## Procedural 2x2 pond visual — blue pond body covering 2x2 cell footprint.

func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var radius := float(GridManager.CELL_SIZE) * 0.85
	# Main water body
	draw_circle(Vector2.ZERO, radius, Color(0.196, 0.463, 0.659, 0.9))
	# Highlight
	draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.35, Color(0.35, 0.6, 0.8, 0.5))
	# Edge darkening
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.12, 0.30, 0.50, 0.6), 3.0)

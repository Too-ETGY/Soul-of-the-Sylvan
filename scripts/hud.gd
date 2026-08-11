extends CanvasLayer

## HUD — swapped layout (Left Sidebar: Resources/Stats/Tree, Right Sidebar: Awareness/Pause).
## Includes Ecosystem Inspector Card on hover/click.

@onready var lf_label: Label = $LeftSidebar/LifeForceLabel
@onready var day_label: Label = $LeftSidebar/DayLabel
@onready var lf_rate_label: Label = $LeftSidebar/LFRateLabel

@onready var oxygen_bar: ProgressBar = $LeftSidebar/StatsPanel/OxyContainer/OxygenBar
@onready var water_bar: ProgressBar = $LeftSidebar/StatsPanel/WatContainer/WaterBar
@onready var biodiversity_bar: ProgressBar = $LeftSidebar/StatsPanel/BioContainer/BiodiversityBar
@onready var oxygen_label: Label = $LeftSidebar/StatsPanel/OxyContainer/OxygenLabel
@onready var water_label: Label = $LeftSidebar/StatsPanel/WatContainer/WaterLabel
@onready var biodiversity_label: Label = $LeftSidebar/StatsPanel/BioContainer/BiodiversityLabel

@onready var tree_progress: ProgressBar = $LeftSidebar/SacredTreePanel/TreeProgress
@onready var tree_percent_label: Label = $LeftSidebar/SacredTreePanel/TreePercentLabel
@onready var restore_button: Button = $LeftSidebar/SacredTreePanel/RestoreButton

@onready var awareness_bar: ProgressBar = $RightSidebar/AwarenessBar
@onready var awareness_label: Label = $RightSidebar/AwarenessLabel
@onready var pause_button: Button = $RightSidebar/PauseButton

@onready var grove_button: Button = $BottomCenterPalette/GroveButton
@onready var pond_button: Button = $BottomCenterPalette/PondButton
@onready var flower_button: Button = $BottomCenterPalette/FlowerButton

@onready var tooltip_label: Label = $TooltipLabel
@onready var syva_portrait: TextureRect = $SyvaPortrait

# Ecosystem Inspector Panel
@onready var inspector_panel: Panel = $InspectorPanel
@onready var inspector_title: Label = $InspectorPanel/VBox/TitleLabel
@onready var inspector_stats: Label = $InspectorPanel/VBox/StatsLabel
@onready var inspector_status: Label = $InspectorPanel/VBox/StatusLabel

var _placement_system: Node2D
var _sacred_tree: Node


func setup(placement_system: Node2D, sacred_tree: Node) -> void:
	_placement_system = placement_system
	_sacred_tree = sacred_tree

	LifeForceManager.life_force_changed.connect(_on_life_force_changed)
	DayCycle.day_passed.connect(_on_day_passed)

	if _sacred_tree:
		_sacred_tree.restoration_changed.connect(_on_restoration_changed)

	grove_button.pressed.connect(_on_grove_pressed)
	pond_button.pressed.connect(_on_pond_pressed)
	flower_button.pressed.connect(_on_flower_pressed)
	restore_button.pressed.connect(_on_restore_pressed)
	pause_button.pressed.connect(_on_pause_pressed)

	var grove_def := EcosystemData.get_def(EcosystemData.Type.FOREST_GROVE)
	var pond_def := EcosystemData.get_def(EcosystemData.Type.POND)
	var flower_def := EcosystemData.get_def(EcosystemData.Type.WILDFLOWERS)

	grove_button.text = "🌲 Grove\n%d LF" % grove_def.life_force_cost
	pond_button.text = "💧 Pond\n%d LF" % pond_def.life_force_cost
	flower_button.text = "🌸 Flowers\n%d LF" % flower_def.life_force_cost

	inspector_panel.visible = false
	_on_life_force_changed(LifeForceManager.get_life_force())
	_update_forest_stats()
	_update_tree_display()
	tooltip_label.text = ""


func _process(_delta: float) -> void:
	var lf := LifeForceManager.get_life_force()
	grove_button.disabled = lf < EcosystemData.get_def(EcosystemData.Type.FOREST_GROVE).life_force_cost
	pond_button.disabled = lf < EcosystemData.get_def(EcosystemData.Type.POND).life_force_cost
	flower_button.disabled = lf < EcosystemData.get_def(EcosystemData.Type.WILDFLOWERS).life_force_cost

	if _sacred_tree and _sacred_tree.has_method("get_next_restore_cost"):
		var cost: int = _sacred_tree.get_next_restore_cost()
		restore_button.text = "✦ Restore (+1%%)\n%d LF" % cost
		restore_button.disabled = (lf < cost) or (_sacred_tree.get_restoration_percent() >= 100.0)

	_check_hover_inspector()


func _check_hover_inspector() -> void:
	if _placement_system and _placement_system.is_placing():
		inspector_panel.visible = false
		return

	var mouse_world := get_viewport().get_camera_2d().get_global_mouse_position() if get_viewport().get_camera_2d() else Vector2.ZERO
	var cell := GridManager.world_to_cell(mouse_world)
	var eco := GridManager.get_ecosystem_at(cell)

	if eco != null:
		inspector_panel.visible = true
		var def := EcosystemData.get_def(eco.type)
		inspector_title.text = "%s (Cell %d, %d)" % [def.display_name, eco.cell.x, eco.cell.y]
		inspector_stats.text = "O₂: %d  |  💧: %d  |  🌿: %d" % [eco.oxygen, eco.water, eco.biodiversity]

		if eco.is_broken:
			inspector_status.text = "Status: ⚠️ BROKEN (%d/3 days to decay)" % eco.days_broken
			inspector_status.modulate = Color(1.0, 0.3, 0.3, 1.0)
		elif eco.is_occupied_by_human:
			inspector_status.text = "Status: 🚨 Occupied by Human (-1 Bio/day)"
			inspector_status.modulate = Color(1.0, 0.7, 0.3, 1.0)
		else:
			inspector_status.text = "Status: ✅ Healthy"
			inspector_status.modulate = Color(0.4, 0.9, 0.4, 1.0)
	else:
		inspector_panel.visible = false


func update_human_awareness(awareness: float) -> void:
	awareness_bar.value = awareness
	awareness_label.text = "Human Awareness: %.0f%%" % awareness


func _on_life_force_changed(new_amount: int) -> void:
	lf_label.text = "✦ %d LF" % new_amount
	lf_rate_label.text = "+%d/day" % GridManager.get_total_lf_per_tick()


func _on_day_passed(day_number: int) -> void:
	day_label.text = "Day %d" % day_number
	_update_forest_stats()


func _update_forest_stats() -> void:
	var stats := GridManager.get_forest_stats()
	var oxy: int = stats["oxygen"]
	var wat: int = stats["water"]
	var bio: int = stats["biodiversity"]

	oxygen_bar.value = mini(oxy, 100)
	water_bar.value = mini(wat, 100)
	biodiversity_bar.value = mini(bio, 100)

	oxygen_label.text = "O₂ %d" % oxy
	water_label.text = "💧 %d" % wat
	biodiversity_label.text = "🌿 %d" % bio


func _update_tree_display() -> void:
	if not _sacred_tree:
		return
	var pct: float = _sacred_tree.get_restoration_percent()
	tree_progress.value = pct
	tree_percent_label.text = "Sacred Tree: %.0f%%" % pct


func _on_restoration_changed(_percent: float, _spirit_level: int) -> void:
	_update_tree_display()
	_update_forest_stats()


func _on_grove_pressed() -> void:
	if _placement_system:
		_placement_system.start_placement(EcosystemData.Type.FOREST_GROVE)
		tooltip_label.text = "Planting Forest Grove — click to plant, right-click to cancel"


func _on_pond_pressed() -> void:
	if _placement_system:
		_placement_system.start_placement(EcosystemData.Type.POND)
		tooltip_label.text = "Planting Pond — click to plant, right-click to cancel"


func _on_flower_pressed() -> void:
	if _placement_system:
		_placement_system.start_placement(EcosystemData.Type.WILDFLOWERS)
		tooltip_label.text = "Planting Wildflowers — click to plant, right-click to cancel"


func _on_restore_pressed() -> void:
	if _sacred_tree:
		var cost: int = _sacred_tree.get_next_restore_cost()
		if _sacred_tree.restore(1.0):
			tooltip_label.text = "Sacred Tree restored by +1%!"
		else:
			tooltip_label.text = "Requires %d Life Force!" % cost


func _on_pause_pressed() -> void:
	var pause_menu := get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_method("open"):
		pause_menu.open()

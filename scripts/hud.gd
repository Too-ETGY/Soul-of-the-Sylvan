extends CanvasLayer

## HUD — displays Life Force, day counter, forest stats, ecosystem palette,
## and Sacred Tree panel.

@onready var lf_label: Label = $TopBar/LifeForceLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var lf_rate_label: Label = $TopBar/LFRateLabel

@onready var oxygen_bar: ProgressBar = $TopBar/StatsContainer/OxygenBar
@onready var water_bar: ProgressBar = $TopBar/WaterContainer/WaterBar
@onready var biodiversity_bar: ProgressBar = $TopBar/BiodiversityContainer/BiodiversityBar
@onready var oxygen_label: Label = $TopBar/StatsContainer/OxygenLabel
@onready var water_label: Label = $TopBar/WaterContainer/WaterLabel
@onready var biodiversity_label: Label = $TopBar/BiodiversityContainer/BiodiversityLabel

@onready var grove_button: Button = $BottomPanel/GroveButton
@onready var pond_button: Button = $BottomPanel/PondButton
@onready var flower_button: Button = $BottomPanel/FlowerButton

@onready var tree_progress: ProgressBar = $SacredTreePanel/TreeProgress
@onready var tree_percent_label: Label = $SacredTreePanel/TreePercentLabel
@onready var spirit_level_label: Label = $SacredTreePanel/SpiritLevelLabel
@onready var restore_button: Button = $SacredTreePanel/RestoreButton

@onready var day_progress_bar: ProgressBar = $TopBar/DayProgressBar

@onready var tooltip_label: Label = $TooltipLabel

var _placement_system: Node2D
var _sacred_tree: Node  # Actually a Sprite2D with sacred_tree.gd script


func setup(placement_system: Node2D, sacred_tree: Node) -> void:
	_placement_system = placement_system
	_sacred_tree = sacred_tree

	# Connect signals
	LifeForceManager.life_force_changed.connect(_on_life_force_changed)
	DayCycle.day_passed.connect(_on_day_passed)

	if _sacred_tree:
		_sacred_tree.restoration_changed.connect(_on_restoration_changed)

	# Ecosystem palette buttons
	grove_button.pressed.connect(_on_grove_pressed)
	pond_button.pressed.connect(_on_pond_pressed)
	flower_button.pressed.connect(_on_flower_pressed)
	restore_button.pressed.connect(_on_restore_pressed)

	# Set button labels
	var grove_def := EcosystemData.get_def(EcosystemData.Type.FOREST_GROVE)
	var pond_def := EcosystemData.get_def(EcosystemData.Type.POND)
	var flower_def := EcosystemData.get_def(EcosystemData.Type.WILDFLOWERS)

	grove_button.text = "🌲 Grove\n%d LF" % grove_def.life_force_cost
	pond_button.text = "💧 Pond\n%d LF" % pond_def.life_force_cost
	flower_button.text = "🌸 Flowers\n%d LF" % flower_def.life_force_cost
	restore_button.text = "✦ Restore\n10 LF"

	# Initial state
	_on_life_force_changed(LifeForceManager.get_life_force())
	_update_forest_stats()
	_update_tree_display()
	tooltip_label.text = ""


func _process(_delta: float) -> void:
	# Update day progress bar
	day_progress_bar.value = DayCycle.get_day_progress() * 100.0

	# Update button affordability
	var lf := LifeForceManager.get_life_force()
	grove_button.disabled = lf < EcosystemData.get_def(EcosystemData.Type.FOREST_GROVE).life_force_cost
	pond_button.disabled = lf < EcosystemData.get_def(EcosystemData.Type.POND).life_force_cost
	flower_button.disabled = lf < EcosystemData.get_def(EcosystemData.Type.WILDFLOWERS).life_force_cost
	restore_button.disabled = lf < 10


func _on_life_force_changed(new_amount: int) -> void:
	lf_label.text = "✦ %d" % new_amount
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
	var lvl: int = _sacred_tree.get_spirit_level()
	tree_progress.value = pct
	tree_percent_label.text = "%.0f%%" % pct
	spirit_level_label.text = "Spirit Lv.%d" % lvl


func _on_restoration_changed(_percent: float, _spirit_level: int) -> void:
	_update_tree_display()
	_update_forest_stats()


func _on_grove_pressed() -> void:
	if _placement_system:
		_placement_system.start_placement(EcosystemData.Type.FOREST_GROVE)
		tooltip_label.text = "Place Forest Grove — click to place, right-click to cancel"


func _on_pond_pressed() -> void:
	if _placement_system:
		_placement_system.start_placement(EcosystemData.Type.POND)
		tooltip_label.text = "Place Pond — click to place, right-click to cancel"


func _on_flower_pressed() -> void:
	if _placement_system:
		_placement_system.start_placement(EcosystemData.Type.WILDFLOWERS)
		tooltip_label.text = "Place Wildflowers — click to place, right-click to cancel"


func _on_restore_pressed() -> void:
	if _sacred_tree:
		if _sacred_tree.restore(1.0):
			tooltip_label.text = "Sacred Tree restored by 1%!"
		else:
			tooltip_label.text = "Not enough Life Force!"

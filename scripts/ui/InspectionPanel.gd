## InspectionPanel.gd
## Popup panel showing full vehicle condition breakdown.
## Lists all parts with their condition and repair cost.
extends PanelContainer

# ── Scene References ──────────────────────────────────────────────────────────
@onready var title_label: Label = $VBox/TitleLabel
@onready var score_label: Label = $VBox/ScoreLabel
@onready var dirt_label: Label = $VBox/DirtLabel
@onready var parts_list: VBoxContainer = $VBox/ScrollContainer/PartsList
@onready var close_btn: Button = $VBox/CloseBtn
@onready var value_label: Label = $VBox/ValueLabel

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	hide()
	if close_btn:
		close_btn.pressed.connect(hide)

# ── Public API ────────────────────────────────────────────────────────────────
func show_vehicle(data: VehicleData) -> void:
	if not data:
		return

	if title_label:
		title_label.text = data.display_name

	if score_label:
		var score := data.get_condition_score()
		score_label.text = "Overall Condition: %s (%d%%)" % [data.get_condition_label(), score]
		score_label.modulate = _condition_color(score)

	if dirt_label:
		dirt_label.text = "Cleanliness: %s (%.0f%% dirty)" % [data.get_dirt_label(), data.dirt_level * 100]

	if value_label:
		value_label.text = "Estimated Value: $%d" % data.get_sell_value()

	_populate_parts_list(data)
	show()

# ── Internal ──────────────────────────────────────────────────────────────────
func _populate_parts_list(data: VehicleData) -> void:
	if not parts_list:
		return

	# Clear old entries
	for child in parts_list.get_children():
		child.queue_free()

	for part_name in data.parts:
		var cond: int = data.parts[part_name]
		var cond_label_text: String = VehicleData.PartCondition.keys()[cond].capitalize()
		var repair_cost: int = VehicleDatabase.get_part_repair_cost(part_name)

		var row := HBoxContainer.new()

		var name_lbl := Label.new()
		name_lbl.text = part_name.replace("_", " ").capitalize()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var cond_lbl := Label.new()
		cond_lbl.text = cond_label_text
		cond_lbl.modulate = _condition_color_from_enum(cond)
		cond_lbl.custom_minimum_size.x = 100
		row.add_child(cond_lbl)

		# Show repair button for damaged/broken/missing parts
		if cond >= VehicleData.PartCondition.DAMAGED:
			var repair_btn := Button.new()
			repair_btn.text = "Repair ($%d)" % repair_cost
			if not EconomyManager.can_afford(repair_cost):
				repair_btn.disabled = true
				repair_btn.modulate = Color(0.7, 0.7, 0.7)
			repair_btn.pressed.connect(func(): _on_repair_pressed(part_name))
			row.add_child(repair_btn)
		else:
			var ok_lbl := Label.new()
			ok_lbl.text = "✓ OK"
			ok_lbl.modulate = Color.GREEN
			row.add_child(ok_lbl)

		parts_list.add_child(row)

func _on_repair_pressed(part_name: String) -> void:
	# Find the garage node and trigger repair
	var garage = get_tree().get_first_node_in_group("garage")
	if garage and garage.has_method("do_repair_part"):
		garage.do_repair_part(part_name)
		# Refresh panel with updated data
		if garage.current_vehicle:
			show_vehicle(garage.current_vehicle.data)

func _condition_color(score: int) -> Color:
	if score >= 75: return Color.GREEN
	if score >= 50: return Color.YELLOW
	if score >= 25: return Color(1, 0.5, 0)
	return Color.RED

func _condition_color_from_enum(cond: int) -> Color:
	match cond:
		VehicleData.PartCondition.PERFECT: return Color.CYAN
		VehicleData.PartCondition.GOOD:    return Color.GREEN
		VehicleData.PartCondition.WORN:    return Color.YELLOW
		VehicleData.PartCondition.DAMAGED: return Color(1, 0.5, 0)
		VehicleData.PartCondition.BROKEN:  return Color.RED
		VehicleData.PartCondition.MISSING: return Color(0.5, 0.5, 0.5)
	return Color.WHITE

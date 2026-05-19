## VehicleData.gd
## Resource class representing a single vehicle instance in the world.
## Holds runtime state: which parts are broken, paint condition, etc.
class_name VehicleData
extends Resource

# ── Enums ─────────────────────────────────────────────────────────────────────
enum PartCondition { PERFECT, GOOD, WORN, DAMAGED, BROKEN, MISSING }

# ── Properties ────────────────────────────────────────────────────────────────
@export var template_id: String = ""
@export var display_name: String = ""
@export var vehicle_type: String = ""
@export var base_value: int = 0

## Part name → PartCondition
@export var parts: Dictionary = {}

## Overall filth level 0.0 (clean) – 1.0 (filthy)
@export var dirt_level: float = 0.0

## Paint condition 0.0 (bare metal) – 1.0 (pristine)
@export var paint_condition: float = 1.0

## Paint color
@export var paint_color: Color = Color.WHITE

## Purchase price paid by the player (used to calculate profit)
@export var purchase_price: int = 0

# ── Computed ──────────────────────────────────────────────────────────────────

## Overall condition score 0–100
func get_condition_score() -> int:
	if parts.is_empty():
		return 0

	var total_weight: float = 0.0
	var earned_weight: float = 0.0

	for part_name in parts:
		var w: float = VehicleDatabase.get_part_value_weight(part_name)
		total_weight += w
		var cond: int = parts[part_name]
		match cond:
			PartCondition.PERFECT:  earned_weight += w * 1.0
			PartCondition.GOOD:     earned_weight += w * 0.8
			PartCondition.WORN:     earned_weight += w * 0.55
			PartCondition.DAMAGED:  earned_weight += w * 0.3
			PartCondition.BROKEN:   earned_weight += w * 0.1
			PartCondition.MISSING:  earned_weight += 0.0

	var part_score: float = (earned_weight / total_weight) if total_weight > 0 else 0.0
	var cleanliness_score: float = 1.0 - dirt_level
	var paint_score: float = paint_condition

	# Weighted blend: parts 60%, cleanliness 20%, paint 20%
	var final_score: float = (part_score * 0.6) + (cleanliness_score * 0.2) + (paint_score * 0.2)
	return int(final_score * 100)

## Estimated sell price based on condition
func get_sell_value() -> int:
	var condition: float = get_condition_score() / 100.0
	# Non-linear: bad condition vehicles tank in value quickly
	var value_multiplier: float = pow(condition, 1.5)
	return int(base_value * value_multiplier)

## Returns a human-readable condition label
func get_condition_label() -> String:
	var score: int = get_condition_score()
	if score >= 90: return "Pristine"
	if score >= 75: return "Good"
	if score >= 55: return "Fair"
	if score >= 35: return "Poor"
	if score >= 15: return "Wreck"
	return "Junk"

## How dirty is the vehicle as a label
func get_dirt_label() -> String:
	if dirt_level < 0.2: return "Clean"
	if dirt_level < 0.5: return "Dusty"
	if dirt_level < 0.75: return "Dirty"
	return "Filthy"

## List of broken/missing parts for quick inspection UI
func get_problem_parts() -> Array:
	var problems: Array = []
	for part_name in parts:
		var cond: int = parts[part_name]
		if cond >= PartCondition.DAMAGED:
			problems.append({"part": part_name, "condition": cond})
	return problems

# ── Factory ───────────────────────────────────────────────────────────────────

## Create a VehicleData from a template, with randomized damage
static func create_from_template(template: Dictionary, damage_level: float = 0.5) -> VehicleData:
	var vd := VehicleData.new()
	vd.template_id = template["id"]
	vd.display_name = template["name"]
	vd.vehicle_type = template["type"]
	vd.base_value = template["base_value"]
	vd.paint_color = template["color"]

	# Randomize part conditions based on damage_level (0.0 = mint, 1.0 = destroyed)
	for part_name in template["parts"]:
		var roll: float = randf()
		var condition: int
		if roll < damage_level * 0.2:
			condition = PartCondition.MISSING
		elif roll < damage_level * 0.5:
			condition = PartCondition.BROKEN
		elif roll < damage_level * 0.75:
			condition = PartCondition.DAMAGED
		elif roll < damage_level * 0.9:
			condition = PartCondition.WORN
		else:
			condition = PartCondition.GOOD
		vd.parts[part_name] = condition

	# Dirt scales with damage
	vd.dirt_level = clamp(damage_level * randf_range(0.6, 1.2), 0.0, 1.0)
	vd.paint_condition = clamp(1.0 - damage_level * randf_range(0.4, 0.9), 0.0, 1.0)

	return vd

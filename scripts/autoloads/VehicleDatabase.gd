## VehicleDatabase.gd
## Autoload singleton — defines all vehicle templates available in the game.
## Add new vehicles here as the game expands.
extends Node

# ── Vehicle Template Structure ────────────────────────────────────────────────
## Each vehicle template is a Dictionary with:
##   id          : String  - unique identifier
##   name        : String  - display name
##   type        : String  - "sedan", "truck", "classic", "motorcycle"
##   base_value  : int     - clean/fully-restored sell price
##   color       : Color   - placeholder color for prototype sprite
##   parts       : Array   - list of part names this vehicle has
##   unlock_tier : int     - garage tier required to work on this vehicle

var vehicles: Dictionary = {
	"rustbucket_sedan": {
		"id": "rustbucket_sedan",
		"name": "Rustbucket Sedan",
		"type": "sedan",
		"base_value": 1200,
		"color": Color(0.6, 0.3, 0.2),   # rusty brown
		"parts": ["engine", "transmission", "body_front", "body_rear",
				  "hood", "doors", "wheels_front", "wheels_rear",
				  "interior", "windshield"],
		"unlock_tier": 1,
		"description": "A beat-up old sedan. Might be worth something cleaned up."
	},
	"old_pickup": {
		"id": "old_pickup",
		"name": "Old Pickup Truck",
		"type": "truck",
		"base_value": 1800,
		"color": Color(0.4, 0.5, 0.3),   # faded green
		"parts": ["engine", "transmission", "body_front", "body_rear",
				  "hood", "doors", "wheels_front", "wheels_rear",
				  "bed", "interior", "windshield"],
		"unlock_tier": 1,
		"description": "A workhorse pickup with a few hard years behind it."
	},
	"classic_coupe": {
		"id": "classic_coupe",
		"name": "Vintage Coupe",
		"type": "classic",
		"base_value": 4500,
		"color": Color(0.8, 0.75, 0.2),  # faded gold
		"parts": ["engine", "transmission", "body_front", "body_rear",
				  "hood", "doors", "wheels_front", "wheels_rear",
				  "interior", "windshield", "chrome_trim", "convertible_top"],
		"unlock_tier": 2,
		"description": "A beauty from another era. Collectors would pay big for this restored."
	}
}

# ── Part Definitions ─────────────────────────────────────────────────────────
## Repair cost and value contribution for each part type
var part_data: Dictionary = {
	"engine":         {"repair_cost": 300, "value_weight": 0.30},
	"transmission":   {"repair_cost": 200, "value_weight": 0.15},
	"body_front":     {"repair_cost": 80,  "value_weight": 0.08},
	"body_rear":      {"repair_cost": 80,  "value_weight": 0.08},
	"hood":           {"repair_cost": 60,  "value_weight": 0.05},
	"doors":          {"repair_cost": 100, "value_weight": 0.08},
	"wheels_front":   {"repair_cost": 120, "value_weight": 0.06},
	"wheels_rear":    {"repair_cost": 120, "value_weight": 0.06},
	"interior":       {"repair_cost": 150, "value_weight": 0.08},
	"windshield":     {"repair_cost": 90,  "value_weight": 0.04},
	"bed":            {"repair_cost": 70,  "value_weight": 0.04},
	"chrome_trim":    {"repair_cost": 110, "value_weight": 0.05},
	"convertible_top":{"repair_cost": 140, "value_weight": 0.06},
}

# ── Helpers ───────────────────────────────────────────────────────────────────
func get_vehicle(id: String) -> Dictionary:
	return vehicles.get(id, {})

func get_all_vehicles() -> Array:
	return vehicles.values()

func get_vehicles_by_tier(max_tier: int) -> Array:
	return vehicles.values().filter(func(v): return v["unlock_tier"] <= max_tier)

func get_random_vehicle(tier: int = 1) -> Dictionary:
	var available = get_vehicles_by_tier(tier)
	if available.is_empty():
		return {}
	return available[randi() % available.size()]

func get_part_repair_cost(part_name: String) -> int:
	return part_data.get(part_name, {}).get("repair_cost", 50)

func get_part_value_weight(part_name: String) -> float:
	return part_data.get(part_name, {}).get("value_weight", 0.05)

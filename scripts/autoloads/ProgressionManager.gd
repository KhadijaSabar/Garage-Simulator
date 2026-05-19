## ProgressionManager.gd
## Autoload — garage tier, upgrades, and unlock gates.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal tier_upgraded(new_tier: int)
signal upgrade_purchased(upgrade_id: String)

# ── Tier Data ─────────────────────────────────────────────────────────────────
## Each tier: what it costs to reach, what it unlocks
const TIERS: Array = [
	{},  # tier 0 placeholder (unused)
	{    # Tier 1 — starting tier, no cost
		"name": "Grease Monkey",
		"upgrade_cost": 0,
		"max_bays": 1,
		"vehicle_types": ["sedan"],
		"unlocks": ["Basic tools, 1 bay, sedans only"]
	},
	{    # Tier 2
		"name": "Wrench Wizard",
		"upgrade_cost": 3000,
		"max_bays": 3,
		"vehicle_types": ["sedan", "truck"],
		"unlocks": ["3 bays", "Pickup trucks", "Parts shelf"]
	},
	{    # Tier 3
		"name": "Shop Owner",
		"upgrade_cost": 8000,
		"max_bays": 6,
		"vehicle_types": ["sedan", "truck", "classic"],
		"unlocks": ["6 bays", "Classic cars", "Hire 1 mechanic"]
	},
	{    # Tier 4
		"name": "Junkyard Boss",
		"upgrade_cost": 20000,
		"max_bays": 10,
		"vehicle_types": ["sedan", "truck", "classic", "motorcycle"],
		"unlocks": ["10 bays", "Motorcycles", "Auction house"]
	},
	{    # Tier 5
		"name": "Legend",
		"upgrade_cost": 50000,
		"max_bays": 15,
		"vehicle_types": ["sedan", "truck", "classic", "motorcycle", "rare"],
		"unlocks": ["15 bays", "Rare vehicles", "TV show offer"]
	},
]

## One-off upgrades (bought with money, independent of tier)
const UPGRADES: Dictionary = {
	"better_tools": {
		"name": "Better Tools",
		"description": "Repairs cost 20% less money.",
		"cost": 800,
		"icon": "🔧"
	},
	"pressure_washer": {
		"name": "Pressure Washer",
		"description": "Cleaning removes 60% dirt (up from 35%).",
		"cost": 600,
		"icon": "🚿"
	},
	"haggling_course": {
		"name": "Haggling Course",
		"description": "Customers start 10% higher offers.",
		"cost": 500,
		"icon": "🤝"
	},
	"junkyard_map": {
		"name": "Junkyard Map",
		"description": "Reveals what's in each pile before searching.",
		"cost": 1200,
		"icon": "🗺️"
	},
}

# ── State ─────────────────────────────────────────────────────────────────────
var current_tier: int = 1
var purchased_upgrades: Array = []   ## Array of upgrade_id strings

# ── Tier API ─────────────────────────────────────────────────────────────────
func get_tier_data(tier: int = -1) -> Dictionary:
	var t := current_tier if tier < 0 else tier
	if t < 1 or t >= TIERS.size():
		return {}
	return TIERS[t]

func get_next_tier_data() -> Dictionary:
	return get_tier_data(current_tier + 1)

func can_upgrade() -> bool:
	if current_tier >= TIERS.size() - 1:
		return false
	var next := get_next_tier_data()
	return EconomyManager.can_afford(next.get("upgrade_cost", 0))

func is_max_tier() -> bool:
	return current_tier >= TIERS.size() - 1

func upgrade_tier() -> bool:
	if not can_upgrade():
		return false
	var next := get_next_tier_data()
	var cost: int = next.get("upgrade_cost", 0)
	EconomyManager.spend_money(cost, "Garage upgrade to Tier %d" % (current_tier + 1))
	current_tier += 1
	emit_signal("tier_upgraded", current_tier)
	print("[Progression] Upgraded to Tier %d: %s" % [current_tier, get_tier_data()["name"]])
	SaveManager.auto_save()
	return true

func get_tier_name() -> String:
	return get_tier_data().get("name", "Unknown")

func get_max_bays() -> int:
	return get_tier_data().get("max_bays", 1)

func can_use_vehicle_type(vtype: String) -> bool:
	return vtype in get_tier_data().get("vehicle_types", ["sedan"])

# ── Upgrade API ───────────────────────────────────────────────────────────────
func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in purchased_upgrades

func buy_upgrade(upgrade_id: String) -> bool:
	if has_upgrade(upgrade_id):
		return false
	var udata: Dictionary = UPGRADES.get(upgrade_id, {})
	if udata.is_empty():
		return false
	var cost: int = udata["cost"]
	if not EconomyManager.can_afford(cost):
		return false
	EconomyManager.spend_money(cost, "Upgrade: %s" % udata["name"])
	purchased_upgrades.append(upgrade_id)
	emit_signal("upgrade_purchased", upgrade_id)
	SaveManager.auto_save()
	return true

## Repair cost modifier from upgrades
func get_repair_cost_multiplier() -> float:
	return 0.80 if has_upgrade("better_tools") else 1.0

## Clean power modifier
func get_clean_power() -> float:
	return 0.60 if has_upgrade("pressure_washer") else 0.35

## Customer offer bonus
func get_offer_bonus() -> float:
	return 0.10 if has_upgrade("haggling_course") else 0.0

## Serialization ──────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {"tier": current_tier, "upgrades": purchased_upgrades.duplicate()}

func from_dict(data: Dictionary) -> void:
	current_tier = data.get("tier", 1)
	purchased_upgrades = data.get("upgrades", [])

## InventoryManager.gd
## Autoload singleton — tracks the player's spare parts and scrap metal.
## Parts found in the junkyard can be used for FREE repairs in the garage.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal inventory_changed
signal scrap_changed(new_total: int)

# ── State ─────────────────────────────────────────────────────────────────────
## part_name (String) → quantity (int)
var parts: Dictionary = {}
var scrap_metal: int = 0

# ── Parts ─────────────────────────────────────────────────────────────────────
func add_part(part_name: String, qty: int = 1) -> void:
	parts[part_name] = parts.get(part_name, 0) + qty
	emit_signal("inventory_changed")
	print("[Inventory] +%d × %s (have %d)" % [qty, part_name, parts[part_name]])

func use_part(part_name: String) -> bool:
	if not has_part(part_name):
		return false
	parts[part_name] -= 1
	if parts[part_name] <= 0:
		parts.erase(part_name)
	emit_signal("inventory_changed")
	return true

func has_part(part_name: String) -> bool:
	return parts.get(part_name, 0) > 0

func get_part_count(part_name: String) -> int:
	return parts.get(part_name, 0)

func get_all_parts() -> Dictionary:
	return parts.duplicate()

# ── Scrap Metal ───────────────────────────────────────────────────────────────
func add_scrap(amount: int) -> void:
	var actual: int = amount * EventSystem.get_scrap_multiplier()
	scrap_metal += actual
	emit_signal("scrap_changed", scrap_metal)
	print("[Inventory] +%d scrap metal (total: %d)" % [actual, scrap_metal])

func sell_all_scrap() -> int:
	if scrap_metal <= 0:
		return 0
	var value := scrap_metal
	EconomyManager.add_money(value, "Sold %d scrap metal" % value)
	scrap_metal = 0
	emit_signal("scrap_changed", 0)
	return value

## Remove all scrap without adding money (caller handles the payment externally,
## e.g. when the junkyard applies its own market price per unit).
func clear_scrap() -> void:
	scrap_metal = 0
	emit_signal("scrap_changed", 0)

# ── Serialization (for save system later) ────────────────────────────────────
func to_dict() -> Dictionary:
	return {"parts": parts.duplicate(), "scrap": scrap_metal}

func from_dict(data: Dictionary) -> void:
	parts = data.get("parts", {})
	scrap_metal = data.get("scrap", 0)
	emit_signal("inventory_changed")
	emit_signal("scrap_changed", scrap_metal)

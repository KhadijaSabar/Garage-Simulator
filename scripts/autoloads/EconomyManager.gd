## EconomyManager.gd
## Autoload singleton — tracks money, handles transactions, reputation.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal money_changed(new_amount: int, delta: int)
signal reputation_changed(new_rep: float)
signal transaction_completed(description: String, amount: int)

# ── Constants ─────────────────────────────────────────────────────────────────
const STARTING_MONEY: int = 2000

# ── State ─────────────────────────────────────────────────────────────────────
var money: int = STARTING_MONEY
var reputation: float = 50.0       # 0 – reputation_cap
var reputation_cap: float = 100.0  ## Raised by XP level rewards
var transaction_log: Array[Dictionary] = []

# ── Money ─────────────────────────────────────────────────────────────────────
func add_money(amount: int, description: String = "") -> void:
	money += amount
	_log_transaction(description, amount)
	emit_signal("money_changed", money, amount)
	emit_signal("transaction_completed", description, amount)
	print("[Economy] +$%d (%s) → Total: $%d" % [amount, description, money])

func spend_money(amount: int, description: String = "") -> bool:
	if amount > money:
		print("[Economy] Not enough money! Need $%d, have $%d" % [amount, money])
		return false
	money -= amount
	_log_transaction(description, -amount)
	emit_signal("money_changed", money, -amount)
	emit_signal("transaction_completed", description, -amount)
	print("[Economy] -$%d (%s) → Total: $%d" % [amount, description, money])
	return true

func can_afford(amount: int) -> bool:
	return money >= amount

# ── Reputation ────────────────────────────────────────────────────────────────
func change_reputation(delta: float, reason: String = "") -> void:
	reputation = clamp(reputation + delta, 0.0, reputation_cap)
	emit_signal("reputation_changed", reputation)
	print("[Economy] Reputation %+.1f (%s) → %.1f" % [delta, reason, reputation])

func get_reputation_label() -> String:
	if reputation >= 80: return "Legendary"
	if reputation >= 60: return "Trusted"
	if reputation >= 40: return "Known"
	if reputation >= 20: return "Shady"
	return "Unknown"

# ── Internal ──────────────────────────────────────────────────────────────────
func _log_transaction(description: String, amount: int) -> void:
	transaction_log.append({
		"day": GameManager.current_day,
		"description": description,
		"amount": amount,
		"balance": money
	})

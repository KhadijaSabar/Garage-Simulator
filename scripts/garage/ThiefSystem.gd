## ThiefSystem.gd
## Night-phase thief events. Triggers at end of each day.
## Security upgrades reduce theft chance and can catch thieves.
extends Node

signal theft_attempted(caught: bool, item_stolen: String)
signal night_phase_start
signal night_phase_end

# ── Security upgrade costs ────────────────────────────────────────────────────
const SECURITY_UPGRADES := {
	"alarm":   {"name": "Alarm System",  "cost": 400,  "catch_bonus": 0.35, "icon": "🚨"},
	"camera":  {"name": "CCTV Camera",   "cost": 700,  "catch_bonus": 0.25, "icon": "📷"},
	"dog":     {"name": "Guard Dog",     "cost": 1000, "catch_bonus": 0.40, "icon": "🐕"},
	"guard":   {"name": "Night Guard",   "cost": 3000, "catch_bonus": 0.80, "icon": "💂"},
}

# ── State ─────────────────────────────────────────────────────────────────────
var installed_security: Array[String] = []
var hud_ref: CanvasLayer = null   ## Set by Garage.gd after ready

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.day_ended.connect(_on_day_ended)

# ── Night phase ───────────────────────────────────────────────────────────────
func _on_day_ended(_day: int) -> void:
	emit_signal("night_phase_start")
	await get_tree().create_timer(1.5).timeout
	_run_theft_check()

func _run_theft_check() -> void:
	# Resolve garage reference once, used throughout
	var garage : Node = get_tree().get_first_node_in_group("garage")

	# Neighbourhood Watch event makes tonight completely safe
	if EventSystem.safe_tonight:
		_show_alert("👁️ Neighbourhood Watch kept things quiet tonight.", Color(0.6, 0.8, 1.0), garage)
		emit_signal("theft_attempted", true, "")   # "caught" variant — no theft
		emit_signal("night_phase_end")
		return

	# Base theft probability rises with wealth & tier, falls with security
	var wealth_factor : float = clamp(float(EconomyManager.money) / 10000.0, 0.0, 1.0)
	var tier_factor   : float = float(ProgressionManager.current_tier) / 5.0
	var base_chance   : float = 0.08 + wealth_factor * 0.12 + tier_factor * 0.08  # 8%–28%

	# Security lowers the chance
	var catch_power  : float = _get_total_catch_power()
	var theft_chance : float = base_chance * (1.0 - catch_power * 0.6)

	if randf() < theft_chance:
		# Theft attempt!
		if randf() < catch_power:
			# Caught!
			EconomyManager.change_reputation(4.0, "Caught a thief")
			_show_alert("🚨 THIEF CAUGHT! Your security stopped them.", Color.YELLOW, garage)
			AudioManager.play("caught")
			emit_signal("theft_attempted", true, "")
		else:
			# Successful theft
			var stolen := _steal_something(garage)
			EconomyManager.change_reputation(-6.0, "Theft occurred")
			_show_alert("🔓 BREAK-IN! Someone stole: %s" % stolen, Color.RED, garage)
			AudioManager.play("alarm")
			emit_signal("theft_attempted", false, stolen)
	else:
		_show_alert("🌙 Night passed quietly.", Color(0.6, 0.7, 0.9), garage)

	emit_signal("night_phase_end")

func _steal_something(garage: Node) -> String:
	# Try to steal: vehicle > parts > money
	var vehicle = garage.get("current_vehicle") if garage else null
	if is_instance_valid(vehicle):
		var value: int = vehicle.data.get_sell_value()
		vehicle.queue_free()
		garage.set("current_vehicle", null)
		return "your %s (worth ~$%d)!" % [vehicle.data.display_name, value]

	# Steal parts from inventory
	var parts := InventoryManager.get_all_parts()
	if not parts.is_empty():
		var part_name: String = parts.keys()[randi() % parts.size()]
		InventoryManager.use_part(part_name)
		return "your spare %s" % part_name.replace("_", " ")

	# Steal some cash
	var amount: int = min(EconomyManager.money, randi_range(50, 300))
	EconomyManager.money -= amount
	return "$%d cash" % amount

func _get_total_catch_power() -> float:
	var total := 0.0
	for upg in installed_security:
		total += SECURITY_UPGRADES.get(upg, {}).get("catch_bonus", 0.0)
	return clamp(total, 0.0, 0.95)

func _show_alert(msg: String, color: Color, garage: Node) -> void:
	if garage and garage.has_method("show_feedback"):
		garage.show_feedback(msg, color)
	print("[ThiefSystem] %s" % msg)

# ── Security purchases ────────────────────────────────────────────────────────
func buy_security(upgrade_id: String) -> bool:
	if upgrade_id in installed_security:
		return false
	var udata: Dictionary = SECURITY_UPGRADES.get(upgrade_id, {})
	if udata.is_empty():
		return false
	if not EconomyManager.can_afford(udata["cost"]):
		return false
	EconomyManager.spend_money(udata["cost"], "Security: %s" % udata["name"])
	installed_security.append(upgrade_id)
	SaveManager.auto_save()
	return true

func has_security(upgrade_id: String) -> bool:
	return upgrade_id in installed_security

func get_security_level_label() -> String:
	if installed_security.is_empty(): return "None (vulnerable!)"
	var names := []
	for s in installed_security:
		names.append(SECURITY_UPGRADES[s]["icon"] + " " + SECURITY_UPGRADES[s]["name"])
	return ", ".join(names)

# ── Serialization ─────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {"security": installed_security.duplicate()}

func from_dict(data: Dictionary) -> void:
	installed_security.assign(data.get("security", []))

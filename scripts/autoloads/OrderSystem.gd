## OrderSystem.gd
## Autoload — manages customer job orders (drop-off, work, pick-up loop).
## Orders arrive at the reception desk and queue up for the player to accept.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal order_received(order: Dictionary)
signal order_accepted(order: Dictionary)
signal order_completed(order: Dictionary, payout: int)
signal order_expired(order: Dictionary)
signal orders_changed

# ── Constants ─────────────────────────────────────────────────────────────────
const MAX_PENDING_ORDERS := 4   ## Max orders waiting at reception
const MAX_ACTIVE_ORDERS  := 2   ## Max orders being worked on simultaneously

# ── State ─────────────────────────────────────────────────────────────────────
var pending_orders: Array[Dictionary] = []   ## Waiting at reception
var active_orders:  Array[Dictionary] = []   ## Accepted, vehicle in garage
var completed_today: int = 0
var _next_order_id: int = 1

# ── Order Structure ───────────────────────────────────────────────────────────
## {
##   id            : int
##   customer_name : String
##   vehicle_id    : String      (template id)
##   required_jobs : Array[String]  (e.g. ["fix_engine","clean","fix_brakes"])
##   base_reward   : int
##   tip_multiplier: float       (bonus for completing early/perfectly)
##   deadline_days : int         (days from now to complete)
##   arrived_day   : int
##   urgency       : String      ("low","medium","high","emergency")
##   damage_level  : float
##   status        : String      ("pending","active","complete","expired")
## }

# ── Urgency Data ──────────────────────────────────────────────────────────────
const URGENCY_DATA := {
	"low":       {"deadline": 5, "reward_mult": 1.0, "tip_mult": 1.1, "label": "No rush"},
	"medium":    {"deadline": 3, "reward_mult": 1.3, "tip_mult": 1.2, "label": "Within 3 days"},
	"high":      {"deadline": 2, "reward_mult": 1.6, "tip_mult": 1.4, "label": "Urgent!"},
	"emergency": {"deadline": 1, "reward_mult": 2.2, "tip_mult": 1.8, "label": "TODAY"},
}

const JOB_TYPES := {
	"clean":         {"label": "Clean the vehicle",       "base_pay": 80},
	"fix_engine":    {"label": "Fix the engine",          "base_pay": 350},
	"fix_brakes":    {"label": "Fix the brakes",          "base_pay": 200},
	"fix_body":      {"label": "Repair body panels",      "base_pay": 150},
	"fix_wheels":    {"label": "Replace wheels",          "base_pay": 160},
	"fix_interior":  {"label": "Restore interior",        "base_pay": 180},
	"full_service":  {"label": "Full service & clean",    "base_pay": 600},
}

const CUSTOMER_NAMES := [
	"Mr. Hassan", "Mrs. Dupont", "Tony", "Laura B.", "The Chief",
	"Old Pete", "Ravi S.", "Coach Kim", "Sandra T.", "Big Mike"
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.day_started.connect(_on_day_started)

func _on_day_started(_day: int) -> void:
	# Check for expired orders
	var expired: Array = []
	for order in active_orders:
		var days_left: int = order["deadline_days"] - (GameManager.current_day - order["arrived_day"])
		if days_left <= 0:
			order["status"] = "expired"
			expired.append(order)
			EconomyManager.change_reputation(-8.0, "Failed order for %s" % order["customer_name"])
			emit_signal("order_expired", order)
	for o in expired:
		active_orders.erase(o)

	# Spawn 1-3 new orders per day based on reputation and tier
	var spawn_count := randi_range(1, min(3, ProgressionManager.get_max_bays()))
	for _i in spawn_count:
		if pending_orders.size() < MAX_PENDING_ORDERS:
			_generate_order()

	emit_signal("orders_changed")
	completed_today = 0

# ── Order Generation ──────────────────────────────────────────────────────────
func _generate_order() -> void:
	var _urgency_keys := ["low", "medium", "high", "emergency"]
	# Higher reputation → more high-urgency (and lucrative) orders
	var rep_normalized := EconomyManager.reputation / 100.0
	var urgency: String
	var roll := randf()
	if roll < 0.15 * rep_normalized:
		urgency = "emergency"
	elif roll < 0.35 * rep_normalized:
		urgency = "high"
	elif roll < 0.65:
		urgency = "medium"
	else:
		urgency = "low"

	var udata: Dictionary = URGENCY_DATA[urgency]
	var template := VehicleDatabase.get_random_vehicle(ProgressionManager.current_tier)
	if template.is_empty():
		return

	# Pick 1–4 jobs
	var all_jobs := JOB_TYPES.keys()
	all_jobs.shuffle()
	var job_count := randi_range(1, min(4, all_jobs.size()))
	var jobs := all_jobs.slice(0, job_count)

	# Calculate reward
	var base_reward := 0
	for j in jobs:
		base_reward += JOB_TYPES[j]["base_pay"]
	base_reward = int(base_reward * udata["reward_mult"])

	var order := {
		"id":             _next_order_id,
		"customer_name":  CUSTOMER_NAMES[randi() % CUSTOMER_NAMES.size()],
		"vehicle_id":     template["id"],
		"vehicle_name":   template["name"],
		"required_jobs":  jobs,
		"base_reward":    base_reward,
		"tip_multiplier": udata["tip_mult"],
		"deadline_days":  udata["deadline"],
		"arrived_day":    GameManager.current_day,
		"urgency":        urgency,
		"damage_level":   randf_range(0.4, 0.85),
		"status":         "pending",
		"completed_jobs": [],
	}
	_next_order_id += 1
	pending_orders.append(order)
	emit_signal("order_received", order)
	emit_signal("orders_changed")
	print("[Orders] New order #%d from %s — %s — $%d" % [order["id"], order["customer_name"], urgency, base_reward])

# ── Order Management ──────────────────────────────────────────────────────────
func accept_order(order_id: int) -> Dictionary:
	var order := _find_pending(order_id)
	if order.is_empty():
		return {}
	if active_orders.size() >= MAX_ACTIVE_ORDERS:
		return {"error": "No free bay — finish an active order first"}
	pending_orders.erase(order)
	order["status"] = "active"
	active_orders.append(order)
	emit_signal("order_accepted", order)
	emit_signal("orders_changed")
	return order

func mark_job_done(order_id: int, job: String) -> void:
	var order := _find_active(order_id)
	if order.is_empty() or job in order["completed_jobs"]:
		return
	order["completed_jobs"].append(job)
	emit_signal("orders_changed")

func complete_order(order_id: int) -> int:
	var order := _find_active(order_id)
	if order.is_empty():
		return 0

	# Check all required jobs are done
	for job in order["required_jobs"]:
		if job not in order["completed_jobs"]:
			return -1   ## signal: not done yet

	# Calculate payout (bonus for being fast)
	var days_taken: int = GameManager.current_day - int(order["arrived_day"])
	var days_left: int  = int(order["deadline_days"]) - days_taken
	var speed_bonus: float = 1.0 + (0.05 * max(0, days_left))
	var payout: int = int(int(order["base_reward"]) * speed_bonus * float(order["tip_multiplier"]))

	order["status"] = "complete"
	active_orders.erase(order)
	EconomyManager.add_money(payout, "Order #%d — %s" % [order["id"], order["customer_name"]])
	EconomyManager.change_reputation(5.0 + days_left, "Completed order on time")
	completed_today += 1
	emit_signal("order_completed", order, payout)
	emit_signal("orders_changed")
	SaveManager.auto_save()
	print("[Orders] Completed #%d — Payout: $%d" % [order_id, payout])
	return payout

## Walk-in service order — skips the pending queue, goes straight to active.
## Called when a service customer and player agree on a repair price.
func generate_walk_in_order(customer_name: String, vehicle_id: String, vehicle_name: String,
		jobs: Array, negotiated_price: int) -> Dictionary:
	var order : Dictionary = {
		"id":             _next_order_id,
		"customer_name":  customer_name,
		"vehicle_id":     vehicle_id,
		"vehicle_name":   vehicle_name,
		"required_jobs":  jobs,
		"base_reward":    negotiated_price,
		"tip_multiplier": 1.0,
		"deadline_days":  3,
		"arrived_day":    GameManager.current_day,
		"urgency":        "medium",
		"damage_level":   randf_range(0.35, 0.75),
		"status":         "active",
		"completed_jobs": [],
		"walk_in":        true,
	}
	_next_order_id += 1
	active_orders.append(order)
	emit_signal("order_accepted", order)
	emit_signal("orders_changed")
	print("[Orders] Walk-in #%d from %s — %d jobs — $%d" % [
		order["id"], customer_name, jobs.size(), negotiated_price])
	return order

## Returns the first walk-in order whose all jobs are ticked off, or {}.
func get_completed_walk_in_order() -> Dictionary:
	for o in active_orders:
		if not o.get("walk_in", false): continue
		if (o["completed_jobs"] as Array).size() >= (o["required_jobs"] as Array).size():
			return o
	return {}

func get_active_order_for_vehicle(vehicle_template_id: String) -> Dictionary:
	for o in active_orders:
		if o["vehicle_id"] == vehicle_template_id and o["status"] == "active":
			return o
	return {}

func get_days_left(order: Dictionary) -> int:
	return order["deadline_days"] - (GameManager.current_day - order["arrived_day"])

# ── Helpers ───────────────────────────────────────────────────────────────────
func _find_pending(id: int) -> Dictionary:
	for o in pending_orders:
		if o["id"] == id: return o
	return {}

func _find_active(id: int) -> Dictionary:
	for o in active_orders:
		if o["id"] == id: return o
	return {}

func urgency_color(urgency: String) -> Color:
	match urgency:
		"emergency": return Color.RED
		"high":      return Color(1.0, 0.5, 0.0)
		"medium":    return Color.YELLOW
		_:           return Color.GREEN

func to_dict() -> Dictionary:
	return {
		"pending": pending_orders.duplicate(true),
		"active":  active_orders.duplicate(true),
		"next_id": _next_order_id
	}

func from_dict(data: Dictionary) -> void:
	pending_orders.assign(data.get("pending", []))
	active_orders.assign(data.get("active", []))
	_next_order_id = data.get("next_id", 1)
	emit_signal("orders_changed")

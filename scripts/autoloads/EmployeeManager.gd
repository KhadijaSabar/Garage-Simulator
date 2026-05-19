## EmployeeManager.gd
## Autoload — hire/fire mechanics who auto-repair vehicles each day.
## Wages are deducted at day start. Each mechanic does 1-3 repair jobs
## on the active vehicle depending on their skill level.
## Max employees scales with garage tier.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal employee_hired(employee: Dictionary)
signal employee_fired(employee: Dictionary)
signal wages_paid(total: int)
signal auto_repair_done(employee: Dictionary, repairs: Array)  ## repairs = [{part, quality}]

# ── Employee pool (available to hire) ────────────────────────────────────────
## Re-rolled each in-game week (every 7 days).
const EMPLOYEE_POOL : Array = [
	{
		"id": "gary_jr",
		"name": "Gary Jr.",
		"icon": "🔧",
		"skill": 1,
		"specialty": "body",
		"daily_wage": 80,
		"bio": "Gary's nephew. Enthusiastic, not always accurate.",
		"blunder_chance": 0.18,   ## Chance of making a part worse instead of better
	},
	{
		"id": "miguel",
		"name": "Miguel",
		"icon": "⚙️",
		"skill": 2,
		"specialty": "engine",
		"daily_wage": 140,
		"bio": "Ex-factory worker. Solid on engines, slow everywhere else.",
		"blunder_chance": 0.08,
	},
	{
		"id": "priya",
		"name": "Priya",
		"icon": "🛠️",
		"skill": 3,
		"specialty": "all",
		"daily_wage": 200,
		"bio": "Trained mechanic. Fast, reliable, and she knows it.",
		"blunder_chance": 0.03,
	},
	{
		"id": "old_pete",
		"name": "Old Pete",
		"icon": "🎩",
		"skill": 2,
		"specialty": "classic",
		"daily_wage": 120,
		"bio": "Retired. Great with classics. Moves slowly. Brings his own tea.",
		"blunder_chance": 0.10,
	},
	{
		"id": "kat",
		"name": "Kat",
		"icon": "🔩",
		"skill": 3,
		"specialty": "interior",
		"daily_wage": 180,
		"bio": "Specialises in interior and bodywork. Perfectionist.",
		"blunder_chance": 0.02,
	},
	{
		"id": "dex",
		"name": "Dex",
		"icon": "🏎️",
		"skill": 4,
		"specialty": "all",
		"daily_wage": 280,
		"bio": "Former race team tech. Expensive but exceptional.",
		"blunder_chance": 0.01,
	},
	{
		"id": "tamara",
		"name": "Tamara",
		"icon": "🪛",
		"skill": 2,
		"specialty": "wheel",
		"daily_wage": 110,
		"bio": "Tyre specialist. Fast hands, great attitude.",
		"blunder_chance": 0.07,
	},
	{
		"id": "boris",
		"name": "Boris",
		"icon": "💪",
		"skill": 1,
		"specialty": "cleaning",
		"daily_wage": 60,
		"bio": "Will clean anything, anywhere, anytime. No questions asked.",
		"blunder_chance": 0.0,   ## He only cleans — can't blunder a repair
	},
]

## How many repair jobs each skill level does per day
const REPAIRS_PER_SKILL : Array = [0, 1, 2, 3, 5]   ## index = skill (1–4)

# ── State ─────────────────────────────────────────────────────────────────────
var hired        : Array[Dictionary] = []   ## Currently employed staff
var available    : Array[Dictionary] = []   ## Today's hire pool (subset of EMPLOYEE_POOL)
var _pool_day    : int = -1                 ## Day the pool was last rolled

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.day_started.connect(_on_day_started)

func _on_day_started(day: int) -> void:
	_roll_pool_if_needed(day)
	_pay_wages()
	# Auto-repair is triggered by Garage.gd via do_auto_repairs()
	# so it can pass the active vehicle reference.

# ── Hire pool ─────────────────────────────────────────────────────────────────
func _roll_pool_if_needed(day: int) -> void:
	## Re-roll every 7 days (keeps things fresh without being chaotic)
	if day == _pool_day: return
	var week : int = int((day - 1) / 7.0)
	if week == int((_pool_day - 1) / 7.0) and _pool_day > 0: return
	_pool_day = day
	_roll_available_pool()

func _roll_available_pool() -> void:
	var shuffled := EMPLOYEE_POOL.duplicate()
	shuffled.shuffle()
	# Show 3-4 candidates, never show already-hired employees
	var hired_ids : Array = hired.map(func(e: Dictionary) -> String: return e["id"])
	var candidates : Array = shuffled.filter(func(e: Dictionary) -> bool:
		return e["id"] not in hired_ids)
	available.assign(candidates.slice(0, min(4, candidates.size())))

func get_available() -> Array:
	return available

# ── Hire / Fire ───────────────────────────────────────────────────────────────
func max_employees() -> int:
	return int(ProgressionManager.get_max_bays() / 2.0)   ## 1 bay = 0.5 slots (rounds down)

func can_hire() -> bool:
	return hired.size() < max_employees()

func hire(employee_id: String) -> bool:
	if not can_hire(): return false
	for e in available:
		if e["id"] == employee_id:
			hired.append(e.duplicate())
			available.erase(e)
			emit_signal("employee_hired", e)
			SaveManager.auto_save()
			print("[Employees] Hired %s ($%d/day)" % [e["name"], e["daily_wage"]])
			return true
	return false

func fire(employee_id: String) -> bool:
	for i in hired.size():
		if hired[i]["id"] == employee_id:
			var e : Dictionary = hired[i]
			hired.remove_at(i)
			# Put them back in available pool for today
			available.append(e)
			emit_signal("employee_fired", e)
			SaveManager.auto_save()
			print("[Employees] Fired %s" % e["name"])
			return true
	return false

func get_daily_wage_total() -> int:
	var total : int = 0
	for e in hired:
		total += int(e["daily_wage"])
	return total

func _pay_wages() -> void:
	var total : int = get_daily_wage_total()
	if total <= 0: return
	if EconomyManager.can_afford(total):
		EconomyManager.spend_money(total, "Employee wages")
		emit_signal("wages_paid", total)
		print("[Employees] Paid $%d in wages." % total)
	else:
		## Can't pay — fire the most expensive employee
		if hired.is_empty(): return
		hired.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["daily_wage"]) > int(b["daily_wage"]))
		var fired_emp : Dictionary = hired[0]
		hired.remove_at(0)
		emit_signal("employee_fired", fired_emp)
		print("[Employees] Couldn't pay wages — %s quit!" % fired_emp["name"])
		# Try again with reduced headcount
		var reduced : int = get_daily_wage_total()
		if reduced > 0 and EconomyManager.can_afford(reduced):
			EconomyManager.spend_money(reduced, "Employee wages (reduced)")
			emit_signal("wages_paid", reduced)

# ── Auto-repair ───────────────────────────────────────────────────────────────
## Called by Garage.gd at day start, passing the active VehicleData (may be null).
## Returns an Array of result dicts: [{employee, part, outcome}]
func do_auto_repairs(vehicle_data) -> Array:
	var results : Array = []
	if vehicle_data == null or hired.is_empty():
		return results

	var parts_dict : Dictionary = vehicle_data.parts
	if parts_dict.is_empty():
		return results

	for emp in hired:
		# Boris only cleans — skip repair loop for him
		if emp["id"] == "boris":
			vehicle_data.dirt_level = maxf(0.0, float(vehicle_data.get("dirt_level", 0.5)) - 0.35)
			results.append({"employee": emp, "part": "dirt", "outcome": "cleaned"})
			continue

		var repairs_today : int = REPAIRS_PER_SKILL[clamp(int(emp["skill"]), 1, 4)]
		var eligible_parts : Array = _get_eligible_parts(parts_dict, emp)

		for _r in repairs_today:
			if eligible_parts.is_empty(): break
			var part : String = eligible_parts[randi() % eligible_parts.size()]
			var outcome : String = _attempt_repair(vehicle_data, part, emp)
			results.append({"employee": emp, "part": part, "outcome": outcome})
			eligible_parts.erase(part)   # don't repeat same part

	if not results.is_empty():
		emit_signal("auto_repair_done", {}, results)

	return results

func _get_eligible_parts(parts: Dictionary, emp: Dictionary) -> Array:
	## Parts that are DAMAGED or BROKEN (not GOOD/PERFECT)
	var eligible : Array = []
	for pname in parts:
		var cond : int = int(parts[pname])
		if cond >= VehicleData.PartCondition.DAMAGED:
			## Specialty filter — skill 1-2 employees prefer their specialty
			var specialty : String = emp.get("specialty", "all")
			if specialty == "all" or specialty in pname or int(emp["skill"]) >= 3:
				eligible.append(pname)
	return eligible

func _attempt_repair(vehicle_data, part: String, emp: Dictionary) -> String:
	var blunder : float = float(emp.get("blunder_chance", 0.05))
	var cond    : int   = int(vehicle_data.parts.get(part, VehicleData.PartCondition.BROKEN))

	if randf() < blunder:
		## Blunder — makes it slightly worse (clamp at BROKEN)
		vehicle_data.parts[part] = min(cond + 1, VehicleData.PartCondition.BROKEN)
		return "blunder"
	else:
		## Success — improve by 1 tier (clamp at GOOD; never auto to PERFECT)
		vehicle_data.parts[part] = max(cond - 1, VehicleData.PartCondition.GOOD)
		return "fixed"

# ── Save / Load ───────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {
		"hired":     hired.duplicate(true),
		"pool_day":  _pool_day,
		"available": available.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	hired.assign(data.get("hired", []))
	_pool_day = data.get("pool_day", -1)
	available.assign(data.get("available", []))
	if available.is_empty():
		_roll_available_pool()

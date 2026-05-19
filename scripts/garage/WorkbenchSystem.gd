## WorkbenchSystem.gd
## 3D workbench node — physical station for detailed part work.
## Workers (unlockable) auto-repair queued parts over time.
extends Node3D

signal worker_finished(worker_name: String, part_name: String)

# ── Worker data ───────────────────────────────────────────────────────────────
const WORKER_DATA := [
	{"name": "Junior",  "speed": 1.0,  "cost": 0,    "salary": 0,   "unlock_tier": 1, "desc": "You (manual work)"},
	{"name": "Rookie",  "speed": 1.2,  "cost": 800,  "salary": 50,  "unlock_tier": 2, "desc": "Slow but reliable"},
	{"name": "Skilled", "speed": 1.8,  "cost": 2000, "salary": 120, "unlock_tier": 3, "desc": "Handles most repairs"},
	{"name": "Expert",  "speed": 2.8,  "cost": 5000, "salary": 280, "unlock_tier": 4, "desc": "Fast and precise"},
]

# ── Tool upgrade data ─────────────────────────────────────────────────────────
## Each tool gives a permanent passive bonus once purchased.
const TOOL_DATA := [
	{
		"id": "socket_set",
		"name": "Socket Set",       "icon": "🔩",
		"cost": 350,
		"desc": "Basic socket set. -10% all repair costs.",
		"repair_discount": 0.10,   "clean_bonus": 0.0, "paint_discount": 0.0,
	},
	{
		"id": "torque_wrench",
		"name": "Torque Wrench",    "icon": "🔧",
		"cost": 750,
		"desc": "Proper torque control. -15% repair costs.",
		"repair_discount": 0.15,   "clean_bonus": 0.0, "paint_discount": 0.0,
	},
	{
		"id": "power_washer",
		"name": "Power Washer",     "icon": "💧",
		"cost": 900,
		"desc": "Strip grime fast. +60% cleaning power.",
		"repair_discount": 0.0,    "clean_bonus": 0.60, "paint_discount": 0.0,
	},
	{
		"id": "spray_gun",
		"name": "Pro Spray Gun",    "icon": "🎨",
		"cost": 1200,
		"desc": "Even finish, less waste. -30% paint cost.",
		"repair_discount": 0.0,    "clean_bonus": 0.0,  "paint_discount": 0.30,
	},
	{
		"id": "lift",
		"name": "Hydraulic Lift",   "icon": "🏗️",
		"cost": 2800,
		"desc": "Get under any car easily. -20% repair costs.",
		"repair_discount": 0.20,   "clean_bonus": 0.0,  "paint_discount": 0.0,
	},
	{
		"id": "scanner",
		"name": "Diagnostic Scanner","icon": "📡",
		"cost": 3500,
		"desc": "Full engine readout. Speeds up Expert workers x1.5.",
		"repair_discount": 0.05,   "clean_bonus": 0.0,  "paint_discount": 0.0,
		"scanner": true,
	},
]

# ── State ─────────────────────────────────────────────────────────────────────
var hired_workers: Array[Dictionary] = []   ## Active worker slots
var repair_queue:  Array[Dictionary] = []   ## {part_name, vehicle_ref, progress}
var owned_tools:   Array[String]     = []   ## IDs of purchased tools

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("workbench_system")
	_build_3d_bench()
	GameManager.day_started.connect(_on_day_started)

func _build_3d_bench() -> void:
	# Workbench table
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.45, 0.35, 0.22)
	bench_mat.roughness = 0.8
	_box(Vector3(2.2, 0.9, 0.7), Vector3(0, 0.45, 0), bench_mat)
	_box(Vector3(2.2, 0.06, 0.7), Vector3(0, 0.93, 0), bench_mat)  # top surface

	# Vice on bench
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.55, 0.58)
	metal.metallic = 0.7
	_box(Vector3(0.22, 0.22, 0.18), Vector3(0.7, 0.99, 0), metal)

	# Toolbox
	var tbox := StandardMaterial3D.new()
	tbox.albedo_color = Color(0.8, 0.25, 0.1)
	_box(Vector3(0.35, 0.25, 0.25), Vector3(-0.65, 0.99, 0), tbox)

	# Click area
	var area := Area3D.new()
	area.add_to_group("workbench")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 0.9)
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	area.add_child(col)
	area.input_event.connect(_on_bench_clicked)
	add_child(area)

	# Workers panel label (above bench)
	# (shown in HUD via get_status())

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

# ── Worker management ─────────────────────────────────────────────────────────
func can_hire(worker_index: int) -> bool:
	if worker_index >= WORKER_DATA.size():
		return false
	var wdata: Dictionary = WORKER_DATA[worker_index]
	return (ProgressionManager.current_tier >= wdata["unlock_tier"]
		and EconomyManager.can_afford(wdata["cost"])
		and not _is_hired(worker_index))

func hire_worker(worker_index: int) -> bool:
	if not can_hire(worker_index):
		return false
	var wdata: Dictionary = WORKER_DATA[worker_index]
	EconomyManager.spend_money(wdata["cost"], "Hired %s" % wdata["name"])
	hired_workers.append({"index": worker_index, "busy": false, "current_job": ""})
	print("[Workbench] Hired: %s" % wdata["name"])
	return true

func _is_hired(index: int) -> bool:
	for w in hired_workers:
		if w["index"] == index: return true
	return false

# ── Repair queue ──────────────────────────────────────────────────────────────
func queue_repair(part_name: String, vehicle: Vehicle) -> void:
	repair_queue.append({"part_name": part_name, "vehicle": vehicle, "progress": 0.0})
	_try_assign_worker()
	print("[Workbench] Queued repair: %s" % part_name)

func _try_assign_worker() -> void:
	for w in hired_workers:
		if not w["busy"] and not repair_queue.is_empty():
			var job: Dictionary = repair_queue.pop_front()
			w["busy"] = true
			w["current_job"] = job["part_name"]
			var wdata: Dictionary = WORKER_DATA[w["index"]]
			var repair_time: float = 8.0 / float(wdata["speed"])
			var timer := get_tree().create_timer(repair_time)
			timer.timeout.connect(func(): _worker_done(w, job))

func _worker_done(worker: Dictionary, job: Dictionary) -> void:
	var v: Vehicle = job.get("vehicle")
	if is_instance_valid(v) and v.data:
		v.action_repair_part(job["part_name"])
	worker["busy"] = false
	worker["current_job"] = ""
	var wname: String = WORKER_DATA[worker["index"]]["name"]
	emit_signal("worker_finished", wname, job["part_name"])
	print("[Workbench] %s finished repairing %s" % [wname, job["part_name"]])
	_try_assign_worker()

func _on_day_started(_day: int) -> void:
	# Pay daily salaries
	for w in hired_workers:
		var salary: int = WORKER_DATA[w["index"]]["salary"]
		if salary > 0:
			EconomyManager.spend_money(salary, "Salary: %s" % WORKER_DATA[w["index"]]["name"])

func _on_bench_clicked(_camera, event: InputEvent, _pos, _normal, _idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var _g = get_tree().get_first_node_in_group("garage")
		if _g:
			_g.show_feedback("Walk to the workbench zone and press E!", Color(0.8, 0.9, 1.0))

# ── Tool purchases ────────────────────────────────────────────────────────────
func has_tool(tool_id: String) -> bool:
	return tool_id in owned_tools

func can_buy_tool(tool_id: String) -> bool:
	if has_tool(tool_id): return false
	for td: Dictionary in TOOL_DATA:
		if td["id"] == tool_id:
			return EconomyManager.can_afford(int(td["cost"]))
	return false

func buy_tool(tool_id: String) -> bool:
	if not can_buy_tool(tool_id): return false
	for td: Dictionary in TOOL_DATA:
		if td["id"] == tool_id:
			EconomyManager.spend_money(int(td["cost"]), "Tool: %s" % td["name"])
			owned_tools.append(tool_id)
			SaveManager.auto_save()
			print("[Workbench] Bought tool: %s" % td["name"])
			return true
	return false

func get_tool_repair_discount() -> float:
	var total := 0.0
	for tool_id: String in owned_tools:
		for td: Dictionary in TOOL_DATA:
			if td["id"] == tool_id:
				total += float(td["repair_discount"])
	return minf(total, 0.60)   # cap at 60 % off

func get_tool_clean_bonus() -> float:
	var total := 0.0
	for tool_id: String in owned_tools:
		for td: Dictionary in TOOL_DATA:
			if td["id"] == tool_id:
				total += float(td["clean_bonus"])
	return total

func get_tool_paint_discount() -> float:
	var total := 0.0
	for tool_id: String in owned_tools:
		for td: Dictionary in TOOL_DATA:
			if td["id"] == tool_id:
				total += float(td["paint_discount"])
	return minf(total, 0.50)

func get_status() -> String:
	if hired_workers.is_empty():
		return "Workbench (no workers hired)"
	var lines: Array = []
	for w in hired_workers:
		var wdata: Dictionary = WORKER_DATA[w["index"]]
		var status: String = ("Fixing: %s" % str(w["current_job"])) if bool(w["busy"]) else "Idle"
		lines.append("%s — %s" % [wdata["name"], status])
	return "\n".join(lines)

# ── Serialization ─────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	var workers_data: Array = []
	for w in hired_workers:
		workers_data.append({"index": w["index"]})
	return {"workers": workers_data, "tools": owned_tools.duplicate()}

func from_dict(data: Dictionary) -> void:
	hired_workers.clear()
	for w in data.get("workers", []):
		hired_workers.append({"index": w["index"], "busy": false, "current_job": ""})
	owned_tools.assign(data.get("tools", []))

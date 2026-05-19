## TowingManager.gd
## Autoload — generates roadside towing dispatch missions each day.
## Missions are shown in the Tablet → DISPATCH tab.
## When the player dispatches the truck, a real-time countdown runs;
## on arrival the wreck is delivered to the garage bay.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal missions_refreshed
signal tow_dispatched(mission: Dictionary)
signal tow_arrived(mission: Dictionary)
signal tow_progress(fraction: float)   ## 0.0 → 1.0 as truck travels

# ── Mission templates ─────────────────────────────────────────────────────────
## vehicle_id must match a key in VehicleDatabase.
## travel_sec = real-time seconds for the truck to return (at 300 s/day ≈ 10–25% of a day).
const MISSION_TEMPLATES : Array = [
	{
		"id":         "hwy_sedan",
		"label":      "Highway crash",
		"desc":       "Overturned sedan on Route 9. Engine and body damage.",
		"vehicle_id": "rustbucket_sedan",
		"damage":     0.88,
		"tow_fee":    150,
		"travel_sec": 22.0,
		"min_tier":   1,
	},
	{
		"id":         "alley_beater",
		"label":      "Abandoned alley car",
		"desc":       "Stripped junker left in an alley. Lots of rust, solid frame.",
		"vehicle_id": "rustbucket_sedan",
		"damage":     0.95,
		"tow_fee":    60,
		"travel_sec": 12.0,
		"min_tier":   1,
	},
	{
		"id":         "strip_pickup",
		"label":      "Stalled pickup",
		"desc":       "Old pickup ran dry on the main strip. Minor mechanical issues.",
		"vehicle_id": "old_pickup",
		"damage":     0.40,
		"tow_fee":    90,
		"travel_sec": 14.0,
		"min_tier":   1,
	},
	{
		"id":         "lot_pickup",
		"label":      "Parking lot wreck",
		"desc":       "Pickup reversed into a wall. Rear suspension and bodywork.",
		"vehicle_id": "old_pickup",
		"damage":     0.65,
		"tow_fee":    110,
		"travel_sec": 16.0,
		"min_tier":   1,
	},
	{
		"id":         "burnout_coupe",
		"label":      "Burnout gone wrong",
		"desc":       "Classic coupe blew a tyre and clipped the kerb hard.",
		"vehicle_id": "classic_coupe",
		"damage":     0.72,
		"tow_fee":    130,
		"travel_sec": 20.0,
		"min_tier":   2,
	},
	{
		"id":         "track_coupe",
		"label":      "Track day incident",
		"desc":       "Vintage coupe lost it at the autocross. Heavy front damage.",
		"vehicle_id": "classic_coupe",
		"damage":     0.92,
		"tow_fee":    210,
		"travel_sec": 30.0,
		"min_tier":   2,
	},
	{
		"id":         "night_coupe",
		"label":      "Night race casualty",
		"desc":       "Classic found in a ditch off the industrial road. No ID on the owner.",
		"vehicle_id": "classic_coupe",
		"damage":     0.80,
		"tow_fee":    175,
		"travel_sec": 25.0,
		"min_tier":   3,
	},
]

const MAX_DAILY_MISSIONS : int = 3

# ── State ─────────────────────────────────────────────────────────────────────
var available_missions : Array[Dictionary] = []
var active_mission     : Dictionary        = {}
var is_dispatched      : bool              = false
var _travel_total      : float             = 0.0
var _travel_remaining  : float             = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.day_started.connect(func(_d: int): _refresh_daily())
	_refresh_daily()

func _process(delta: float) -> void:
	if not is_dispatched:
		return
	_travel_remaining -= delta
	var frac : float = 1.0 - clampf(_travel_remaining / _travel_total, 0.0, 1.0)
	emit_signal("tow_progress", frac)
	if _travel_remaining <= 0.0:
		is_dispatched = false
		var arrived : Dictionary = active_mission.duplicate()
		active_mission   = {}
		_travel_total    = 0.0
		_travel_remaining = 0.0
		emit_signal("tow_arrived", arrived)

# ── Daily refresh ─────────────────────────────────────────────────────────────
func _refresh_daily() -> void:
	if is_dispatched:
		return   # Don't reshuffle mid-tow

	var tier : int = ProgressionManager.current_tier
	var eligible : Array = []
	for tmpl in MISSION_TEMPLATES:
		if int(tmpl.get("min_tier", 1)) <= tier:
			eligible.append(tmpl.duplicate())
	eligible.shuffle()

	available_missions.clear()
	for i in range(mini(MAX_DAILY_MISSIONS, eligible.size())):
		available_missions.append(eligible[i])

	emit_signal("missions_refreshed")

# ── Dispatch ──────────────────────────────────────────────────────────────────
## Returns false if already dispatched or mission not found.
func dispatch(mission_id: String) -> bool:
	if is_dispatched:
		return false
	for i in range(available_missions.size()):
		var m : Dictionary = available_missions[i]
		if m["id"] == mission_id:
			active_mission    = m.duplicate()
			available_missions.remove_at(i)
			is_dispatched     = true
			_travel_total     = float(m.get("travel_sec", 20.0))
			_travel_remaining = _travel_total
			emit_signal("tow_dispatched", active_mission)
			return true
	return false

## How many seconds remain on the active tow (0 if not dispatched).
func travel_remaining() -> float:
	return _travel_remaining if is_dispatched else 0.0

## Fraction complete 0.0 → 1.0 (0 if not dispatched).
func travel_fraction() -> float:
	if not is_dispatched or _travel_total <= 0.0:
		return 0.0
	return 1.0 - clampf(_travel_remaining / _travel_total, 0.0, 1.0)

# ── Save / Load ───────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	var avail : Array = []
	for m in available_missions:
		avail.append(m)
	return {
		"available":        avail,
		"active":           active_mission,
		"is_dispatched":    is_dispatched,
		"travel_total":     _travel_total,
		"travel_remaining": _travel_remaining,
	}

func from_dict(d: Dictionary) -> void:
	available_missions.clear()
	for m in d.get("available", []):
		available_missions.append(m as Dictionary)
	active_mission    = d.get("active",    {})
	is_dispatched     = d.get("is_dispatched", false)
	_travel_total     = float(d.get("travel_total",     0.0))
	_travel_remaining = float(d.get("travel_remaining", 0.0))

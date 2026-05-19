## AuctionSystem.gd
## Autoload — daily vehicle auction. Player bids against 3 AI rivals.
## Lots reset each morning. Won vehicles are delivered the next day.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal auction_resolved(results: Array)   ## Fired when player finalises bids
signal vehicle_delivered(lot: Dictionary) ## Fired on day start for pending deliveries

# ── AI Rival Profiles ─────────────────────────────────────────────────────────
const AI_BIDDERS := [
	{
		"name":        "Rival Gary",
		"icon":        "🔨",
		"interest":    0.80,   ## Probability he bids on any lot
		"budget_mult": 0.82,   ## He'll bid up to 82% of true vehicle value
		"description": "Local competitor. Aggressive, but tight budget.",
	},
	{
		"name":        "The Dealer",
		"icon":        "🕴️",
		"interest":    0.55,
		"budget_mult": 1.12,
		"description": "Professional dealer. Knows the numbers, outbids on good stock.",
	},
	{
		"name":        "Collector Rex",
		"icon":        "🎩",
		"interest":    0.35,
		"budget_mult": 1.45,
		"description": "Wealthy collector. Rarely bids, but goes high when he does.",
	},
]

# ── State ─────────────────────────────────────────────────────────────────────
var current_lots        : Array[Dictionary] = []
var pending_deliveries  : Array[Dictionary] = []   ## Vehicles won, waiting for empty bay
var _resolved_today     : bool = false
var _lot_counter        : int  = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.day_started.connect(_on_day_started)

func _on_day_started(_day: int) -> void:
	_resolved_today = false
	_generate_lots()
	# Deliver the first pending vehicle if bay is ready
	if not pending_deliveries.is_empty():
		var lot : Dictionary = pending_deliveries.pop_front()
		emit_signal("vehicle_delivered", lot)
		print("[Auction] Delivering won lot: %s" % lot["vehicle_name"])

# ── Lot Generation ─────────────────────────────────────────────────────────────
func _generate_lots() -> void:
	current_lots.clear()
	var tier    : int = ProgressionManager.current_tier
	var count   : int = randi_range(4, 6)

	for _i in count:
		var template : Dictionary = VehicleDatabase.get_random_vehicle(tier)
		if template.is_empty(): continue

		var damage      : float = randf_range(0.25, 0.90)
		var vdata                = VehicleData.create_from_template(template, damage)
		var true_value  : int   = vdata.get_sell_value()
		var start_bid   : int   = int(true_value * randf_range(0.20, 0.45))
		# Condition label for the UI (no exact value shown — forces player to learn)
		var cond_label  : String
		var cond_color  : Color
		if damage <= 0.35:
			cond_label = "Nearly New"; cond_color = Color(0.35, 1.0, 0.45)
		elif damage <= 0.55:
			cond_label = "Decent";     cond_color = Color(0.8, 0.9, 0.3)
		elif damage <= 0.72:
			cond_label = "Rough";      cond_color = Color(1.0, 0.55, 0.15)
		else:
			cond_label = "Wreck";      cond_color = Color(1.0, 0.25, 0.25)

		current_lots.append({
			"id":           _lot_counter,
			"vehicle_id":   template["id"],
			"vehicle_name": template["name"],
			"damage":       damage,
			"true_value":   true_value,
			"start_bid":    start_bid,
			"cond_label":   cond_label,
			"cond_color":   [cond_color.r, cond_color.g, cond_color.b],
			"player_max":   0,    ## 0 = player not bidding on this lot
			"reserved":     false,
		})
		_lot_counter += 1

# ── Player Interaction ────────────────────────────────────────────────────────
func set_player_max(lot_id: int, max_bid: int) -> void:
	for lot in current_lots:
		if lot["id"] == lot_id:
			lot["player_max"] = max_bid
			return

func get_lot(lot_id: int) -> Dictionary:
	for lot in current_lots:
		if lot["id"] == lot_id: return lot
	return {}

func can_resolve() -> bool:
	return not _resolved_today and not current_lots.is_empty()

# ── Auction Resolution ────────────────────────────────────────────────────────
func resolve() -> Array:
	if _resolved_today: return []
	_resolved_today = true
	var results : Array = []

	for lot in current_lots:
		var res : Dictionary = _resolve_lot(lot)
		results.append(res)
		if res["is_player_win"]:
			var price : int = res["final_price"]
			if EconomyManager.can_afford(price):
				EconomyManager.spend_money(price, "Auction: %s" % lot["vehicle_name"])
				var delivery : Dictionary = lot.duplicate()
				delivery["final_price"] = price
				pending_deliveries.append(delivery)
				EconomyManager.change_reputation(1.0, "Auction win")
				XPManager.award("auction_win")
				# Bargain bonus — won at < 70% of true vehicle value
				if price < int(float(lot["true_value"]) * 0.70):
					XPManager.award("auction_bargain")
			else:
				# Can't afford — override to no win
				res["is_player_win"] = false
				res["winner_name"]   = "You (couldn't pay — outbid!)"

	emit_signal("auction_resolved", results)
	SaveManager.auto_save()
	return results

func _resolve_lot(lot: Dictionary) -> Dictionary:
	var bids : Array = []

	## Player bid
	if lot["player_max"] > lot["start_bid"]:
		bids.append({
			"name":      "You",
			"max_bid":   lot["player_max"],
			"is_player": true,
		})

	## AI bids
	for ai in AI_BIDDERS:
		if randf() > float(ai["interest"]): continue
		var ai_value : int = int(lot["true_value"] * float(ai["budget_mult"]) * randf_range(0.88, 1.12))
		if ai_value <= lot["start_bid"]: continue
		bids.append({
			"name":      ai["name"] + " " + ai["icon"],
			"max_bid":   ai_value,
			"is_player": false,
		})

	## No bids → unsold
	if bids.is_empty():
		return {
			"lot_id":        lot["id"],
			"vehicle_name":  lot["vehicle_name"],
			"is_player_win": false,
			"winner_name":   "No bids — unsold",
			"final_price":   0,
			"bids":          [],
		}

	## Sort descending by max_bid
	bids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["max_bid"] > b["max_bid"])

	var winner : Dictionary = bids[0]
	## Price = just above 2nd-highest bid (makes auction feel real)
	var price : int = lot["start_bid"]
	if bids.size() >= 2:
		price = clamp(bids[1]["max_bid"] + randi_range(25, 150), lot["start_bid"], winner["max_bid"])
	else:
		price = lot["start_bid"]

	return {
		"lot_id":        lot["id"],
		"vehicle_name":  lot["vehicle_name"],
		"is_player_win": winner["is_player"],
		"winner_name":   winner["name"],
		"final_price":   price,
		"bids":          bids,
	}

# ── Save / Load ───────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {
		"resolved":    _resolved_today,
		"deliveries":  pending_deliveries.duplicate(true),
		"counter":     _lot_counter,
	}

func from_dict(data: Dictionary) -> void:
	_resolved_today    = data.get("resolved",   false)
	pending_deliveries.assign(data.get("deliveries", []))
	_lot_counter       = data.get("counter",    0)

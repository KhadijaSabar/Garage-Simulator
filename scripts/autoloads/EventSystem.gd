## EventSystem.gd
## Autoload — fires one (occasionally two) random events each morning.
## Events apply immediately and/or set day-long modifiers checked by other systems.
## Displays an animated slide-in popup at day start, then a persistent banner
## in the top-right corner so players always know what's active today.
extends Node

signal event_triggered(event_id: String)

# ── Day-long modifiers (reset every morning) ──────────────────────────────────
var repair_modifier         : float = 1.0   ## Multiplier on all repair costs
var scrap_multiplier        : int   = 1     ## Multiplier on scrap yield in junkyard
var safe_tonight            : bool  = false ## ThiefSystem skips theft check if true
var customer_payout_bonus   : float = 1.0   ## Multiplier on VIP customer's opening offer
var rush_hour_today         : bool  = false ## Halves the customer arrival timer in Garage
var junkyard_bonus_today    : bool  = false ## JunkPile increases rare/wreck loot chances
var bad_weather_today       : bool  = false ## Fewer customers but junkyard has double scrap
var parts_discount_today    : bool  = false ## Rusty's Shop prices 25% off

# ── Active event record (for the HUD banner) ──────────────────────────────────
var _active_event_id    : String = ""
var _active_event_title : String = ""
var _active_event_desc  : String = ""
var _active_event_color : Color  = Color.WHITE
var _banner_layer       : CanvasLayer = null

# ── Event table ───────────────────────────────────────────────────────────────
const EVENTS: Array = [
	# ── Money & economy ──────────────────────────────────────────────────────
	{
		"id": "lucky_cash",
		"title": "💵  Lucky Find!",
		"desc": "Found $%d stuffed inside an old seat cushion!",
		"color": Color(0.4, 1.0, 0.4),
		"weight": 14,
		"effect": "cash",
	},
	{
		"id": "mystery_client",
		"title": "🕵️  Mystery Client!",
		"desc": "An anonymous caller pre-paid $%d for your next job. Easy money.",
		"color": Color(0.78, 0.60, 1.0),
		"weight": 9,
		"effect": "prepay",
	},
	{
		"id": "broken_pipe",
		"title": "🚰  Burst Pipe!",
		"desc": "A water pipe burst in the back. Emergency plumber cost you $%d. Classic.",
		"color": Color(0.45, 0.65, 1.0),
		"weight": 10,
		"effect": "pipe_bill",
	},

	# ── Reputation ────────────────────────────────────────────────────────────
	{
		"id": "tv_feature",
		"title": "📺  Local TV Feature!",
		"desc": "A reporter filmed the garage for the evening news. +%.0f reputation!",
		"color": Color(0.55, 0.80, 1.0),
		"weight": 8,
		"effect": "rep_boost",
	},
	{
		"id": "customer_complaint",
		"title": "😤  Customer Complaint!",
		"desc": "Someone posted a scathing 1-star review online. -8 reputation. Do better today!",
		"color": Color(1.0, 0.45, 0.35),
		"weight": 11,
		"effect": "rep_loss",
	},
	{
		"id": "gone_viral",
		"title": "📱  Gone Viral!",
		"desc": "A short clip of your garage hit the internet. +15 reputation and customers are flooding in!",
		"color": Color(0.55, 1.0, 0.85),
		"weight": 6,
		"effect": "viral",
	},

	# ── Inventory & parts ─────────────────────────────────────────────────────
	{
		"id": "parts_delivery",
		"title": "📦  Surprise Parts Delivery!",
		"desc": "Someone left a box of free parts at your door. No return address. No questions asked.",
		"color": Color(0.45, 0.9, 0.45),
		"weight": 16,
		"effect": "parts",
	},
	{
		"id": "lucky_tip",
		"title": "🎯  Hot Tip!",
		"desc": "A buddy texted: 'Check the junkyard today, trust me.' Loot quality is boosted all day!",
		"color": Color(1.0, 0.78, 0.30),
		"weight": 11,
		"effect": "junkyard_bonus",
	},

	# ── Modifiers (day-long) ──────────────────────────────────────────────────
	{
		"id": "repair_discount",
		"title": "🔧  Bulk Tool Deal!",
		"desc": "A supplier sold you a full toolkit at cost price. All repairs 50%% off today!",
		"color": Color(0.5, 0.92, 0.72),
		"weight": 12,
		"effect": "repair_discount",
	},
	{
		"id": "scrap_bonus",
		"title": "♻️  Scrap Metal Rally!",
		"desc": "Prices are soaring on the scrap market! Every pile in the junkyard yields double metal today.",
		"color": Color(0.9, 0.78, 0.4),
		"weight": 13,
		"effect": "scrap_bonus",
	},
	{
		"id": "vip_customer",
		"title": "🌟  VIP Buyer!",
		"desc": "Word is a well-heeled collector is shopping for a vehicle today. Their opening offer is 75%% higher — don't blow it!",
		"color": Color(1.0, 0.92, 0.28),
		"weight": 7,
		"effect": "vip_customer",
	},
	{
		"id": "rush_hour",
		"title": "🚗  Rush Hour!",
		"desc": "The whole neighbourhood needs their car today. Customers are arriving twice as fast — ka-ching!",
		"color": Color(1.0, 0.60, 0.25),
		"weight": 8,
		"effect": "rush_hour",
	},
	{
		"id": "bad_weather",
		"title": "⛈️  Stormy Day!",
		"desc": "Customers are staying home in the rain — expect fewer walk-ins. On the bright side, the junkyard is deserted and ripe for picking.",
		"color": Color(0.55, 0.70, 1.0),
		"weight": 10,
		"effect": "bad_weather",
	},
	{
		"id": "rusty_sale",
		"title": "🛠️  Rusty's Sale!",
		"desc": "Old Rusty is clearing stock — everything in his shop is 25%% off today. Stock up!",
		"color": Color(0.88, 0.60, 0.25),
		"weight": 10,
		"effect": "parts_discount",
	},

	# ── Events ────────────────────────────────────────────────────────────────
	{
		"id": "health_inspection",
		"title": "🔍  Health & Safety Visit!",
		"desc": "Inspectors are on their way. A clean garage = good review. A dirty one = pain.",
		"color": Color(1.0, 0.85, 0.3),
		"weight": 11,
		"effect": "inspection",
	},
	{
		"id": "neighbourhood_watch",
		"title": "👁️  Neighbourhood Watch!",
		"desc": "The neighbours are keeping a sharp eye tonight. No thief would dare show their face.",
		"color": Color(0.60, 0.72, 1.0),
		"weight": 10,
		"effect": "safe_night",
	},
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.day_started.connect(_on_day_started)
	call_deferred("_on_day_started", GameManager.current_day)

func _on_day_started(day: int) -> void:
	# Reset all modifiers
	repair_modifier       = 1.0
	scrap_multiplier      = 1
	safe_tonight          = false
	customer_payout_bonus = 1.0
	rush_hour_today       = false
	junkyard_bonus_today  = false
	bad_weather_today     = false
	parts_discount_today  = false
	_active_event_id      = ""
	_active_event_title   = ""
	_active_event_desc    = ""
	_active_event_color   = Color.WHITE
	_dismiss_banner()

	# 75% chance on normal days; 100% on day 1
	var chance := 1.0 if day == 1 else 0.75
	if randf() >= chance:
		return

	var event: Dictionary = _pick_event()
	if event.is_empty():
		return

	# Rare double-event on days 3+ (8% chance)
	var second: Dictionary = {}
	if day >= 3 and randf() < 0.08:
		second = _pick_event()
		while not second.is_empty() and second["id"] == event["id"]:
			second = _pick_event()

	call_deferred("_apply_event", event, true)
	if not second.is_empty():
		get_tree().create_timer(5.5).timeout.connect(func(): _apply_event(second, false))

# ── Event selection ───────────────────────────────────────────────────────────
func _pick_event() -> Dictionary:
	var total := 0
	for e: Dictionary in EVENTS:
		total += int(e["weight"])
	var roll := randi() % total
	var cum  := 0
	for e: Dictionary in EVENTS:
		cum += int(e["weight"])
		if roll < cum:
			return e
	return {}

# ── Effect application ────────────────────────────────────────────────────────
func _apply_event(event: Dictionary, primary: bool) -> void:
	var effect : String = event["effect"]
	var title  : String = event["title"]
	var color  : Color  = event["color"]
	var desc   : String = event.get("desc", "")

	match effect:
		"cash":
			var amount: int = randi_range(60, 350)
			EconomyManager.add_money(amount, "Event: Lucky Find")
			desc = desc % amount

		"prepay":
			var bonus: int = randi_range(150, 450)
			EconomyManager.add_money(bonus, "Event: Mystery Client")
			desc = desc % bonus

		"pipe_bill":
			var bill: int = randi_range(80, 220)
			if EconomyManager.can_afford(bill):
				EconomyManager.spend_money(bill, "Event: Burst Pipe")
				desc = desc % bill
			else:
				desc = "A pipe burst but you fixed it yourself with duct tape. Phew — barely saved $0."

		"rep_boost":
			var boost := randf_range(10.0, 20.0)
			EconomyManager.change_reputation(boost, "Event: TV Feature")
			desc = desc % boost

		"rep_loss":
			EconomyManager.change_reputation(-8.0, "Event: Customer Complaint")
			# desc is pre-filled (no format needed)

		"viral":
			EconomyManager.change_reputation(15.0, "Event: Gone Viral")
			rush_hour_today = true   # bonus customers too
			# desc is pre-filled

		"parts":
			var part_pool: Array = ["engine", "wheels_front", "wheels_rear",
				"doors", "hood", "interior", "windshield", "body_front", "body_rear",
				"exhaust_pipe", "headlight", "brake_pads"]
			var count := randi_range(2, 4)
			var added: Array = []
			for _i in count:
				var p: String = part_pool[randi() % part_pool.size()]
				InventoryManager.add_part(p)
				if p not in added: added.append(p)
			desc = desc   # desc already set in const

		"junkyard_bonus":
			junkyard_bonus_today = true
			# desc is pre-filled

		"repair_discount":
			repair_modifier = 0.50
			# desc is pre-filled

		"scrap_bonus":
			scrap_multiplier = 2
			# desc is pre-filled

		"vip_customer":
			customer_payout_bonus = 1.75
			# desc is pre-filled

		"rush_hour":
			rush_hour_today = true
			# desc is pre-filled

		"bad_weather":
			bad_weather_today = true
			junkyard_bonus_today = true   # consolation prize
			# desc is pre-filled

		"parts_discount":
			parts_discount_today = true
			# desc is pre-filled

		"inspection":
			desc = _run_inspection()

		"safe_night":
			safe_tonight = true
			# desc is pre-filled

	# Store for the persistent banner (only primary event shown in banner)
	if primary:
		_active_event_id    = event["id"]
		_active_event_title = title
		_active_event_desc  = desc
		_active_event_color = color

	emit_signal("event_triggered", event["id"])
	AudioManager.play("day_start", -10.0)
	_show_popup(title, desc, color, primary)
	if primary: _show_banner()
	print("[EventSystem] Day event (%s): %s — %s" % [
		"primary" if primary else "bonus", event["id"], desc])

func _run_inspection() -> String:
	var cleaning := get_tree().get_first_node_in_group("garage_cleaning")
	var spill_count: int = 0
	if cleaning:
		var spills = cleaning.get("spills")
		if spills is Array:
			spill_count = (spills as Array).size()

	if spill_count >= 3:
		EconomyManager.change_reputation(-12.0, "Event: Failed inspection")
		return "Inspectors found %d oil spills — health hazard! -12 reputation. Clean up!" % spill_count
	elif spill_count >= 1:
		EconomyManager.change_reputation(-4.0, "Event: Marginal inspection")
		return "Inspectors flagged %d spill(s). Minor warning. -4 reputation." % spill_count
	else:
		EconomyManager.change_reputation(8.0, "Event: Passed inspection")
		return "Squeaky clean! Inspectors gave a glowing report. +8 reputation!"

# ── Animated popup ────────────────────────────────────────────────────────────
func _show_popup(title: String, desc: String, color: Color, _primary: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	get_tree().root.add_child(layer)

	# ── Outer card (shadow) ───────────────────────────────────────────────────
	var shadow := ColorRect.new()
	shadow.position = Vector2(278, 212)
	shadow.size     = Vector2(726, 186)
	shadow.color    = Color(0, 0, 0, 0.55)
	layer.add_child(shadow)

	# ── Card background ───────────────────────────────────────────────────────
	var card := ColorRect.new()
	card.position = Vector2(275, 208)
	card.size     = Vector2(726, 184)
	card.color    = Color(0.10, 0.09, 0.08, 0.97)
	layer.add_child(card)

	# ── Color accent bar (left edge) ──────────────────────────────────────────
	var accent := ColorRect.new()
	accent.position = Vector2(275, 208)
	accent.size     = Vector2(6, 184)
	accent.color    = color
	layer.add_child(accent)

	# ── Header strip ─────────────────────────────────────────────────────────
	var hdr := ColorRect.new()
	hdr.position = Vector2(281, 208)
	hdr.size     = Vector2(720, 44)
	hdr.color    = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 1.0)
	layer.add_child(hdr)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.text    = title
	title_lbl.position = Vector2(294, 212)
	title_lbl.size    = Vector2(700, 38)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.modulate = color
	layer.add_child(title_lbl)

	# ── Description ───────────────────────────────────────────────────────────
	var desc_lbl := Label.new()
	desc_lbl.text          = desc
	desc_lbl.position      = Vector2(294, 256)
	desc_lbl.size          = Vector2(706, 100)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.modulate = Color(0.88, 0.86, 0.82)
	layer.add_child(desc_lbl)

	# ── Progress bar (countdown) ──────────────────────────────────────────────
	var bar := ColorRect.new()
	bar.position = Vector2(281, 384)
	bar.size     = Vector2(720, 5)
	bar.color    = color
	layer.add_child(bar)

	# ── Dismiss hint ─────────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text     = "click to dismiss"
	hint.position = Vector2(880, 388)
	hint.size     = Vector2(130, 18)
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.45, 0.42, 0.38)
	layer.add_child(hint)

	# ── Animate slide in from top ─────────────────────────────────────────────
	var nodes := [shadow, card, accent, hdr, title_lbl, desc_lbl, bar, hint]
	var start_y := -220.0
	for nd in nodes:
		nd.position.y += start_y

	var slide_tw := layer.create_tween()
	slide_tw.set_ease(Tween.EASE_OUT)
	slide_tw.set_trans(Tween.TRANS_BACK)
	for nd in nodes:
		slide_tw.parallel().tween_property(nd, "position:y", nd.position.y - start_y, 0.42)

	# ── Countdown + auto-dismiss ──────────────────────────────────────────────
	var dur := 5.5
	var count_tw := layer.create_tween()
	count_tw.tween_property(bar, "size:x", 0.0, dur)
	count_tw.tween_callback(func(): _slide_out(layer, nodes))

	# ── Click anywhere to dismiss ─────────────────────────────────────────────
	var click_area := ColorRect.new()
	click_area.position = Vector2(275, 208)
	click_area.size     = Vector2(726, 186)
	click_area.color    = Color(0, 0, 0, 0.0)
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			count_tw.kill()
			_slide_out(layer, nodes))
	layer.add_child(click_area)

func _slide_out(layer: CanvasLayer, nodes: Array) -> void:
	if not is_instance_valid(layer): return
	var tw := layer.create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_BACK)
	for nd in nodes:
		tw.parallel().tween_property(nd, "position:y", nd.position.y - 220.0, 0.30)
	tw.tween_callback(layer.queue_free)

# ── Persistent HUD banner ─────────────────────────────────────────────────────
## Shows the day's active event in the top-right corner until midnight.
func _show_banner() -> void:
	_dismiss_banner()
	if _active_event_title.is_empty(): return

	_banner_layer = CanvasLayer.new()
	_banner_layer.layer = 12
	get_tree().root.add_child(_banner_layer)

	# Background pill
	var bg := ColorRect.new()
	bg.position = Vector2(860, 58)
	bg.size     = Vector2(412, 50)
	bg.color    = Color(0.08, 0.07, 0.06, 0.92)
	_banner_layer.add_child(bg)

	var border := ColorRect.new()
	border.position = Vector2(858, 56)
	border.size     = Vector2(416, 54)
	border.color    = Color(_active_event_color.r, _active_event_color.g, _active_event_color.b, 0.35)
	_banner_layer.add_child(border)
	_banner_layer.move_child(bg, _banner_layer.get_child_count() - 1)

	# Left accent
	var stripe := ColorRect.new()
	stripe.position = Vector2(858, 56)
	stripe.size     = Vector2(4, 54)
	stripe.color    = _active_event_color
	_banner_layer.add_child(stripe)

	# Text
	var lbl := Label.new()
	lbl.text     = _active_event_title
	lbl.position = Vector2(868, 62)
	lbl.size     = Vector2(400, 36)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.modulate = _active_event_color
	_banner_layer.add_child(lbl)

	# Gentle pulse on the border
	var tw := _banner_layer.create_tween().set_loops()
	tw.tween_property(border, "modulate:a", 0.55, 1.4)
	tw.tween_property(border, "modulate:a", 0.20, 1.4)

func _dismiss_banner() -> void:
	if is_instance_valid(_banner_layer):
		_banner_layer.queue_free()
		_banner_layer = null

# ── Public helpers (checked by Garage, Junkyard, etc.) ───────────────────────
func get_repair_modifier() -> float:
	return repair_modifier

func get_scrap_multiplier() -> int:
	return scrap_multiplier

func get_customer_payout_bonus() -> float:
	return customer_payout_bonus

func is_rush_hour() -> bool:
	return rush_hour_today

func is_junkyard_bonus() -> bool:
	return junkyard_bonus_today

func is_bad_weather() -> bool:
	return bad_weather_today

func is_parts_discount() -> bool:
	return parts_discount_today

func get_active_event() -> String:
	return _active_event_id

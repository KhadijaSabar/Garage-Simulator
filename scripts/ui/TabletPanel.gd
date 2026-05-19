## TabletPanel.gd
## Workshop management tablet — opened by interacting with the desk computer in the garage.
## Five tabs: Market, Auction, Dispatch, Employees, Upgrades.
## Modern dark-mode design, no emojis.
extends Control

signal panel_closed

# ── Tab IDs ───────────────────────────────────────────────────────────────────
enum Tab { MARKET, AUCTION, DISPATCH, EMPLOYEES, UPGRADES }

const TAB_LABELS : Array = ["Market", "Auction", "Dispatch", "Employees", "Upgrades"]
const TAB_ACCENT : Array = [
	Color(0.28, 0.62, 1.00),   # Market    — blue
	Color(1.00, 0.78, 0.22),   # Auction   — gold
	Color(1.00, 0.50, 0.18),   # Dispatch  — orange
	Color(0.30, 0.88, 0.52),   # Employees — green
	Color(0.75, 0.45, 1.00),   # Upgrades  — purple
]

# ── Layout constants ───────────────────────────────────────────────────────────
const PANEL_X  : float = 140.0
const PANEL_Y  : float = 50.0
const PANEL_W  : float = 1000.0
const PANEL_H  : float = 620.0
const TAB_H    : float = 42.0
const CONTENT_Y: float = PANEL_Y + TAB_H + 8.0

# ── State ─────────────────────────────────────────────────────────────────────
var _active_tab    : int          = Tab.MARKET
var _tab_btns      : Array[Button] = []
var _content_root  : Control      = null
var _stripe        : ColorRect    = null
var _tab_underline : ColorRect    = null   ## Moving accent underline on active tab

# Dispatch tab live-update refs (set when DISPATCH tab is built)
var _disp_progress : ProgressBar = null
var _disp_eta_lbl  : Label       = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_chrome()
	_switch_tab(Tab.MARKET)

func _process(_delta: float) -> void:
	# Keep the dispatch tab countdown live without a full rebuild
	if _active_tab != Tab.DISPATCH: return
	if not TowingManager.is_dispatched: return
	if _disp_progress:
		_disp_progress.value = TowingManager.travel_fraction()
	if _disp_eta_lbl:
		_disp_eta_lbl.text = "Truck en route — %.0f s remaining" % TowingManager.travel_remaining()

# ── Chrome (frame, tabs, close) ───────────────────────────────────────────────
func _build_chrome() -> void:
	# Full-screen dim
	var overlay := ColorRect.new()
	overlay.size         = Vector2(1280, 720)
	overlay.color        = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Drop shadow under the card
	var shadow := ColorRect.new()
	shadow.position = Vector2(PANEL_X, PANEL_Y + 8)
	shadow.size     = Vector2(PANEL_W, PANEL_H)
	shadow.color    = Color(0, 0, 0, 0.45)
	add_child(shadow)

	# Card background — matches HUD darks
	var card := ColorRect.new()
	card.position = Vector2(PANEL_X, PANEL_Y)
	card.size     = Vector2(PANEL_W, PANEL_H)
	card.color    = Color(0.06, 0.07, 0.09)
	add_child(card)

	# Top accent stripe (changes colour per tab)
	_stripe = ColorRect.new()
	_stripe.position = Vector2(PANEL_X, PANEL_Y)
	_stripe.size     = Vector2(PANEL_W, 2.0)
	_stripe.color    = TAB_ACCENT[Tab.MARKET]
	add_child(_stripe)

	# Tab bar background — slightly darker than card
	var tab_bg := ColorRect.new()
	tab_bg.position = Vector2(PANEL_X, PANEL_Y + 2)
	tab_bg.size     = Vector2(PANEL_W, TAB_H)
	tab_bg.color    = Color(0.04, 0.05, 0.07)
	add_child(tab_bg)

	# Tab buttons (5 tabs × 150 px = 750 px)
	const TAB_W : float = 150.0
	for i in TAB_LABELS.size():
		var btn := Button.new()
		btn.text     = TAB_LABELS[i].to_upper()
		btn.position = Vector2(PANEL_X + i * TAB_W + 4.0, PANEL_Y + 4.0)
		btn.size     = Vector2(TAB_W - 8.0, TAB_H - 8.0)
		btn.add_theme_font_size_override("font_size", 12)
		btn.flat     = true
		var idx : int = i
		btn.pressed.connect(func(): _switch_tab(idx))
		add_child(btn)
		_tab_btns.append(btn)

	# Active tab underline indicator (moves on tab change)
	_tab_underline = ColorRect.new()
	_tab_underline.size     = Vector2(TAB_W - 8.0, 2.5)
	_tab_underline.color    = TAB_ACCENT[Tab.MARKET]
	_tab_underline.position = Vector2(PANEL_X + 4.0, PANEL_Y + TAB_H - 3.0)
	add_child(_tab_underline)

	# Close button (top-right)
	var close_btn := Button.new()
	close_btn.text     = "X"
	close_btn.position = Vector2(PANEL_X + PANEL_W - 44.0, PANEL_Y + 6.0)
	close_btn.size     = Vector2(36.0, 30.0)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.flat     = true
	close_btn.modulate = Color(0.55, 0.55, 0.60)
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)

	# Thin divider below tab bar
	var div := ColorRect.new()
	div.position = Vector2(PANEL_X, PANEL_Y + TAB_H)
	div.size     = Vector2(PANEL_W, 1.0)
	div.color    = Color(0.14, 0.16, 0.22)
	add_child(div)

	# Content area container
	_content_root = Control.new()
	_content_root.position = Vector2(PANEL_X, CONTENT_Y)
	_content_root.size     = Vector2(PANEL_W, PANEL_H - TAB_H - 8.0)
	add_child(_content_root)

func _switch_tab(tab: int) -> void:
	_active_tab = tab
	_stripe.color = TAB_ACCENT[tab]
	# Move + recolor the underline indicator
	if _tab_underline:
		_tab_underline.color    = TAB_ACCENT[tab]
		_tab_underline.position = Vector2(PANEL_X + tab * 150.0 + 4.0, _tab_underline.position.y)
	# Style tab buttons
	for i in _tab_btns.size():
		var btn : Button = _tab_btns[i]
		if i == tab:
			btn.modulate = TAB_ACCENT[tab]
		else:
			btn.modulate = Color(0.38, 0.40, 0.46)
	# Clear and rebuild content
	for c in _content_root.get_children(): c.queue_free()
	_disp_progress = null
	_disp_eta_lbl  = null
	match tab:
		Tab.MARKET:    _build_market()
		Tab.AUCTION:   _build_auction()
		Tab.DISPATCH:  _build_dispatch()
		Tab.EMPLOYEES: _build_employees()
		Tab.UPGRADES:  _build_upgrades()

# ─────────────────────────────────────────────────────────────────────────────
#  TAB — MARKET
# ─────────────────────────────────────────────────────────────────────────────
func _build_market() -> void:
	var root := _content_root

	_section_label(root, Vector2(24, 14), "VEHICLE MARKET")
	_sub_label(root, Vector2(24, 38), "Browse available vehicles for purchase. Price reflects condition.")

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 64)
	scroll.size     = Vector2(PANEL_W - 32, PANEL_H - TAB_H - 100)
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var tier     : int   = ProgressionManager.current_tier
	var templates: Array = VehicleDatabase.get_vehicles_by_tier(tier)

	if templates.is_empty():
		var lbl := _plain_label("No vehicles available at your current tier.", Color(0.5, 0.5, 0.5), 14)
		lbl.position = Vector2(24, 80)
		root.add_child(lbl)
		return

	for t in templates:
		var base_val   : int   = int(t.get("base_value", 1000))
		var buy_price  : int   = int(base_val * randf_range(0.25, 0.50))
		var condition  : float = randf_range(0.40, 0.85)
		var cond_label : String
		var cond_col   : Color
		if condition <= 0.45:
			cond_label = "Good"; cond_col = Color(0.30, 0.90, 0.45)
		elif condition <= 0.65:
			cond_label = "Worn"; cond_col = Color(0.90, 0.80, 0.25)
		else:
			cond_label = "Rough"; cond_col = Color(1.00, 0.50, 0.20)

		var card := _card(list, Color(0.092, 0.096, 0.118), TAB_ACCENT[Tab.MARKET])
		var row  := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		# Vehicle name + type
		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_vb)

		var name_lbl := _plain_label(t.get("name", "Unknown"), Color(0.92, 0.92, 0.95), 16)
		info_vb.add_child(name_lbl)

		var type_lbl := _plain_label(t.get("type", "sedan").capitalize(), Color(0.50, 0.52, 0.58), 12)
		info_vb.add_child(type_lbl)

		# Condition badge
		var cond_vb := VBoxContainer.new()
		cond_vb.custom_minimum_size = Vector2(80, 0)
		row.add_child(cond_vb)
		var cond_lbl := _plain_label(cond_label, cond_col, 14)
		cond_vb.add_child(cond_lbl)

		# Price + buy button
		var price_vb := VBoxContainer.new()
		price_vb.custom_minimum_size = Vector2(120, 0)
		row.add_child(price_vb)

		var price_lbl := _plain_label("$%d" % buy_price, Color(0.92, 0.78, 0.28), 18)
		price_vb.add_child(price_lbl)

		var can_afford : bool = EconomyManager.can_afford(buy_price)
		var buy_btn := Button.new()
		buy_btn.text     = "BUY"
		buy_btn.disabled = not can_afford
		buy_btn.add_theme_font_size_override("font_size", 13)
		buy_btn.custom_minimum_size = Vector2(80, 30)
		var tid   : String = t["id"]
		var tname : String = t["name"]
		var tprice: int    = buy_price
		var tcond : float  = condition
		buy_btn.pressed.connect(func(): _on_buy_vehicle(tid, tname, tprice, tcond))
		price_vb.add_child(buy_btn)

	# Balance indicator
	var bal_lbl := _plain_label("Available cash:  $%s" % _fmt(EconomyManager.money), Color(0.40, 0.70, 0.40), 13)
	bal_lbl.position = Vector2(24, PANEL_H - TAB_H - 44)
	root.add_child(bal_lbl)

func _on_buy_vehicle(template_id: String, _name: String, price: int, damage: float) -> void:
	if not EconomyManager.can_afford(price):
		return
	EconomyManager.spend_money(price, "Market: %s" % _name)
	# Tell Garage.gd to spawn it — send via GameManager meta
	GameManager.set_meta("market_purchase", {"id": template_id, "damage": damage, "price": price})
	_on_close()

# ─────────────────────────────────────────────────────────────────────────────
#  TAB — AUCTION
# ─────────────────────────────────────────────────────────────────────────────
func _build_auction() -> void:
	var root := _content_root
	var accent : Color = TAB_ACCENT[Tab.AUCTION]

	_section_label(root, Vector2(24, 14), "DAILY AUCTION")
	_sub_label(root, Vector2(24, 38), "Set your maximum bid. Rivals bid against you. Winners pay just above the second-highest bid.")

	if not AuctionSystem.can_resolve() and AuctionSystem.current_lots.is_empty():
		var lbl := _plain_label("No lots today. Check back tomorrow.", Color(0.5, 0.5, 0.5), 15)
		lbl.position = Vector2(24, 80)
		root.add_child(lbl)
		return

	# Rivals strip
	var rivals_row := HBoxContainer.new()
	rivals_row.position = Vector2(24, 58)
	rivals_row.add_theme_constant_override("separation", 24)
	root.add_child(rivals_row)
	for ai in AuctionSystem.AI_BIDDERS:
		var riv_lbl := _plain_label("%s  %s" % [ai["name"], _interest_bar(float(ai["interest"]))],
			Color(0.60, 0.60, 0.65), 12)
		rivals_row.add_child(riv_lbl)

	# Lots
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 84)
	scroll.size     = Vector2(PANEL_W - 32, PANEL_H - TAB_H - 160)
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for lot in AuctionSystem.current_lots:
		var true_val : int = int(lot["true_value"])
		var lo : int = int(true_val * 0.70)
		var hi : int = int(true_val * 1.30)
		var cond_col : Color = Color(lot["cond_color"][0], lot["cond_color"][1], lot["cond_color"][2])

		var card := _card(list, Color(0.092, 0.096, 0.115), TAB_ACCENT[Tab.AUCTION])
		var row  := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		# Name + info
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_plain_label(lot["vehicle_name"], Color(0.90, 0.90, 0.95), 15))
		info.add_child(_plain_label("Condition: %s   |   Est. value: $%d – $%d" % [lot["cond_label"], lo, hi],
			Color(0.55, 0.56, 0.60), 12))
		info.add_child(_plain_label("Starting bid: $%d" % int(lot["start_bid"]), cond_col, 12))

		# Slider column
		var slider_vb := VBoxContainer.new()
		slider_vb.custom_minimum_size = Vector2(260, 0)
		row.add_child(slider_vb)

		var slider_lbl := _plain_label("Max bid: $%d" % int(lot.get("player_max", 0)), accent, 13)
		slider_vb.add_child(slider_lbl)

		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = int(true_val * 1.6)
		slider.step      = 50
		slider.value     = int(lot.get("player_max", 0))
		slider.custom_minimum_size = Vector2(240, 22)
		var lot_id : int = lot["id"]
		slider.value_changed.connect(func(v: float):
			# Snap to 0 if below start bid (means "not bidding")
			var bid_floor : int = 0 if v < int(lot["start_bid"]) else int(v)
			AuctionSystem.set_player_max(lot_id, bid_floor)
			slider_lbl.text = "Max bid: %s" % ("—  (not bidding)" if bid_floor == 0 else "$%d" % bid_floor))
		slider_vb.add_child(slider)

	# Bottom bar
	var bottom_row := HBoxContainer.new()
	bottom_row.position = Vector2(16, PANEL_H - TAB_H - 60)
	bottom_row.add_theme_constant_override("separation", 16)
	root.add_child(bottom_row)

	var finalise_btn := Button.new()
	finalise_btn.text = "FINALISE BIDS"
	finalise_btn.custom_minimum_size = Vector2(180, 38)
	finalise_btn.add_theme_font_size_override("font_size", 14)
	if not AuctionSystem.can_resolve():
		finalise_btn.disabled = true
		finalise_btn.text = "BIDS FINALISED TODAY"
	finalise_btn.pressed.connect(_on_finalise_bids)
	bottom_row.add_child(finalise_btn)

	var budget_lbl := _plain_label("Your cash:  $%s" % _fmt(EconomyManager.money), Color(0.40, 0.70, 0.40), 13)
	bottom_row.add_child(budget_lbl)

func _on_finalise_bids() -> void:
	var results : Array = AuctionSystem.resolve()
	if results.is_empty(): return
	# Rebuild the tab to show results state
	_switch_tab(Tab.AUCTION)
	# Show result summary in a popup
	_show_result_popup(results)

func _show_result_popup(results: Array) -> void:
	var popup := ColorRect.new()
	popup.position = Vector2(200, 120)
	popup.size     = Vector2(600, 420)
	popup.color    = Color(0.07, 0.08, 0.10, 0.98)
	add_child(popup)

	var title := _plain_label("AUCTION RESULTS", Color(1.0, 0.78, 0.22), 22)
	title.position = Vector2(220, 132)
	add_child(title)

	var wins : int = 0
	var spent: int = 0
	var y : float = 170.0
	for res in results:
		var col : Color = Color(0.35, 0.92, 0.52) if res["is_player_win"] else Color(0.52, 0.52, 0.55)
		var outcome : String = "WON — $%d" % res["final_price"] if res["is_player_win"] \
			else "Lost to %s" % res["winner_name"]
		var row_lbl := _plain_label("%-28s  %s" % [res["vehicle_name"], outcome], col, 14)
		row_lbl.position = Vector2(220, y)
		add_child(row_lbl)
		y += 26.0
		if res["is_player_win"]:
			wins += 1
			spent += int(res["final_price"])

	var summary := _plain_label("Vehicles won: %d   |   Total spent: $%s" % [wins, _fmt(spent)],
		Color(0.75, 0.75, 0.80), 14)
	summary.position = Vector2(220, y + 12)
	add_child(summary)

	var ok_btn := Button.new()
	ok_btn.text     = "OK"
	ok_btn.position = Vector2(548, 498)
	ok_btn.size     = Vector2(80, 32)
	ok_btn.pressed.connect(func():
		popup.queue_free(); title.queue_free(); summary.queue_free(); ok_btn.queue_free()
		for c in get_children():
			if c is Label and c.position.y >= 170 and c.position.y < 500:
				c.queue_free())
	add_child(ok_btn)

# ─────────────────────────────────────────────────────────────────────────────
#  TAB — DISPATCH
# ─────────────────────────────────────────────────────────────────────────────
func _build_dispatch() -> void:
	var root   := _content_root
	var accent : Color = TAB_ACCENT[Tab.DISPATCH]

	_section_label(root, Vector2(24, 14), "DISPATCH")
	_sub_label(root, Vector2(24, 38), "Send your tow truck to recover roadside wrecks. Three missions refresh each day.")

	# ── Truck status strip ────────────────────────────────────────────────────
	var status_card := ColorRect.new()
	status_card.position = Vector2(16, 60)
	status_card.size     = Vector2(PANEL_W - 32, 68)
	status_card.color    = Color(0.10, 0.10, 0.13)
	root.add_child(status_card)

	if TowingManager.is_dispatched:
		# En-route state
		var active : Dictionary = TowingManager.active_mission

		var status_lbl := _plain_label(
			"En route — %s" % active.get("label", "Unknown"), accent, 15)
		status_lbl.position = Vector2(28, 66)
		root.add_child(status_lbl)

		_disp_eta_lbl = _plain_label(
			"Truck en route — %.0f s remaining" % TowingManager.travel_remaining(),
			Color(0.70, 0.70, 0.75), 13)
		_disp_eta_lbl.position = Vector2(28, 86)
		root.add_child(_disp_eta_lbl)

		_disp_progress = ProgressBar.new()
		_disp_progress.position          = Vector2(28, 108)
		_disp_progress.size              = Vector2(PANEL_W - 72, 12)
		_disp_progress.value             = TowingManager.travel_fraction()
		_disp_progress.show_percentage   = false
		root.add_child(_disp_progress)
	else:
		var ready_lbl := _plain_label("Truck available — ready to dispatch.", Color(0.42, 0.88, 0.52), 15)
		ready_lbl.position = Vector2(28, 74)
		root.add_child(ready_lbl)

	# ── Mission list ──────────────────────────────────────────────────────────
	var list_hdr := _plain_label("AVAILABLE MISSIONS", accent, 12)
	list_hdr.position = Vector2(24, 140)
	root.add_child(list_hdr)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 160)
	scroll.size     = Vector2(PANEL_W - 32, PANEL_H - TAB_H - 210)
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if TowingManager.available_missions.is_empty():
		var no_mission_txt : String = \
			"No more missions today — next batch arrives tomorrow." \
			if TowingManager.is_dispatched \
			else "No missions available today. Check back tomorrow."
		list.add_child(_plain_label(no_mission_txt, Color(0.45, 0.45, 0.48), 14))
	else:
		for mission in TowingManager.available_missions:
			list.add_child(_dispatch_card(mission))

func _dispatch_card(m: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.092, 0.096, 0.115)
	style.border_color = TAB_ACCENT[Tab.DISPATCH]
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12; style.content_margin_right  = 12
	style.content_margin_top  = 10; style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vb.add_child(title_row)

	var label_vb := VBoxContainer.new()
	label_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(label_vb)
	label_vb.add_child(_plain_label(m.get("label", "Unknown"), Color(0.90, 0.90, 0.95), 16))

	# Get vehicle name from database
	var vdata : Dictionary = VehicleDatabase.get_vehicle(m.get("vehicle_id", ""))
	var vname : String = vdata.get("name", m.get("vehicle_id", "Unknown")) if not vdata.is_empty() else m.get("vehicle_id","")
	label_vb.add_child(_plain_label(vname, Color(0.55, 0.56, 0.60), 12))

	# Right side: fee + travel time
	var meta_vb := VBoxContainer.new()
	meta_vb.custom_minimum_size = Vector2(110, 0)
	title_row.add_child(meta_vb)

	var fee_lbl := _plain_label("+$%d tow fee" % int(m.get("tow_fee", 0)), Color(0.42, 0.88, 0.52), 15)
	meta_vb.add_child(fee_lbl)

	var travel_lbl := _plain_label("%.0f s trip" % float(m.get("travel_sec", 0)), Color(0.55, 0.56, 0.60), 12)
	meta_vb.add_child(travel_lbl)

	# Description
	vb.add_child(_plain_label(m.get("desc", ""), Color(0.55, 0.56, 0.60), 12))

	# Damage preview
	var dmg_pct  : int = int(float(m.get("damage", 0.5)) * 100.0)
	var dmg_col  : Color
	if dmg_pct >= 80:
		dmg_col = Color(1.0, 0.40, 0.30)
	elif dmg_pct >= 60:
		dmg_col = Color(1.0, 0.72, 0.22)
	else:
		dmg_col = Color(0.40, 0.88, 0.52)
	vb.add_child(_plain_label("Damage: %d%%    |    Tier required: %d" % [dmg_pct, int(m.get("min_tier", 1))],
		dmg_col, 12))

	# Dispatch button
	var can_dispatch : bool = not TowingManager.is_dispatched
	var btn := Button.new()
	btn.text     = "DISPATCH TRUCK"
	btn.disabled = not can_dispatch
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(180, 32)
	if not can_dispatch:
		btn.text = "TRUCK BUSY"
	var mid : String = m["id"]
	btn.pressed.connect(func():
		TowingManager.dispatch(mid)
		_switch_tab(Tab.DISPATCH))
	vb.add_child(btn)

	return panel

# ─────────────────────────────────────────────────────────────────────────────
#  TAB — EMPLOYEES
# ─────────────────────────────────────────────────────────────────────────────
func _build_employees() -> void:
	var root   := _content_root
	var accent : Color = TAB_ACCENT[Tab.EMPLOYEES]

	_section_label(root, Vector2(24, 14), "STAFF MANAGEMENT")
	var wage : int = EmployeeManager.get_daily_wage_total()
	var slots : String = "%d / %d" % [EmployeeManager.hired.size(), EmployeeManager.max_employees()]
	_sub_label(root, Vector2(24, 38), "Daily wage bill: $%d   |   Slots: %s   |   Tier %d" % [
		wage, slots, ProgressionManager.current_tier])

	# Two-column layout
	var cols := HBoxContainer.new()
	cols.position = Vector2(16, 64)
	cols.size     = Vector2(PANEL_W - 32, PANEL_H - TAB_H - 90)
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	# Left — current staff
	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 6)
	cols.add_child(left_vb)
	left_vb.add_child(_col_header("CURRENT STAFF", accent))

	var hired_scroll := ScrollContainer.new()
	hired_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vb.add_child(hired_scroll)
	var hired_list := VBoxContainer.new()
	hired_list.add_theme_constant_override("separation", 6)
	hired_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hired_scroll.add_child(hired_list)

	if EmployeeManager.hired.is_empty():
		hired_list.add_child(_plain_label("No staff hired yet.", Color(0.45, 0.45, 0.48), 13))
	else:
		for emp in EmployeeManager.hired:
			hired_list.add_child(_emp_card(emp, true))

	# Right — available
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 6)
	cols.add_child(right_vb)
	right_vb.add_child(_col_header("AVAILABLE THIS WEEK", accent))

	var avail_scroll := ScrollContainer.new()
	avail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_child(avail_scroll)
	var avail_list := VBoxContainer.new()
	avail_list.add_theme_constant_override("separation", 6)
	avail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avail_scroll.add_child(avail_list)

	var pool : Array = EmployeeManager.get_available()
	if pool.is_empty():
		avail_list.add_child(_plain_label("No candidates this week.", Color(0.45, 0.45, 0.48), 13))
	else:
		for emp in pool:
			avail_list.add_child(_emp_card(emp, false))

func _emp_card(emp: Dictionary, is_hired: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.15)
	style.border_color = TAB_ACCENT[Tab.EMPLOYEES] * Color(1,1,1,0.35) if is_hired \
		else Color(0.22, 0.24, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top  = 8;  style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	# Name + skill
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vb.add_child(name_row)
	name_row.add_child(_plain_label(emp["name"], Color(0.90, 0.90, 0.95), 15))
	var stars : String = "".join(PackedStringArray(Array(range(int(emp.get("skill",1)))).map(func(_x): return "+")))
	var empties: String = "".join(PackedStringArray(Array(range(4 - int(emp.get("skill",1)))).map(func(_x): return "-")))
	var skill_lbl := _plain_label(stars + empties, Color(1.0, 0.82, 0.22), 13)
	name_row.add_child(skill_lbl)

	vb.add_child(_plain_label(emp.get("bio",""), Color(0.55, 0.56, 0.60), 11))

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 14)
	vb.add_child(stats_row)
	stats_row.add_child(_plain_label("Specialty: %s" % emp.get("specialty","all").capitalize(), Color(0.38,0.78,0.55), 11))
	stats_row.add_child(_plain_label("$%d/day" % int(emp.get("daily_wage",0)), Color(0.88,0.72,0.28), 11))
	var rel : int = 100 - int(float(emp.get("blunder_chance",0.0)) * 100.0)
	stats_row.add_child(_plain_label("Reliability %d%%" % rel, Color(0.55,0.55,0.60), 11))

	var emp_id : String = emp["id"]
	if is_hired:
		var btn := Button.new()
		btn.text = "FIRE"; btn.add_theme_font_size_override("font_size", 12)
		btn.modulate = Color(1.0, 0.42, 0.35)
		btn.pressed.connect(func(): EmployeeManager.fire(emp_id); _switch_tab(Tab.EMPLOYEES))
		vb.add_child(btn)
	else:
		var can : bool = EmployeeManager.can_hire() and EconomyManager.can_afford(int(emp.get("daily_wage",0)))
		var btn := Button.new()
		btn.text     = "HIRE  —  $%d/day" % int(emp.get("daily_wage",0))
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = not can
		btn.pressed.connect(func(): EmployeeManager.hire(emp_id); XPManager.award_raw(25,"hire"); _switch_tab(Tab.EMPLOYEES))
		vb.add_child(btn)

	return panel

# ─────────────────────────────────────────────────────────────────────────────
#  TAB — UPGRADES
# ─────────────────────────────────────────────────────────────────────────────
func _build_upgrades() -> void:
	var root   := _content_root
	var accent : Color = TAB_ACCENT[Tab.UPGRADES]

	_section_label(root, Vector2(24, 14), "GARAGE UPGRADES")
	_sub_label(root, Vector2(24, 38), "Permanent improvements to your workshop.")

	# Tier upgrade card
	var tier_card := _card(root, Color(0.092, 0.092, 0.128), TAB_ACCENT[Tab.UPGRADES])
	tier_card.position = Vector2(16, 62)

	var tier_vb := tier_card.get_child(0) as VBoxContainer
	if not tier_vb:
		tier_vb = VBoxContainer.new(); tier_card.add_child(tier_vb)
	tier_vb.add_theme_constant_override("separation", 6)

	var cur_data : Dictionary = ProgressionManager.get_tier_data()
	var nxt_data : Dictionary = ProgressionManager.get_next_tier_data()

	tier_vb.add_child(_plain_label("GARAGE TIER", accent, 12))
	tier_vb.add_child(_plain_label(
		"Current: Tier %d  —  %s  (%d bays)" % [ProgressionManager.current_tier, cur_data.get("name",""), cur_data.get("max_bays",1)],
		Color(0.85, 0.85, 0.90), 15))

	if ProgressionManager.is_max_tier():
		tier_vb.add_child(_plain_label("Maximum tier reached.", Color(1.0, 0.78, 0.22), 14))
	else:
		tier_vb.add_child(_plain_label(
			"Next: Tier %d  —  %s  |  Cost: $%s" % [ProgressionManager.current_tier + 1,
			nxt_data.get("name",""), _fmt(nxt_data.get("upgrade_cost",0))],
			Color(0.60, 0.60, 0.65), 13))
		var can_up : bool = ProgressionManager.can_upgrade()
		var up_btn := Button.new()
		up_btn.text     = "UPGRADE GARAGE  —  $%s" % _fmt(nxt_data.get("upgrade_cost", 0))
		up_btn.disabled = not can_up
		up_btn.add_theme_font_size_override("font_size", 13)
		up_btn.custom_minimum_size = Vector2(260, 34)
		up_btn.pressed.connect(func():
			ProgressionManager.upgrade_tier()
			_switch_tab(Tab.UPGRADES))
		tier_vb.add_child(up_btn)

	# One-off upgrades
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 210)
	scroll.size     = Vector2(PANEL_W - 32, PANEL_H - TAB_H - 260)
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	list.add_child(_plain_label("ONE-OFF UPGRADES", accent, 12))
	list.add_child(HSeparator.new())

	for uid in ProgressionManager.UPGRADES:
		var udata : Dictionary = ProgressionManager.UPGRADES[uid]
		var purchased : bool  = ProgressionManager.has_upgrade(uid)

		var card := _card(list, Color(0.092, 0.096, 0.115), TAB_ACCENT[Tab.UPGRADES])
		var row  := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_plain_label(udata.get("name",""), Color(0.88, 0.88, 0.92), 15))
		info.add_child(_plain_label(udata.get("description",""), Color(0.55, 0.56, 0.60), 12))

		if purchased:
			var done_lbl := _plain_label("INSTALLED", accent, 13)
			row.add_child(done_lbl)
		else:
			var cost : int = udata.get("cost", 0)
			var btn  := Button.new()
			btn.text     = "$%s" % _fmt(cost)
			btn.disabled = not EconomyManager.can_afford(cost)
			btn.add_theme_font_size_override("font_size", 13)
			btn.custom_minimum_size = Vector2(90, 32)
			btn.pressed.connect(func():
				ProgressionManager.buy_upgrade(uid)
				_switch_tab(Tab.UPGRADES))
			row.add_child(btn)

# ─────────────────────────────────────────────────────────────────────────────
#  SHARED HELPERS
# ─────────────────────────────────────────────────────────────────────────────
## bg = card background; accent = optional left border stripe color.
func _card(parent: Node, bg: Color, accent: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var pc    := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(4)
	style.content_margin_left  = 12; style.content_margin_right  = 12
	style.content_margin_top   = 10; style.content_margin_bottom = 10
	if accent.a > 0.0:
		style.border_width_left   = 3
		style.border_width_right  = 0
		style.border_width_top    = 0
		style.border_width_bottom = 0
		style.border_color        = accent
	pc.add_theme_stylebox_override("panel", style)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	parent.add_child(pc)
	return pc

func _section_label(parent: Control, pos: Vector2, text: String) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.modulate = Color(0.88, 0.88, 0.92)
	parent.add_child(lbl)
	return lbl

func _sub_label(parent: Control, pos: Vector2, text: String) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.45, 0.46, 0.50)
	parent.add_child(lbl)
	return lbl

func _col_header(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text    = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl

func _plain_label(text: String, color: Color, font_sz: int) -> Label:
	var lbl := Label.new()
	lbl.text    = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", font_sz)
	return lbl

func _interest_bar(interest: float) -> String:
	var filled : int = int(round(interest * 5.0))
	return "|".repeat(filled) + ".".repeat(5 - filled)

func _fmt(n: int) -> 
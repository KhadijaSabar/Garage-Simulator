## AuctionPanel.gd
## Full-screen auction UI. Shows today's lots, lets player place max bids,
## then resolves with an animated results sequence.
extends Control

# ── State ─────────────────────────────────────────────────────────────────────
var _player_bids : Dictionary = {}   ## lot_id → max bid the player set
var _in_results  : bool       = false

# ── UI refs ───────────────────────────────────────────────────────────────────
var _lots_container : VBoxContainer
var _total_lbl      : Label
var _resolve_btn    : Button
var _status_lbl     : Label
var _results_box    : VBoxContainer
var _close_btn      : Button

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_populate_lots()

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Full overlay (dim background)
	var overlay := ColorRect.new()
	overlay.size         = Vector2(1280, 720)
	overlay.color        = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel card
	var panel := ColorRect.new()
	panel.size     = Vector2(820, 620)
	panel.position = Vector2(230, 50)
	panel.color    = Color(0.08, 0.07, 0.06, 0.98)
	add_child(panel)

	# Left gold accent
	var accent := ColorRect.new()
	accent.size     = Vector2(6, 620)
	accent.position = Vector2(230, 50)
	accent.color    = Color(1.0, 0.80, 0.20)
	add_child(accent)

	# Layout VBox
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(246, 62)
	vbox.size     = Vector2(796, 596)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var title := Label.new()
	title.text = "🏷️  VEHICLE AUCTION — Day %d" % GameManager.current_day
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(1.0, 0.82, 0.22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var budget_lbl := Label.new()
	budget_lbl.text = "Budget: $%s" % _fmt(EconomyManager.money)
	budget_lbl.add_theme_font_size_override("font_size", 16)
	budget_lbl.modulate = Color(0.45, 1.0, 0.45)
	header_row.add_child(budget_lbl)

	# ── Rivals row ────────────────────────────────────────────────────────────
	var rival_lbl := Label.new()
	rival_lbl.add_theme_font_size_override("font_size", 12)
	rival_lbl.modulate = Color(0.60, 0.60, 0.60)
	var rivals := []
	for b in AuctionSystem.AI_BIDDERS:
		rivals.append("%s %s" % [b["icon"], b["name"]])
	rival_lbl.text = "Competing today: " + "  •  ".join(rivals)
	vbox.add_child(rival_lbl)

	vbox.add_child(HSeparator.new())

	# Status label (shown before / after resolve)
	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.modulate = Color(0.75, 0.82, 1.0)
	_status_lbl.text = "Set your max bids below, then hit  Finalise Bids  to see results."
	vbox.add_child(_status_lbl)

	# ── Lots scroll area ───────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 320
	vbox.add_child(scroll)

	_lots_container = VBoxContainer.new()
	_lots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lots_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_lots_container)

	# ── Results box (hidden until resolved) ───────────────────────────────────
	_results_box = VBoxContainer.new()
	_results_box.visible = false
	_results_box.add_theme_constant_override("separation", 5)
	vbox.add_child(_results_box)

	# ── Footer ────────────────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	vbox.add_child(footer)

	_total_lbl = Label.new()
	_total_lbl.add_theme_font_size_override("font_size", 14)
	_total_lbl.modulate = Color(0.80, 0.80, 0.80)
	_total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_total_lbl)

	if not AuctionSystem.can_resolve():
		_status_lbl.text   = "⏳ Already resolved today — check tomorrow for fresh lots."
		_status_lbl.modulate = Color(0.70, 0.65, 0.55)

	_resolve_btn = Button.new()
	_resolve_btn.text = "⚡  Finalise Bids"
	_resolve_btn.custom_minimum_size = Vector2(180, 42)
	_resolve_btn.add_theme_font_size_override("font_size", 15)
	_resolve_btn.disabled = not AuctionSystem.can_resolve()
	_resolve_btn.pressed.connect(_on_resolve_pressed)
	footer.add_child(_resolve_btn)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(90, 42)
	_close_btn.pressed.connect(func(): queue_free())
	footer.add_child(_close_btn)

# ── Populate lot cards ────────────────────────────────────────────────────────
func _populate_lots() -> void:
	for c in _lots_container.get_children(): c.queue_free()

	if AuctionSystem.current_lots.is_empty():
		var empty := Label.new()
		empty.text = "No lots available today."
		_lots_container.add_child(empty)
		return

	for lot in AuctionSystem.current_lots:
		_lots_container.add_child(_make_lot_card(lot))

	_refresh_total()

func _make_lot_card(lot: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color              = Color(0.12, 0.11, 0.10, 1.0)
	card.custom_minimum_size = Vector2(0, 72)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(10, 8)
	hbox.size     = Vector2(760, 56)
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Lot number
	var lot_num := Label.new()
	lot_num.text = "Lot\n%d" % (AuctionSystem.current_lots.find(lot) + 1)
	lot_num.add_theme_font_size_override("font_size", 11)
	lot_num.modulate = Color(0.55, 0.55, 0.55)
	lot_num.custom_minimum_size.x = 36
	hbox.add_child(lot_num)

	# Condition color bar
	var cond_color := Color(
		float(lot["cond_color"][0]),
		float(lot["cond_color"][1]),
		float(lot["cond_color"][2]))
	var cbar := ColorRect.new()
	cbar.color              = cond_color
	cbar.custom_minimum_size = Vector2(5, 56)
	hbox.add_child(cbar)

	# Name + condition
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 2)
	hbox.add_child(info_col)

	var name_lbl := Label.new()
	name_lbl.text = lot["vehicle_name"]
	name_lbl.add_theme_font_size_override("font_size", 16)
	info_col.add_child(name_lbl)

	var cond_lbl := Label.new()
	cond_lbl.text    = "Condition: %s" % lot["cond_label"]
	cond_lbl.modulate = cond_color
	cond_lbl.add_theme_font_size_override("font_size", 12)
	info_col.add_child(cond_lbl)

	var est_lbl := Label.new()
	var lo : int = int(lot["true_value"] * 0.70)
	var hi : int = int(lot["true_value"] * 1.30)
	est_lbl.text    = "Est. value: $%s – $%s" % [_fmt(lo), _fmt(hi)]
	est_lbl.modulate = Color(0.60, 0.60, 0.60)
	est_lbl.add_theme_font_size_override("font_size", 11)
	info_col.add_child(est_lbl)

	# Start bid
	var bid_col := VBoxContainer.new()
	bid_col.custom_minimum_size.x = 140
	bid_col.add_theme_constant_override("separation", 2)
	hbox.add_child(bid_col)

	var start_lbl := Label.new()
	start_lbl.text    = "Start bid"
	start_lbl.modulate = Color(0.55, 0.55, 0.55)
	start_lbl.add_theme_font_size_override("font_size", 11)
	start_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_col.add_child(start_lbl)

	var start_val := Label.new()
	start_val.text    = "$%s" % _fmt(lot["start_bid"])
	start_val.add_theme_font_size_override("font_size", 18)
	start_val.modulate = Color(0.95, 0.88, 0.40)
	start_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_col.add_child(start_val)

	# Max bid slider
	var slider_col := VBoxContainer.new()
	slider_col.custom_minimum_size.x = 230
	slider_col.add_theme_constant_override("separation", 2)
	hbox.add_child(slider_col)

	var bid_header_row := HBoxContainer.new()
	slider_col.add_child(bid_header_row)

	var bid_hdr := Label.new()
	bid_hdr.text = "Your max bid:"
	bid_hdr.add_theme_font_size_override("font_size", 11)
	bid_hdr.modulate = Color(0.65, 0.65, 0.65)
	bid_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid_header_row.add_child(bid_hdr)

	var slider_val_lbl := Label.new()
	var init_max : int = _player_bids.get(lot["id"], 0)
	slider_val_lbl.text = "No bid" if init_max == 0 else "$%s" % _fmt(init_max)
	slider_val_lbl.add_theme_font_size_override("font_size", 13)
	slider_val_lbl.modulate = Color(0.45, 1.0, 0.55) if init_max > 0 else Color(0.55, 0.55, 0.55)
	bid_header_row.add_child(slider_val_lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = int(lot["true_value"] * 2.0)
	slider.step      = 50
	slider.value     = init_max
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lid : int = lot["id"]
	slider.value_changed.connect(func(v: float):
		var iv : int = int(v)
		if iv < lot["start_bid"]:
			iv = 0; slider.value = 0
		_player_bids[lid] = iv
		AuctionSystem.set_player_max(lid, iv)
		if iv == 0:
			slider_val_lbl.text    = "No bid"
			slider_val_lbl.modulate = Color(0.55, 0.55, 0.55)
		else:
			slider_val_lbl.text    = "$%s" % _fmt(iv)
			slider_val_lbl.modulate = Color(0.45, 1.0, 0.55)
		_refresh_total())
	slider_col.add_child(slider)

	var hint_lbl := Label.new()
	hint_lbl.text    = "0 = not bidding  •  slide to set your max"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.modulate = Color(0.42, 0.42, 0.42)
	slider_col.add_child(hint_lbl)

	return card

func _refresh_total() -> void:
	var total := 0
	for v in _player_bids.values(): total += int(v)
	if total == 0:
		_total_lbl.text    = "No bids placed yet."
		_total_lbl.modulate = Color(0.55, 0.55, 0.55)
	else:
		var affordable : bool = EconomyManager.can_afford(total)
		_total_lbl.text    = "If you win all: ~$%s  (budget: $%s)" % [_fmt(total), _fmt(EconomyManager.money)]
		_total_lbl.modulate = Color(0.45, 1.0, 0.45) if affordable else Color(1.0, 0.45, 0.35)

# ── Resolve auction ───────────────────────────────────────────────────────────
func _on_resolve_pressed() -> void:
	if _in_results: return
	_in_results = true
	_resolve_btn.disabled = true
	_lots_container.visible = false
	_results_box.visible    = true
	_status_lbl.text        = "⚡  Auction in progress…"
	_status_lbl.modulate    = Color(1.0, 0.85, 0.25)

	var results : Array = AuctionSystem.resolve()
	AudioManager.play("day_start", -6.0)
	await _animate_results(results)

	_status_lbl.text    = "✅  Auction complete! Won vehicles will be delivered tomorrow."
	_status_lbl.modulate = Color(0.45, 1.0, 0.55)

func _animate_results(results: Array) -> void:
	var wins : int = 0
	var spent: int = 0
	for res in results:
		var row := _make_result_row(res, false)
		_results_box.add_child(row)
		AudioManager.play_varied("click", 0.9, 1.1, -4.0)
		await get_tree().create_timer(0.45).timeout
		# Reveal winner colour
		_reveal_result_row(row, res)
		if res["is_player_win"]:
			wins  += 1
			spent += res["final_price"]
			AudioManager.play("cash", -3.0)
		await get_tree().create_timer(0.30).timeout

	# Summary
	var sep := HSeparator.new(); _results_box.add_child(sep)
	var summary := Label.new()
	if wins == 0:
		summary.text    = "You won nothing today. Try higher bids tomorrow."
		summary.modulate = Color(0.75, 0.55, 0.55)
	else:
		summary.text    = "🏆  You won %d vehicle%s — paid $%s total. Delivery tomorrow!" % [
			wins, "s" if wins > 1 else "", _fmt(spent)]
		summary.modulate = Color(0.45, 1.0, 0.55)
		AudioManager.play("order_ok", -4.0)
	summary.add_theme_font_size_override("font_size", 15)
	_results_box.add_child(summary)

func _make_result_row(res: Dictionary, _revealed: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 28

	var name_lbl := Label.new()
	name_lbl.text = res["vehicle_name"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var dots := Label.new()
	dots.text    = "bidding…"
	dots.modulate = Color(0.60, 0.60, 0.60)
	dots.add_theme_font_size_override("font_size", 13)
	dots.set_meta("result_dots", true)
	row.add_child(dots)

	return row

func _reveal_result_row(row: HBoxContainer, res: Dictionary) -> void:
	var dots : Label = null
	for c in row.get_children():
		if c.has_meta("result_dots"):
			dots = c as Label
			break
	if not dots: return

	if res["final_price"] == 0:
		dots.text    = "— No bids — unsold"
		dots.modulate = Color(0.50, 0.50, 0.50)
	elif res["is_player_win"]:
		dots.text    = "✅  YOU WON — $%s" % _fmt(res["final_price"])
		dots.modulate = Color(0.40, 1.0, 0.50)
	else:
		dots.text    = "❌  Lost to %s  ($%s)" % [res["winner_name"], _fmt(res["final_price"])]
		dots.modulate = Color(0.80, 0.45, 0.45)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _fmt(n: int) -> String:
	var s := str(abs(n)); var r := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0: r += ","
		r += s[i]
	return r

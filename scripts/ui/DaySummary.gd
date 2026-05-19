## DaySummary.gd
## Full-screen overlay shown after each day's night phase.
## Clean sim-game style — dark card, stat rows, no emojis.
extends CanvasLayer

# ── Tips ──────────────────────────────────────────────────────────────────────
const TIPS: Array = [
	"Clean cars sell for more — invest in a pressure washer early!",
	"Emergency orders pay 2× but expire in just 1 day. High risk, high reward.",
	"The junkyard resets every day — stop by often for free parts.",
	"Higher reputation unlocks better-paying orders from richer customers.",
	"Hire a Workbench worker and they'll auto-repair while you focus elsewhere.",
	"Security upgrades stack — combine alarm + dog + camera for tough nights.",
	"Flip cheap wrecks from the junkyard for fast early-game cash.",
	"Spare parts from the junkyard let you repair vehicles for FREE.",
	"Complete orders early for a speed bonus on top of the base payout.",
	"A dirty garage slowly drags your reputation down — clean those spills!",
	"The Classic Coupe unlocks at Tier 2 and is worth 3× a standard sedan.",
	"Workers cost a daily salary — make sure orders cover the overhead!",
]

# ── Data (set by Garage before add_child) ────────────────────────────────────
var night_event: Dictionary = {}   ## keys: type ("quiet"/"caught"/"stolen"), item (String)

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 20   # On top of everything
	_build_ui()

# ── UI ────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Snapshot data
	var day: int          = GameManager.current_day
	var money_before: int = GameManager.day_start_money
	var money_after: int  = EconomyManager.money
	var rep_before: float = GameManager.day_start_rep
	var rep_after: float  = EconomyManager.reputation
	var orders_done: int  = OrderSystem.completed_today

	# ── Dark dim overlay ──────────────────────────────────────────────────────
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.84)
	add_child(overlay)

	# ── Card (centered) ──────────────────────────────────────────────────────
	var card := PanelContainer.new()
	card.position = Vector2(340, 60)
	card.custom_minimum_size = Vector2(600, 600)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.07, 0.09, 0.98)
	card_style.corner_radius_top_left     = 6
	card_style.corner_radius_top_right    = 6
	card_style.corner_radius_bottom_left  = 6
	card_style.corner_radius_bottom_right = 6
	card_style.border_color       = Color(UITheme.RUST, 0.50)
	card_style.border_width_top   = 1; card_style.border_width_bottom = 1
	card_style.border_width_left  = 1; card_style.border_width_right  = 1
	card_style.content_margin_left   = 30
	card_style.content_margin_right  = 30
	card_style.content_margin_top    = 24
	card_style.content_margin_bottom = 24
	card_style.shadow_color  = Color(0, 0, 0, 0.6)
	card_style.shadow_size   = 24
	card_style.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var kicker := Label.new()
	kicker.text = "END OF DAY"
	kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	kicker.modulate = Color(UITheme.RUST, 0.85)
	vbox.add_child(kicker)

	var header := Label.new()
	header.text = "DAY %d  COMPLETE" % day
	header.add_theme_font_size_override("font_size", 34)
	header.modulate = Color(0.96, 0.96, 0.96)
	vbox.add_child(header)

	# Accent stripe
	var stripe := ColorRect.new()
	stripe.color = Color(UITheme.RUST, 0.55)
	stripe.custom_minimum_size = Vector2(80, 2)
	vbox.add_child(stripe)

	# ── Stat cards row (Money, Reputation, Orders, Scrap) ─────────────────────
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 14)
	vbox.add_child(stat_row)

	var earnings: int = money_after - money_before
	var earnings_col: Color = UITheme.SAGE if earnings >= 0 else UITheme.CHERRY
	_stat_card(stat_row, "BALANCE",
		"$%s" % _fmt(money_after),
		_delta_str(earnings, "$"),
		earnings_col)

	var rep_delta: float = rep_after - rep_before
	var rep_col: Color = UITheme.SAGE if rep_delta >= 0 else UITheme.CHERRY
	_stat_card(stat_row, "REPUTATION",
		_rep_label(rep_after),
		_delta_str(int(rep_delta), "rep"),
		rep_col if rep_delta != 0 else UITheme.SKY)

	_stat_card(stat_row, "ORDERS",
		"%d" % orders_done,
		"done today",
		UITheme.HAZARD)

	_stat_card(stat_row, "SCRAP METAL",
		"%d" % InventoryManager.scrap_metal,
		"units in stock",
		Color(0.78, 0.74, 0.62))

	# Divider
	var div1 := ColorRect.new()
	div1.color = Color(1, 1, 1, 0.10)
	div1.custom_minimum_size = Vector2(0, 1)
	div1.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(div1)

	# ── Night report block ────────────────────────────────────────────────────
	var night_hdr := Label.new()
	night_hdr.text = "NIGHT REPORT"
	night_hdr.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	night_hdr.modulate = Color(UITheme.SKY, 0.85)
	vbox.add_child(night_hdr)

	var night_inset := PanelContainer.new()
	var night_style := StyleBoxFlat.new()
	night_style.bg_color = Color(0.0, 0.0, 0.0, 0.30)
	night_style.corner_radius_top_left = 4; night_style.corner_radius_top_right = 4
	night_style.corner_radius_bottom_left = 4; night_style.corner_radius_bottom_right = 4
	night_style.content_margin_left = 14; night_style.content_margin_right = 14
	night_style.content_margin_top = 10; night_style.content_margin_bottom = 10
	night_inset.add_theme_stylebox_override("panel", night_style)
	vbox.add_child(night_inset)

	var night_msg := Label.new()
	night_msg.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	night_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ntype: String = night_event.get("type", "quiet")
	if ntype == "caught":
		night_msg.text  = "Thief caught — your security stopped them. +4 reputation."
		night_msg.modulate = UITheme.HAZARD
	elif ntype == "stolen":
		night_msg.text  = "Break-in. Someone stole: %s" % night_event.get("item", "something")
		night_msg.modulate = UITheme.CHERRY
	else:
		night_msg.text  = "All quiet. No intruders tonight."
		night_msg.modulate = UITheme.SAGE
	night_inset.add_child(night_msg)

	# ── Today's event recap (if any) ──────────────────────────────────────────
	var ev_id : String = EventSystem.get_active_event()
	if ev_id != "":
		var ev_hdr := Label.new()
		ev_hdr.text    = "TODAY'S EVENT"
		ev_hdr.add_theme_font_size_override("font_size", UITheme.FONT_XS)
		ev_hdr.modulate = Color(UITheme.HAZARD, 0.85)
		vbox.add_child(ev_hdr)
		var ev_lbl := Label.new()
		ev_lbl.text          = EventSystem._active_event_title
		ev_lbl.add_theme_font_size_override("font_size", UITheme.FONT_MD)
		ev_lbl.modulate      = EventSystem._active_event_color
		ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(ev_lbl)

	# ── Tip block ─────────────────────────────────────────────────────────────
	var tip_hdr := Label.new()
	tip_hdr.text = "TIP"
	tip_hdr.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	tip_hdr.modulate = Color(0.55, 0.55, 0.58)
	vbox.add_child(tip_hdr)
	var tip := Label.new()
	tip.text = TIPS[randi() % TIPS.size()]
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	tip.modulate = Color(0.78, 0.78, 0.80)
	vbox.add_child(tip)

	# ── Footer divider + Next Day ─────────────────────────────────────────────
	var div2 := ColorRect.new()
	div2.color = Color(1, 1, 1, 0.10)
	div2.custom_minimum_size = Vector2(0, 1)
	div2.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(div2)

	# Next Day button — primary filled
	var next_btn := _next_btn("NEXT  DAY")
	next_btn.custom_minimum_size = Vector2(0, 52)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.disabled = true
	next_btn.modulate = Color(1, 1, 1, 0.45)
	next_btn.pressed.connect(_on_next_day)
	vbox.add_child(next_btn)

	var cd_lbl := Label.new()
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	cd_lbl.modulate = Color(0.50, 0.50, 0.55)
	cd_lbl.text = "Ready in 2s..."
	vbox.add_child(cd_lbl)

	# Enable after 2s
	get_tree().create_timer(2.0).timeout.connect(func():
		next_btn.disabled = false
		next_btn.modulate = Color.WHITE
		cd_lbl.text = "")

# ── UI Helpers ────────────�
## EmployeePanel.gd
## Full-screen overlay showing current staff and hire candidates.
## Opened from the 👷 Employees HUD button in Garage.gd.
extends Control

# ── Signals ───────────────────────────────────────────────────────────────────
signal panel_closed

# ── Internal refs ─────────────────────────────────────────────────────────────
var _hired_list    : VBoxContainer
var _available_list: VBoxContainer
var _wage_label    : Label
var _slots_label   : Label
var _feedback_lbl  : Label
var _feedback_tw   : Tween

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_refresh()

# ── UI construction ────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Full-screen dimming overlay
	var overlay := ColorRect.new()
	overlay.size         = Vector2(1280, 720)
	overlay.color        = Color(0, 0, 0, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main card
	var card := ColorRect.new()
	card.position = Vector2(160, 60)
	card.size     = Vector2(960, 600)
	card.color    = Color(0.09, 0.08, 0.07, 0.98)
	add_child(card)

	# Left accent stripe
	var stripe := ColorRect.new()
	stripe.position = Vector2(160, 60)
	stripe.size     = Vector2(6, 600)
	stripe.color    = Color(0.4, 0.85, 0.5)
	add_child(stripe)

	# Title
	var title := Label.new()
	title.text = "👷  EMPLOYEES"
	title.position = Vector2(178, 72)
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(0.45, 1.0, 0.6)
	add_child(title)

	# Wage + slot summary
	_wage_label = Label.new()
	_wage_label.position = Vector2(178, 108)
	_wage_label.add_theme_font_size_override("font_size", 15)
	_wage_label.modulate = Color(0.75, 0.75, 0.75)
	add_child(_wage_label)

	_slots_label = Label.new()
	_slots_label.position = Vector2(178, 128)
	_slots_label.add_theme_font_size_override("font_size", 15)
	_slots_label.modulate = Color(0.75, 0.75, 0.75)
	add_child(_slots_label)

	# Divider
	var div := ColorRect.new()
	div.position = Vector2(168, 152)
	div.size     = Vector2(944, 2)
	div.color    = Color(0.25, 0.25, 0.20, 0.6)
	add_child(div)

	# ── Left column: current staff ────────────────────────────────────────────
	var hired_hdr := Label.new()
	hired_hdr.text = "CURRENT STAFF"
	hired_hdr.position = Vector2(178, 162)
	hired_hdr.add_theme_font_size_override("font_size", 14)
	hired_hdr.modulate = Color(1.0, 0.85, 0.4)
	add_child(hired_hdr)

	var hired_scroll := ScrollContainer.new()
	hired_scroll.position = Vector2(168, 184)
	hired_scroll.size     = Vector2(450, 380)
	add_child(hired_scroll)

	_hired_list = VBoxContainer.new()
	_hired_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hired_list.add_theme_constant_override("separation", 8)
	hired_scroll.add_child(_hired_list)

	# ── Right column: available to hire ───────────────────────────────────────
	var avail_hdr := Label.new()
	avail_hdr.text = "AVAILABLE TO HIRE"
	avail_hdr.position = Vector2(638, 162)
	avail_hdr.add_theme_font_size_override("font_size", 14)
	avail_hdr.modulate = Color(1.0, 0.85, 0.4)
	add_child(avail_hdr)

	var avail_scroll := ScrollContainer.new()
	avail_scroll.position = Vector2(628, 184)
	avail_scroll.size     = Vector2(480, 380)
	add_child(avail_scroll)

	_available_list = VBoxContainer.new()
	_available_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_available_list.add_theme_constant_override("separation", 8)
	avail_scroll.add_child(_available_list)

	# Feedback label
	_feedback_lbl = Label.new()
	_feedback_lbl.position             = Vector2(168, 578)
	_feedback_lbl.size                 = Vector2(780, 28)
	_feedback_lbl.add_theme_font_size_override("font_size", 15)
	_feedback_lbl.modulate             = Color(1, 1, 1, 0)
	add_child(_feedback_lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text     = "Close"
	close_btn.position = Vector2(1012, 578)
	close_btn.size     = Vector2(96, 34)
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)

# ── Data refresh ──────────────────────────────────────────────────────────────
func _refresh() -> void:
	_refresh_summary()
	_refresh_hired()
	_refresh_available()

func _refresh_summary() -> void:
	var total_wage : int = EmployeeManager.get_daily_wage_total()
	var hired_count: int = EmployeeManager.hired.size()
	var max_slots  : int = EmployeeManager.max_employees()
	_wage_label.text  = "Daily wage bill:  $%d / day" % total_wage
	_slots_label.text = "Staff slots:  %d / %d  (tier %d)" % [hired_count, max_slots, ProgressionManager.current_tier]

func _refresh_hired() -> void:
	for c in _hired_list.get_children(): c.queue_free()

	if EmployeeManager.hired.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text    = "No staff yet — hire someone from the right panel."
		empty_lbl.modulate = Color(0.55, 0.55, 0.55)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		_hired_list.add_child(empty_lbl)
		return

	for emp in EmployeeManager.hired:
		_hired_list.add_child(_make_employee_card(emp, true))

func _refresh_available() -> void:
	for c in _available_list.get_children(): c.queue_free()

	var pool : Array = EmployeeManager.get_available()
	if pool.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text    = "No candidates this week — check back next week."
		empty_lbl.modulate = Color(0.55, 0.55, 0.55)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		_available_list.add_child(empty_lbl)
		return

	for emp in pool:
		_available_list.add_child(_make_employee_card(emp, false))

# ── Employee card ─────────────────────────────────────────────────────────────
func _make_employee_card(emp: Dictionary, is_hired: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.14, 0.13, 0.11) if is_hired else Color(0.12, 0.14, 0.12)
	style.border_color = Color(0.35, 0.80, 0.45, 0.5) if is_hired else Color(0.25, 0.45, 0.28, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vb.add_child(name_row)

	var icon_lbl := Label.new()
	icon_lbl.text = emp.get("icon", "👷")
	icon_lbl.add_theme_font_size_override("font_size", 22)
	name_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = emp["name"]
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.modulate = Color(0.95, 0.92, 0.85)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	# Skill stars
	var star_str : String = ""
	for _s in int(emp.get("skill", 1)):
		star_str += "★"
	for _s in (4 - int(emp.get("skill", 1))):
		star_str += "☆"
	var skill_lbl := Label.new()
	skill_lbl.text    = star_str
	skill_lbl.modulate = Color(1.0, 0.85, 0.25)
	skill_lbl.add_theme_font_size_override("font_size", 14)
	name_row.add_child(skill_lbl)

	# Bio
	var bio_lbl := Label.new()
	bio_lbl.text          = emp.get("bio", "")
	bio_lbl.modulate       = Color(0.68, 0.65, 0.60)
	bio_lbl.add_theme_font_size_override("font_size", 12)
	bio_lbl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(bio_lbl)

	# Stats row
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	vb.add_child(stats_row)

	var spec_lbl := Label.new()
	spec_lbl.text    = "Specialty: %s" % emp.get("specialty", "all").capitalize()
	spec_lbl.modulate = Color(0.55, 0.88, 0.65)
	spec_lbl.add_theme_font_size_override("font_size", 12)
	stats_row.add_child(spec_lbl)

	var wage_lbl := Label.new()
	wage_lbl.text    = "$%d / day" % int(emp.get("daily_wage", 0))
	wage_lbl.modulate = Color(0.9, 0.75, 0.35)
	wage_lbl.add_theme_font_size_override("font_size", 12)
	stats_row.add_child(wage_lbl)

	var blunder_pct : int = int(float(emp.get("blunder_chance", 0.0)) * 100.0)
	var reliability_lbl := Label.new()
	reliability_lbl.text    = "Reliability: %d%%" % (100 - blunder_pct)
	reliability_lbl.modulate = Color(0.65, 0.65, 0.65)
	reliability_lbl.add_theme_font_size_override("font_size", 12)
	stats_row.add_child(reliability_lbl)

	# Action button
	var emp_id : String = emp["id"]
	if is_hired:
		var fire_btn := Button.new()
		fire_btn.text = "Fire"
		fire_btn.modulate = Color(1.0, 0.5, 0.4)
		fire_btn.pressed.connect(func(): _on_fire(emp_id))
		vb.add_child(fire_btn)
	else:
		var hire_btn := Button.new()
		hire_btn.text = "Hire  ($%d/day)" % int(emp.get("daily_wage", 0))
		var can_hire : bool = EmployeeManager.can_hire() and EconomyManager.can_afford(int(emp.get("daily_wage", 0)))
		hire_btn.disabled = not can_hire
		hire_btn.pressed.connect(func(): _on_hire(emp_id))
		vb.add_child(hire_btn)

	return panel

# ── Actions ───────────────────────────────────────────────────────────────────
func _on_hire(emp_id: String) -> void:
	var success : bool = EmployeeManager.hire(emp_id)
	if success:
		_show_feedback("✅ Hired! They start tomorrow.", Color(0.4, 1.0, 0.55))
		XPManager.award_raw(25, "Hired employee")
	else:
		if not EmployeeManager.can_hire():
			_show_feedback("No free slots — upgrade your garage tier or fire someone.", Color(1.0, 0.55, 0.4))
		else:
			_show_feedback("Can't afford them right now.", Color(1.0, 0.55, 0.4))
	_refresh()

func _on_fire(emp_id: String) -> void:
	EmployeeManager.fire(emp_id)
	_show_feedback("They've been let go.", Color(0.85, 0.65, 0.4))
	_refresh()

func _on_close() -> void:
	emit_signal("panel_closed")
	queue_free()

# ── Feedback ──────────────────────────────────────────────────────────────────
func _show_feedback(msg: String, color: Color) -> void:
	_feedback_lbl.text    = msg
	_feedback_lbl.modulate = color
	if _feedback_tw: _feedback_tw.kill()
	_feedback_tw = create_tween()
	_feedback_tw.tween_property(_feedback_lbl, "modulate:a", 1.0, 0.0)
	_feedback_tw.tween_interval(2.5)
	_feedback_tw.tween_property(_feedback_lbl, "modulate:a", 0.0, 0.6)

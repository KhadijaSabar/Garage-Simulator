## WorkbenchPanel.gd
## Overlay panel opened when the player walks to the workbench zone and presses E.
## Three tabs: STAFF (hire workers), TOOLS (buy upgrades), QUEUE (repair queue).
extends PanelContainer

# ── Injected references (set by Garage.gd before add_child) ──────────────────
var workbench_ref: Node = null   ## WorkbenchSystem node
var garage_ref:    Node = null   ## Garage node (for current_vehicle + freeze)

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _staff_list:   VBoxContainer
var _tools_list:   VBoxContainer
var _queue_list:   VBoxContainer
var _tab_btns:     Array[Button] = []
var _sections:     Array[Control] = []
var _status_label: Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_refresh()

func _build_ui() -> void:
	custom_minimum_size = Vector2(740, 540)
	position = Vector2(270, 70)

	# Dark sim card style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	card_style.corner_radius_top_left = 6; card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6; card_style.corner_radius_bottom_right = 6
	card_style.border_color = Color(UITheme.HAZARD, 0.50)
	card_style.border_width_top = 1; card_style.border_width_bottom = 1
	card_style.border_width_left = 1; card_style.border_width_right = 1
	card_style.shadow_color = Color(0, 0, 0, 0.55)
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 8)
	add_theme_stylebox_override("panel", card_style)

	var root := MarginContainer.new()
	root.add_theme_constant_override("margin_top",    18)
	root.add_theme_constant_override("margin_bottom", 18)
	root.add_theme_constant_override("margin_left",   22)
	root.add_theme_constant_override("margin_right",  22)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	# ── Title block ──────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	title_row.add_child(title_col)
	var kicker := Label.new()
	kicker.text = "WORKSHOP"
	kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	kicker.modulate = Color(UITheme.HAZARD, 0.85)
	title_col.add_child(kicker)
	var title := Label.new()
	title.text = "WORKBENCH"
	title.add_theme_font_size_override("font_size", UITheme.FONT_XL)
	title.modulate = Color(0.96, 0.96, 0.96)
	title_col.add_child(title)

	var close_btn := _wb_text_btn("CLOSE", Color(0.65, 0.65, 0.68))
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)

	# Accent stripe under header
	var stripe := ColorRect.new()
	stripe.color = Color(UITheme.HAZARD, 0.45)
	stripe.custom_minimum_size = Vector2(80, 2)
	vbox.add_child(stripe)

	# ── Status bar ───────────────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	_status_label.modulate = Color(0.65, 0.74, 0.86)
	vbox.add_child(_status_label)

	# Subtle divider
	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.10)
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(div)

	# ── Tab buttons ──────────────────────────────────────────────────────────
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_row)

	for tab_name in ["STAFF", "TOOLS", "REPAIR QUEUE"]:
		var btn := _wb_tab_btn(tab_name)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = _tab_btns.size()
		btn.pressed.connect(func(): _switch_tab(idx))
		tab_row.add_child(btn)
		_tab_btns.append(btn)

	# ── Tab content areas ─────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_vbox)

	# Staff section
	_staff_list = VBoxContainer.new()
	_staff_list.add_theme_constant_override("separation", 6)
	scroll_vbox.add_child(_staff_list)

	# Tools section
	_tools_list = VBoxContainer.new()
	_tools_list.add_theme_constant_override("separation", 6)
	scroll_vbox.add_child(_tools_list)

	# Queue section
	_queue_list = VBoxContainer.new()
	_queue_list.add_theme_constant_override("separation", 6)
	scroll_vbox.add_child(_queue_list)

	_sections = [_staff_list, _tools_list, _queue_list]
	_switch_tab(0)

# ── Tab switching ──────────────────────────────────────────────────────────────
func _switch_tab(idx: int) -> void:
	for i in _sections.size():
		_sections[i].visible = (i == idx)
	for i in _tab_btns.size():
		_tab_btns[i].modulate = Color(UITheme.HAZARD, 1.0) if i == idx else Color(0.55, 0.55, 0.60)
	_refresh()

# ── Helper: small clean text button ───────────────────────────────────────────
func _wb_text_btn(txt: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0.30)
	n.border_color = accent
	n.border_width_top = 1; n.border_width_bottom = 1
	n.border_width_left = 1; n.border_width_right = 1
	n.corner_radius_top_left = 4; n.corner_radius_top_right = 4
	n.corner_radius_bottom_left = 4; n.corner_radius_bottom_right = 4
	n.content_margin_left = 10; n.content_margin_right = 10
	n.content_margin_top = 6; n.content_margin_bottom = 6
	var h := n.duplicate() as StyleBoxFlat; h.bg_color = Color(accent, 0.18)
	var p := n.duplicate() as StyleBoxFlat; p.bg_color = Color(accent, 0.28)
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color",         accent)
	btn.add_theme_color_override("font_hover_color",   accent.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", accent.darkened(0.10))
	return btn

func _wb_tab_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0.25)
	n.border_color = Color(1, 1, 1, 0.08)
	n.border_width_top = 1; n.border_width_bottom = 1
	n.border_width_left = 1; n.border_width_right = 1
	n.corner_radius_top_left = 4; n.corner_radius_top_right = 4
	n.corner_radius_bottom_left = 4; n.corner_radius_bottom_right = 4
	n.content_margin_left = 12; n.content_margin_right = 12
	n.content_margin_top = 8; n.content_margin_bottom = 8
	var h := n.duplicate() as StyleBoxFlat; h.bg_color = Color(UITheme.HAZARD, 0.15)
	var p := n.duplicate() as StyleBoxFlat; p.bg_color = Color(UITheme.HAZARD, 0.25)
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color",         Color(0.55, 0.55, 0.60))
	btn.add_theme_color_override("font_hover_color",   Color(0.88, 0.88, 0.90))
	return btn

# ── Refresh all sections ───────────────────────────────────────────────────────
func _refresh() -> void:
	if not workbench_ref:
		return
	_refresh_status()
	_refresh_staff()
	_refresh_tools()
	_refresh_queue()

func _refresh_status() -> void:
	var discount: float = workbench_ref.get_tool_repair_discount() * 100.0
	var clean:    float = workbench_ref.get_tool_clean_bonus()    * 100.0
	var paint:    float = workbench_ref.get_tool_paint_discount()  * 100.0
	var workers:  int   = workbench_ref.hired_workers.size()
	var queued:   int   = workbench_ref.repair_queue.size()
	_status_label.text = (
		"Workers: %d hired   |   Repairs queued: %d   |   "
		% [workers, queued]
		+ "Tools: -%d%% repairs  +%d%% clean  -%d%% paint"
		% [int(discount), int(clean), int(paint)]
	)

# ── Staff tab ─────────────────────────────────────────────────────────────────
func _refresh_staff() -> void:
	for c in _staff_list.get_children(): c.queue_free()

	var header := Label.new()
	header.text = "Hire mechanics to auto-repair queued parts while you work on other things."
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 13)
	header.modulate = Color(0.75, 0.75, 0.75)
	_staff_list.add_child(header)
	_staff_list.add_child(HSeparator.new())

	var wb: Node = workbench_ref
	for i in wb.WORKER_DATA.size():
		var wdata: Dictionary = wb.WORKER_DATA[i]
		var is_hired: bool = wb._is_hired(i)
		var tier_ok: bool  = ProgressionManager.current_tier >= int(wdata["unlock_tier"])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_staff_list.add_child(row)

		# Worker info column
		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_col)

		var worker_lbl := Label.new()
		worker_lbl.text = "%s  %s" % [wdata["name"], "(You)" if i == 0 else ""]
		worker_lbl.add_theme_font_size_override("font_size", 15)
		if is_hired:
			worker_lbl.modulate = Color(0.4, 1.0, 0.5)
		elif not tier_ok:
			worker_lbl.modulate = Color(0.5, 0.5, 0.5)
		info_col.add_child(worker_lbl)

		var desc_lbl := Label.new()
		var speed_str: String = "Speed: %.1fx" % float(wdata["speed"])
		var salary_str: String = "$%d/day" % int(wdata["salary"]) if int(wdata["salary"]) > 0 else "Free"
		desc_lbl.text = "%s   %s   %s" % [wdata["desc"], speed_str, salary_str]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.65, 0.65, 0.65)
		info_col.add_child(desc_lbl)

		# Status / hire button
		if i == 0:
			var you_lbl := Label.new()
			you_lbl.text = "ALWAYS ACTIVE"
			you_lbl.modulate = UITheme.SAGE
			you_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
			row.add_child(you_lbl)
		elif is_hired:
			var busy: String = ""
			for w in wb.hired_workers:
				if w["index"] == i:
					busy = ("FIXING: %s" % str(w["current_job"]).to_upper()) if bool(w["busy"]) else "IDLE"
			var status_lbl := Label.new()
			status_lbl.text = busy
			status_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
			status_lbl.modulate = UITheme.SKY
			row.add_child(status_lbl)
		elif not tier_ok:
			var lock_lbl := Label.new()
			lock_lbl.text = "LOCKED  ·  TIER %d" % int(wdata["unlock_tier"])
			lock_lbl.modulate = Color(0.55, 0.55, 0.58)
			lock_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
			row.add_child(lock_lbl)
		else:
			var hire_btn := _wb_text_btn("HIRE  $%d" % int(wdata["cost"]), UITheme.HAZARD)
			hire_btn.disabled = not wb.can_hire(i)
			var wi: int = i
			hire_btn.pressed.connect(func():
				if wb.hire_worker(wi):
					_refresh())
			row.add_child(hire_btn)

		_staff_list.add_child(HSeparator.new())

# ── Tools tab ─────────────────────────────────────────────────────────────────
func _refresh_tools() -> void:
	for c in _tools_list.get_children(): c.queue_free()

	var header := Label.new()
	header.text = "Permanent upgrades. Bonuses stack. Owned tools are highlighted green."
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 13)
	header.modulate = Color(0.75, 0.75, 0.75)
	_tools_list.add_child(header)
	_tools_list.add_child(HSeparator.new())

	var wb: Node = workbench_ref
	for td: Dictionary in wb.TOOL_DATA:
		var tool_id: String  = td["id"]
		var owned:   bool    = wb.has_tool(tool_id)
		var can_buy: bool    = wb.can_buy_tool(tool_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_tools_list.add_child(row)

		# Left color stripe (replaces emoji icon)
		var stripe_box := ColorRect.new()
		stripe_box.custom_minimum_size = Vector2(3, 36)
		stripe_box.color = UITheme.SAGE if owned else UITheme.HAZARD
		row.add_child(stripe_box)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_col)

		var tool_lbl := Label.new()
		tool_lbl.text = td["name"]
		tool_lbl.add_theme_font_size_override("font_size", 15)
		tool_lbl.modulate = Color(0.35, 1.0, 0.45) if owned else Color.WHITE
		info_col.add_child(tool_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = td["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.65, 0.65, 0.65)
		info_col.add_child(desc_lbl)

		# Buy / owned button
		if owned:
			var owned_lbl := Label.new()
			owned_lbl.text = "OWNED"
			owned_lbl.modulate = UITheme.SAGE
			owned_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
			row.add_child(owned_lbl)
		else:
			var buy_btn := _wb_text_btn("BUY  $%d" % int(td["cost"]), UITheme.HAZARD)
			buy_btn.disabled = not can_buy
			var tid: String = tool_id
			buy_btn.pressed.connect(func():
				if wb.buy_tool(tid):
					_refresh()
					if garage_ref:
						garage_ref.show_feedback("%s purchased" % td["name"], UITheme.SAGE))
			row.add_child(buy_btn)

		_tools_list.add_child(HSeparator.new())

# ── Repair Queue tab ───────────────────────────────────────────────────────────
func _refresh_queue() -> void:
	for c in _queue_list.get_children(): c.queue_free()

	var wb:      Node    = workbench_ref
	var vehicle: Variant = garage_ref.get("current_vehicle") if garage_ref else null

	# Active queue
	var queue_hdr := Label.new()
	queue_hdr.text = "CURRENTLY QUEUED"
	queue_hdr.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	queue_hdr.modulate = Color(UITheme.HAZARD, 0.85)
	_queue_list.add_child(queue_hdr)

	if wb.repair_queue.is_empty() and wb.hired_workers.size() <= 1:
		var no_workers := Label.new()
		no_workers.text = "Hire a worker in the Staff tab first — then queue repairs here."
		no_workers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no_workers.add_theme_font_size_override("font_size", UITheme.FONT_SM)
		no_workers.modulate = Color(0.55, 0.55, 0.60)
		_queue_list.add_child(no_workers)
	elif wb.repair_queue.is_empty():
		var empty_lbl := Lab
## UpgradeShop.gd
## Popup panel showing garage tier upgrades and one-off upgrades.
## Instantiated and added to the HUD by Garage.gd
extends PanelContainer

# ── Refs ──────────────────────────────────────────────────────────────────────
var tier_title: Label
var tier_desc: Label
var tier_upgrade_btn: Button
var upgrades_list: VBoxContainer
var close_btn: Button
var feedback_lbl: Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	visible = false
	ProgressionManager.tier_upgraded.connect(func(_t): _refresh())
	ProgressionManager.upgrade_purchased.connect(func(_id): _refresh())
	EconomyManager.money_changed.connect(func(_a, _d): _refresh())

func _build_ui() -> void:
	custom_minimum_size = Vector2(540, 520)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "🏗️  GARAGE UPGRADES"
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1.0, 0.85, 0.4)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── Tier section ──────────────────────────────────────────────────────────
	var tier_header := Label.new()
	tier_header.text = "GARAGE TIER"
	tier_header.add_theme_font_size_override("font_size", 14)
	tier_header.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(tier_header)

	tier_title = Label.new()
	tier_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(tier_title)

	tier_desc = Label.new()
	tier_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_desc.add_theme_font_size_override("font_size", 13)
	tier_desc.modulate = Color(0.8, 0.85, 0.8)
	vbox.add_child(tier_desc)

	tier_upgrade_btn = Button.new()
	tier_upgrade_btn.pressed.connect(_on_tier_upgrade)
	vbox.add_child(tier_upgrade_btn)

	vbox.add_child(HSeparator.new())

	# ── One-off upgrades ──────────────────────────────────────────────────────
	var upg_header := Label.new()
	upg_header.text = "SHOP UPGRADES"
	upg_header.add_theme_font_size_override("font_size", 14)
	upg_header.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(upg_header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(scroll)

	upgrades_list = VBoxContainer.new()
	upgrades_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(upgrades_list)

	feedback_lbl = Label.new()
	feedback_lbl.modulate = Color(1, 1, 1, 0)
	vbox.add_child(feedback_lbl)

	close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): hide())
	vbox.add_child(close_btn)

# ── Open / Refresh ────────────────────────────────────────────────────────────
func open() -> void:
	_refresh()
	show()

func _refresh() -> void:
	_refresh_tier_section()
	_refresh_upgrades_list()

func _refresh_tier_section() -> void:
	var current := ProgressionManager.current_tier
	var tier_data := ProgressionManager.get_tier_data()
	var is_max := ProgressionManager.is_max_tier()

	tier_title.text = "Tier %d — %s" % [current, tier_data.get("name", "")]

	if is_max:
		tier_desc.text = "✨ Maximum tier reached! You are a Legend."
		tier_upgrade_btn.text = "MAX TIER"
		tier_upgrade_btn.disabled = true
	else:
		var next := ProgressionManager.get_next_tier_data()
		var cost: int = next.get("upgrade_cost", 0)
		var unlocks: Array = next.get("unlocks", [])
		tier_desc.text = "Next: Tier %d — %s\nUnlocks: %s" % [
			current + 1,
			next.get("name", ""),
			", ".join(unlocks)
		]
		var can := ProgressionManager.can_upgrade()
		tier_upgrade_btn.text = "Upgrade for $%s" % _fmt(cost)
		tier_upgrade_btn.disabled = not can
		tier_upgrade_btn.modulate = Color.WHITE if can else Color(0.6, 0.6, 0.6)

func _refresh_upgrades_list() -> void:
	for c in upgrades_list.get_children():
		c.queue_free()

	for upg_id in ProgressionManager.UPGRADES:
		var udata: Dictionary = ProgressionManager.UPGRADES[upg_id]
		var owned := ProgressionManager.has_upgrade(upg_id)

		var row := HBoxContainer.new()
		upgrades_list.add_child(row)

		var icon_lbl := Label.new()
		icon_lbl.text = udata.get("icon", "•") + " "
		row.add_child(icon_lbl)

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var name_lbl := Label.new()
		name_lbl.text = udata["name"]
		name_lbl.add_theme_font_size_override("font_size", 14)
		text_col.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = udata["description"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.75, 0.75, 0.75)
		text_col.add_child(desc_lbl)

		if owned:
			var owned_lbl := Label.new()
			owned_lbl.text = "✓ Owned"
			owned_lbl.modulate = Color.GREEN
			owned_lbl.custom_minimum_size = Vector2(90, 0)
			row.add_child(owned_lbl)
		else:
			var buy_btn := Button.new()
			var cost: int = udata["cost"]
			buy_btn.text = "$%s" % _fmt(cost)
			buy_btn.custom_minimum_size = Vector2(90, 0)
			buy_btn.disabled = not EconomyManager.can_afford(cost)
			var uid: String = upg_id  # capture
			buy_btn.pressed.connect(func(): _on_buy_upgrade(uid))
			row.add_child(buy_btn)

		upgrades_list.add_child(HSeparator.new())

# ── Handlers ──────────────────────────────────────────────────────────────────
func _on_tier_upgrade() -> void:
	if ProgressionManager.upgrade_tier():
		var tier_name := ProgressionManager.get_tier_name()
		_flash("🎉 Upgraded! You are now: %s" % tier_name, Color.YELLOW)
	else:
		_flash("Not enough money!", Color.RED)

func _on_buy_upgrade(upg_id: String) -> void:
	if ProgressionManager.buy_upgrade(upg_id):
		var upg_name: String = ProgressionManager.UPGRADES[upg_id]["name"]
		_flash("✓ Purchased: %s" % upg_name, Color.GREEN)
	else:
		_flash("Not enough money!", Color.RED)

func _flash(msg: String, color: Color) -> void:
	feedback_lbl.text = msg
	feedback_lbl.modulate = color
	var tw := create_tween()
	tw.tween_property(feedback_lbl, "modulate:a", 1.0, 0.0)
	tw.tween_interval(2.0)
	tw.tween_property(feedback_lbl, "modulate:a", 0.0, 0.6)

func _fmt(n: int) -> String:
	var s := str(n)
	var r := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			r += ","
		r += s[i]
	return r

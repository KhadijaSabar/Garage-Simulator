## PaintBoothPanel.gd
## Color-picker panel opened at the paint booth zone.
## Shows a grid of preset swatches + an HSV slider row for custom colors.
## Calls vehicle.action_repaint(color) on confirm.
extends PanelContainer

# ── Injected (set before add_child) ──────────────────────────────────────────
var garage_ref: Node = null

# ── Preset palette ────────────────────────────────────────────────────────────
const SWATCHES: Array = [
	# Reds / oranges
	Color(0.85, 0.12, 0.10), Color(0.95, 0.32, 0.08), Color(0.98, 0.55, 0.05),
	Color(0.95, 0.78, 0.08), Color(0.85, 0.70, 0.18),
	# Greens
	Color(0.10, 0.72, 0.18), Color(0.18, 0.55, 0.20), Color(0.20, 0.48, 0.38),
	Color(0.48, 0.78, 0.28), Color(0.15, 0.65, 0.50),
	# Blues / purples
	Color(0.08, 0.35, 0.85), Color(0.18, 0.55, 0.90), Color(0.40, 0.70, 0.95),
	Color(0.48, 0.22, 0.80), Color(0.68, 0.38, 0.90),
	# Neutrals / metals
	Color(0.90, 0.90, 0.90), Color(0.60, 0.60, 0.62), Color(0.28, 0.28, 0.30),
	Color(0.08, 0.08, 0.08), Color(0.78, 0.72, 0.58),
	# Pinks / specials
	Color(0.95, 0.40, 0.62), Color(0.90, 0.22, 0.45), Color(0.55, 0.10, 0.22),
	Color(0.95, 0.88, 0.55), Color(0.70, 0.95, 0.90),
]

# ── UI state ──────────────────────────────────────────────────────────────────
var _selected_color : Color  = Color(0.85, 0.12, 0.10)
var _preview_rect   : ColorRect
var _confirm_btn    : Button
var _cost_lbl       : Label
var _hue_slider     : HSlider
var _sat_slider     : HSlider
var _val_slider     : HSlider

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(580, 500)
	position            = Vector2(350, 100)

	# Dark sim card style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	card_style.corner_radius_top_left = 6; card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6; card_style.corner_radius_bottom_right = 6
	card_style.border_color = Color(UITheme.GRAPE, 0.50)
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
	kicker.text = "VEHICLE CUSTOMIZATION"
	kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	kicker.modulate = Color(UITheme.GRAPE, 0.85)
	title_col.add_child(kicker)
	var title := Label.new()
	title.text = "PAINT BOOTH"
	title.add_theme_font_size_override("font_size", UITheme.FONT_XL)
	title.modulate = Color(0.96, 0.96, 0.96)
	title_col.add_child(title)

	var close_btn := _pb_text_btn("CLOSE", Color(0.65, 0.65, 0.68))
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)

	# Accent stripe
	var stripe := ColorRect.new()
	stripe.color = Color(UITheme.GRAPE, 0.45)
	stripe.custom_minimum_size = Vector2(80, 2)
	vbox.add_child(stripe)

	# ── Preview + cost ────────────────────────────────────────────────────────
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 16)
	vbox.add_child(preview_row)

	# Big color preview swatch
	_preview_rect = ColorRect.new()
	_preview_rect.custom_minimum_size = Vector2(96, 96)
	_preview_rect.color = _selected_color
	preview_row.add_child(_preview_rect)

	var cost_col := VBoxContainer.new()
	cost_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cost_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_col.add_theme_constant_override("separation", 4)
	preview_row.add_child(cost_col)

	var hint_kicker := Label.new()
	hint_kicker.text = "SELECTED COLOR"
	hint_kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	hint_kicker.modulate = Color(0.55, 0.55, 0.58)
	cost_col.add_child(hint_kicker)

	var pick_hint := Label.new()
	pick_hint.text = "Pick from the palette or fine-tune with the HSV sliders below."
	pick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick_hint.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	pick_hint.modulate = Color(0.78, 0.78, 0.80)
	cost_col.add_child(pick_hint)

	_cost_lbl = Label.new()
	_cost_lbl.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	_cost_lbl.modulate = UITheme.SAGE
	cost_col.add_child(_cost_lbl)
	_update_cost_label()

	# Divider
	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.10)
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(div)

	# ── Swatch palette ────────────────────────────────────────────────────────
	var palette_lbl := Label.new()
	palette_lbl.text = "PRESET PALETTE"
	palette_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	palette_lbl.modulate = Color(0.55, 0.55, 0.58)
	vbox.add_child(palette_lbl)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for sw: Color in SWATCHES:
		var sw_btn := Button.new()
		var sw_n := StyleBoxFlat.new()
		sw_n.bg_color = sw
		sw_n.border_color = Color(0, 0, 0, 0.40)
		sw_n.border_width_top = 1; sw_n.border_width_bottom = 1
		sw_n.border_width_left = 1; sw_n.border_width_right = 1
		sw_n.corner_radius_top_left = 3; sw_n.corner_radius_top_right = 3
		sw_n.corner_radius_bottom_left = 3; sw_n.corner_radius_bottom_right = 3
		var sw_h := sw_n.duplicate() as StyleBoxFlat
		sw_h.border_color = Color(1, 1, 1, 0.85)
		sw_h.border_width_top = 2; sw_h.border_width_bottom = 2
		sw_h.border_width_left = 2; sw_h.border_width_right = 2
		sw_btn.add_theme_stylebox_override("normal",  sw_n)
		sw_btn.add_theme_stylebox_override("hover",   sw_h)
		sw_btn.add_theme_stylebox_override("pressed", sw_h)
		sw_btn.custom_minimum_size = Vector2(96, 38)
		sw_btn.pressed.connect(func(): _pick_color(sw))
		grid.add_child(sw_btn)

	# ── HSV sliders for custom ────────────────────────────────────────────────
	var slider_lbl := Label.new()
	slider_lbl.text = "CUSTOM  ·  HUE / SATURATION / VALUE"
	slider_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	slider_lbl.modulate = Color(0.55, 0.55, 0.58)
	vbox.add_child(slider_lbl)

	_hue_slider = _add_slider(vbox, "H", 0.0, 1.0, _selected_color.h)
	_sat_slider = _add_slider(vbox, "S", 0.0, 1.0, _selected_color.s)
	_val_slider = _add_slider(vbox, "V", 0.0, 1.0, _selected_color.v)

	_hue_slider.value_changed.connect(func(_v): _on_slider_changed())
	_sat_slider.value_changed.connect(func(_v): _on_slider_changed())
	_val_slider.value_changed.connect(func(_v): _on_slider_changed())

	# ── Confirm button ────────────────────────────────────────────────────────
	_confirm_btn = _pb_primary_btn("APPLY PAINT JOB")
	_confirm_btn.custom_minimum_size = Vector2(0, 48)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)
	_refresh_confirm_btn()

# ── Helper buttons ────────────────────────────────────────────────────────────
func _pb_text_btn(txt: String, accent: Color) ->
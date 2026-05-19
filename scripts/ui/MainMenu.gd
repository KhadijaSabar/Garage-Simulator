## MainMenu.gd — Grease & Glory title screen, clean modern sim-game style.
## Dark warehouse atmosphere, bold typography, no floating emoji or hazard tape.
extends Node2D

const W := 1280.0
const H := 720.0

# UI refs
var _feedback:     Label  = null
var _continue_btn: Button = null

# Animation state
var _t        : float = 0.0
var _logo_grease : Label = null
var _logo_glory  : Label = null
var _tagline_lbl : Label = null
var _accent_bar  : ColorRect = null

# ── Entry ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_background()
	_build_garage_door_backdrop()
	_build_logo()
	_build_buttons()
	_build_footer()
	_animate_in()

func _process(delta: float) -> void:
	_t += delta
	# Subtle logo float — minimal, professional
	if _logo_grease:
		var pulse: float = sin(_t * 0.7) * 1.2
		_logo_grease.position.y = 140.0 + pulse
	if _logo_glory:
		var pulse: float = sin(_t * 0.7 + 0.5) * 1.2
		_logo_glory.position.y = 200.0 + pulse
	# Accent bar pulse
	if _accent_bar:
		var glow: float = 0.85 + sin(_t * 1.4) * 0.15
		_accent_bar.color = Color(UITheme.RUST, glow)

# ── Background — vertical dark gradient (charcoal top -> warm dark bottom) ───
func _build_background() -> void:
	# Base wash
	var base := ColorRect.new()
	base.color = Color(0.08, 0.09, 0.11)
	base.size  = Vector2(W, H)
	add_child(base)

	# Stacked thin rects to fake a smooth vertical gradient
	var top_col    := Color(0.04, 0.05, 0.07)
	var bottom_col := Color(0.14, 0.10, 0.07)
	var bands       := 60
	var band_h      := H / float(bands)
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		var col: Color = top_col.lerp(bottom_col, t)
		var band := ColorRect.new()
		band.color    = col
		band.size     = Vector2(W, band_h + 1.0)
		band.position = Vector2(0, i * band_h)
		add_child(band)

	# Warm radial accent at the center — sodium lamp spill
	var glow_h := 280
	for i in glow_h:
		var t: float = 1.0 - (float(i) / float(glow_h - 1))
		var alpha: float = pow(t, 2.2) * 0.20
		var stripe := ColorRect.new()
		stripe.color    = Color(1.00, 0.62, 0.28, alpha)
		stripe.size     = Vector2(W, 1.0)
		stripe.position = Vector2(0, 280 + i)
		add_child(stripe)

	# Top vignette darkening
	for i in 80:
		var t: float = 1.0 - (float(i) / 80.0)
		var alpha: float = pow(t, 2.0) * 0.55
		var stripe := ColorRect.new()
		stripe.color    = Color(0.0, 0.0, 0.0, alpha)
		stripe.size     = Vector2(W, 1.0)
		stripe.position = Vector2(0, i)
		add_child(stripe)

	# Bottom vignette darkening (floor area heavier shadow)
	for i in 120:
		var t: float = float(i) / 120.0
		var alpha: float = pow(t, 2.0) * 0.55
		var stripe := ColorRect.new()
		stripe.color    = Color(0.0, 0.0, 0.0, alpha)
		stripe.size     = Vector2(W, 1.0)
		stripe.position = Vector2(0, H - 120 + i)
		add_child(stripe)

# ── Garage backdrop — door slats silhouette + floor line ─────────────────────
func _build_garage_door_backdrop() -> void:
	# Floor line — single thin warm strip suggesting the workshop floor edge
	var floor_line := ColorRect.new()
	floor_line.color    = Color(0.30, 0.20, 0.12, 0.55)
	floor_line.size     = Vector2(W, 1.5)
	floor_line.position = Vector2(0, H - 165)
	add_child(floor_line)

	# Faint hazard yellow stripe band (very subtle, just an industrial cue)
	var hz := ColorRect.new()
	hz.color    = Color(UITheme.HAZARD, 0.08)
	hz.size     = Vector2(W, 4)
	hz.position = Vector2(0, H - 156)
	add_child(hz)

	# Concrete floor wash at the bottom (subtle warm gradient already done above)
	# Add a few "expansion joint" hint lines on the floor
	for jx in [W * 0.25, W * 0.50, W * 0.75]:
		var joint := ColorRect.new()
		joint.color    = Color(0.0, 0.0, 0.0, 0.35)
		joint.size     = Vector2(1.5, 120)
		joint.position = Vector2(jx, H - 150)
		add_child(joint)

	# Suggestion of garage door slats — thin horizontal lines fading at top
	for i in 8:
		var y: float = 30.0 + i * 18.0
		var alpha: float = 0.16 - i * 0.018
		if alpha < 0.02: continue
		var slat := ColorRect.new()
		slat.color    = Color(0.40, 0.40, 0.46, alpha)
		slat.size     = Vector2(W, 1.0)
		slat.position = Vector2(0, y)
		add_child(slat)

# ── Logo block ───────────────────────────────────────────────────────────────
func _build_logo() -> void:
	# Top label — small kicker above the title
	var kicker := Label.new()
	kicker.text = "AUTO  WORKSHOP  SIMULATOR"
	kicker.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	kicker.modulate = Color(UITheme.STEEL, 0.7)
	kicker.add_theme_constant_override("outline_size", 0)
	kicker.position = Vector2(0, 108)
	kicker.size     = Vector2(W, 20)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(kicker)

	# GREASE — bold rust orange
	_logo_grease = Label.new()
	_logo_grease.text = "GREASE"
	_logo_grease.add_theme_font_size_override("font_size", 110)
	_logo_grease.modulate = UITheme.RUST
	_logo_grease.position = Vector2(0, 140)
	_logo_grease.size     = Vector2(W, 100)
	_logo_grease.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_logo_grease)

	# Subtle dark drop shadow text behind GREASE (offset 4px down)
	var grease_shadow := Label.new()
	grease_shadow.text = "GREASE"
	grease_shadow.add_theme_font_size_override("font_size", 110)
	grease_shadow.modulate = Color(0.0, 0.0, 0.0, 0.55)
	grease_shadow.position = Vector2(0, 144)
	grease_shadow.size     = Vector2(W, 100)
	grease_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Put behind via z_index
	grease_shadow.z_index = -1
	add_child(grease_shadow)

	# & GLORY — cream / off-white, smaller, second line
	_logo_glory = Label.new()
	_logo_glory.text = "&  GLORY"
	_logo_glory.add_theme_font_size_override("font_size", 86)
	_logo_glory.modulate = Color(0.92, 0.90, 0.86)
	_logo_glory.position = Vector2(0, 200)
	_logo_glory.size     = Vector2(W, 90)
	_logo_glory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_logo_glory)

	# Drop shadow for GLORY too
	var glory_shadow := Label.new()
	glory_shadow.text = "&  GLORY"
	glory_shadow.add_theme_font_size_override("font_size", 86)
	glory_shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
	glory_shadow.position = Vector2(0, 204)
	glory_shadow.size     = Vector2(W, 90)
	glory_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glory_shadow.z_index = -1
	add_child(glory_shadow)

	# Glowing thin RUST accent bar under the logo
	_accent_bar = ColorRect.new()
	_accent_bar.color    = UITheme.RUST
	_accent_bar.size     = Vector2(320, 3)
	_accent_bar.position = Vector2((W - 320) / 2.0, 305)
	add_child(_accent_bar)

	# Tagline
	_tagline_lbl = Label.new()
	_tagline_lbl.text = "Fix it.  Flip it.  Own the block."
	_tagline_lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	_tagline_lbl.modulate = Color(0.78, 0.74, 0.66)
	_tagline_lbl.position = Vector2(0, 320)
	_tagline_lbl.size     = Vector2(W, 24)
	_tagline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tagline_lbl)

# ── Buttons — clean modern stack ──────────────────────────────────────────────
func _build_buttons() -> void:
	var btn_w: float = 320.0
	var center_x: float = (W - btn_w) / 2.0
	var btn_y: float = 388.0
	var gap: float = 62.0

	# NEW GAME — primary filled button (warm rust)
	var new_btn := _make_button("NEW  GAME", true, UITheme.RUST)
	new_btn.custom_minimum_size = Vector2(btn_w, 52)
	new_btn.position = Vector2(center_x, btn_y)
	new_btn.pressed.connect(_on_new_game)
	add_child(new_btn)

	# CONTINUE — outlined
	_continue_btn = _make_button("CONTINUE", false, UITheme.SKY)
	_continue_btn.custom_minimum_size = Vector2(btn_w, 52)
	_continue_btn.position = Vector2(center_x, btn_y + gap)
	_continue_btn.pressed.connect(_on_continue)
	_continue_btn.disabled = not SaveManager.has_save()
	if not SaveManager.has_save():
		_continue_btn.modulate = Color(1, 1, 1, 0.35)
	add_child(_continue_btn)

	# SETTINGS — outlined, muted
	var settings_btn := _make_button("SETTINGS", false, Color(0.72, 0.72, 0.74))
	settings_btn.custom_minimum_size = Vector2(btn_w, 48)
	settings_btn.position = Vector2(center_x, btn_y + gap * 2)
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

	# QUIT — minimal text-only
	var quit_btn := _make_button("QUIT", false, Color(0.50, 0.50, 0.55))
	quit_btn.custom_minimum_size = Vector2(btn_w, 40)
	quit_btn.position = Vector2(center_x, btn_y + gap * 3)
	quit_btn.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	quit_btn.pressed.connect(func(): get_tree().quit())
	add_child(quit_btn)

	# Feedback label
	_feedback = Label.new()
	_feedback.position = Vector2(0, btn_y + gap * 4 + 10)
	_feedback.size     = Vector2(W, 28)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	_feedback.modulate = Color(1, 1, 1, 0.0)
	add_child(_feedback)

# ── Custom modern button — no chunky shadows, subtle hover glow ──────────────
func _make_button(txt: String, primary: bool, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", UITheme.FONT_H3)

	var radius: int = 6
	var normal := StyleBoxFlat.new()
	if primary:
		normal.bg_color = accent
		normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
	else:
		normal.bg_color = Color(0.0, 0.0, 0.0, 0.30)
		normal.border_color = accent
		normal.border_width_top = 2
		normal.border_width_bottom = 2
		normal.border_width_left = 2
		normal.border_width_right = 2
	normal.corner_radius_top_left     = radius
	normal.corner_radius_top_right    = radius
	normal.corner_radius_bottom_left  = radius
	normal.corner_radius_bottom_right = radius
	normal.content_margin_left   = 16
	normal.content_margin_right  = 16
	normal.content_margin_top    = 10
	normal.content_margin_bottom = 10

	var hover := normal.duplicate() as StyleBoxFlat
	if primary:
		hover.bg_color = accent.lightened(0.10)
	else:
		hover.bg_color = Color(accent, 0.18)

	var pressed_s := normal.duplicate() as StyleBoxFlat
	if primary:
		pressed_s.bg_color = accent.darkened(0.10)
	else:
		pressed_s.bg_color = Color(accent, 0.28)

	var disabled_s := normal.duplicate() as StyleBoxFlat
	disabled_s.bg_color = Color(accent, 0.20) if primary else Color(0, 0, 0, 0.10)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed_s)
	btn.add_theme_stylebox_override("disabled", disabled_s)

	var txt_col: Color = Color(1, 1, 1, 0.95) if primary else accent
	btn.add_theme_color_override("font_color",          txt_col)
	btn.add_theme_color_override("font_hover_color",    txt_col)
	btn.add_theme_color_override("font_pressed_color",  txt_col)
	btn.add_theme_color_override("font_disabled_color", Color(txt_col, 0.5))
	return btn

# ── Footer ────────────────────────────────────────────────────────────────────
func _build_footer() -> void:
	# Version (bottom left, minimal)
	var ver_lbl := Label.new()
	ver_lbl.text = "v0.1  ·  Early Prototype"
	ver_lbl.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
	ver_lbl.modulate = Color(0.55, 0.55, 0.58)
	ver_lbl.position = Vector2(24, H - 28)
	ver_lbl.size     = Vector2(220, 20)
	add_child(ver_lbl)

	# Studio credit (bottom right)
	var credit := Label.new()
	credit.text = "Reddouja  Studios"
	credit.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
	credit.modulate  = Color(0.55, 0.55, 0.58)
	credit.position  = Vector2(0, H - 28)
	credit.size      = Vector2(W - 24, 20)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(credit)

	# Small controls hint (centered, very subtle)
	var hint := Label.new()
	hint.text = "WASD  to move    ·    E  to interact    ·    SHIFT  to sprint"
	hint.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
	hint.modulate = Color(0.45, 0.45, 0.48)
	hint.position = Vector2(0, H - 50)
	hint.size     = Vector2(W, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

# ── Animate in ───────────────────────────────────────────────────────────────
func _animate_in() -> void:
	var delay := 0.0
	for child in get_children():
		if child is CanvasItem:
			var orig_alpha: float = child.modulate.a
			child.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(child, "modulate:a", orig_alpha, 0.35)
			delay += 0.02
			if delay > 0.5: delay = 0.5

# ── Handlers ──────────────────────────────────────────────────────────────────
func _on_new_game() -> void:
	if SaveManager.has_save():
		_flash("Starting fresh — old save deleted.", UITheme.WARNING)
		SaveManager.delete_save()
		EconomyManager.money      = EconomyManager.STARTING_MONEY
		EconomyManager.reputation = 50.0
		GameManager.current_day   = 1
		InventoryManager.from_dict({})
		ProgressionManager.from_dict({})
		await get_tree().create_timer(1.0).timeout
	_transition_out("res://scenes/garage/Garage.tscn")

func _on_continue() -> void:
	var ok := SaveManager.load_game()
	if ok:
		_transition_out("res://scenes/garage/Garage.tscn")
	else:
		_flash("Save file could not be loaded!", UITheme.DANGER)

func _on_settings() -> void:
	_flash("Settings coming soon!", UITheme.SKY)

func _transition_out(scene: String) -> void:
	var overlay := ColorRect.new()
	overlay.color   = Color(0.0, 0.0, 0.0, 0.0)
	overlay.size    = Vector2(W, H)
	overlay.z_index = 100
	add_child(overlay)
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.4)
	await tw.finished
	get_tree().change_scene_to_file(scene)

func _flash(msg: String, color: Color) -> void:
	_feedback.text     = msg
	_feedback.modulate = Color(color, 1.0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_feedback, "modulate:a", 0.0, 0.6)

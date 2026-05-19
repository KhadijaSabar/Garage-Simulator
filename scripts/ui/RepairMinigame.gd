## RepairMinigame.gd — Precision-tap repair mini-game
## Each step: a cursor oscillates on a bar. Press WORK when it's inside the
## sweet-zone (green). Perfect hits fill the step gauge fast; misses slow it down.
## Emits repair_completed(part_name, quality) when all steps finish.
extends Control

# ── Signals ───────────────────────────────────────────────────────────────────
signal repair_completed(part_name: String, quality: float)   ## quality 0.0–1.0
signal repair_cancelled

# ── Inputs ────────────────────────────────────────────────────────────────────
var part_name  : String = ""
var garage_ref          = null

# ── Tuning constants ──────────────────────────────────────────────────────────
const BAR_W          : float = 420.0   ## pixel width of the precision bar
const ZONE_PERFECT   : float = 0.14   ## ±14% of centre = perfect (green)
const ZONE_GOOD      : float = 0.26   ## ±26% = good (yellow)
const HITS_PER_STEP  : int   = 4      ## taps needed to complete a step
const CURSOR_SPEED   : float = 1.6    ## oscillations per second (increases each step)
const MISS_PENALTY   : float = 0.5    ## hits subtracted on a miss

# ── Internal state ────────────────────────────────────────────────────────────
var _steps      : Array  = []
var _current    : int    = 0
var _hits       : float  = 0.0        ## accumulated hit-points this step
var _cursor_t   : float  = 0.0        ## 0→1 phase for oscillation
var _speed_mult : float  = 1.0
var _quality_acc: float  = 0.0        ## sum of hit qualities for final score
var _total_hits : int    = 0
var _accepting  : bool   = true       ## blocks double-tap during flash

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _title_lbl  : Label
var _step_lbl   : Label
var _tool_lbl   : Label
var _hint_lbl   : Label
var _dots_row   : HBoxContainer
var _bar_bg     : ColorRect         ## full bar background
var _zone_good  : ColorRect
var _zone_perf  : ColorRect
var _cursor_rect: ColorRect
var _hit_flash  : ColorRect         ## full-bar flash on hit
var _step_prog  : ProgressBar       ## step fill gauge (hits / HITS_PER_STEP)
var _feedback   : Label             ## "PERFECT!" / "GOOD" / "MISS"
var _cancel_btn : Button
var _work_btn   : Button            ## tap — NOT hold

# ── Repair step library ───────────────────────────────────────────────────────
const STEPS := {
	"engine": [
		{"label": "Drain old oil",       "tool": "🛢️"},
		{"label": "Remove components",   "tool": "🔧"},
		{"label": "Install new parts",   "tool": "🔩"},
		{"label": "Refill and test",     "tool": "🛢️"},
	],
	"brake": [
		{"label": "Remove wheel",        "tool": "🔩"},
		{"label": "Swap brake pads",     "tool": "🔧"},
		{"label": "Bleed brake line",    "tool": "🛢️"},
	],
	"body": [
		{"label": "Sand damaged area",   "tool": "📐"},
		{"label": "Apply body filler",   "tool": "🖌️"},
		{"label": "Shape and smooth",    "tool": "📐"},
		{"label": "Prime the surface",   "tool": "🖌️"},
	],
	"wheel": [
		{"label": "Jack up the car",     "tool": "🔧"},
		{"label": "Remove old tyre",     "tool": "🔩"},
		{"label": "Mount new tyre",      "tool": "🔧"},
		{"label": "Torque the bolts",    "tool": "🔩"},
	],
	"interior": [
		{"label": "Strip old trim",      "tool": "🔧"},
		{"label": "Fit new upholstery",  "tool": "✂️"},
		{"label": "Secure and finish",   "tool": "🔧"},
	],
	"default": [
		{"label": "Disassemble",         "tool": "🔧"},
		{"label": "Replace part",        "tool": "🔩"},
		{"label": "Reassemble & test",   "tool": "🔧"},
	],
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_load_steps()
	_show_step()
	set_process_input(true)

func _process(delta: float) -> void:
	_cursor_t += delta * CURSOR_SPEED * _speed_mult
	# sine wave 0→1, cursor position
	var pos : float = (sin(_cursor_t * TAU) * 0.5 + 0.5)  # 0..1
	_cursor_rect.position.x = _bar_bg.position.x + pos * BAR_W - 4.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_tap()

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Full-screen dimmer
	var overlay := ColorRect.new()
	overlay.size         = Vector2(1280, 720)
	overlay.color        = Color(0.0, 0.0, 0.0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# ── Card ──────────────────────────────────────────────────────────────────
	const CX : float = 360.0
	const CY : float = 170.0
	const CW : float = 560.0
	const CH : float = 380.0

	var card_shadow := ColorRect.new()
	card_shadow.size     = Vector2(CW + 8, CH + 8)
	card_shadow.position = Vector2(CX - 4, CY + 6)
	card_shadow.color    = Color(UITheme.GREASE, 0.70)
	add_child(card_shadow)

	var card := ColorRect.new()
	card.size     = Vector2(CW, CH)
	card.position = Vector2(CX, CY)
	card.color    = UITheme.PAPER
	add_child(card)

	# Left accent stripe (RUST)
	var stripe := ColorRect.new()
	stripe.size     = Vector2(6, CH)
	stripe.position = Vector2(CX, CY)
	stripe.color    = UITheme.RUST
	add_child(stripe)

	# Top border (GREASE)
	var top_border := ColorRect.new()
	top_border.size     = Vector2(CW, 3)
	top_border.position = Vector2(CX, CY)
	top_border.color    = UITheme.GREASE
	add_child(top_border)

	# Hit flash overlay (transparent by default, flashes on tap)
	_hit_flash = ColorRect.new()
	_hit_flash.size          = Vector2(CW, CH)
	_hit_flash.position      = Vector2(CX, CY)
	_hit_flash.color         = Color(UITheme.SAGE, 0.0)
	_hit_flash.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_hit_flash)

	# ── Content VBox ──────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(CX + 18, CY + 14)
	vbox.size     = Vector2(CW - 28, CH - 24)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	_tool_lbl = Label.new()
	_tool_lbl.add_theme_font_size_override("font_size", 28)
	_tool_lbl.custom_minimum_size.x = 38
	title_row.add_child(_tool_lbl)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.modulate = UITheme.RUST
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_lbl)

	# Dots row
	_dots_row = HBoxContainer.new()
	_dots_row.add_theme_constant_override("separation", 7)
	vbox.add_child(_dots_row)

	# Step label
	_step_lbl = Label.new()
	_step_lbl.add_theme_font_size_override("font_size", 17)
	_step_lbl.modulate = UITheme.OIL
	vbox.add_child(_step_lbl)

	# ── Step progress bar (hits / HITS_PER_STEP) ──────────────────────────────
	_step_prog = UITheme.progress_bar(0.0, float(HITS_PER_STEP), UITheme.RUST, 14)
	_step_prog.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(_step_prog)

	# ── Precision bar area ────────────────────────────────────────────────────
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_W, 52)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(bar_container)

	# Bar background (CONCRETE)
	_bar_bg = ColorRect.new()
	_bar_bg.size     = Vector2(BAR_W, 40)
	_bar_bg.position = Vector2(0, 6)
	_bar_bg.color    = UITheme.CONCRETE
	bar_container.add_child(_bar_bg)

	# Border on bar
	for side in [Vector2(0,6), Vector2(BAR_W-2,6)]:
		var b := ColorRect.new()
		b.size     = Vector2(2, 40)
		b.position = side
		b.color    = UITheme.GREASE
		bar_container.add_child(b)
	var tb := ColorRect.new(); tb.size = Vector2(BAR_W, 2); tb.position = Vector2(0, 6); tb.color = UITheme.GREASE; bar_container.add_child(tb)
	var bb := ColorRect.new(); bb.size = Vector2(BAR_W, 2); bb.position = Vector2(0, 44); bb.color = UITheme.GREASE; bar_container.add_child(bb)

	# Good zone (yellow)
	var gz_w : float = BAR_W * ZONE_GOOD * 2.0
	_zone_good = ColorRect.new()
	_zone_good.size     = Vector2(gz_w, 40)
	_zone_good.position = Vector2((BAR_W - gz_w) / 2.0, 6)
	_zone_good.color    = Color(UITheme.HAZARD, 0.45)
	bar_container.add_child(_zone_good)

	# Perfect zone (green)
	var pz_w : float = BAR_W * ZONE_PERFECT * 2.0
	_zone_perf = ColorRect.new()
	_zone_perf.size     = Vector2(pz_w, 40)
	_zone_perf.position = Vector2((BAR_W - pz_w) / 2.0, 6)
	_zone_perf.color    = Color(UITheme.SAGE, 0.55)
	bar_container.add_child(_zone_perf)

	# Centre tick mark
	var tick := ColorRect.new()
	tick.size     = Vector2(2, 40)
	tick.position = Vector2(BAR_W / 2.0 - 1, 6)
	tick.color    = Color(UITheme.GREASE, 0.25)
	bar_container.add_child(tick)

	# Cursor (white vertical bar, moves with sine)
	_cursor_rect = ColorRect.new()
	_cursor_rect.size     = Vector2(8, 40)
	_cursor_rect.position = Vector2(BAR_W / 2.0, 6)
	_cursor_rect.color    = UITheme.GREASE
	bar_container.add_child(_cursor_rect)

	# ── Feedback label ("PERFECT!" / "GOOD" / "MISS") ─────────────────────────
	_feedback = Label.new()
	_feedback.add_theme_font_size_override("font_size", 26)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.modulate = Color(UITheme.SAGE, 0.0)
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_feedback)

	# ── Hint ──────────────────────────────────────────────────────────────────
	_hint_lbl = Label.new()
	_hint_lbl.add_theme_font_size_override("font_size", 13)
	_hint_lbl.modulate = UITheme.OIL_SOFT
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_hint_lbl)

	# ── Buttons ───────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_work_btn = UITheme.button("🔧   TAP TO WORK", UITheme.RUST, UITheme.CREAM, UITheme.FONT_H3)
	_work_btn.custom_minimum_size   = Vector2(0, 50)
	_work_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_work_btn.pressed.connect(_on_tap)
	btn_row.add_child(_work_btn)

	_cancel_btn = UITheme.ghost_button("Quit", UITheme.STEEL, UITheme.FONT_BODY)
	_cancel_btn.custom_minimum_size = Vector2(80, 50)
	_cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(_cancel_btn)

# ── Step logic ────────────────────────────────────────────────────────────────
func _load_steps() -> void:
	var key := "default"
	var pn  := part_name.to_lower()
	if   "engine"   in pn: key = "engine"
	elif "brake"    in pn: key = "brake"
	elif "body"     in pn: key = "body"
	elif "wheel"    in pn: key = "wheel"
	elif "interior" in pn: key = "interior"
	_steps = STEPS[key]

	_title_lbl.text = "Repairing: %s" % part_name.replace("_", " ").capitalize()

	for _s in _steps:
		var dot := Label.new()
		dot.text = "○"
		dot.add_theme_font_size_override("font_size", 18)
		dot.modulate = UITheme.STEEL
		_dots_row.add_child(dot)

func _show_step() -> void:
	if _current >= _steps.size(): return
	var s : Dictionary = _steps[_current]
	_step_lbl.text  = "Step %d / %d  —  %s" % [_current + 1, _steps.size(), s["label"]]
	_tool_lbl.text  = s["tool"]
	_hits           = 0.0
	_step_prog.value = 0.0
	# Speed ramps up slightly each step
	_speed_mult = 1.0 + _current * 0.18
	_hint_lbl.text = "Tap when the cursor is inside the  🟢  zone"

	_update_dots()

func _update_dots() -> void:
	var children := _dots_row.get_children()
	for i in children.size():
		var dot : Label = children[i] as Label
		if i < _current:
			dot.text    = "●"; dot.modulate = UITheme.SAGE
		elif i == _current:
			dot.text    = "◉"; dot.modulate = UITheme.HAZARD
		else:
			dot.text    = "○"; dot.modulate = UITheme.STEEL

# ── Tap handler ───────────────────────────────────────────────────────────────
func _on_tap() -> void:
	if not _accepting or _current >= _steps.size(): return
	_accepting = false

	# Cursor position 0..1 within the bar
	var cursor_x  : float = (_cursor_rect.position.x - _bar_bg.position.x) / BAR_W
	var dist      : float = abs(cursor_x - 0.5)   ## 0 = centre, 0.5 = edge

	var hit_label : String
	var hit_color : Color
	var hit_pts   : float

	if dist <= ZONE_PERFECT:
		hit_label = "PERFECT!"
		hit_color = UITheme.SAGE
		hit_pts   = 1.5
		_quality_acc += 1.0
		_flash_bar(UITheme.SAGE, 0.22)
		AudioManager.play_varied("repair_impact", 0.95, 1.05, -2.0)
	elif dist <= ZONE_GOOD:
		hit_label = "GOOD"
		hit_color = UITheme.HAZARD
		hit_pts   = 1.0
		_quality_acc += 0.65
		_flash_bar(UITheme.HAZARD, 0.18)
		AudioManager.play_varied("repair_ratchet", 0.90, 1.10, -4.0)
	else:
		hit_label = "MISS"
		hit_color = UITheme.CHERRY
		hit_pts   = -MISS_PENALTY
		_flash_bar(UITheme.CHERRY, 0.16)
		AudioManager.play_varied("repair_clang", 0.85, 1.05, -6.0)

	_total_hits += 1
	_hits = clampf(_hits + hit_pts, 0.0, float(HITS_PER_STEP))
	_step_prog.value = _hits

	# Feedback flash
	_feedback.text     = hit_label
	_feedback.modulate = Color(hit_color, 1.0)
	var fw := create_tween()
	fw.tween_property(_feedback, "modulate:a", 0.0, 0.55)

	# Re-enable tap after short lockout
	await get_tree().create_timer(0.18).timeout
	_accepting = true

	if _hits >= float(HITS_PER_STEP):
		_finish_step()

func _flash_bar(col: Color, alpha: float) -> void:
	_hit_flash.color = Color(col, alpha)
	var tw := create_tween()
	tw.tween_property(_hit_flash, "color:a", 0.0, 0.25)

func _finish_step() -> void:
	_accepting = false
	AudioManager.play_varied("repair", 0.90, 1.10, -3.0)
	_current += 1
	# Mark done dot
	_update_dots()

	if _current >= _steps.size():
		await get_tree().create_timer(0.3).timeout
		_on_all_done()
	else:
		_hits      = 0.0
		_accepting = true
		_show_step()

func _on_all_done() -> void:
	_work_btn.disabled = true
	var quality : float = clampf(_quality_acc / max(_total_hits, 1), 0.0, 1.0)
	var grade   : String
	var grade_col : Color
	if quality >= 0.85:
		grade = "⭐ Flawless!"; grade_col = UITheme.HAZARD
	elif quality >= 0.60:
		grade = "✅ Good job!"; grade_col = UITheme.SAGE
	else:
		grade = "🔧 Done (rough)"; grade_col = UITheme.STEEL

	_hint_lbl.text     = grade
	_hint_lbl.modulate = grade_col
	_feedback.text     = ""
	_cancel_btn.text   = "✅  Close"
	AudioManager.play("order_ok", -3.0)

	await get_tree().create_timer(0.8).timeout
	emit_signal("repair_completed", part_name, quality)
	queue_free()

func _on_cancel() -> void:
	_accepting = false
	emit_signal("repair_cancelled")
	queue_free()

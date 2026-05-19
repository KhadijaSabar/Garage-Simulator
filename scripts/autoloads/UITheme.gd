## UITheme.gd — Grease & Glory Design System
## "Workshop Palette" — directly from Claude Design tokens (colors_and_type.css)
## Overcooked-style: chunky dark outlines, pop shadows, warm cream backgrounds
extends Node

# ── PRIMARY COLORS ────────────────────────────────────────────────────────────
const RUST        := Color("F18738")   # primary action, signage, mechanic apron
const RUST_DEEP   := Color("D26A1F")   # hover/press
const RUST_SOFT   := Color("FBC791")   # tinted backgrounds

const SKY         := Color("4DB8E8")   # info, paint can, waterpark blue
const SKY_DEEP    := Color("2E91C1")
const SKY_SOFT    := Color("B5E3F4")

const CHERRY      := Color("E64A3C")   # danger, low condition, STOP
const CHERRY_DEEP := Color("C2342A")

const HAZARD      := Color("FFC73A")   # coins, hazard tape, highlights
const HAZARD_DEEP := Color("E0A21A")

const SAGE        := Color("5BB867")   # success, money in, healthy condition
const SAGE_DEEP   := Color("3F9A4B")

const GRAPE       := Color("8B6CC4")   # rare / legendary tier
const GRAPE_DEEP  := Color("6B4DA1")

# ── NEUTRALS — workshop concrete, oil, paper ──────────────────────────────────
const CREAM       := Color("FFF1D4")   # paper / receipt / page bg
const PAPER       := Color("FFFAF0")   # card surface
const CONCRETE    := Color("E8DFCE")   # secondary bg / shop floor
const CONCRETE2   := Color("D2C7B0")   # dividers, inner shadow
const OIL         := Color("3A2E26")   # primary text
const OIL_SOFT    := Color("6E5A48")   # secondary text
const GREASE      := Color("1F1814")   # hard outline, max-contrast text

const STEEL       := Color("98A6B0")
const STEEL_DEEP  := Color("6E7C86")
const RUST_GRIT   := Color("8B4A22")   # deep oxidized brown

# ── SEMANTIC ALIASES ──────────────────────────────────────────────────────────
const BG          := CREAM
const BG_CARD     := PAPER
const BG_SUNKEN   := CONCRETE
const FG          := OIL
const FG_SOFT     := OIL_SOFT
const FG_ON_DARK  := CREAM
const OUTLINE     := GREASE
const OUTLINE_SOFT:= CONCRETE2

const ACCENT      := RUST
const ACCENT_DEEP := RUST_DEEP
const INFO        := SKY
const SUCCESS     := SAGE
const WARNING     := HAZARD
const DANGER      := CHERRY
const LEGENDARY   := GRAPE
const MONEY       := SAGE
const COIN        := HAZARD

# ── FONT SIZES (matching CSS --fs-* tokens) ───────────────────────────────────
const FONT_TINY    := 12
const FONT_SMALL   := 14
const FONT_BODY    := 16
const FONT_H3      := 20
const FONT_H2      := 24
const FONT_H1      := 32
const FONT_DISPLAY := 40
const FONT_HERO    := 56

# Shorthand aliases used throughout existing code
const FONT_XS  := FONT_TINY
const FONT_SM  := FONT_SMALL
const FONT_MD  := FONT_BODY
const FONT_LG  := FONT_H3
const FONT_XL  := FONT_H2
const FONT_2XL := FONT_H1
const FONT_3XL := FONT_HERO

# ── SPACING (4-pt scale) ──────────────────────────────────────────────────────
const PAD_XS := 4
const PAD_SM := 8
const PAD_MD := 16
const PAD_LG := 24
const PAD_XL := 40

# ── RADII ─────────────────────────────────────────────────────────────────────
const RADIUS_SM   := 8
const RADIUS_MD   := 14
const RADIUS_LG   := 20
const RADIUS_XL   := 28
const RADIUS_PILL := 999

# ── STROKE WIDTHS (Overcooked-style chunky outlines) ─────────────────────────
const STROKE_1 := 2
const STROKE_2 := 3
const STROKE_3 := 4   # default chunky outline
const STROKE_4 := 5

# ── SHADOW OFFSET (pop shadow = bottom-only) ──────────────────────────────────
const SHADOW_POP_OFFSET := Vector2(0, 4)
const SHADOW_POP_SIZE   := 0   # used as shadow_offset in StyleBoxFlat

# ── HELPER: Overcooked-style StyleBox ────────────────────────────────────────
## bg_color + dark chunky border + bottom pop shadow
static func _chunky_style(bg: Color, border_w: int = STROKE_3,
		border_col: Color = GREASE, radius: int = RADIUS_MD,
		pad: int = PAD_MD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color       = border_col
	s.border_width_top   = border_w
	s.border_width_bottom = border_w
	s.border_width_left  = border_w
	s.border_width_right = border_w
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left   = pad
	s.content_margin_right  = pad
	s.content_margin_top    = pad - 2
	s.content_margin_bottom = pad - 2
	# Pop shadow — bottom only, dark
	s.shadow_color  = Color(GREASE, 0.85)
	s.shadow_size   = 0
	s.shadow_offset = Vector2(0, 4)
	return s

# ── HELPER: Label ─────────────────────────────────────────────────────────────
static func label(txt: String, sz: int = FONT_BODY, col: Color = OIL) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.modulate = col
	return l

# ── HELPER: PanelContainer (Overcooked card) ─────────────────────────────────
## Cream bg, chunky dark border, pop shadow
static func panel(bg: Color = PAPER, radius: int = RADIUS_LG,
		pad: int = PAD_MD, border_w: int = STROKE_3) -> PanelContainer:
	var pc := PanelContainer.new()
	var s := _chunky_style(bg, border_w, GREASE, radius, pad)
	pc.add_theme_stylebox_override("panel", s)
	return pc

# ── HELPER: Button (Overcooked-style) ────────────────────────────────────────
## Solid color fill + dark border + bottom pop shadow that squishes on press
static func button(txt: String, col: Color = RUST,
		txt_col: Color = CREAM, sz: int = FONT_BODY) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", sz)

	# Normal — pop shadow offset 4px
	var normal := _chunky_style(col, STROKE_3, GREASE, RADIUS_MD, PAD_MD)
	normal.shadow_offset = Vector2(0, 4)

	# Hover — slightly lighter
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = col.lightened(0.10)
	hover.shadow_offset = Vector2(0, 5)

	# Pressed — shadow squishes to 1px (pop effect)
	var pressed_s := normal.duplicate() as StyleBoxFlat
	pressed_s.bg_color    = col.darkened(0.12)
	pressed_s.shadow_offset = Vector2(0, 1)

	# Disabled
	var disabled_s := normal.duplicate() as StyleBoxFlat
	disabled_s.bg_color = Color(col, 0.45)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed_s)
	btn.add_theme_stylebox_override("disabled", disabled_s)
	btn.add_theme_color_override("font_color",          txt_col)
	btn.add_theme_color_override("font_hover_color",    txt_col)
	btn.add_theme_color_override("font_pressed_color",  txt_col)
	btn.add_theme_color_override("font_disabled_color", Color(txt_col, 0.5))
	return btn

# ── HELPER: Ghost / outline button ───────────────────────────────────────────
static func ghost_button(txt: String, col: Color = OIL,
		sz: int = FONT_BODY) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", sz)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.border_color = col
	for side in ["top","bottom","left","right"]:
		normal.set("border_width_" + side, STROKE_2)
	normal.corner_radius_top_left     = RADIUS_MD
	normal.corner_radius_top_right    = RADIUS_MD
	normal.corner_radius_bottom_left  = RADIUS_MD
	normal.corner_radius_bottom_right = RADIUS_MD
	normal.content_margin_left   = PAD_MD
	normal.content_margin_right  = PAD_MD
	normal.content_margin_top    = PAD_SM
	normal.content_margin_bottom = PAD_SM

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(col, 0.10)

	var pressed_s := normal.duplicate() as StyleBoxFlat
	pressed_s.bg_color = Color(col, 0.18)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed_s)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color",          col)
	btn.add_theme_color_override("font_hover_color",    col.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color",  col.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", Color(col, 0.4))
	return btn

# ── HELPER: Separator ────────────────────────────────────────────────────────
static func separator(vertical: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.color = CONCRETE2
	if vertical:
		r.custom_minimum_size = Vector2(2, 0)
		r.size_flags_vertical = Control.SIZE_FILL
	else:
		r.custom_minimum_size = Vector2(0, 2)
		r.size_flags_horizontal = Control.SIZE_FILL
	return r

# ── HELPER: Dashed separator (CSS border-bottom: 2px dashed) ─────────────────
## GDScript doesn't have native dashed lines — approximate with dotted ColorRects
static func dashed_separator() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.custom_minimum_size = Vector2(0, 2)
	for i in 30:
		var dot := ColorRect.new()
		dot.color = CONCRETE2
		dot.custom_minimum_size = Vector2(6, 2)
		hb.add_child(dot)
	return hb

# ── HELPER: Hazard tape strip ─────────────────────────────────────────────────
## The signature diagonal yellow/black stripe from the CSS
static func hazard_tape(w: float, h: float = 24.0) -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(w, h)
	# Approximate with alternating colour — shader would be ideal but this works
	c.color = HAZARD
	return c

# ── HELPER: Tag / chip label ─────────────────────────────────────────────────
static func chip(txt: String, col: Color = RUST, text_col: Color = CREAM) -> PanelContainer:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = GREASE
	s.border_width_top = STROKE_2; s.border_width_bottom = STROKE_2
	s.border_width_left = STROKE_2; s.border_width_right = STROKE_2
	s.corner_radius_top_left     = RADIUS_PILL
	s.corner_radius_top_right    = RADIUS_PILL
	s.corner_radius_bottom_left  = RADIUS_PILL
	s.corner_radius_bottom_right = RADIUS_PILL
	s.content_margin_left   = PAD_SM
	s.content_margin_right  = PAD_SM
	s.content_margin_top    = 2
	s.content_margin_bottom = 2
	s.shadow_color  = Color(GREASE, 0.8)
	s.shadow_offset = Vector2(0, 2)
	pc.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", FONT_TINY)
	l.modulate = text_col
	pc.add_child(l)
	return pc

# ── HELPER: Progress bar (Overcooked condition bar) ───────────────────────────
static func progress_bar(val: float, max_val: float,
		fill_col: Color = SAGE, h: int = 12) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = max_val
	pb.value     = val
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)

	var bg := StyleBoxFlat.new()
	bg.bg_color = CONCRETE
	bg.border_color = GREASE
	bg.border_width_top = 2; bg.border_width_bottom = 2
	bg.border_width_left = 2; bg.border_width_right = 2
	bg.corner_radius_top_left     = RADIUS_PILL
	bg.corner_radius_top_right    = RADIUS_PILL
	bg.corner_radius_bottom_left  = RADIUS_PILL
	bg.corner_radius_bottom_right = RADIUS_PILL

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.corner_radius_top_left     = RADIUS_PILL
	fill.corner_radius_top_right    = RADIUS_PILL
	fill.corner_radius_bottom_left  = RADIUS_PILL
	fill.corner_radius_bottom_right = RADIUS_PILL

	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill",       fill)
	return pb

# ── Color for condition value (green/yellow/red) ──────────────────────────────
static func condition_color(pct: float) -> Color:
	if pct >= 0.70: return SAGE
	elif pct >= 0.40: return HAZARD
	return CHERRY

# ── BACKWARD-COMPAT ALIASES (for Garage.gd / old code) ───────────────────────
## These map the old "Honey & Wrench" palette names onto Workshop Palette equivalents.
const SURFACE    := CONCRETE        # secondary background / shop floor
const SURFACE2   := PAPER           # card surface (lighter than CONCRETE)
const SURFACE3   := Color("C8BBAA") # sunken/inset — slightly darker than CONCRETE
const HONEY      := HAZARD          # warm amber accent (was honey orange)
const GOLD       := HAZARD          # coin / money highlight
const TEAL       := SKY             # info / secondary accent
const TEXT       := OIL             # primary text
const TEXT_DIM   := OIL_SOFT        # secondary / dimmed text
const TEXT_MUTED := STEEL           # muted / hint text
const DIVIDER    := CONCRETE2       # rule / separator line
const SHADOW     := Color(0.122, 0.094, 0.078, 0.65)  # GREASE @ 65% alpha
const XP_COLOR   := GRAPE           # XP bar / level colour

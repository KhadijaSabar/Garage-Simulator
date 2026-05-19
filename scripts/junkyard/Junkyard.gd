## Junkyard.gd  (3D)
## Outdoor junkyard scene. Scavenge piles for parts, scrap, and wrecks.
## Now includes: daily scrap market price, Rusty's Shop, 10 piles, full loot type handling.
extends Node3D

const JunkPileScript = preload("res://scripts/junkyard/JunkPile.gd")
const PILE_COUNT := 10

# ── Rusty's Shop buyable parts ────────────────────────────────────────────────
const RUSTY_ITEMS: Array = [
	{"part_name": "air_filter",     "label": "Air Filter",         "cost": 45},
	{"part_name": "spark_plugs",    "label": "Spark Plugs (set)",  "cost": 60},
	{"part_name": "brake_pads",     "label": "Brake Pads",         "cost": 80},
	{"part_name": "timing_belt",    "label": "Timing Belt",        "cost": 150},
	{"part_name": "alternator",     "label": "Alternator",         "cost": 220},
	{"part_name": "radiator_cap",   "label": "Radiator Cap",       "cost": 30},
	{"part_name": "headlight",      "label": "Headlight Assembly", "cost": 95},
	{"part_name": "exhaust_pipe",   "label": "Exhaust Section",    "cost": 120},
]

# Base scrap price per unit — fluctuates daily by ±35%
const BASE_SCRAP_PRICE : float = 8.0
var _scrap_price : float = BASE_SCRAP_PRICE

# Pile positions — 12 slots, 10 used per run (shuffled)
const PILE_POSITIONS: Array = [
	Vector3(-6,  0, -6), Vector3(-3,  0, -5), Vector3( 1,  0, -6),
	Vector3( 5,  0, -5), Vector3(-5,  0, -1), Vector3(-1,  0, -2),
	Vector3( 4,  0, -2), Vector3(-6,  0,  3), Vector3( 0,  0,  3),
	Vector3( 5,  0,  3), Vector3(-3,  0,  5), Vector3( 2,  0,  5),
]

var piles: Array = []
var pending_wreck: String = ""

# HUD refs
var hud: CanvasLayer
var money_label: Label
var scrap_label: Label
var market_label: Label        ## Scrap market price ticker
var log_list: VBoxContainer
var log_scroll: ScrollContainer
var tow_btn: Button
var feedback_label: Label
var feedback_tween: Tween
var interact_prompt: Label

# Rusty's Shop panel
var _shop_panel: CanvasLayer = null
var _shop_open: bool = false

# Player
var player: Node = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_roll_scrap_price()
	_build_3d_scene()
	_build_piles()
	_build_hud()
	_build_zones()
	EconomyManager.money_changed.connect(func(amt, _d): _update_money(amt))
	InventoryManager.scrap_changed.connect(func(s): _update_scrap(s))
	GameManager.day_started.connect(func(_d): _on_new_day())
	_update_money(EconomyManager.money)
	_update_scrap(InventoryManager.scrap_metal)
	if player:
		player.set("_interact_label", interact_prompt)

# ── Scrap market ──────────────────────────────────────────────────────────────
func _roll_scrap_price() -> void:
	_scrap_price = BASE_SCRAP_PRICE * randf_range(0.65, 1.40)
	# Round to nearest 0.5 for readability
	_scrap_price = round(_scrap_price * 2.0) / 2.0

func _price_color() -> Color:
	if _scrap_price > BASE_SCRAP_PRICE * 1.15:
		return Color(0.35, 1.0, 0.35)   # green — good day
	elif _scrap_price < BASE_SCRAP_PRICE * 0.85:
		return Color(1.0, 0.45, 0.35)   # red — bad day
	else:
		return Color(1.0, 0.88, 0.45)   # yellow — average

# ── Interaction zones ─────────────────────────────────────────────────────────
func _build_zones() -> void:
	# Gate / exit zone
	_make_zone(Vector3(0, 0.9, 8.2), 1.6, "Return to Garage",
		func():
			show_feedback("Heading back to the garage…", Color.CYAN)
			get_tree().create_timer(0.8).timeout.connect(_go_to_garage))

	# Scrap sale zone (floor alternative to button)
	_make_zone(Vector3(-9, 0.9, 6.5), 1.5, "Sell All Scrap",
		func(): _on_sell_scrap())

	# Rusty's Shop zone — near the back-right shed
	_make_zone(Vector3(8, 0.9, -6.5), 1.8, "🛠️  Rusty's Shop",
		func(): _open_rusty_shop())

func _make_zone(pos: Vector3, radius: float, label: String, cb: Callable) -> Area3D:
	var zone := Area3D.new()
	zone.collision_layer = 2
	zone.collision_mask  = 0
	zone.set_meta("interact_label", label)
	zone.set_meta("interact_cb",    cb)
	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape    = shape
	zone.add_child(col)
	zone.position = pos
	add_child(zone)

	# Glowing floor ring
	var ring_mi   := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius      = radius * 0.78
	ring_mesh.bottom_radius   = radius * 0.78
	ring_mesh.height          = 0.035
	ring_mesh.radial_segments = 32
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color               = Color(0.95, 0.85, 0.10, 0.50)
	ring_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled           = true
	ring_mat.emission                   = Color(1.0, 0.88, 0.0)
	ring_mat.emission_energy_multiplier = 0.45
	ring_mi.mesh              = ring_mesh
	ring_mi.material_override = ring_mat
	ring_mi.position          = Vector3(pos.x, 0.02, pos.z)
	add_child(ring_mi)

	var tw := create_tween().set_loops()
	tw.tween_property(ring_mat, "emission_energy_multiplier", 0.85, 1.1)
	tw.tween_property(ring_mat, "emission_energy_multiplier", 0.25, 1.1)

	return zone

# ── 3-D Scene ─────────────────────────────────────────────────────────────────
func _build_3d_scene() -> void:
	# Lighting
	var env         := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode         = Environment.BG_COLOR
	environment.background_color        = Color(0.45, 0.52, 0.60)
	environment.ambient_light_source    = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color     = Color(0.7, 0.68, 0.64)
	environment.ambient_light_energy    = 0.6
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	sun.light_color      = Color(1.0, 0.93, 0.80)
	sun.light_energy     = 1.4
	sun.shadow_enabled   = true
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position    = Vector3(0, 6, 0)
	fill.light_color = Color(0.9, 0.85, 0.75)
	fill.light_energy = 1.0
	fill.omni_range  = 18.0
	add_child(fill)

	# Ground
	var ground_mat := _mat(Color(0.30, 0.26, 0.20), 1.0)
	_box(Vector3(24, 0.2, 20), Vector3(0, -0.1, 0), ground_mat)

	# Dirt patches / oil stains
	_box(Vector3(3.0, 0.01, 2.5), Vector3(-2, 0.01,  1), _mat(Color(0.20, 0.17, 0.13), 1.0))
	_box(Vector3(2.0, 0.01, 1.8), Vector3( 5, 0.01, -3), _mat(Color(0.18, 0.14, 0.10), 1.0))
	_box(Vector3(1.5, 0.01, 1.2), Vector3(-7, 0.01,  4), _mat(Color(0.15, 0.12, 0.09), 1.0))

	# Fences
	var fence_mat := _mat(Color(0.38, 0.30, 0.22), 0.9)
	_box(Vector3(24, 1.8, 0.2), Vector3( 0,  0.9, -10), fence_mat)
	_box(Vector3(0.2, 1.8, 20), Vector3(-12, 0.9,  0),  fence_mat)
	_box(Vector3(0.2, 1.8, 20), Vector3( 12, 0.9,  0),  fence_mat)
	_box(Vector3( 9, 1.8, 0.2), Vector3(-7.5, 0.9, 10), fence_mat)
	_box(Vector3( 9, 1.8, 0.2), Vector3( 7.5, 0.9, 10), fence_mat)

	# Gate posts
	var post_mat := _mat(Color(0.45, 0.35, 0.25), 0.8)
	_box(Vector3(0.3, 2.2, 0.3), Vector3(-3, 1.1, 10), post_mat)
	_box(Vector3(0.3, 2.2, 0.3), Vector3( 3, 1.1, 10), post_mat)

	# Rusty's Shop shed (back-right corner)
	_build_rustys_shed()

	# Scrap office / weigh station (back-left)
	_build_weigh_station()

	# Decorative junk piles & props
	_build_decor()

	# Physics bodies
	_add_junkyard_physics()

	# Spawn player
	_spawn_player()

# ── Rusty's Shop shed ─────────────────────────────────────────────────────────
func _build_rustys_shed() -> void:
	var wood_mat  := _mat(Color(0.45, 0.32, 0.20), 0.9)
	var roof_mat  := _mat(Color(0.55, 0.22, 0.14), 0.85)   # rusty red corrugated roof
	var wall_mat  := _mat(Color(0.50, 0.38, 0.26), 0.88)
	var dark_mat  := _mat(Color(0.12, 0.10, 0.08), 0.95)

	# Walls
	_box(Vector3(5.0, 3.2, 0.2), Vector3(8.0, 1.6, -8.9), wall_mat)   # back
	_box(Vector3(0.2, 3.2, 4.0), Vector3(5.6, 1.6, -7.0), wall_mat)   # left
	_box(Vector3(0.2, 3.2, 4.0), Vector3(10.4, 1.6, -7.0), wall_mat)  # right
	# Front wall with doorway gap
	_box(Vector3(1.8, 3.2, 0.2), Vector3(5.9, 1.6, -5.1), wall_mat)   # front left
	_box(Vector3(1.8, 3.2, 0.2), Vector3(10.1, 1.6, -5.1), wall_mat)  # front right
	_box(Vector3(1.4, 0.8, 0.2), Vector3(8.0, 2.8, -5.1), wall_mat)   # door lintel

	# Roof (slanted — two halves with slight angle)
	_box(Vector3(5.4, 0.18, 2.2), Vector3(8.0, 3.38, -6.3), roof_mat)
	_box(Vector3(5.4, 0.18, 2.2), Vector3(8.0, 3.22, -7.8), roof_mat)

	# Signboard above door
	_box(Vector3(2.2, 0.55, 0.12), Vector3(8.0, 3.0, -5.05), wood_mat)
	# Sign text stand-ins (small colored boxes like letters)
	var sign_mat := _mat(Color(0.95, 0.78, 0.20), 0.5)
	_box(Vector3(1.8, 0.28, 0.08), Vector3(8.0, 3.0, -5.00), sign_mat)

	# Shop counter inside
	_box(Vector3(3.0, 0.9, 0.5), Vector3(8.0, 0.45, -8.5), wood_mat)
	# Shelves on back wall
	_box(Vector3(3.8, 0.1, 0.4), Vector3(8.0, 1.2, -8.7), wood_mat)
	_box(Vector3(3.8, 0.1, 0.4), Vector3(8.0, 2.0, -8.7), wood_mat)
	# Random parts on shelves (colored boxes)
	_box(Vector3(0.22, 0.18, 0.20), Vector3(6.5, 1.32, -8.6), _mat(Color(0.20, 0.22, 0.28), 0.7))
	_box(Vector3(0.28, 0.20, 0.22), Vector3(7.2, 1.32, -8.6), _mat(Color(0.72, 0.32, 0.10), 0.8))
	_box(Vector3(0.18, 0.22, 0.18), Vector3(8.8, 1.32, -8.6), _mat(Color(0.30, 0.62, 0.30), 0.7))
	_box(Vector3(0.24, 0.16, 0.20), Vector3(9.4, 1.32, -8.6), _mat(Color(0.85, 0.78, 0.12), 0.6))

	# Dim interior light
	var shop_light := OmniLight3D.new()
	shop_light.position      = Vector3(8.0, 2.8, -7.0)
	shop_light.light_color   = Color(1.0, 0.85, 0.60)
	shop_light.light_energy  = 1.8
	shop_light.omni_range    = 5.0
	add_child(shop_light)

# ── Weigh station (back-left) ─────────────────────────────────────────────────
func _build_weigh_station() -> void:
	var wall_mat := _mat(Color(0.40, 0.42, 0.38), 0.85)
	var roof_mat := _mat(Color(0.28, 0.30, 0.28), 0.9)
	# Small hut
	_box(Vector3(3.0, 2.4, 2.4), Vector3(-9.5, 1.2, -7.8), wall_mat)
	_box(Vector3(3.4, 0.18, 2.8), Vector3(-9.5, 2.42, -7.8), roof_mat)
	# Window
	_box(Vector3(0.7, 0.5, 0.08), Vector3(-9.5, 1.4, -6.7), _mat(Color(0.5, 0.7, 0.85, 0.6), 0.2))
	# "SCRAP SCALE" text box decoration
	_box(Vector3(1.5, 0.30, 0.08), Vector3(-9.5, 2.0, -6.68), _mat(Color(0.85, 0.65, 0.10), 0.5))
	# Platform scale
	_box(Vector3(2.2, 0.12, 1.4), Vector3(-9.5, 0.06, -6.0), _mat(Color(0.50, 0.50, 0.52), 0.4))

# ── Decorative props ──────────────────────────────────────────────────────────
func _build_decor() -> void:
	var scrap_mat := _mat(Color(0.28, 0.26, 0.30), 0.9)
	scrap_mat.metallic = 0.5

	# Static scrap piles (non-interactive, corners)
	_box(Vector3(1.8, 0.9, 1.4), Vector3(-10, 0.45, -8),  scrap_mat)
	_box(Vector3(2.2, 0.7, 1.0), Vector3( 9,  0.35, -8),  scrap_mat)
	_box(Vector3(1.4, 1.1, 1.0), Vector3(-10, 0.55, 7),   scrap_mat)
	_box(Vector3(1.0, 0.7, 1.6), Vector3( 10, 0.35, 6),   scrap_mat)

	# Rusty barrel cluster near weigh station
	var barrel_mat := _mat(Color(0.42, 0.26, 0.16), 0.8)
	barrel_mat.metallic = 0.3
	for i in 4:
		var mi    := MeshInstance3D.new()
		var cm    := CylinderMesh.new()
		cm.top_radius    = 0.24
		cm.bottom_radius = 0.24
		cm.height        = 0.70
		mi.mesh              = cm
		mi.material_override = barrel_mat
		mi.position = Vector3(-7.8 + (i % 2) * 0.55, 0.35 + (i / 2.0) * 0.68, 7.5)
		add_child(mi)

	# Random car hoods / panels lying around (flat boxes)
	_box(Vector3(1.6, 0.06, 0.9), Vector3(-3,  0.03,  6.5),  _mat(Color(0.62, 0.18, 0.12), 0.75))
	_box(Vector3(1.2, 0.05, 0.7), Vector3( 3,  0.025, 6.0),  _mat(Color(0.18, 0.28, 0.55), 0.75))
	_box(Vector3(0.9, 0.06, 1.1), Vector3(-7,  0.03, -3.5),  _mat(Color(0.25, 0.25, 0.26), 0.72))

	# Old tyres flat on the ground (thin cylinders)
	var tyre_mat := _mat(Color(0.10, 0.09, 0.09), 0.95)
	for i in 3:
		var mi   := MeshInstance3D.new()
		var cm   := CylinderMesh.new()
		cm.top_radius    = 0.40
		cm.bottom_radius = 0.40
		cm.height        = 0.14
		mi.mesh              = cm
		mi.material_override = tyre_mat
		mi.position = Vector3(-8.0 + i * 1.05, 0.07, 2.0 + i * 0.4)
		add_child(mi)

	# Tall junk tower (interesting landmark)
	var rust_mat := _mat(Color(0.50, 0.26, 0.12), 0.85)
	rust_mat.metallic = 0.4
	_box(Vector3(0.8, 3.5, 0.8), Vector3(9.5, 1.75, 3.0), rust_mat)
	_box(Vector3(1.2, 0.4, 1.0), Vector3(9.5, 3.7,  3.0), rust_mat)

# ── Physics ───────────────────────────────────────────────────────────────────
func _add_junkyard_physics() -> void:
	_physics_box(Vector3(24, 0.2, 20), Vector3(0, -0.1, 0))
	_physics_box(Vector3(24, 1.8, 0.2), Vector3(0, 0.9, -10))
	_physics_box(Vector3(0.2, 1.8, 20), Vector3(-12, 0.9, 0))
	_physics_box(Vector3(0.2, 1.8, 20), Vector3( 12, 0.9, 0))
	_physics_box(Vector3(9, 1.8, 0.2), Vector3(-7.5, 0.9, 10))
	_physics_box(Vector3(9, 1.8, 0.2), Vector3( 7.5, 0.9, 10))
	# Shed walls (player can't walk through)
	_physics_box(Vector3(5.0, 3.2, 0.2), Vector3(8.0, 1.6, -8.9))
	_physics_box(Vector3(0.2, 3.2, 4.0), Vector3(5.6, 1.6, -7.0))
	_physics_box(Vector3(0.2, 3.2, 4.0), Vector3(10.4, 1.6, -7.0))

func _spawn_player() -> void:
	var PlayerScript = load("res://scripts/player/Player.gd")
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(PlayerScript)
	p.position = Vector3(0.0, 0.5, 8.5)
	add_child(p)
	player = p

# ── Piles ─────────────────────────────────────────────────────────────────────
func _build_piles() -> void:
	var positions := PILE_POSITIONS.duplicate()
	positions.shuffle()
	for i in PILE_COUNT:
		var pile := Node3D.new()
		pile.set_script(JunkPileScript)
		var base_pos: Vector3 = positions[i % positions.size()]
		pile.position = base_pos + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.25, 0.25))
		add_child(pile)
		pile.setup(i)
		pile.pile_searched.connect(_on_pile_searched)
		piles.append(pile)

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var top_bg := ColorRect.new()
	top_bg.size  = Vector2(1280, 52)
	top_bg.color = Color(0.10, 0.09, 0.07, 0.94)
	hud.add_child(top_bg)

	money_label  = _lbl(Vector2(14,  8), 22, Color(0.4, 1.0, 0.4))
	scrap_label  = _lbl(Vector2(220, 8), 20, Color(0.85, 0.75, 0.5))
	market_label = _lbl(Vector2(480, 6), 18, Color(1.0, 0.88, 0.45))
	_update_market_label()

	var back_btn := Button.new()
	back_btn.text     = "🔧  Back to Garage"
	back_btn.position = Vector2(1060, 8)
	back_btn.size     = Vector2(200, 36)
	back_btn.pressed.connect(_go_to_garage)
	hud.add_child(back_btn)

	# Right panel
	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2(980, 55)
	panel_bg.size     = Vector2(300, 640)
	panel_bg.color    = Color(0.10, 0.09, 0.08, 0.94)
	hud.add_child(panel_bg)

	_lbl(Vector2(1040, 64), 16, Color(1.0, 0.85, 0.4), "FOUND TODAY")

	log_scroll          = ScrollContainer.new()
	log_scroll.position = Vector2(984, 90)
	log_scroll.size     = Vector2(290, 460)
	hud.add_child(log_scroll)

	log_list = VBoxContainer.new()
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_list)

	var sell_btn := Button.new()
	sell_btn.text     = "💰  Sell All Scrap"
	sell_btn.position = Vector2(988, 563)
	sell_btn.size     = Vector2(282, 42)
	sell_btn.pressed.connect(_on_sell_scrap)
	hud.add_child(sell_btn)

	tow_btn         = Button.new()
	tow_btn.text    = "🚛  Tow Wreck to Garage"
	tow_btn.position = Vector2(988, 614)
	tow_btn.size    = Vector2(282, 42)
	tow_btn.visible = false
	tow_btn.pressed.connect(_on_tow_wreck)
	hud.add_child(tow_btn)

	# Interaction prompt
	interact_prompt = Label.new()
	interact_prompt.position             = Vector2(240, 548)
	interact_prompt.size                 = Vector2(500, 36)
	interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt.add_theme_font_size_override("font_size", 19)
	interact_prompt.modulate = Color(1.0, 1.0, 0.55)
	interact_prompt.visible  = false
	hud.add_child(interact_prompt)

	feedback_label = Label.new()
	feedback_label.position             = Vector2(160, 594)
	feedback_label.size                 = Vector2(800, 36)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 20)
	feedback_label.modulate = Color(1, 1, 1, 0)
	hud.add_child(feedback_label)

func _update_market_label() -> void:
	if not market_label: return
	market_label.text     = "📈 Scrap: $%.1f / unit" % _scrap_price
	market_label.modulate = _price_color()

# ── Loot handler ──────────────────────────────────────────────────────────────
func _on_pile_searched(_pile: Node3D, loot: Array) -> void:
	# XP for doing a junkyard run (once per pile searched)
	XPManager.award("junkyard_run")

	if loot.is_empty():
		_log("Nothing here.", Color(0.6, 0.6, 0.6))
		return
	for item in loot:
		match item["type"]:
			"scrap":
				InventoryManager.add_scrap(item["amount"])
				_log("🔩 Scrap +%d" % item["amount"], Color(0.85, 0.75, 0.5))
				show_feedback("+%d Scrap Metal!" % item["amount"], Color(0.9, 0.8, 0.4))

			"part":
				InventoryManager.add_part(item["part_name"])
				_log("⚙️  %s" % item["label"], Color(0.5, 0.9, 0.6))
				show_feedback("Found: %s!" % item["label"], Color.GREEN)

			"wreck":
				pending_wreck = item["template_id"]
				_log("🚗 WRECK! Tow it!", Color.YELLOW)
				show_feedback("Vehicle wreck found! Tow it!", Color.YELLOW)
				tow_btn.visible = true

			"cash":
				var amount: int = item["amount"]
				EconomyManager.add_money(amount)
				_log("💵 CASH FIND!  +$%d" % amount, Color(0.4, 1.0, 0.55))
				show_feedback("💵 Cash found: +$%d!" % amount, Color(0.35, 1.0, 0.50))
				AudioManager.play("cash_find", -4.0)

			"funny":
				# Key is "scrap" (set by JunkPile._generate_loot, not "scrap_amount")
				var scrap_bonus: int = item.get("scrap", 0)
				var flavor: String   = item.get("label", "Mysterious object")
				if scrap_bonus > 0:
					InventoryManager.add_scrap(scrap_bonus)
					_log("😂 %s  (+%d scrap)" % [flavor, scrap_bonus], Color(0.85, 0.62, 1.0))
					show_feedback("😂 %s" % flavor, Color(0.82, 0.60, 1.0))
				else:
					_log("😂 %s" % flavor, Color(0.85, 0.62, 1.0))
					show_feedback("😂 %s" % flavor, Color(0.82, 0.60, 1.0))

			"rare":
				var part_name: String = item.get("part_name", "rare_part")
				var label: String     = item.get("label", "Rare Part")
				InventoryManager.add_part(part_name)
				XPManager.award("rare_part_found")
				_log("⭐ RARE: %s" % label, Color(1.0, 0.85, 0.10))
				show_feedback("⭐ RARE FIND: %s!" % label, Color(1.0, 0.88, 0.0))
				AudioManager.play("rare_find", -2.0)

			"nothing":
				_log("🍃 Nothing useful.", Color(0.6, 0.6, 0.6))

# ── Rusty's Shop panel ────────────────────────────────────────────────────────
func _open_rusty_shop() -> void:
	if _shop_open: return
	_shop_open = true
	if player: player.freeze()

	_shop_panel = CanvasLayer.new()
	add_child(_shop_panel)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.size  = Vector2(1280, 720)
	overlay.color = Color(0, 0, 0, 0.55)
	_shop_panel.add_child(overlay)

	# Panel background
	var bg := ColorRect.new()
	bg.position = Vector2(340, 80)
	bg.size     = Vector2(600, 560)
	bg.color    = Color(0.12, 0.10, 0.08, 0.97)
	_shop_panel.add_child(bg)

	# Panel border
	var border := ColorRect.new()
	border.position = Vector2(337, 77)
	border.size     = Vector2(606, 566)
	border.color    = Color(0.62, 0.42, 0.18, 0.9)
	_shop_panel.add_child(border)
	_shop_panel.move_child(bg, _shop_panel.get_child_count() - 1)

	# Title
	var title := Label.new()
	title.text             = "🛠️  RUSTY'S SHOP"
	title.position         = Vector2(430, 100)
	title.size             = Vector2(400, 40)
	title.add_theme_font_size_override("font_size", 26)
	title.modulate         = Color(1.0, 0.78, 0.22)
	_shop_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text     = "\"If it ain't broke, it will be soon.\""
	subtitle.position = Vector2(355, 138)
	subtitle.size     = Vector2(570, 28)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.65, 0.60, 0.52)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_panel.add_child(subtitle)

	# Divider
	var div := ColorRect.new()
	div.position = Vector2(350, 168)
	div.size     = Vector2(580, 2)
	div.color    = Color(0.50, 0.35, 0.15, 0.6)
	_shop_panel.add_child(div)

	# Money display
	var mon_lbl := Label.new()
	mon_lbl.name     = "ShopMoneyLabel"
	mon_lbl.text     = "💰 Your cash: $%s" % _fmt(EconomyManager.money)
	mon_lbl.position = Vector2(355, 175)
	mon_lbl.size     = Vector2(580, 28)
	mon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mon_lbl.add_theme_font_size_override("font_size", 16)
	mon_lbl.modulate = Color(0.5, 1.0, 0.5)
	_shop_panel.add_child(mon_lbl)

	# Item list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(350, 210)
	scroll.size     = Vector2(580, 360)
	_shop_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	for item in RUSTY_ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text     = item["label"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.modulate = Color(0.92, 0.90, 0.84)
		row.add_child(name_lbl)

		var base_cost : int = item["cost"]
		var display_cost : int = int(round(base_cost * 0.75)) if EventSystem.is_parts_discount() else base_cost

		var price_lbl := Label.new()
		if EventSystem.is_parts_discount():
			price_lbl.text = "$%d  ($%d)" % [display_cost, base_cost]
		else:
			price_lbl.text = "$%d" % display_cost
		price_lbl.add_theme_font_size_override("font_size", 17)
		price_lbl.modulate = Color(0.35, 1.0, 0.55) if EventSystem.is_parts_discount() else Color(0.9, 0.78, 0.30)
		price_lbl.custom_minimum_size = Vector2(80, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price_lbl)

		var buy_btn := Button.new()
		buy_btn.text             = "Buy"
		buy_btn.custom_minimum_size = Vector2(72, 32)
		var capture_item: Dictionary = item.duplicate()
		buy_btn.pressed.connect(func(): _buy_rusty_item(capture_item, mon_lbl))
		row.add_child(buy_btn)

		# Disable if can't afford the discounted price
		if EconomyManager.money < display_cost:
			buy_btn.disabled = true
			price_lbl.modulate = Color(0.55, 0.45, 0.30)

		vbox.add_child(row)

		# Thin separator
		var sep := ColorRect.new()
		sep.size  = Vector2(560, 1)
		sep.color = Color(0.35, 0.28, 0.18, 0.4)
		vbox.add_child(sep)

	# Close button
	var close_btn := Button.new()
	close_btn.text     = "Close"
	close_btn.position = Vector2(575, 590)
	close_btn.size     = Vector2(120, 36)
	close_btn.pressed.connect(_close_rusty_shop)
	_shop_panel.add_child(close_btn)

func _buy_rusty_item(item: Dictionary, money_label_ref: Label) -> void:
	var base_cost : int = item["cost"]
	var cost : int = base_cost
	if EventSystem.is_parts_discount():
		cost = int(round(base_cost * 0.75))   # 25% off on Rusty's Sale day
	if EconomyManager.money < cost:
		show_feedback("Not enough cash!", Color(1.0, 0.4, 0.3))
		return
	EconomyManager.add_money(-cost)
	InventoryManager.add_part(item["part_name"])
	show_feedback("Bought: %s" % item["label"], Color(0.4, 1.0, 0.55))
	_log("🛒 Bought %s  (-$%d)" % [item["label"], cost], Color(0.5, 0.85, 0.65))
	AudioManager.play("zone_enter", -5.0)
	if money_label_ref:
		money_label_ref.text = "💰 Your cash: $%s" % _fmt(EconomyManager.money)

func _close_rusty_shop() -> void:
	if _shop_panel:
		_shop_panel.queue_free()
		_shop_panel = null
	_shop_open = false
	if player: player.unfreeze()

# ── Helpers ───────────────────────────────────────────────────────────────────
func _on_sell_scrap() -> void:
	var scrap : int = InventoryManager.scrap_metal
	if scrap <= 0:
		show_feedback("No scrap to sell.", Color(0.7, 0.7, 0.7))
		return
	var earned : int = int(round(float(scrap) * _scrap_price))
	EconomyManager.add_money(earned)
	InventoryManager.clear_scrap()
	show_feedback("Sold %d scrap for $%d!" % [scrap, earned], Color.GREEN)
	_log("💰 Sold %d scrap × $%.1f = $%d" % [scrap, _scrap_price, earned], Color(0.4, 1.0, 0.55))
	AudioManager.play("sell_car", -6.0)

func _on_tow_wreck() -> void:
	if pending_wreck.is_empty(): return
	GameManager.set_meta("pending_wreck", pending_wreck)
	pending_wreck       = ""
	tow_btn.visible     = false
	show_feedback("Wreck towed! Heading back…", Color.CYAN)
	await get_tree().create_timer(1.2).timeout
	_go_to_garage()

func _go_to_garage() -> void:
	get_tree().change_scene_to_file("res://scenes/garage/Garage.tscn")

func _on_new_day() -> void:
	_roll_scrap_price()
	_update_market_label()
	for pile in piles:
		pile.reset_for_new_day()
	for c in log_list.get_children():
		c.queue_free()

# ── HUD helpers ───────────────────────────────────────────────────────────────
func _log(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text    = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 13)
	log_list.add_child(lbl)
	await get_tree().process_frame
	log_scroll.scroll_vertical = log_scroll.get_v_scroll_bar().max_value

func _update_money(amt: int) -> void:
	if money_label: money_label.text = "$%s" % _fmt(amt)

func _update_scrap(amt: int) -> void:
	if scrap_label: scrap_label.text = "🔩 Scrap: %d" % amt

func show_feedback(msg: String, color: Color = Color.WHITE) -> void:
	if not feedback_label: return
	feedback_label.text    = msg
	feedback_label.modulate = color
	if feedback_tween: feedback_tween.kill()
	feedback_tween = create_tween()
	feedback_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.0)
	feedback_tween.tween_interval(2.2)
	feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.8)

func _lbl(pos: Vector2, size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	l.text     = text
	hud.add_child(l)
	return l

func _fmt(n: int) -> String:
	var s := str(abs(n)); var r := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0: r += ","
		r += s[i]
	return ("-" if n < 0 else "") + r

# ── Mesh helpers ──────────────────────────────────────────────────────────────
func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	return m

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size             = size
	mi.mesh               = mesh
	mi.material_override  = mat
	mi.position           = pos
	add_child(mi)
	return mi

func _physics_box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb    := StaticBody3D.new()
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape  = shape
	sb.add_child(col)
	sb.position = pos
	add_child(sb)
	return sb

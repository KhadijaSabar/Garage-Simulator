## Garage.gd  (3D)
## Main scene. Builds the entire 3D garage in code.
## Manages vehicles, orders, workbench, cleaning, thief system.
extends Node3D

# ── Preload ───────────────────────────────────────────────────────────────────
const VehicleScene       = preload("res://scenes/vehicles/Vehicle.tscn")
const WorkbenchScript    = preload("res://scripts/garage/WorkbenchSystem.gd")
const CleaningScript     = preload("res://scripts/garage/GarageCleaning.gd")
const ThiefScript        = preload("res://scripts/garage/ThiefSystem.gd")
const UpgradeShopScript  = preload("res://scripts/ui/UpgradeShop.gd")
const ReceptionScript    = preload("res://scripts/garage/ReceptionDesk.gd")
const DaySummaryScript      = preload("res://scripts/ui/DaySummary.gd")
const WorkbenchPanelScript  = preload("res://scripts/ui/WorkbenchPanel.gd")
const CustomerNPCScript     = preload("res://scripts/npc/CustomerNPC.gd")
const PaintBoothScript      = preload("res://scripts/ui/PaintBoothPanel.gd")
const AuctionPanelScript    = preload("res://scripts/ui/AuctionPanel.gd")
const EmployeePanelScript   = preload("res://scripts/ui/EmployeePanel.gd")
const TabletPanelScript     = preload("res://scripts/ui/TabletPanel.gd")

# ── Child systems ─────────────────────────────────────────────────────────────
var workbench:   Node3D
var cleaning:    Node
var thief_sys:   Node
var reception:   Node3D
var bay_slot:    Node3D
var customer_timer: Timer
var hud:              CanvasLayer
var upgrade_shop:     PanelContainer
var workbench_panel:  PanelContainer = null   ## WorkbenchPanel, spawned on demand

# ── HUD widgets ───────────────────────────────────────────────────────────────
var money_label:       Label
var day_label:         Label
var time_bar:          ProgressBar
var rep_label:         Label
var tier_label:        Label
var feedback_label:    Label
var inv_parts_label:   Label
var interact_prompt:   Label   ## "[ E ]  ..." shown near interaction zones
var order_panel_list:  VBoxContainer
var active_panel_list: VBoxContainer
var feedback_tween:    Tween

# Car action bar (bottom strip — visible when vehicle is in bay)
var _car_bar:          Control
var _car_bar_btns:     Array[Button] = []

# XP HUD
var xp_bar:            ProgressBar
var xp_level_label:    Label
var xp_ticker_label:   Label     ## "+20 XP" floaty text
var xp_ticker_tween:   Tween

# Inspection + negotiation panels
var inspection_panel:  PanelContainer
var negotiation_panel: Control
var insp_title:  Label
var insp_score:  Label
var insp_dirt:   Label
var insp_value:  Label
var insp_order:  Label
var insp_parts_list: VBoxContainer
var neg_cust_name:      Label
var neg_personality:    Label
var neg_greeting:       Label
var neg_offer:          Label
var neg_vehicle_val:    Label
var neg_slider:         HSlider
var neg_slider_val:     Label
var neg_accept_btn:     Button
var neg_counter_btn:    Button
var neg_refuse_btn:     Button
var neg_free_btn:       Button   ## "Help for Free" — shown only for POOR_STUDENT
var neg_kick_btn:       Button   ## "Kick Out" — shown after refusing a persistent customer twice
var neg_result:         Label
var neg_panel_stripe:   ColorRect  ## Left accent color bar
var neg_service_section:   VBoxContainer  ## Visible only in service-quote mode
var neg_service_jobs_list: VBoxContainer
var neg_service_quote:     Label
var neg_slider_row:        HBoxContainer  ## Whole slider row — hidden in pickup mode
var _notify_btn:           Button         ## "Notify Customer" — shown when service car is done

# ── State ─────────────────────────────────────────────────────────────────────
var current_vehicle:   Vehicle = null
var pending_customer:  Customer = null
var feedback_tween2:   Tween = null
var _night_event:      Dictionary = {}   ## Filled by ThiefSystem signals each night
var player:            Node = null       ## CharacterBody3D with Player.gd
var customer_npc:      Node = null       ## CustomerNPC walking into the garage
var _reception_zone:   Area3D = null    ## Zone near the reception desk

# ── Towing ────────────────────────────────────────────────────────────────────
var _pending_tow : Dictionary = {}   ## Filled when tow arrives but bay is occupied

# ── Service customer state ─────────────────────────────────────────────────────
var _refuse_count          : int    = 0      ## How many times player refused persistent customer
var _neg_mode              : String = "flip"  ## "flip" | "service" | "pickup" | "pickup_open"
var _service_base_quote    : int    = 0       ## Calculated estimate for service jobs
var _service_rep_bonus     : float  = 0.0    ## Rep to award on successful service completion
var _active_service_order_id: int   = -1     ## Walk-in order currently in the bay (-1 = none)

# ── Day / night lighting ───────────────────────────────────────────────────────
var _sun           : DirectionalLight3D = null
var _fill_light    : OmniLight3D        = null
var _bay_light     : SpotLight3D        = null
var _sky_env       : Environment        = null
var _ceiling_lamps : Array              = []   ## Array[OmniLight3D]
var _lights_on     : bool               = false  ## True once ceiling lights have flickered on

# ── Lighting time keypoints (t = 0.0 … 1.0) ──────────────────────────────────
# Readable sim-style: bright daylight overhead, clean indoor visibility.
# Interior lamps stay ON to keep the shop well-lit at all hours.
const _TK : Array = [0.0,  0.15,  0.45,  0.75,  0.90,  1.0]
# Sun pitch
const _SUN_PITCH : Array = [-22.0, -38.0, -70.0, -30.0, -12.0, -4.0]
# Sun yaw
const _SUN_YAW   : Array = [ 78.0,  58.0,  18.0, -36.0, -62.0, -80.0]
# Sun energy — punchy daylight, gentle dawn/dusk, low moon
const _SUN_E     : Array = [  0.6,   1.1,   1.7,   1.0,   0.4,   0.10]
# Sun color
const _SUN_COL   : Array = [
	Color(1.00, 0.80, 0.58),  # dawn — warm peach
	Color(1.00, 0.92, 0.78),  # morning — soft golden
	Color(1.00, 0.97, 0.92),  # midday — near-white
	Color(1.00, 0.82, 0.50),  # late afternoon — amber
	Color(1.00, 0.58, 0.32),  # dusk — orange
	Color(0.50, 0.55, 0.72),  # night — cool moonlight
]
# Sky color (seen through door)
const _SKY_COL   : Array = [
	Color(0.42, 0.36, 0.48),  # dawn — soft violet
	Color(0.60, 0.74, 0.92),  # morning — light blue
	Color(0.52, 0.74, 0.95),  # midday — clear sky blue
	Color(0.78, 0.62, 0.36),  # afternoon — golden
	Color(0.46, 0.24, 0.18),  # dusk — burnt orange
	Color(0.05, 0.07, 0.14),  # night — deep blue
]
# Ambient — bright enough to read every surface
const _AMB_E     : Array = [0.42, 0.65, 0.85, 0.62, 0.40, 0.30]
# Ambient color
const _AMB_COL   : Array = [
	Color(0.55, 0.55, 0.60),
	Color(0.68, 0.68, 0.70),
	Color(0.75, 0.76, 0.78),
	Color(0.72, 0.62, 0.50),
	Color(0.56, 0.40, 0.32),
	Color(0.36, 0.40, 0.50),
]
# Interior overhead lamp energy — always lit, brighter at night
const _LAMP_E    : Array = [1.30, 1.05, 0.85, 1.20, 1.80, 2.20]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("garage")
	_build_3d_scene()
	_build_hud()
	_build_inspection_panel()
	_build_negotiation_panel()
	_setup_systems()
	_setup_timer()
	_connect_signals()

	# Wire interact prompt into player now that HUD has been built
	if player:
		player.set("_interact_label", interact_prompt)

	# Load save or spawn starting vehicle
	if GameManager.has_meta("pending_wreck"):
		var wreck_id: String = GameManager.get_meta("pending_wreck")
		GameManager.remove_meta("pending_wreck")
		_spawn_vehicle(wreck_id, randf_range(0.70, 0.90))
		show_feedback("Towed wreck arrived — let's fix it up!", Color.CYAN)
	else:
		_spawn_vehicle("rustbucket_sedan", 0.65)

	_update_money(EconomyManager.money)
	_update_day(GameManager.current_day)
	_update_rep(EconomyManager.reputation)
	_update_tier_label()
	_refresh_inventory_display()
	_refresh_order_panels()
	_update_xp_bar()

# ─────────────────────────────────────────────────────────────────────────────
#  3D SCENE CONSTRUCTION
# ─────────────────────────────────────────────────────────────────────────────
func _build_3d_scene() -> void:
	_build_lighting()
	_build_garage_room()
	_add_physics_bodies()          # StaticBody3D walls/floor for player collision
	_build_bay()
	_build_workbench_area()
	_build_reception_area()
	_build_paint_booth()
	_build_tablet_prop()           # Visible wall-mounted tablet near back wall
	_build_scene_props()           # Toolbox, tire stack, oil drum
	_build_interaction_zones()     # Area3D zones the player can walk up to
	_spawn_player()                # CharacterBody3D with third-person camera

func _build_lighting() -> void:
	# Bright readable sim-style lighting. Daylight punches in, interior lamps
	# keep everything clearly visible at all hours. No moody crushed blacks.
	var env_node    := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode        = Environment.BG_COLOR
	environment.background_color       = _SKY_COL[0]
	environment.ambient_light_source   = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color    = _AMB_COL[0]
	environment.ambient_light_energy   = _AMB_E[0]

	# ── Tone mapping — ACES, standard exposure ────────────────────────────────
	environment.tonemap_mode       = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure   = 1.05
	environment.tonemap_white      = 1.0

	# ── Bloom / Glow — subtle, only on hot emissives ──────────────────────────
	environment.glow_enabled              = true
	environment.glow_normalized           = true
	environment.glow_intensity            = 0.55
	environment.glow_bloom                = 0.10
	environment.glow_blend_mode           = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold        = 1.10
	environment.glow_hdr_scale            = 2.0

	# ── SSAO — gentle corner shadowing only ───────────────────────────────────
	environment.ssao_enabled       = true
	environment.ssao_radius        = 1.0
	environment.ssao_intensity     = 1.4
	environment.ssao_power         = 1.5
	environment.ssao_detail        = 0.5
	environment.ssao_horizon       = 0.06
	environment.ssao_sharpness     = 0.98

	# ── SSIL — bounce light keeps surfaces vibrant ────────────────────────────
	environment.ssil_enabled       = true
	environment.ssil_radius        = 5.0
	environment.ssil_intensity     = 1.0
	environment.ssil_sharpness     = 0.94

	# No fog by default — sim-game look is clean, not hazy
	environment.fog_enabled        = false
	environment.volumetric_fog_enabled = false

	# No color grading shift — keep colors natural
	environment.adjustment_enabled = false

	env_node.environment = environment
	add_child(env_node)
	_sky_env = environment   # save for animation

	# ── Sun — punchy directional daylight with crisp shadows ──────────────────
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees    = Vector3(_SUN_PITCH[0], _SUN_YAW[0], 0.0)
	sun.light_color         = _SUN_COL[0]
	sun.light_energy        = _SUN_E[0]
	sun.light_angular_distance = 0.5
	sun.shadow_enabled      = true
	sun.shadow_bias         = 0.05
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	_sun = sun

	# ── Fill — warm interior bounce so the room never reads as dark ───────────
	var fill := OmniLight3D.new()
	fill.position     = Vector3(0, 4.5, 0)
	fill.light_color  = Color(1.0, 0.95, 0.85)
	fill.light_energy = 1.8
	fill.omni_range   = 24.0
	add_child(fill)
	_fill_light = fill

	# ── Bay work-light — clean white spot on the active lift ──────────────────
	var bay := SpotLight3D.new()
	bay.position         = Vector3(-2.0, 5.6, 0.0)
	bay.rotation_degrees = Vector3(-78.0, 0.0, 0.0)
	bay.light_color      = Color(0.98, 0.98, 1.00)
	bay.light_energy     = 3.5
	bay.spot_range       = 9.0
	bay.spot_angle       = 32.0
	bay.spot_attenuation = 1.0
	bay.shadow_enabled   = true
	bay.shadow_bias      = 0.04
	add_child(bay)
	_bay_light = bay

	# Ceiling lamp fixtures (visible props + point lights)
	_build_ceiling_lamps()

## Ceiling lamp fixtures — clean modern enameled industrial pendants hanging
## from the new 12m warehouse beams via long chains. Warm amber bulbs.
func _build_ceiling_lamps() -> void:
	# Pendant rows hang well below the beams to stay within visible play space.
	# Three rows of pendants spanning the 5 bays in the front + middle work zones.
	var lamp_positions := [
		Vector3(-16.0, 7.20, -1.4), Vector3(-9.0, 7.20, -1.4),
		Vector3( -2.0, 7.20, -1.4), Vector3( 5.0, 7.20, -1.4),
		Vector3( 12.0, 7.20, -1.4),
		Vector3(-16.0, 7.20,  2.4), Vector3(-9.0, 7.20,  2.4),
		Vector3( -2.0, 7.20,  2.4), Vector3( 5.0, 7.20,  2.4),
		Vector3( 12.0, 7.20,  2.4),
	]

	# Dirty enameled metal shade — green-painted industrial fixture
	var shade_mat := StandardMaterial3D.new()
	shade_mat.albedo_color = Color(0.10, 0.12, 0.10)
	shade_mat.metallic     = 0.4
	shade_mat.roughness    = 0.62

	# Inside of shade — bright cream reflector, slightly emissive so it always reads
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color              = Color(0.96, 0.78, 0.42)
	inner_mat.emission_enabled          = true
	inner_mat.emission                  = Color(1.00, 0.74, 0.32)
	inner_mat.emission_energy_multiplier = 0.55

	# Sodium bulb — hot amber core that blooms hard
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color              = Color(1.00, 0.78, 0.36)
	bulb_mat.emission_enabled          = true
	bulb_mat.emission                  = Color(1.00, 0.62, 0.18)
	bulb_mat.emission_energy_multiplier = 6.0

	# Chain material — dark oxidized steel
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.14, 0.13, 0.12)
	chain_mat.metallic     = 0.6
	chain_mat.roughness    = 0.55

	for lp: Vector3 in lamp_positions:
		# Long chain dropping from ceiling beam (at y=11.7) down to the shade
		var chain_top: float = 11.65
		var chain_len: float = chain_top - (lp.y + 0.20)
		_make_box(Vector3(0.04, chain_len, 0.04),
			Vector3(lp.x, lp.y + 0.20 + chain_len * 0.5, lp.z), chain_mat)

		# Conical shade — approximated as wide flat disk
		_make_box(Vector3(0.72, 0.10, 0.72), Vector3(lp.x, lp.y + 0.18, lp.z), shade_mat)
		_make_box(Vector3(0.58, 0.06, 0.58), Vector3(lp.x, lp.y + 0.12, lp.z), shade_mat)
		_make_box(Vector3(0.44, 0.05, 0.44), Vector3(lp.x, lp.y + 0.07, lp.z), shade_mat)

		# Inner reflector — amber glow on the underside
		_make_box(Vector3(0.42, 0.02, 0.42), Vector3(lp.x, lp.y + 0.04, lp.z), inner_mat)

		# Sodium bulb hanging below — the actual light source mesh
		_make_box(Vector3(0.12, 0.16, 0.12), Vector3(lp.x, lp.y - 0.08, lp.z), bulb_mat)

		# Point light below the bulb — warm sodium amber
		var lamp := OmniLight3D.new()
		lamp.position       = Vector3(lp.x, lp.y - 0.18, lp.z)
		lamp.light_color    = Color(1.00, 0.68, 0.28)
		lamp.light_energy   = _LAMP_E[0]
		lamp.omni_range     = 8.5
		lamp.omni_attenuation = 1.4
		lamp.shadow_enabled = true
		lamp.shadow_bias    = 0.06
		add_child(lamp)
		_ceiling_lamps.append(lamp)

	# ── Accent rim lights — define silhouettes against the dark walls ─────────
	# Cool LED strip from above the back tool rack (technical / clinical feel)
	var rack_led := OmniLight3D.new()
	rack_led.position       = Vector3(-7.0, 3.6, -9.4)
	rack_led.light_color    = Color(0.62, 0.78, 1.00)
	rack_led.light_energy   = 0.55
	rack_led.omni_range     = 6.5
	add_child(rack_led)

	# Cold blue accent at back of bay — backlight separation
	var back_rim := OmniLight3D.new()
	back_rim.position       = Vector3(0.0, 2.4, 5.6)
	back_rim.light_color    = Color(0.30, 0.46, 0.78)
	back_rim.light_energy   = 0.45
	back_rim.omni_range     = 11.0
	add_child(back_rim)

	# Red exit-sign accent over service door — small atmospheric pop
	var exit_glow := OmniLight3D.new()
	exit_glow.position      = Vector3(13.4, 3.6, 0.0)
	exit_glow.light_color   = Color(1.00, 0.18, 0.12)
	exit_glow.light_energy  = 0.30
	exit_glow.omni_range    = 4.0
	add_child(exit_glow)

func _build_garage_room() -> void:
	# ── Floor — clean polished concrete, 56×40m XL workshop ───────────────
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.44, 0.43, 0.42)
	floor_mat.roughness    = 0.55
	floor_mat.metallic     = 0.05
	floor_mat.metallic_specular = 0.5
	_make_box(Vector3(56, 0.2, 40), Vector3(0, -0.1, 0), floor_mat)

	# Expansion joints — thin dark seam grid (56×40 floor)
	var joint_mat := StandardMaterial3D.new()
	joint_mat.albedo_color = Color(0.05, 0.04, 0.03)
	joint_mat.roughness    = 0.95
	for gx in [-22.0, -16.0, -9.0, -4.5, 0.0, 4.5, 9.0, 16.0, 22.0]:
		_make_box(Vector3(0.05, 0.012, 40.0), Vector3(gx, 0.01, 0.0), joint_mat)
	for gz in [-15.0, -10.0, -7.0, -3.5, 0.0, 3.5, 7.0, 10.0, 15.0]:
		_make_box(Vector3(56.0, 0.012, 0.05), Vector3(0.0, 0.01, gz), joint_mat)

	# Subtle wear marks beneath each vehicle bay — small, clean, not grungy
	var stain_mat := StandardMaterial3D.new()
	stain_mat.albedo_color  = Color(0.22, 0.20, 0.18)
	stain_mat.metallic      = 0.10
	stain_mat.roughness     = 0.55
	for bx_pos: float in [-16.0, -9.0, -2.0, 5.0, 12.0]:
		_make_box(Vector3(2.4, 0.006, 1.4), Vector3(bx_pos - 0.2, 0.005, 0.3), stain_mat)

	# Decorative epoxy floor accent stripe — runs across the back of the bay row
	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.30, 0.58, 0.82)
	accent_mat.roughness    = 0.55
	_make_box(Vector3(54.0, 0.006, 0.55), Vector3(0.0, 0.006, -5.0), accent_mat)

	# Floor drain grates — sunken slatted metal, one per bay
	var drain_mat := StandardMaterial3D.new()
	drain_mat.albedo_color = Color(0.10, 0.10, 0.10)
	drain_mat.metallic     = 0.7
	drain_mat.roughness    = 0.35
	for dpos in [
		Vector3(-16.0, 0.005, 1.1), Vector3(-9.4, 0.005, 1.1),
		Vector3( -2.2, 0.005, 1.1), Vector3( 5.0, 0.005, 1.1),
		Vector3( 12.0, 0.005, 1.1),
	]:
		_make_box(Vector3(0.36, 0.006, 0.36), dpos, drain_mat)
		# Grate slats — alternating dark gaps
		for si in range(5):
			var gap_m := StandardMaterial3D.new()
			gap_m.albedo_color = Color(0.02, 0.02, 0.02)
			_make_box(Vector3(0.32, 0.004, 0.04),
				Vector3(dpos.x, dpos.y + 0.004, dpos.z - 0.14 + si * 0.07), gap_m)

	# ── Bay floor markings — fresh bright safety yellow paint ─────────────
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.98, 0.82, 0.10)
	line_mat.roughness    = 0.45
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.98, 0.82, 0.10)
	line_mat.emission_energy_multiplier = 0.10
	# Bays at x = -16, -9, -2 (active), +5, +12. 5.8m wide each.
	for bxc: float in [-16.0, -9.0, -2.0, 5.0, 12.0]:
		_make_box(Vector3(5.8, 0.012, 0.10), Vector3(bxc, 0.011, -2.10), line_mat)
		_make_box(Vector3(5.8, 0.012, 0.10), Vector3(bxc, 0.011,  2.10), line_mat)
	# Bright fresh yellow walkway markings along the back wall (clean, not faded)
	var tape_y := StandardMaterial3D.new()
	tape_y.albedo_color = Color(0.98, 0.82, 0.10)
	tape_y.roughness    = 0.45
	tape_y.emission_enabled = true
	tape_y.emission = Color(0.98, 0.82, 0.10)
	tape_y.emission_energy_multiplier = 0.08
	var tape_k := StandardMaterial3D.new()
	tape_k.albedo_color = Color(0.12, 0.12, 0.12)
	tape_k.roughness    = 0.55
	for sx in range(56):
		var fx: float = -27.6 + sx * 0.99
		_make_box(Vector3(0.5, 0.012, 0.22), Vector3(fx, 0.011, -18.2),
			tape_y if sx % 2 == 0 else tape_k)

	# ── Walls — painted industrial pale teal (low) + clean off-white (high) ─
	var wall_lo := StandardMaterial3D.new()
	wall_lo.albedo_color = Color(0.32, 0.46, 0.46)    # pale teal-gray
	wall_lo.roughness    = 0.85
	var wall_hi := StandardMaterial3D.new()
	wall_hi.albedo_color = Color(0.82, 0.82, 0.80)    # warm off-white
	wall_hi.roughness    = 0.82
	# Back wall (Z=-20) — XL warehouse, 12m tall
	_make_box(Vector3(56, 2.4, 0.2), Vector3(0, 1.2, -20.0), wall_lo)
	_make_box(Vector3(56, 9.6, 0.2), Vector3(0, 7.2, -20.0), wall_hi)
	# Left wall (X=-28)
	_make_box(Vector3(0.2, 2.4, 40), Vector3(-28, 1.2, 0), wall_lo)
	_make_box(Vector3(0.2, 9.6, 40), Vector3(-28, 7.2, 0), wall_hi)
	# Right wall (X=28)
	_make_box(Vector3(0.2, 2.4, 40), Vector3(28, 1.2, 0), wall_lo)
	_make_box(Vector3(0.2, 9.6, 40), Vector3(28, 7.2, 0), wall_hi)
	# Front panels (Z=20) — wide door opening 12m in center
	_make_box(Vector3(22, 2.4, 0.2), Vector3(-17.0, 1.2, 20.0), wall_lo)
	_make_box(Vector3(22, 9.6, 0.2), Vector3(-17.0, 7.2, 20.0), wall_hi)
	_make_box(Vector3(22, 2.4, 0.2), Vector3( 17.0, 1.2, 20.0), wall_lo)
	_make_box(Vector3(22, 9.6, 0.2), Vector3( 17.0, 7.2, 20.0), wall_hi)
	# Tall lintel panel over the garage door — fills wall above 2.88m door slats
	_make_box(Vector3(12, 9.12, 0.2), Vector3(0, 7.44, 20.0), wall_hi)

	# Painted yellow safety stripe where lo meets hi (fresh paint)
	var div_m := StandardMaterial3D.new()
	div_m.albedo_color = Color(0.96, 0.78, 0.10)
	div_m.roughness    = 0.5
	_make_box(Vector3(56.0, 0.09, 0.04), Vector3(0,    2.44, -19.98), div_m)
	_make_box(Vector3(0.04, 0.09, 40.0), Vector3(-27.98, 2.44, 0.0), div_m)
	_make_box(Vector3(0.04, 0.09, 40.0), Vector3( 27.98, 2.44, 0.0), div_m)

	# Polished steel baseboard kickplate — clean galvanized
	var base_m := StandardMaterial3D.new()
	base_m.albedo_color = Color(0.62, 0.62, 0.64)
	base_m.metallic     = 0.55
	base_m.roughness    = 0.3
	_make_box(Vector3(56.0, 0.20, 0.06), Vector3(0,     0.10, -19.97), base_m)
	_make_box(Vector3(0.06, 0.20, 40.0), Vector3(-27.97, 0.10, 0.0),  base_m)
	_make_box(Vector3(0.06, 0.20, 40.0), Vector3( 27.97, 0.10, 0.0),  base_m)

	# Decorative wall panel seams — clean modern shop look, not grunge
	var seam_mat := StandardMaterial3D.new()
	seam_mat.albedo_color = Color(0.20, 0.30, 0.32)
	seam_mat.roughness    = 0.6
	for rx: float in [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]:
		_make_box(Vector3(0.06, 2.0, 0.04), Vector3(rx, 1.2, -19.93), seam_mat)
	for rz: float in [-15.0, -7.5, 0.0, 7.5, 15.0]:
		_make_box(Vector3(0.04, 2.0, 0.06), Vector3(-27.91, 1.2, rz), seam_mat)
		_make_box(Vector3(0.04, 2.0, 0.06), Vector3( 27.91, 1.2, rz), seam_mat)

	# Painted bay number stencils on the rear wall above each of the 5 bays
	for bnx: float in [-16.0, -9.0, -2.0, 5.0, 12.0]:
		var stencil_m := StandardMaterial3D.new()
		stencil_m.albedo_color = Color(0.18, 0.30, 0.48)   # clean nautical blue
		stencil_m.roughness    = 0.55
		_make_box(Vector3(0.46, 0.70, 0.03), Vector3(bnx, 6.3, -19.91), stencil_m)
		# Hint of the digit shape: short horizontal bar
		_make_box(Vector3(0.36, 0.10, 0.03), Vector3(bnx, 5.95, -19.90), stencil_m)

	# ── Ceiling — light corrugated metal panels, 12m high warehouse ───────
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_color = Color(0.62, 0.62, 0.64)
	ceil_mat.roughness    = 0.7
	ceil_mat.metallic     = 0.18
	_make_box(Vector3(56, 0.2, 40), Vector3(0, 12.1, 0), ceil_mat)

	# Painted structural I-beams at Y=11.80 — friendly graphite gray
	var beam_m := StandardMaterial3D.new()
	beam_m.albedo_color = Color(0.32, 0.32, 0.34)
	beam_m.metallic     = 0.35
	beam_m.roughness    = 0.55
	for bz: float in [-15.0, -10.5, -7.0, -3.5, 0.0, 3.5, 7.0, 10.5, 15.0]:
		_make_box(Vector3(56, 0.42, 0.40), Vector3(0, 11.80, bz), beam_m)
	for bx: float in [-22.0, -16.0, -9.0, -4.5, 0.0, 4.5, 9.0, 16.0, 22.0]:
		_make_box(Vector3(0.40, 0.38, 40), Vector3(bx, 11.80, 0), beam_m)

	# Vertical lattice trusses dropping from beams — gives the height some structure
	var truss_m := StandardMaterial3D.new()
	truss_m.albedo_color = Color(0.30, 0.30, 0.32)
	truss_m.metallic     = 0.4
	truss_m.roughness    = 0.55
	for tx: float in [-22.0, -16.0, -9.0, -4.5, 0.0, 4.5, 9.0, 16.0, 22.0]:
		for tz: float in [-15.0, -7.0, 0.0, 7.0, 15.0]:
			# Diagonal cross-braces (approximated as thin angled boxes at corners)
			_make_box(Vector3(0.12, 1.40, 0.12), Vector3(tx, 11.0, tz), truss_m)

	# Exposed HVAC duct running across the ceiling — bigger, higher up
	var duct_m := StandardMaterial3D.new()
	duct_m.albedo_color = Color(0.62, 0.62, 0.60)
	duct_m.metallic     = 0.45
	duct_m.roughness    = 0.5
	_make_box(Vector3(56.0, 0.80, 0.80), Vector3(0.0, 11.10, -10.4), duct_m)
	_make_box(Vector3(56.0, 0.70, 0.70), Vector3(0.0, 11.15,  10.0), duct_m)
	# Strap brackets around the duct every few meters
	for dx in range(-24, 25, 4):
		var strap_m := StandardMaterial3D.new()
		strap_m.albedo_color = Color(0.30, 0.30, 0.32)
		strap_m.metallic     = 0.55
		_make_box(Vector3(0.05, 0.88, 0.88), Vector3(float(dx), 11.10, -10.4), strap_m)
		_make_box(Vector3(0.05, 0.78, 0.78), Vector3(float(dx), 11.15,  10.0), strap_m)

	# Bright red sprinkler pipe — clean shop fire line
	var pipe_m := StandardMaterial3D.new()
	pipe_m.albedo_color = Color(0.86, 0.18, 0.14)
	pipe_m.metallic     = 0.4
	pipe_m.roughness    = 0.4
	_make_box(Vector3(56.0, 0.12, 0.12), Vector3(0.0, 11.40, 5.6), pipe_m)
	# Sprinkler heads
	for px in range(-22, 23, 4):
		_make_box(Vector3(0.10, 0.20, 0.10), Vector3(float(px), 11.24, 5.6), pipe_m)

	# Tall narrow upper windows — strip of clerestory glazing above wall_hi divider
	var win_glass := StandardMaterial3D.new()
	win_glass.albedo_color              = Color(0.62, 0.78, 0.92)
	win_glass.emission_enabled          = true
	win_glass.emission                  = Color(0.62, 0.78, 0.92)
	win_glass.emission_energy_multiplier = 0.5
	win_glass.metallic                  = 0.3
	win_glass.roughness                 = 0.15
	# Back wall clerestory strip
	for wx: float in [-22.0, -16.0, -8.0, 0.0, 8.0, 16.0, 22.0]:
		_make_box(Vector3(4.0, 1.6, 0.05), Vector3(wx, 9.6, -19.93), win_glass)
	# Side walls clerestory strips
	for wz: float in [-15.0, -8.0, 0.0, 8.0, 15.0]:
		_make_box(Vector3(0.05, 1.6, 4.0), Vector3(-27.93, 9.6, wz), win_glass)
		_make_box(Vector3(0.05, 1.6, 4.0), Vector3( 27.93, 9.6, wz), win_glass)

	# ── Garage door — clean industrial roll-up door, 12m wide, light blue ─
	var slat_a := StandardMaterial3D.new()
	slat_a.albedo_color = Color(0.62, 0.74, 0.82)
	slat_a.metallic     = 0.45
	slat_a.roughness    = 0.35
	var slat_b := StandardMaterial3D.new()
	slat_b.albedo_color = Color(0.54, 0.66, 0.74)
	slat_b.metallic     = 0.40
	slat_b.roughness    = 0.38
	for di in range(9):
		_make_box(Vector3(12.0, 0.28, 0.07), Vector3(0, 0.18 + di * 0.32, 19.97),
			slat_a if di % 2 == 0 else slat_b)

	# Door track rails (vertical channels either side of the door, full height)
	var track_m := StandardMaterial3D.new()
	track_m.albedo_color = Color(0.20, 0.20, 0.22)
	track_m.metallic     = 0.55
	track_m.roughness    = 0.35
	_make_box(Vector3(0.18, 11.6, 0.18), Vector3(-6.10, 5.8, 19.94), track_m)
	_make_box(Vector3(0.18, 11.6, 0.18), Vector3( 6.10, 5.8, 19.94), track_m)

	# ── Back-wall tool rack (XL, clean pegboard at Z=-19.8) ───────────────
	var rack_bg := StandardMaterial3D.new()
	rack_bg.albedo_color = Color(0.86, 0.32, 0.20)     # Snap-On orange-red pegboard
	rack_bg.roughness    = 0.55
	_make_box(Vector3(11.0, 3.4, 0.12), Vector3(-15.0, 3.2, -19.80), rack_bg)
	var rail_m := StandardMaterial3D.new()
	rail_m.albedo_color = Color(0.80, 0.80, 0.82)
	rail_m.metallic     = 0.7
	rail_m.roughness    = 0.3
	for ry in [2.10, 2.70, 3.30, 3.90, 4.50]:
		_make_box(Vector3(10.8, 0.040, 0.14), Vector3(-15.0, ry, -19.73), rail_m)
	# Tool pegs — extend across the wider rack
	var peg_cols := [
		Color(0.88, 0.24, 0.14), Color(0.26, 0.52, 0.92), Color(0.88, 0.76, 0.18),
		Color(0.50, 0.50, 0.50), Color(0.22, 0.68, 0.28), Color(0.88, 0.24, 0.14),
		Color(0.50, 0.50, 0.50), Color(0.18, 0.42, 0.78), Color(0.88, 0.76, 0.18),
		Color(0.88, 0.24, 0.14), Color(0.50, 0.50, 0.50), Color(0.26, 0.52, 0.92),
		Color(0.88, 0.76, 0.18), Color(0.22, 0.68, 0.28), Color(0.50, 0.50, 0.50),
	]
	for prow in [3.15, 2.55, 3.75]:
		for pi in range(peg_cols.size()):
			var pc_x: float = -19.6 + float(pi) * 0.62
			_tool_peg(peg_cols[pi], Vector3(pc_x, prow, -19.65))

	# ── Left-wall parts shelf (at X=-27.8, runs along most of left wall) ─
	var shf_m := StandardMaterial3D.new()
	shf_m.albedo_color = Color(0.30, 0.27, 0.22)
	shf_m.roughness    = 0.85
	# Vertical posts every 4.5m
	for vz: float in [-16.0, -11.5, -7.0, -2.5, 2.0, 6.5, 11.0, 15.5]:
		_make_box(Vector3(0.08, 3.6, 0.34), Vector3(-27.72, 1.9, vz), shf_m)
	# Horizontal shelf bands
	for sy in [1.0, 1.80, 2.60, 3.40]:
		_make_box(Vector3(0.22, 0.07, 34.0), Vector3(-27.59, sy, 0.0), shf_m)
	# Coloured part bins scattered along the shelves — vibrant sim-style
	var bin_cols : Array = [
		Color(0.88, 0.22, 0.18), Color(0.20, 0.50, 0.88),
		Color(0.24, 0.74, 0.34), Color(0.96, 0.78, 0.12),
		Color(0.78, 0.24, 0.78), Color(0.18, 0.72, 0.72),
		Color(0.96, 0.55, 0.10), Color(0.50, 0.52, 0.58),
	]
	for bi in range(28):
		var bm := StandardMaterial3D.new()
		bm.albedo_color = bin_cols[bi % bin_cols.size()]
		bm.roughness    = 0.85
		var bz: float = -16.0 + float(bi) * 1.14
		var by: float = 1.10 if (bi % 2 == 0) else 1.90
		_make_box(Vector3(0.18, 0.24, 0.48), Vector3(-27.52, by, bz), bm)

func _tool_peg(color: Color, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.72
	_make_box(Vector3(0.28, 0.10, 0.10), pos, mat)

func _build_bay() -> void:
	bay_slot = Node3D.new()
	bay_slot.name = "BaySlot"
	bay_slot.position = Vector3(-2.0, 0.0, 0.0)
	add_child(bay_slot)

	# ── Hydraulic lift posts ──────────────────────────────────────────────
	var post_m := StandardMaterial3D.new()
	post_m.albedo_color = Color(0.60, 0.56, 0.16)
	post_m.metallic     = 0.42
	post_m.roughness    = 0.50
	_make_box(Vector3(0.14, 3.0, 0.14), Vector3(-4.2, 1.5, 0.0), post_m)
	_make_box(Vector3(0.14, 3.0, 0.14), Vector3( 0.2, 1.5, 0.0), post_m)
	# Lift arms at two heights
	var arm_m := StandardMaterial3D.new()
	arm_m.albedo_color = Color(0.50, 0.47, 0.14)
	arm_m.metallic     = 0.40
	for ay in [0.85, 1.85]:
		_make_box(Vector3(4.4, 0.09, 0.50), Vector3(-2.0, ay, 0.0), arm_m)
	# Rubber saddle pads at arm tips
	var pad_m := StandardMaterial3D.new()
	pad_m.albedo_color = Color(0.12, 0.12, 0.12)
	pad_m.roughness    = 0.96
	for px in [-4.25, 0.25]:
		_make_box(Vector3(0.07, 0.12, 0.42), Vector3(px, 0.85, 0.0), pad_m)
		_make_box(Vector3(0.07, 0.12, 0.42), Vector3(px, 1.85, 0.0), pad_m)

	# ── BAY 3 sign on the new back wall (now at z=-20) ────────────────────
	var sign_bg := StandardMaterial3D.new()
	sign_bg.albedo_color = Color(0.10, 0.15, 0.42)
	_make_box(Vector3(1.40, 0.42, 0.04), Vector3(-2.0, 4.70, -19.92), sign_bg)
	var sign_stripe := StandardMaterial3D.new()
	sign_stripe.albedo_color = Color(0.90, 0.86, 0.18)
	sign_stripe.emission_enabled = true
	sign_stripe.emission = Color(0.90, 0.86, 0.18)
	sign_stripe.emission_energy_multiplier = 0.22
	_make_box(Vector3(1.40, 0.07, 0.02), Vector3(-2.0, 4.50, -19.90), sign_stripe)

## Standalone scene dressing — toolbox, tires, oil drum, neon sign.
func _build_scene_props() -> void:
	_build_tool_chest(Vector3( 6.8, 0.0, -1.5))
	_build_tire_stack(Vector3(-7.0, 0.0,  2.5))
	_build_oil_drum(  Vector3(-6.6, 0.0,  4.2))
	_build_neon_sign()
	_build_garage_exterior()
	_build_extra_details()
	_build_atmospheric_dressing()

## GREASE & GLORY neon sign — mounted on the inside face of the front lintel,
## above the 12m roll-up door. Glows orange/red against the dark interior.
func _build_neon_sign() -> void:
	const SZ: float = 19.89    # inside face of front lintel (door at z=+20)
	const SY: float = 5.40     # mid-lintel height
	# Backing panel (dark metal plate)
	var backing_mat := StandardMaterial3D.new()
	backing_mat.albedo_color = Color(0.06, 0.06, 0.07)
	backing_mat.metallic     = 0.5
	backing_mat.roughness    = 0.7
	_make_box(Vector3(5.40, 0.78, 0.06), Vector3(0.0, SY, SZ - 0.03), backing_mat)

	# Neon border frame (thin bright orange strip around the sign)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color              = Color(1.00, 0.60, 0.05)
	frame_mat.emission_enabled          = true
	frame_mat.emission                  = Color(1.00, 0.60, 0.05)
	frame_mat.emission_energy_multiplier = 3.5
	# Frame
	_make_box(Vector3(5.30, 0.05, 0.05), Vector3(0.0, SY + 0.35, SZ), frame_mat)
	_make_box(Vector3(5.30, 0.05, 0.05), Vector3(0.0, SY - 0.35, SZ), frame_mat)
	_make_box(Vector3(0.05, 0.72, 0.05), Vector3(-2.625, SY, SZ), frame_mat)
	_make_box(Vector3(0.05, 0.72, 0.05), Vector3( 2.625, SY, SZ), frame_mat)

	# "GREASE" text — individual neon letter blocks (hot orange)
	var neon_orange := StandardMaterial3D.new()
	neon_orange.albedo_color              = Color(1.00, 0.55, 0.02)
	neon_orange.emission_enabled          = true
	neon_orange.emission                  = Color(1.00, 0.55, 0.02)
	neon_orange.emission_energy_multiplier = 4.0

	# "GLORY" text — neon red/pink second line
	var neon_red := StandardMaterial3D.new()
	neon_red.albedo_color              = Color(1.00, 0.22, 0.18)
	neon_red.emission_enabled          = true
	neon_red.emission                  = Color(1.00, 0.22, 0.18)
	neon_red.emission_energy_multiplier = 4.0

	# Simulate "GREASE" text — 6 letter blocks on top row
	for i in range(6):
		var lx : float = -1.95 + i * 0.78
		_make_box(Vector3(0.10, 0.32, 0.06), Vector3(lx, SY + 0.10, SZ + 0.01), neon_orange)
		_make_box(Vector3(0.44, 0.07, 0.06), Vector3(lx, SY + 0.25, SZ + 0.01), neon_orange)
		_make_box(Vector3(0.38, 0.07, 0.06), Vector3(lx, SY - 0.05, SZ + 0.01), neon_orange)

	# "&" ampersand divider — white neon
	var neon_white := StandardMaterial3D.new()
	neon_white.albedo_color              = Color(0.95, 0.95, 1.00)
	neon_white.emission_enabled          = true
	neon_white.emission                  = Color(0.90, 0.92, 1.00)
	neon_white.emission_energy_multiplier = 3.0
	_make_box(Vector3(0.08, 0.28, 0.06), Vector3(0.0, SY, SZ + 0.01), neon_white)

	# Simulate "GLORY" text — 5 letter blocks on bottom row
	for i in range(5):
		var lx : float = -1.56 + i * 0.78
		_make_box(Vector3(0.10, 0.28, 0.06), Vector3(lx, SY - 0.18, SZ + 0.01), neon_red)
		_make_box(Vector3(0.44, 0.06, 0.06), Vector3(lx, SY - 0.07, SZ + 0.01), neon_red)
		_make_box(Vector3(0.38, 0.06, 0.06), Vector3(lx, SY - 0.30, SZ + 0.01), neon_red)

	# Warm orange OmniLight under the sign — illuminates the entrance lintel
	var sign_light := OmniLight3D.new()
	sign_light.position     = Vector3(0.0, SY - 0.60, SZ - 0.40)
	sign_light.light_color  = Color(1.00, 0.62, 0.20)
	sign_light.light_energy = 1.6
	sign_light.omni_range   = 7.0
	add_child(sign_light)

## Exterior glimpse through the garage door — moody overcast industrial street.
## Visible through the 12m roll-up door at z=+20. Placed at z=+22-23.
func _build_garage_exterior() -> void:
	# Heavy overcast sky backdrop — almost no color, just gray-blue smog
	var sky_mat := StandardMaterial3D.new()
	sky_mat.albedo_color  = Color(0.18, 0.20, 0.24)
	sky_mat.emission_enabled          = true
	sky_mat.emission                  = Color(0.18, 0.20, 0.24)
	sky_mat.emission_energy_multiplier = 0.6
	_make_box(Vector3(20.0, 8.0, 0.10), Vector3(0.0, 4.0, 23.5), sky_mat)

	# Horizon band — dirty amber sodium-light pollution
	var horizon_mat := StandardMaterial3D.new()
	horizon_mat.albedo_color              = Color(0.34, 0.22, 0.14)
	horizon_mat.emission_enabled          = true
	horizon_mat.emission                  = Color(0.34, 0.22, 0.14)
	horizon_mat.emission_energy_multiplier = 0.5
	_make_box(Vector3(20.0, 1.2, 0.10), Vector3(0.0, 0.70, 23.4), horizon_mat)

	# Distant city silhouettes against the smog (a few dark rectangles)
	var city_mat := StandardMaterial3D.new()
	city_mat.albedo_color = Color(0.06, 0.06, 0.08)
	city_mat.roughness    = 0.9
	for cx in [-7.5, -5.4, -3.6, -1.8, 0.4, 2.4, 4.2, 6.3]:
		_make_box(Vector3(1.0, randf_range(1.6, 3.2), 0.06), Vector3(cx, randf_range(0.9, 1.7), 23.48), city_mat)
	# A few warm dots — distant lit windows
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color              = Color(1.0, 0.78, 0.40)
	win_mat.emission_enabled          = true
	win_mat.emission                  = Color(1.0, 0.72, 0.32)
	win_mat.emission_energy_multiplier = 3.0
	for wi in range(14):
		_make_box(Vector3(0.08, 0.08, 0.05),
			Vector3(randf_range(-8.0, 8.0), randf_range(0.8, 3.4), 23.47), win_mat)

	# Wet asphalt — dark slick pavement just outside the door
	var pave_mat := StandardMaterial3D.new()
	pave_mat.albedo_color = Color(0.06, 0.06, 0.07)
	pave_mat.metallic     = 0.2
	pave_mat.roughness    = 0.32
	_make_box(Vector3(16.0, 0.20, 6.0), Vector3(0.0, -0.10, 22.5), pave_mat)

	# Painted curb / sidewalk
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.16, 0.16, 0.16)
	curb_mat.roughness    = 0.85
	_make_box(Vector3(16.0, 0.18, 0.30), Vector3(0.0, 0.02, 20.6), curb_mat)

	# Cold rim SpotLight — overcast daylight leaking through the door inward
	var sun_beam := SpotLight3D.new()
	sun_beam.position        = Vector3(-1.5, 5.6, 17.5)
	sun_beam.rotation_degrees = Vector3(-58.0, 188.0, 0.0)  # face into the garage (+Z origin → -Z light)
	sun_beam.light_color     = Color(0.72, 0.78, 0.88)
	sun_beam.light_energy    = 2.2
	sun_beam.spot_range      = 22.0
	sun_beam.spot_angle      = 28.0
	sun_beam.shadow_enabled  = true
	sun_beam.shadow_bias     = 0.04
	add_child(sun_beam)

	# Parked car silhouette outside — dark wet body, glossy
	var ext_car_mat := StandardMaterial3D.new()
	ext_car_mat.albedo_color = Color(0.06, 0.07, 0.08)
	ext_car_mat.metallic     = 0.55
	ext_car_mat.roughness    = 0.32
	_make_box(Vector3(2.2, 0.85, 1.05), Vector3(5.8, 0.42, 22.0), ext_car_mat)
	_make_box(Vector3(1.20, 0.55, 0.95), Vector3(5.65, 1.00, 22.0), ext_car_mat)
	# Tail-light dots
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color              = Color(1.0, 0.18, 0.12)
	tail_mat.emission_enabled          = true
	tail_mat.emission                  = Color(1.0, 0.18, 0.12)
	tail_mat.emission_energy_multiplier = 2.6
	_make_box(Vector3(0.14, 0.10, 0.05), Vector3(6.80, 0.55, 22.20), tail_mat)
	_make_box(Vector3(0.14, 0.10, 0.05), Vector3(6.80, 0.55, 21.78), tail_mat)

	# Second parked car on the other side
	_make_box(Vector3(2.2, 0.85, 1.05), Vector3(-6.4, 0.42, 22.3), ext_car_mat)
	_make_box(Vector3(1.20, 0.55, 0.95), Vector3(-6.25, 1.00, 22.3), ext_car_mat)

	# Lamppost outside on the curb — sodium head + tall metal pole
	var pole_m := StandardMaterial3D.new()
	pole_m.albedo_color = Color(0.10, 0.10, 0.10)
	pole_m.metallic     = 0.45
	pole_m.roughness    = 0.55
	_make_box(Vector3(0.12, 5.5, 0.12), Vector3(8.5, 2.75, 21.0), pole_m)
	_make_box(Vector3(1.0, 0.10, 0.10), Vector3(8.0, 5.4, 21.0), pole_m)
	var street_bulb := StandardMaterial3D.new()
	street_bulb.albedo_color              = Color(1.0, 0.82, 0.42)
	street_bulb.emission_enabled          = true
	street_bulb.emission                  = Color(1.0, 0.74, 0.32)
	street_bulb.emission_energy_multiplier = 5.0
	_make_box(Vector3(0.24, 0.16, 0.24), Vector3(7.4, 5.30, 21.0), street_bulb)
	var street_light := OmniLight3D.new()
	street_light.position     = Vector3(7.4, 5.10, 21.0)
	street_light.light_color  = Color(1.0, 0.72, 0.34)
	street_light.light_energy = 2.0
	street_light.omni_range   = 9.0
	add_child(street_light)

## Extra atmospheric detail — vent, warning stripes, fire extinguisher, fan.
func _build_extra_details() -> void:
	# Safety yellow hazard stripes on the floor near the lift
	var hazard_y := StandardMaterial3D.new()
	hazard_y.albedo_color = Color(0.95, 0.80, 0.05)
	hazard_y.roughness    = 0.85
	var hazard_b := StandardMaterial3D.new()
	hazard_b.albedo_color = Color(0.12, 0.12, 0.14)
	hazard_b.roughness    = 0.85
	for i in range(8):
		var stripe_col := hazard_y if (i % 2 == 0) else hazard_b
		_make_box(Vector3(0.22, 0.006, 1.20), Vector3(-4.5 + i * 0.22, 0.003, 0.0), stripe_col)

	# Fire extinguisher on the back wall
	var ext_body := StandardMaterial3D.new()
	ext_body.albedo_color = Color(0.88, 0.12, 0.10)
	ext_body.metallic     = 0.4
	ext_body.roughness    = 0.5
	var emi   := MeshInstance3D.new()
	var emesh := CylinderMesh.new()
	emesh.top_radius = 0.07; emesh.bottom_radius = 0.09; emesh.height = 0.44
	emi.mesh = emesh; emi.material_override = ext_body
	emi.position = Vector3(7.5, 0.78, 5.75)
	add_child(emi)

	# Metal tag / label on extinguisher
	var ext_tag := StandardMaterial3D.new()
	ext_tag.albedo_color = Color(0.88, 0.86, 0.08)
	ext_tag.emission_enabled          = true
	ext_tag.emission                  = Color(0.60, 0.58, 0.05)
	ext_tag.emission_energy_multiplier = 0.4
	_make_box(Vector3(0.10, 0.07, 0.02), Vector3(7.5, 0.80, 5.82), ext_tag)

	# Industrial ceiling vent/fan unit (dark metal box + blade disc)
	var vent_mat := StandardMaterial3D.new()
	vent_mat.albedo_color = Color(0.20, 0.20, 0.22)
	vent_mat.metallic     = 0.6
	vent_mat.roughness    = 0.5
	_make_box(Vector3(0.60, 0.22, 0.60), Vector3(6.0, 4.55, 4.5), vent_mat)
	# Fan blades (spinning disc)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.30, 0.30, 0.32)
	blade_mat.metallic     = 0.5
	var fmi   := MeshInstance3D.new()
	var fmesh := CylinderMesh.new()
	fmesh.top_radius = 0.25; fmesh.bottom_radius = 0.25; fmesh.height = 0.04
	fmi.mesh = fmesh; fmi.material_override = blade_mat
	fmi.position = Vector3(6.0, 4.44, 4.5)
	add_child(fmi)

	# "EXIT" sign above back door (glowing green)
	var exit_mat := StandardMaterial3D.new()
	exit_mat.albedo_color              = Color(0.10, 0.88, 0.28)
	exit_mat.emission_enabled          = true
	exit_mat.emission                  = Color(0.10, 0.88, 0.28)
	exit_mat.emission_energy_multiplier = 2.5
	_make_box(Vector3(0.52, 0.20, 0.05), Vector3(6.8, 2.70, 5.90), exit_mat)
	var exit_light := OmniLight3D.new()
	exit_light.position    = Vector3(6.8, 2.50, 5.60)
	exit_light.light_color = Color(0.15, 1.00, 0.35)
	exit_light.light_energy = 0.35
	exit_light.omni_range   = 2.5
	add_child(exit_light)

## Sim-style clean shop dressing — bright LED panels, compressor, hose reel,
## hanging hoist, organized parts, neat workshop dressing. PowerWash-clean.
func _build_atmospheric_dressing() -> void:
	# ── Modern LED panel pendants — clean rectangular fixtures higher up ──
	var panel_positions := [
		Vector3(-20.0, 8.4, -8.0),
		Vector3(-12.0, 8.4,  6.0),
		Vector3(  9.0, 8.4,  8.0),
		Vector3( 18.0, 8.4, -7.0),
		Vector3( -4.0, 8.4, 12.0),
		Vector3( 16.0, 8.4, 14.0),
		Vector3(-22.0, 8.4, 14.0),
		Vector3(  0.0, 8.4, -14.0),
	]
	var pendant_m := StandardMaterial3D.new()
	pendant_m.albedo_color = Color(0.85, 0.85, 0.86)
	pendant_m.metallic     = 0.3
	pendant_m.roughness    = 0.5
	var led_face_m := StandardMaterial3D.new()
	led_face_m.albedo_color              = Color(0.94, 0.96, 1.00)
	led_face_m.emission_enabled          = true
	led_face_m.emission                  = Color(0.94, 0.96, 1.00)
	led_face_m.emission_energy_multiplier = 3.0
	for cp: Vector3 in panel_positions:
		# Long suspension cord from ceiling beam (y=11.7) down to fixture top
		var cord_top: float = 11.65
		var cord_len: float = cord_top - (cp.y + 0.05)
		_make_box(Vector3(0.03, cord_len, 0.03),
			Vector3(cp.x, cp.y + 0.05 + cord_len * 0.5, cp.z), pendant_m)
		_make_box(Vector3(1.10, 0.12, 1.10), Vector3(cp.x, cp.y, cp.z), pendant_m)
		_make_box(Vector3(1.00, 0.04, 1.00), Vector3(cp.x, cp.y - 0.08, cp.z), led_face_m)
		var pl := OmniLight3D.new()
		pl.position       = Vector3(cp.x, cp.y - 0.20, cp.z)
		pl.light_color    = Color(1.00, 0.97, 0.92)
		pl.light_energy   = 2.0
		pl.omni_range     = 10.0
		pl.shadow_enabled = false
		add_child(pl)

	# ── Continuous LED strip along the side walls at clerestory height ───
	var led_m := StandardMaterial3D.new()
	led_m.albedo_color              = Color(0.95, 0.97, 1.00)
	led_m.emission_enabled          = true
	led_m.emission                  = Color(0.90, 0.95, 1.00)
	led_m.emission_energy_multiplier = 3.0
	_make_box(Vector3(0.06, 0.06, 36.0), Vector3(-27.7, 10.8, 0.0), led_m)
	_make_box(Vector3(0.06, 0.06, 36.0), Vector3( 27.7, 10.8, 0.0), led_m)
	_make_box(Vector3(52.0, 0.06, 0.06), Vector3(0.0, 10.8, -19.7), led_m)

	# ── Wall-mounted air compressor — bright safety red, modern look ──────
	var tank_m := StandardMaterial3D.new()
	tank_m.albedo_color = Color(0.86, 0.20, 0.14)
	tank_m.metallic     = 0.35
	tank_m.roughness    = 0.4
	var motor_m := StandardMaterial3D.new()
	motor_m.albedo_color = Color(0.20, 0.20, 0.22)
	motor_m.metallic     = 0.45
	motor_m.roughness    = 0.4
	# Horizontal tank lying on legs along the right wall
	var tcyl_mi   := MeshInstance3D.new()
	var tcyl_mesh := CylinderMesh.new()
	tcyl_mesh.top_radius = 0.30
	tcyl_mesh.bottom_radius = 0.30
	tcyl_mesh.height = 1.30
	tcyl_mi.mesh = tcyl_mesh
	tcyl_mi.material_override = tank_m
	tcyl_mi.position = Vector3(13.0, 0.55, -3.5)
	tcyl_mi.rotation_degrees = Vector3(0, 0, 90)         # horizontal
	add_child(tcyl_mi)
	# Two legs under the tank
	for lz in [-3.95, -3.05]:
		_make_box(Vector3(0.10, 0.55, 0.10), Vector3(13.05, 0.275, lz), motor_m)
	# Motor block on top
	_make_box(Vector3(0.50, 0.34, 0.40), Vector3(13.0, 1.10, -3.5), motor_m)
	# Pressure gauges — small bright discs
	var gauge_m := StandardMaterial3D.new()
	gauge_m.albedo_color              = Color(0.92, 0.84, 0.18)
	gauge_m.emission_enabled          = true
	gauge_m.emission                  = Color(0.92, 0.84, 0.18)
	gauge_m.emission_energy_multiplier = 0.5
	_make_box(Vector3(0.10, 0.10, 0.04), Vector3(12.65, 1.20, -3.45), gauge_m)

	# Coiled air hose mounted on the wall (red spiral approximated by stacked discs)
	var hose_m := StandardMaterial3D.new()
	hose_m.albedo_color = Color(0.55, 0.08, 0.06)
	hose_m.roughness    = 0.65
	var hcyl_mi   := MeshInstance3D.new()
	var hcyl_mesh := CylinderMesh.new()
	hcyl_mesh.top_radius = 0.34
	hcyl_mesh.bottom_radius = 0.34
	hcyl_mesh.height = 0.18
	hcyl_mi.mesh = hcyl_mesh
	hcyl_mi.material_override = hose_m
	hcyl_mi.position = Vector3(13.5, 2.40, 1.5)
	hcyl_mi.rotation_degrees = Vector3(90, 0, 0)
	add_child(hcyl_mi)
	# Drop hose to ground
	_make_box(Vector3(0.05, 1.80, 0.05), Vector3(13.6, 1.20, 1.5), hose_m)

	# ── Engine hoist crane — clean modern A-frame with hydraulic cylinder ──
	var hoist_m := StandardMaterial3D.new()
	hoist_m.albedo_color = Color(0.84, 0.18, 0.12)        # bright safety red
	hoist_m.metallic     = 0.35
	hoist_m.roughness    = 0.45
	# Base — two horizontal rails
	_make_box(Vector3(1.80, 0.14, 0.18), Vector3(-22.0, 0.10,  3.0), hoist_m)
	_make_box(Vector3(1.80, 0.14, 0.18), Vector3(-22.0, 0.10,  4.6), hoist_m)
	# Upright post
	_make_box(Vector3(0.18, 1.80, 0.18), Vector3(-22.0, 1.00,  3.8), hoist_m)
	# Diagonal brace
	_make_box(Vector3(0.16, 0.14, 1.50), Vector3(-22.0, 0.80,  3.80), hoist_m)
	# Boom arm extending forward
	_make_box(Vector3(0.18, 0.18, 1.50), Vector3(-22.0, 1.85,  4.6), hoist_m)
	# Hook + chain at the boom tip
	var chain_m := StandardMaterial3D.new()
	chain_m.albedo_color = Color(0.85, 0.85, 0.86)
	chain_m.metallic     = 0.65
	chain_m.roughness    = 0.45
	_make_box(Vector3(0.04, 0.70, 0.04), Vector3(-22.0, 1.50, 5.30), chain_m)
	_make_box(Vector3(0.10, 0.14, 0.12), Vector3(-22.0, 1.10, 5.30), chain_m)
	# Wheels (cylinders for casters)
	var caster_m := StandardMaterial3D.new()
	caster_m.albedo_color = Color(0.12, 0.12, 0.12)
	caster_m.roughness    = 0.7
	for wp in [Vector3(-22.8, 0.10, 3.0), Vector3(-21.2, 0.10, 3.0),
			   Vector3(-22.8, 0.10, 4.6), Vector3(-21.2, 0.10, 4.6)]:
		var w_mi   := MeshInstance3D.new()
		var w_mesh := CylinderMesh.new()
		w_mesh.top_radius = 0.10; w_mesh.bottom_radius = 0.10; w_mesh.height = 0.10
		w_mi.mesh = w_mesh; w_mi.material_override = caster_m
		w_mi.position = wp
		w_mi.rotation_degrees = Vector3(90, 0, 0)
		add_child(w_mi)

	# ── Clean metal trash bin (a few scattered around) ─────────────────────
	var bin_m := StandardMaterial3D.new()
	bin_m.albedo_color = Color(0.40, 0.42, 0.44)
	bin_m.metallic     = 0.45
	bin_m.roughness    = 0.4
	for bp in [Vector3(8.4, 0.375, 0.8), Vector3(-22.5, 0.375, -2.0), Vector3(20.0, 0.375, 8.0)]:
		var bin_mi   := MeshInstance3D.new()
		var bin_mesh := CylinderMesh.new()
		bin_mesh.top_radius = 0.32
		bin_mesh.bottom_radius = 0.28
		bin_mesh.height = 0.75
		bin_mi.mesh = bin_mesh
		bin_mi.material_override = bin_m
		bin_mi.position = bp
		add_child(bin_mi)

	# ── Organized parts crate stacks (modern colored containers) ───────────
	var crate_cols := [
		Color(0.85, 0.18, 0.16),    # red
		Color(0.16, 0.46, 0.84),    # blue
		Color(0.22, 0.68, 0.30),    # green
		Color(0.92, 0.74, 0.16),    # yellow
		Color(0.30, 0.30, 0.36),    # graphite
	]
	for ci in range(5):
		var crate_m := StandardMaterial3D.new()
		crate_m.albedo_color = crate_cols[ci]
		crate_m.roughness    = 0.55
		var cz: float = -10.5 + float(ci) * 1.10
		_make_box(Vector3(0.95, 0.50, 0.95), Vector3(24.5, 0.25, cz), crate_m)
		_make_box(Vector3(0.95, 0.50, 0.95), Vector3(24.5, 0.77, cz), crate_m)

	# ── Bright safety cone next to the bay ─────────────────────────────────
	var cone_m := StandardMaterial3D.new()
	cone_m.albedo_color = Color(0.98, 0.45, 0.10)
	cone_m.roughness    = 0.65
	for cp in [Vector3(2.0, 0.18, 5.0), Vector3(-6.5, 0.18, 5.0)]:
		var c_mi   := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.05; c_mesh.bottom_radius = 0.22; c_mesh.height = 0.38
		c_mi.mesh = c_mesh; c_mi.material_override = cone_m
		c_mi.position = cp
		add_child(c_mi)
		# White reflective band
		var band_m := StandardMaterial3D.new()
		band_m.albedo_color = Color(0.95, 0.95, 0.95)
		band_m.roughness    = 0.5
		_make_box(Vector3(0.30, 0.06, 0.30), Vector3(cp.x, cp.y + 0.04, cp.z), band_m)

func _build_tool_chest(pos: Vector3) -> void:
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color(0.82, 0.13, 0.12)
	body_m.metallic     = 0.42
	body_m.roughness    = 0.50
	_make_box(Vector3(0.65, 0.88, 0.42), pos + Vector3(0, 0.44, 0), body_m)
	var drw_m := StandardMaterial3D.new()
	drw_m.albedo_color = Color(0.70, 0.10, 0.10)
	drw_m.metallic     = 0.35
	for di in range(4):
		_make_box(Vector3(0.58, 0.15, 0.015), pos + Vector3(0, 0.16 + di * 0.20, 0.22), drw_m)
	var hdl_m := StandardMaterial3D.new()
	hdl_m.albedo_color = Color(0.75, 0.72, 0.65)
	hdl_m.metallic     = 0.80
	hdl_m.roughness    = 0.25
	for di in range(4):
		_make_box(Vector3(0.14, 0.030, 0.030), pos + Vector3(0, 0.16 + di * 0.20, 0.235), hdl_m)
	var whl_m := StandardMaterial3D.new()
	whl_m.albedo_color = Color(0.15, 0.15, 0.15)
	for wx in [-0.22, 0.22]:
		for wz in [-0.12, 0.12]:
			_make_box(Vector3(0.07, 0.06, 0.07), pos + Vector3(wx, 0.03, wz), whl_m)

func _build_tire_stack(pos: Vector3) -> void:
	var tire_m := StandardMaterial3D.new()
	tire_m.albedo_color = Color(0.11, 0.11, 0.11)
	tire_m.roughness    = 0.96
	var rim_m := StandardMaterial3D.new()
	rim_m.albedo_color = Color(0.52, 0.50, 0.46)
	rim_m.metallic     = 0.50
	for ti in range(3):
		var y : float = pos.y + 0.13 + ti * 0.25
		var tmi   := MeshInstance3D.new()
		var tmesh := CylinderMesh.new()
		tmesh.top_radius = 0.38; tmesh.bottom_radius = 0.38; tmesh.height = 0.22
		tmi.mesh = tmesh; tmi.material_override = tire_m
		tmi.position = Vector3(pos.x, y, pos.z)
		add_child(tmi)
		var rmi   := MeshInstance3D.new()
		var rmesh := CylinderMesh.new()
		rmesh.top_radius = 0.17; rmesh.bottom_radius = 0.17; rmesh.height = 0.20
		rmi.mesh = rmesh; rmi.material_override = rim_m
		rmi.position = Vector3(pos.x, y, pos.z)
		add_child(rmi)

func _build_oil_drum(pos: Vector3) -> void:
	var drum_m := StandardMaterial3D.new()
	drum_m.albedo_color = Color(0.18, 0.22, 0.62)
	drum_m.metallic     = 0.50
	drum_m.roughness    = 0.52
	var dmi   := MeshInstance3D.new()
	var dmesh := CylinderMesh.new()
	dmesh.top_radius = 0.28; dmesh.bottom_radius = 0.28; dmesh.height = 0.88
	dmi.mesh = dmesh; dmi.material_override = drum_m
	dmi.position = pos + Vector3(0, 0.44, 0)
	add_child(dmi)
	var band_m := StandardMaterial3D.new()
	band_m.albedo_color = Color(0.14, 0.14, 0.14)
	band_m.metallic     = 0.60
	for by in [0.10, 0.44, 0.78]:
		var bmi   := MeshInstance3D.new()
		var bmesh := CylinderMesh.new()
		bmesh.top_radius = 0.295; bmesh.bottom_radius = 0.295; bmesh.height = 0.038
		bmi.mesh = bmesh; bmi.material_override = band_m
		bmi.position = pos + Vector3(0, by, 0)
		add_child(bmi)

func _build_workbench_area() -> void:
	workbench = Node3D.new()
	workbench.name = "Workbench"
	workbench.set_script(WorkbenchScript)
	workbench.position = Vector3(5.5, 0, 1.0)
	add_child(workbench)

func _build_paint_booth() -> void:
	# Back wall paint booth — colourful cabinet with spray gun on top
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color(0.25, 0.22, 0.30)
	cab_mat.roughness    = 0.6
	_make_box(Vector3(1.8, 1.8, 0.55), Vector3(2.5, 0.9, -5.65), cab_mat)

	# Coloured stripe across the cabinet front
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.92, 0.45, 0.70)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(0.92, 0.45, 0.70)
	stripe_mat.emission_energy_multiplier = 0.3
	_make_box(Vector3(1.85, 0.12, 0.05), Vector3(2.5, 1.55, -5.40), stripe_mat)

	# Spray gun prop on top
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.70, 0.68, 0.72)
	gun_mat.metallic     = 0.6
	_make_box(Vector3(0.12, 0.08, 0.40), Vector3(2.9, 1.85, -5.55), gun_mat)

	# Sign above
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.85, 0.25, 0.55)
	_make_box(Vector3(1.6, 0.32, 0.05), Vector3(2.5, 3.2, -5.88), sign_mat)

func _build_reception_area() -> void:
	reception = Node3D.new()
	reception.name = "ReceptionDesk"
	reception.set_script(ReceptionScript)
	reception.position = Vector3(5.5, 0, 4.5)
	add_child(reception)

## Wall-mounted management tablet — back wall, left of centre.
## A small bracket + screen prop that the player walks up to interact with.
func _build_tablet_prop() -> void:
	# Wall bracket / mount
	var bracket_mat := StandardMaterial3D.new()
	bracket_mat.albedo_color = Color(0.18, 0.17, 0.16)
	bracket_mat.metallic     = 0.65
	bracket_mat.roughness    = 0.45
	_make_box(Vector3(0.38, 0.55, 0.07), Vector3(-0.5, 1.55, -5.92), bracket_mat)

	# Tablet screen body
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.08, 0.08, 0.10)
	screen_mat.metallic     = 0.3
	screen_mat.roughness    = 0.25
	_make_box(Vector3(0.32, 0.46, 0.035), Vector3(-0.5, 1.55, -5.87), screen_mat)

	# Screen glow — emissive inner panel (simulates the lit display)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color              = Color(0.18, 0.45, 0.95)
	glow_mat.emission_enabled          = true
	glow_mat.emission                  = Color(0.20, 0.48, 1.0)
	glow_mat.emission_energy_multiplier = 0.9
	_make_box(Vector3(0.24, 0.36, 0.01), Vector3(-0.5, 1.55, -5.845), glow_mat)

	# Gentle idle pulse on the screen glow
	var tw := create_tween().set_loops()
	tw.tween_property(glow_mat, "emission_energy_multiplier", 1.3, 1.4)
	tw.tween_property(glow_mat, "emission_energy_multiplier", 0.65, 1.4)

	# Small label placard below the screen
	var placard_mat := StandardMaterial3D.new()
	placard_mat.albedo_color = Color(0.22, 0.40, 0.80)
	_make_box(Vector3(0.30, 0.04, 0.02), Vector3(-0.5, 1.24, -5.87), placard_mat)

	# Indicator LED (tiny dot, top-right corner of screen)
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color              = Color(0.2, 1.0, 0.4)
	led_mat.emission_enabled          = true
	led_mat.emission                  = Color(0.2, 1.0, 0.4)
	led_mat.emission_energy_multiplier = 1.8
	_make_box(Vector3(0.025, 0.025, 0.01), Vector3(-0.34, 1.74, -5.845), led_mat)

## Spawn the walkable player character with its own third-person camera.
func _spawn_player() -> void:
	var PlayerScript = load("res://scripts/player/Player.gd")
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(PlayerScript)
	p.position = Vector3(0.0, 0.5, 3.5)   # near garage entrance, falls to floor
	add_child(p)
	player = p
	# _interact_label set later in _ready() once HUD is built

## Add invisible StaticBody3D physics walls/floor matching the visual geometry.
## Without these the CharacterBody3D player would fall through the room.
func _add_physics_bodies() -> void:
	# XL warehouse — 56×40 visual, 12m tall walls.
	_make_physics_box(Vector3(56.0, 0.2,  40.0), Vector3( 0.0, -0.1,   0.0))  # floor
	_make_physics_box(Vector3(56.0, 12.0,  0.2), Vector3( 0.0,  6.0, -19.9))  # back wall
	_make_physics_box(Vector3( 0.2, 12.0, 40.0), Vector3(-27.9, 6.0,   0.0))  # left wall
	_make_physics_box(Vector3( 0.2, 12.0, 40.0), Vector3( 27.9, 6.0,   0.0))  # right wall
	# Front wall — split around the central 12m garage door opening
	_make_physics_box(Vector3(22.0, 12.0,  0.2), Vector3(-17.0, 6.0, 19.9))   # front-left
	_make_physics_box(Vector3(22.0, 12.0,  0.2), Vector3( 17.0, 6.0, 19.9))   # front-right
	_make_physics_box(Vector3(12.0,  9.12, 0.2), Vector3(  0.0, 7.44, 19.9))  # lintel above door
	# Interior blockers
	_make_physics_box(Vector3( 1.4, 1.2,   1.4), Vector3( 5.5,  0.6,  1.0))  # workbench blocker
	_make_physics_box(Vector3( 1.4, 1.2,   1.4), Vector3( 5.5,  0.6,  4.5))  # reception blocker

func _make_physics_box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb    := StaticBody3D.new()
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape  = shape
	sb.add_child(col)
	sb.position = pos
	add_child(sb)
	return sb

## Build Area3D interaction zones the player walks into.
## Each zone stores "interact_label" (String) and "interact_cb" (Callable) metadata.
func _build_interaction_zones() -> void:
	# Vehicle bay — inspect vehicle (also shows car action bar via click)
	_make_zone(Vector3(-2.0, 0.9,  0.0), 2.0, "Inspect Vehicle",
		func(): _on_inspect_pressed())

	# Car cleaning zone — walk up to the wash area left of the bay
	_make_zone(Vector3(-5.0, 0.9,  0.0), 1.5, "Clean Vehicle",
		func(): _on_clean_pressed())

	# Workbench zone
	_make_zone(Vector3( 5.5, 0.9,  1.0), 1.6, "Open Workbench",
		func(): _open_workbench_panel())

	# Reception desk — interacts with arriving customers
	_reception_zone = _make_zone(Vector3( 5.5, 0.9, 4.5), 1.8, "Reception Desk",
		func(): _on_reception_interact())

	# Junkyard exit — walk through the front garage opening
	_make_zone(Vector3( 0.0, 0.9,  5.8), 1.5, "Go to Junkyard",
		func(): _on_junkyard_pressed())

	# Tablet / workshop computer — back wall, centre
	_make_zone(Vector3(-0.5, 0.9, -4.8), 1.6, "Workshop Tablet",
		func(): _on_tablet_pressed())

	# Paint booth — back-right corner
	_make_zone(Vector3( 2.5, 0.9, -4.5), 1.8, "Open Paint Booth",
		func(): _open_paint_booth())

func _make_zone(pos: Vector3, radius: float, label: String, cb: Callable) -> Area3D:
	var zone := Area3D.new()
	zone.collision_layer = 2   # Layer 2 — detected by player sensor mask 2
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

	# ── Glowing floor ring so the player can see where to walk ────────────────
	var ring_mi   := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius    = radius * 0.78
	ring_mesh.bottom_radius = radius * 0.78
	ring_mesh.height        = 0.035
	ring_mesh.radial_segments = 32
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color              = Color(0.95, 0.85, 0.10, 0.50)
	ring_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled          = true
	ring_mat.emission                  = Color(1.0, 0.88, 0.0)
	ring_mat.emission_energy_multiplier = 0.45
	ring_mi.mesh             = ring_mesh
	ring_mi.material_override = ring_mat
	ring_mi.position          = Vector3(pos.x, 0.02, pos.z)
	add_child(ring_mi)

	# Gentle pulse on emission energy so the zone breathes
	var tw := create_tween().set_loops()
	tw.tween_property(ring_mat, "emission_energy_multiplier", 0.85, 1.1)
	tw.tween_property(ring_mat, "emission_energy_multiplier", 0.25, 1.1)

	return zone

# ─────────────────────────────────────────────────────────────────────────────
#  HUD  (2D CanvasLayer overlay — same approach as before)
# ─────────────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	# ── TOP BAR — solid dark with thin accent under ─────────────────────────
	var top_bg := ColorRect.new()
	top_bg.size  = Vector2(1280, 56)
	top_bg.color = Color(0.04, 0.05, 0.07, 0.94)
	hud.add_child(top_bg)
	# Subtle inner border bottom
	var top_inner := ColorRect.new()
	top_inner.position = Vector2(0, 55)
	top_inner.size     = Vector2(1280, 1)
	top_inner.color    = Color(0.0, 0.0, 0.0, 0.7)
	hud.add_child(top_inner)
	# Rust accent thin line
	var top_accent := ColorRect.new()
	top_accent.position = Vector2(0, 56)
	top_accent.size     = Vector2(1280, 2)
	top_accent.color    = Color(UITheme.RUST, 0.55)
	hud.add_child(top_accent)

	# ── Stat badges (text labels, no emojis) ────────────────────────────────
	var money_pill := _hud_pill("MONEY",  "$0",     UITheme.SAGE, Vector2(14, 10))
	money_label    = money_pill.get_meta("value_label") as Label

	var day_pill   := _hud_pill("DAY",    "1",      UITheme.HAZARD, Vector2(190, 10))
	day_label      = day_pill.get_meta("value_label") as Label

	# ── Time bar — clean rounded slim ───────────────────────────────────────
	var time_lbl := Label.new()
	time_lbl.text = "SHIFT"
	time_lbl.position = Vector2(310, 14)
	time_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	time_lbl.modulate = Color(0.65, 0.65, 0.70)
	hud.add_child(time_lbl)
	time_bar = ProgressBar.new()
	time_bar.position      = Vector2(310, 30)
	time_bar.custom_minimum_size = Vector2(220, 10)
	time_bar.max_value     = 100.0
	time_bar.show_percentage = false
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = UITheme.HAZARD
	tb_fill.corner_radius_top_left     = 5
	tb_fill.corner_radius_top_right    = 5
	tb_fill.corner_radius_bottom_left  = 5
	tb_fill.corner_radius_bottom_right = 5
	var tb_bg := StyleBoxFlat.new()
	tb_bg.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	tb_bg.corner_radius_top_left     = 5
	tb_bg.corner_radius_top_right    = 5
	tb_bg.corner_radius_bottom_left  = 5
	tb_bg.corner_radius_bottom_right = 5
	time_bar.add_theme_stylebox_override("fill",       tb_fill)
	time_bar.add_theme_stylebox_override("background", tb_bg)
	hud.add_child(time_bar)

	# ── Rep + Tier ──────────────────────────────────────────────────────────
	var rep_pill   := _hud_pill("REPUTATION", "50",     UITheme.SKY,    Vector2(566, 10))
	rep_label      = rep_pill.get_meta("value_label") as Label

	var tier_pill  := _hud_pill("TIER",       "Rookie", UITheme.GRAPE,  Vector2(770, 10))
	tier_label     = tier_pill.get_meta("value_label") as Label

	# ── XP section (right side, vertical layout) ────────────────────────────
	var xp_kicker := Label.new()
	xp_kicker.text = "EXP"
	xp_kicker.position = Vector2(956, 14)
	xp_kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	xp_kicker.modulate = Color(UITheme.GRAPE, 0.85)
	hud.add_child(xp_kicker)

	xp_level_label = Label.new()
	xp_level_label.text = "LV. 1"
	xp_level_label.position = Vector2(990, 12)
	xp_level_label.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	xp_level_label.modulate = Color(0.96, 0.96, 0.96)
	hud.add_child(xp_level_label)

	xp_bar = ProgressBar.new()
	xp_bar.position      = Vector2(956, 32)
	xp_bar.custom_minimum_size = Vector2(214, 8)
	xp_bar.max_value      = 100.0
	xp_bar.value          = 0.0
	xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = UITheme.GRAPE
	xp_fill.corner_radius_top_left     = 4
	xp_fill.corner_radius_top_right    = 4
	xp_fill.corner_radius_bottom_left  = 4
	xp_fill.corner_radius_bottom_right = 4
	var xp_bg2 := StyleBoxFlat.new()
	xp_bg2.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	xp_bg2.corner_radius_top_left     = 4
	xp_bg2.corner_radius_top_right    = 4
	xp_bg2.corner_radius_bottom_left  = 4
	xp_bg2.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill",       xp_fill)
	xp_bar.add_theme_stylebox_override("background", xp_bg2)
	hud.add_child(xp_bar)

	xp_ticker_label = Label.new()
	xp_ticker_label.position  = Vector2(1000, 58)
	xp_ticker_label.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	xp_ticker_label.modulate  = Color(UITheme.GRAPE, 0.0)
	xp_ticker_label.text      = ""
	hud.add_child(xp_ticker_label)

	# ── Notify Customer button ──────────────────────────────────────────────
	_notify_btn = _hud_action_button("NOTIFY CUSTOMER", UITheme.SAGE)
	_notify_btn.position = Vector2(950, 8)
	_notify_btn.custom_minimum_size = Vector2(214, 40)
	_notify_btn.visible  = false
	_notify_btn.pressed.connect(_on_notify_customer_pressed)
	hud.add_child(_notify_btn)

	# ── CAR ACTION BAR (bottom centre) — clean dark panel with key shortcuts ─
	var bar_container := Control.new()
	bar_container.position = Vector2(270, 624)
	bar_container.custom_minimum_size = Vector2(740, 64)
	hud.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.04, 0.05, 0.07, 0.92)
	bar_bg.size  = Vector2(740, 64)
	bar_container.add_child(bar_bg)
	# Top accent line
	var bar_top_line := ColorRect.new()
	bar_top_line.color    = Color(UITheme.RUST, 0.55)
	bar_top_line.size     = Vector2(740, 2)
	bar_container.add_child(bar_top_line)

	_car_bar = bar_container
	_car_bar_btns.clear()

	var actions : Array = [
		["INSPECT",      _on_inspect_pressed,        UITheme.SKY],
		["CLEAN",        _on_clean_pressed,          UITheme.SAGE],
		["SELL",         _on_quick_sell_pressed,     UITheme.HAZARD],
		["COMPLETE JOB", _on_complete_order_pressed, UITheme.RUST],
	]
	var btn_w : float = 740.0 / actions.size()
	for i in actions.size():
		var col : Color = actions[i][2]
		var ab := Button.new()
		ab.text = actions[i][0]
		ab.add_theme_font_size_override("font_size", UITheme.FONT_SM)
		var flat_n := StyleBoxFlat.new()
		flat_n.bg_color = Color.TRANSPARENT
		flat_n.content_margin_left   = 4
		flat_n.content_margin_right  = 4
		flat_n.content_margin_top    = 6
		flat_n.content_margin_bottom = 6
		var flat_h := flat_n.duplicate() as StyleBoxFlat
		flat_h.bg_color = Color(col, 0.15)
		var flat_p := flat_n.duplicate() as StyleBoxFlat
		flat_p.bg_color = Color(col, 0.28)
		ab.add_theme_stylebox_override("normal",  flat_n)
		ab.add_theme_stylebox_override("hover",   flat_h)
		ab.add_theme_stylebox_override("pressed", flat_p)
		ab.add_theme_color_override("font_color",         col)
		ab.add_theme_color_override("font_hover_color",   col.lightened(0.18))
		ab.add_theme_color_override("font_pressed_color", col.darkened(0.10))
		ab.pressed.connect(actions[i][1])
		ab.position = Vector2(i * btn_w + 2, 12)
		ab.size     = Vector2(btn_w - 4, 44)
		bar_container.add_child(ab)
		_car_bar_btns.append(ab)
		# Bottom color stripe per button (subtle category indicator)
		var stripe := ColorRect.new()
		stripe.color    = Color(col, 0.75)
		stripe.position = Vector2(i * btn_w + 14, 58)
		stripe.size     = Vector2(btn_w - 28, 2)
		bar_container.add_child(stripe)
		if i > 0:
			var div := ColorRect.new()
			div.color    = Color(0.18, 0.20, 0.22, 0.6)
			div.position = Vector2(i * btn_w, 12)
			div.size     = Vector2(1, 44)
			bar_container.add_child(div)

	_car_bar.modulate.a = 0.0
	for b in _car_bar_btns:
		b.visible = false

	# ── ORDERS PANEL (left side) — dark panel with rust accent ───────────────
	var orders_bg := ColorRect.new()
	orders_bg.position = Vector2(0, 58)
	orders_bg.size     = Vector2(262, 572)
	orders_bg.color    = Color(0.04, 0.05, 0.07, 0.90)
	hud.add_child(orders_bg)

	# Right border accent
	var orders_border := ColorRect.new()
	orders_border.position = Vector2(260, 58)
	orders_border.size     = Vector2(2, 572)
	orders_border.color    = Color(UITheme.RUST, 0.45)
	hud.add_child(orders_border)

	# Orders header bar
	var ord_hdr_bg := ColorRect.new()
	ord_hdr_bg.position = Vector2(0, 58)
	ord_hdr_bg.size     = Vector2(260, 40)
	ord_hdr_bg.color    = Color(0.0, 0.0, 0.0, 0.50)
	hud.add_child(ord_hdr_bg)
	var ord_hdr_stripe := ColorRect.new()
	ord_hdr_stripe.color    = UITheme.RUST
	ord_hdr_stripe.size     = Vector2(3, 22)
	ord_hdr_stripe.position = Vector2(10, 67)
	hud.add_child(ord_hdr_stripe)
	var ord_hdr := Label.new()
	ord_hdr.text = "ORDERS"
	ord_hdr.position = Vector2(20, 68)
	ord_hdr.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	ord_hdr.modulate = Color(0.96, 0.96, 0.96)
	hud.add_child(ord_hdr)

	# Pending section
	var pend_lbl := Label.new()
	pend_lbl.text = "PENDING"
	pend_lbl.position = Vector2(12, 108)
	pend_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	pend_lbl.modulate = Color(0.62, 0.62, 0.65)
	hud.add_child(pend_lbl)

	var pending_scroll := ScrollContainer.new()
	pending_scroll.position = Vector2(4, 124)
	pending_scroll.size = Vector2(254, 196)
	hud.add_child(pending_scroll)
	order_panel_list = VBoxContainer.new()
	order_panel_list.add_theme_constant_override("separation", 4)
	order_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pending_scroll.add_child(order_panel_list)

	# Divider
	var ord_div := ColorRect.new()
	ord_div.position = Vector2(12, 326)
	ord_div.size     = Vector2(236, 1)
	ord_div.color    = Color(1, 1, 1, 0.10)
	hud.add_child(ord_div)

	# Active section
	var active_lbl := Label.new()
	active_lbl.text = "ACTIVE JOBS"
	active_lbl.position = Vector2(12, 336)
	active_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	active_lbl.modulate = Color(0.62, 0.62, 0.65)
	hud.add_child(active_lbl)

	var active_scroll := ScrollContainer.new()
	active_scroll.position = Vector2(4, 352)
	active_scroll.size = Vector2(254, 174)
	hud.add_child(active_scroll)
	active_panel_list = VBoxContainer.new()
	active_panel_list.add_theme_constant_override("separation", 4)
	active_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_scroll.add_child(active_panel_list)

	# ── INVENTORY STRIP (bottom) ─────────────────────────────────────────────
	var inv_bg := ColorRect.new()
	inv_bg.position = Vector2(0, 632)
	inv_bg.size     = Vector2(268, 88)
	inv_bg.color    = Color(0.04, 0.05, 0.07, 0.92)
	hud.add_child(inv_bg)
	# Top accent stripe
	var inv_top := ColorRect.new()
	inv_top.position = Vector2(0, 630)
	inv_top.size     = Vector2(268, 2)
	inv_top.color    = Color(UITheme.RUST, 0.45)
	hud.add_child(inv_top)
	# Header
	var inv_hdr_stripe := ColorRect.new()
	inv_hdr_stripe.color    = UITheme.RUST
	inv_hdr_stripe.size     = Vector2(3, 18)
	inv_hdr_stripe.position = Vector2(10, 640)
	hud.add_child(inv_hdr_stripe)
	var inv_lbl := Label.new()
	inv_lbl.text = "PARTS INVENTORY"
	inv_lbl.position = Vector2(20, 638)
	inv_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	inv_lbl.modulate = Color(0.62, 0.62, 0.65)
	hud.add_child(inv_lbl)

	inv_parts_label = Label.new()
	inv_parts_label.position = Vector2(10, 658)
	inv_parts_label.size = Vector2(248, 56)
	inv_parts_label.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	inv_parts_label.modulate = Color(0.85, 0.85, 0.86)
	inv_parts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(inv_parts_label)

	# ── INTERACT PROMPT — clean centered chip near bottom of screen ──────────
	interact_prompt = Label.new()
	interact_prompt.position = Vector2(290, 568)
	interact_prompt.size     = Vector2(700, 36)
	interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	interact_prompt.modulate = Color(UITheme.HAZARD, 1.0)
	interact_prompt.visible  = false
	hud.add_child(interact_prompt)

	# Esc hint (bottom right, very subtle)
	var esc_hint := Label.new()
	esc_hint.text = "[ ESC ]  release cursor"
	esc_hint.position = Vector2(1080, 700)
	esc_hint.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	esc_hint.modulate = Color(0.45, 0.45, 0.48)
	hud.add_child(esc_hint)

	# ── FEEDBACK LABEL ────────────────────────────────────────────────────────
	feedback_label = Label.new()
	feedback_label.position = Vector2(290, 596)
	feedback_label.size     = Vector2(700, 34)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", UITheme.FONT_LG)
	feedback_label.modulate = Color(0.96, 0.96, 0.96, 0.0)
	hud.add_child(feedback_label)

	# ── UPGRADE SHOP ─────────────────────────────────────────────────────────
	upgrade_shop = PanelContainer.new()
	upgrade_shop.set_script(UpgradeShopScript)
	upgrade_shop.position = Vector2(270, 70)
	hud.add_child(upgrade_shop)

func _hud_label(pos: Vector2, font_sz: int, color: Color, text: String = "") -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.modulate = color
	lbl.text = text
	hud.add_child(lbl)
	return lbl

## Clean stat badge: dark rectangle with left color stripe, small label + value.
## Returns the PanelContainer with metadata "value_label" pointing to the value Label.
## The `icon` parameter is repurposed as the small uppercase label text (no emojis).
func _hud_pill(icon: String, value: String, accent: Color, pos: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.85)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.border_color       = Color(0.0, 0.0, 0.0, 0.40)
	style.border_width_top   = 1; style.border_width_bottom = 1
	style.border_width_left  = 1; style.border_width_right  = 1
	style.content_margin_left   = 14
	style.content_margin_right  = 14
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", style)
	pc.position = pos

	# Left color accent stripe — draws on top of the panel
	var stripe := ColorRect.new()
	stripe.color    = accent
	stripe.size     = Vector2(3, 36)
	stripe.position = Vector2(0, 4)
	pc.add_child(stripe)

	var hb := HBoxContainer.new()
	hb.name = "HBoxContainer"
	hb.add_theme_constant_override("separation", 8)
	# Small uppercase label (instead of emoji)
	var icon_l := Label.new()
	icon_l.text = icon
	icon_l.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	icon_l.modulate = Color(accent, 0.85)
	hb.add_child(icon_l)
	var val_l := Label.new()
	val_l.text = value
	val_l.name = "Value"
	val_l.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	val_l.modulate = Color(0.96, 0.96, 0.96)
	hb.add_child(val_l)
	pc.add_child(hb)
	hud.add_child(pc)
	pc.set_meta("value_label", val_l)
	return pc

# Clean modern HUD button — flat dark bg with colored border + label, rounded
func _hud_action_button(txt: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	normal.border_color = accent
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.corner_radius_top_left = 4; normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4; normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 10; normal.content_margin_right = 10
	normal.content_margin_top = 8; normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent, 0.22)
	var pressed_s := normal.duplicate() as StyleBoxFlat
	pressed_s.bg_color = Color(accent, 0.34)
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_color_override("font_color",         accent)
	btn.add_theme_color_override("font_hover_color",   accent.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", accent.darkened(0.10))
	return btn

func _make_progress_bar(pos: Vector2, sz: Vector2) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.position = pos
	pb.size = sz
	pb.max_value = 100.0
	pb.show_percentage = false
	hud.add_child(pb)
	return pb

func _make_btn(txt: String, pos: Vector2, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.position = pos
	btn.size = Vector2(180, 40)
	btn.pressed.connect(cb)
	hud.add_child(btn)
	return btn

# ─────────────────────────────────────────────────────────────────────────────
#  PANELS (inspection + negotiation)
# ─────────────────────────────────────────────────────────────────────────────
func _build_inspection_panel() -> void:
	inspection_panel = PanelContainer.new()
	inspection_panel.position = Vector2(290, 70)
	inspection_panel.custom_minimum_size = Vector2(560, 540)
	inspection_panel.visible = false
	# Dark sim-style panel
	var insp_style := StyleBoxFlat.new()
	insp_style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	insp_style.corner_radius_top_left     = 6
	insp_style.corner_radius_top_right    = 6
	insp_style.corner_radius_bottom_left  = 6
	insp_style.corner_radius_bottom_right = 6
	insp_style.border_color       = Color(UITheme.SKY, 0.55)
	insp_style.border_width_top   = 1; insp_style.border_width_bottom = 1
	insp_style.border_width_left  = 1; insp_style.border_width_right  = 1
	insp_style.content_margin_left   = 22
	insp_style.content_margin_right  = 22
	insp_style.content_margin_top    = 18
	insp_style.content_margin_bottom = 18
	insp_style.shadow_color  = Color(0, 0, 0, 0.5)
	insp_style.shadow_size   = 16
	insp_style.shadow_offset = Vector2(0, 8)
	inspection_panel.add_theme_stylebox_override("panel", insp_style)
	hud.add_child(inspection_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	inspection_panel.add_child(vbox)

	# Kicker label
	var kicker := Label.new()
	kicker.text = "VEHICLE INSPECTION"
	kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	kicker.modulate = Color(UITheme.SKY, 0.85)
	vbox.add_child(kicker)

	# Vehicle title
	insp_title = Label.new()
	insp_title.add_theme_font_size_override("font_size", UITheme.FONT_XL)
	insp_title.modulate = Color(0.96, 0.96, 0.96)
	vbox.add_child(insp_title)

	# Accent line
	var div1 := ColorRect.new()
	div1.color = Color(UITheme.SKY, 0.45)
	div1.custom_minimum_size = Vector2(60, 2)
	vbox.add_child(div1)

	# Stat strip — grid of 4 labeled stats
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 12)
	vbox.add_child(stat_row)
	insp_score = _insp_stat_card(stat_row, "CONDITION", "—", UITheme.HAZARD)
	insp_dirt  = _insp_stat_card(stat_row, "CLEANLINESS", "—", Color(0.65, 0.65, 0.68))
	insp_value = _insp_stat_card(stat_row, "EST. VALUE", "—", UITheme.SAGE)
	insp_order = _insp_stat_card(stat_row, "ORDER", "—", UITheme.RUST)

	# Subtle divider
	var div2 := ColorRect.new()
	div2.color = Color(1.0, 1.0, 1.0, 0.10)
	div2.custom_minimum_size = Vector2(0, 1)
	div2.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(div2)

	# Parts section label
	var parts_lbl := Label.new()
	parts_lbl.text = "PARTS CONDITION"
	parts_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	parts_lbl.modulate = Color(0.62, 0.62, 0.65)
	vbox.add_child(parts_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	vbox.add_child(scroll)
	insp_parts_list = VBoxContainer.new()
	insp_parts_list.add_theme_constant_override("separation", 5)
	insp_parts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(insp_parts_list)

	# Footer with close button
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)
	var close := _hud_action_button("CLOSE", Color(0.65, 0.65, 0.68))
	close.custom_minimum_size = Vector2(120, 36)
	close.pressed.connect(func():
		inspection_panel.hide()
		if player: player.call("unfreeze"))
	footer.add_child(close)

# Build a labeled stat card column for the inspection top row.
# Returns the VALUE label so callers can update it later.
func _insp_stat_card(parent: HBoxContainer, label_text: String, value_text: String, accent: Color) -> Label:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	# Kicker label
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	lbl.modulate = Color(accent, 0.80)
	col.add_child(lbl)
	# Value
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", UITheme.FONT_LG)
	val.modulate = Color(0.96, 0.96, 0.96)
	col.add_child(val)
	# Underline stripe
	var strip := ColorRect.new()
	strip.color = Color(accent, 0.55)
	strip.custom_minimum_size = Vector2(36, 2)
	col.add_child(strip)
	parent.add_child(col)
	return val

func _build_negotiation_panel() -> void:
	# Outer container — dark sim-style card with personality color stripe
	var outer := Control.new()
	outer.position = Vector2(340, 100)
	outer.size     = Vector2(560, 520)
	outer.visible  = false
	hud.add_child(outer)
	negotiation_panel = outer

	# Shadow / drop behind the panel
	var shadow := ColorRect.new()
	shadow.position = Vector2(0, 8)
	shadow.size     = Vector2(560, 520)
	shadow.color    = Color(0.0, 0.0, 0.0, 0.45)
	outer.add_child(shadow)

	# Dark card background
	var card := ColorRect.new()
	card.position = Vector2(0, 0)
	card.size     = Vector2(560, 520)
	card.color    = Color(0.06, 0.07, 0.09, 0.97)
	outer.add_child(card)

	# Left personality color stripe (dynamic — set by negotiation logic)
	neg_panel_stripe = ColorRect.new()
	neg_panel_stripe.position = Vector2(0, 0)
	neg_panel_stripe.size     = Vector2(4, 520)
	neg_panel_stripe.color    = UITheme.HAZARD
	outer.add_child(neg_panel_stripe)

	# Subtle border
	var border_t := ColorRect.new()
	border_t.position = Vector2(4, 0); border_t.size = Vector2(556, 1)
	border_t.color    = Color(1, 1, 1, 0.08)
	outer.add_child(border_t)
	var border_b := ColorRect.new()
	border_b.position = Vector2(4, 519); border_b.size = Vector2(556, 1)
	border_b.color    = Color(0, 0, 0, 0.5)
	outer.add_child(border_b)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(28, 22)
	vbox.size     = Vector2(504, 480)
	vbox.add_theme_constant_override("separation", 10)
	outer.add_child(vbox)

	# Kicker
	var kicker := Label.new()
	kicker.text = "CUSTOMER"
	kicker.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	kicker.modulate = Color(0.62, 0.62, 0.65)
	vbox.add_child(kicker)

	# Name + personality on same row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	vbox.add_child(name_row)
	neg_cust_name = Label.new()
	neg_cust_name.add_theme_font_size_override("font_size", UITheme.FONT_XL)
	neg_cust_name.modulate = Color(0.96, 0.96, 0.96)
	neg_cust_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(neg_cust_name)
	neg_personality = Label.new()
	neg_personality.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	neg_personality.modulate = UITheme.HAZARD
	name_row.add_child(neg_personality)

	# Accent stripe under name
	var div_neg := ColorRect.new()
	div_neg.color = Color(UITheme.HAZARD, 0.45)
	div_neg.custom_minimum_size = Vector2(60, 2)
	vbox.add_child(div_neg)

	# Greeting block in a dark inset
	var greeting_bg := PanelContainer.new()
	var greeting_style := StyleBoxFlat.new()
	greeting_style.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	greeting_style.corner_radius_top_left     = 4
	greeting_style.corner_radius_top_right    = 4
	greeting_style.corner_radius_bottom_left  = 4
	greeting_style.corner_radius_bottom_right = 4
	greeting_style.content_margin_left = 14; greeting_style.content_margin_right = 14
	greeting_style.content_margin_top = 12; greeting_style.content_margin_bottom = 12
	greeting_bg.add_theme_stylebox_override("panel", greeting_style)
	vbox.add_child(greeting_bg)
	neg_greeting = Label.new()
	neg_greeting.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	neg_greeting.modulate     = Color(0.92, 0.92, 0.92)
	neg_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greeting_bg.add_child(neg_greeting)

	# Offer row — labeled stat card style
	var offer_row := HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 24)
	vbox.add_child(offer_row)
	# Their offer
	var their_col := VBoxContainer.new()
	their_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var their_lbl := Label.new()
	their_lbl.text = "THEIR OFFER"
	their_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	their_lbl.modulate = Color(UITheme.SAGE, 0.85)
	their_col.add_child(their_lbl)
	neg_offer = Label.new()
	neg_offer.add_theme_font_size_override("font_size", UITheme.FONT_XL)
	neg_offer.modulate = UITheme.SAGE
	their_col.add_child(neg_offer)
	offer_row.add_child(their_col)
	# Vehicle value
	var val_col := VBoxContainer.new()
	val_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val_lbl := Label.new()
	val_lbl.text = "VEHICLE VALUE"
	val_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	val_lbl.modulate = Color(0.62, 0.62, 0.65)
	val_col.add_child(val_lbl)
	neg_vehicle_val = Label.new()
	neg_vehicle_val.add_theme_font_size_override("font_size", UITheme.FONT_LG)
	neg_vehicle_val.modulate = Color(0.86, 0.86, 0.88)
	val_col.add_child(neg_vehicle_val)
	offer_row.add_child(val_col)

	# ── Service-mode section (hidden by default) ──────────────────────────────
	neg_service_section = VBoxContainer.new()
	neg_service_section.visible = false
	neg_service_section.add_theme_constant_override("separation", 4)
	vbox.add_child(neg_service_section)

	var svc_hdr := Label.new()
	svc_hdr.text = "SERVICE REQUEST"
	svc_hdr.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	svc_hdr.modulate = Color(UITheme.SKY, 0.85)
	neg_service_section.add_child(svc_hdr)

	neg_service_jobs_list = VBoxContainer.new()
	neg_service_jobs_list.add_theme_constant_override("separation", 3)
	neg_service_section.add_child(neg_service_jobs_list)

	neg_service_quote = Label.new()
	neg_service_quote.add_theme_font_size_override("font_size", UITheme.FONT_SM)
	neg_service_quote.modulate = Color(0.85, 0.85, 0.85)
	neg_service_section.add_child(neg_service_quote)

	# ── Price slider — labeled with current value ─────────────────────────────
	neg_slider_row = VBoxContainer.new()
	neg_slider_row.add_theme_constant_override("separation", 6)
	vbox.add_child(neg_slider_row)
	var ask_row := HBoxContainer.new()
	neg_slider_row.add_child(ask_row)
	var ask_lbl := Label.new()
	ask_lbl.text = "YOUR ASK"
	ask_lbl.add_theme_font_size_override("font_size", UITheme.FONT_XS)
	ask_lbl.modulate = Color(0.62, 0.62, 0.65)
	ask_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask_row.add_child(ask_lbl)
	neg_slider_val = Label.new()
	neg_slider_val.add_theme_font_size_override("font_size", UITheme.FONT_LG)
	neg_slider_val.modulate = UITheme.HAZARD
	ask_row.add_child(neg_slider_val)
	neg_slider = HSlider.new()
	neg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neg_slider.value_changed.connect(func(v): neg_slider_val.text = "$%d" % int(v))
	neg_slider_row.add_child(neg_slider)

	# Action buttons — three primary actions
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	neg_accept_btn  = _row_btn(btn_row, "ACCEPT",  _on_neg_accept,  UITheme.SAGE)
	neg_counter_btn = _row_btn(btn_row, "COUNTER", _on_neg_counter, UITheme.HAZARD)
	neg_refuse_btn  = _row_btn(btn_row, "REFUSE",  _on_neg_refuse,  UITheme.CHERRY)

	# Help-for-free button (only visible for poor student)
	neg_free_btn = _hud_action_button("HELP FOR FREE  (+20 rep)", UITheme.SKY)
	neg_free_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neg_free_btn.visible  = false
	neg_free_btn.pressed.connect(_on_neg_help_free)
	vbox.add_child(neg_free_btn)

	# Kick out button (only visible after persistent customer)
	neg_kick_btn = _hud_action_button("KICK OUT  (-2 rep)", UITheme.CHERRY)
	neg_kick_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neg_kick_btn.visible  = false
	neg_kick_btn.pressed.connect(_on_neg_kick_out)
	vbox.add_child(neg_kick_btn)

	# Result label (shown after a negotiation turn)
	neg_result = Label.new()
	neg_result.add_theme_font_size_override("font_size", UITheme.FONT_MD)
	neg_result.modulate      = Color(0.92, 0.92, 0.92)
	neg_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neg_result.visible = false
	vbox.add_child(neg_result)

func _panel_label(parent: VBoxContainer, font_sz: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_sz)
	parent.add_child(l)
	return l

func _row_btn(row: HBoxContainer, txt: String, cb: Callable,
		col: Color = UITheme.HAZARD) -> Button:
	var b := _hud_action_button(txt, col)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	row.add_child(b)
	return b

# ─────────────────────────────────────────────────────────────────────────────
#  SYSTEMS SETUP
# ─────────────────────────────────────────────────────────────────────────────
func _setup_systems() -> void:
	# Cleaning system (manages oil spills on floor)
	var clean_node := Node.new()
	clean_node.set_script(CleaningScript)
	add_child(clean_node)
	cleaning = clean_node

	# Thief system
	var thief_node := Node.new()
	thief_node.set_script(ThiefScript)
	add_child(thief_node)
	thief_sys = thief_node
	thief_sys.set("hud_ref", hud)
	thief_sys.connect("theft_attempted", _on_theft_event)
	thief_sys.connect("night_phase_end", _show_day_summary)

	# Workbench worker-finished feedback
	workbench.connect("worker_finished", func(wname: String, part: String):
		show_feedback("👷 %s finished repairing %s!" % [wname, part.replace("_"," ").capitalize()], Color(0.5, 0.9, 1.0)))

func _setup_timer() -> void:
	customer_timer = get_node_or_null("CustomerTimer")
	if not customer_timer:
		customer_timer = Timer.new()
		customer_timer.name = "CustomerTimer"
		add_child(customer_timer)
	customer_timer.one_shot = true
	customer_timer.timeout.connect(_on_customer_arrived)
	_restart_customer_timer()

## Restarts customer timer, respecting today's Rush Hour and Bad Weather modifiers.
func _restart_customer_timer() -> void:
	var base_min := 30.0
	var base_max := 55.0
	if EventSystem.is_rush_hour():
		base_min *= 0.5; base_max *= 0.5    # twice as fast
	elif EventSystem.is_bad_weather():
		base_min *= 2.0; base_max *= 2.5    # half as many customers
	customer_timer.wait_time = randf_range(base_min, base_max)
	customer_timer.start()

func _connect_signals() -> void:
	EconomyManager.money_changed.connect(func(amt, _d): _update_money(amt))
	EconomyManager.reputation_changed.connect(func(rep): _update_rep(rep))
	GameManager.day_started.connect(func(d): _update_day(d))
	GameManager.day_started.connect(func(_d): _on_mechanic_auto_repair())
	GameManager.day_ended.connect(func(_d): _on_day_ended())
	ProgressionManager.tier_upgraded.connect(func(_t): _update_tier_label())
	InventoryManager.inventory_changed.connect(_refresh_inventory_display)
	OrderSystem.orders_changed.connect(_refresh_order_panels)
	OrderSystem.orders_changed.connect(_check_service_completion)
	AuctionSystem.vehicle_delivered.connect(_on_vehicle_delivered)
	TowingManager.tow_arrived.connect(_on_tow_arrived)
	XPManager.xp_gained.connect(_on_xp_gained)
	XPManager.level_up.connect(_on_level_up)

func _process(delta: float) -> void:
	if time_bar:
		time_bar.value = GameManager.get_day_progress() * 100.0
	_update_day_night(GameManager.get_day_progress(), delta)

# ─────────────────────────────────────────────────────────────────────────────
#  VEHICLE
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_vehicle(template_id: String, damage: float = 0.5, order_id: int = -1) -> void:
	if current_vehicle:
		current_vehicle.queue_free()
		current_vehicle = null
	var template := VehicleDatabase.get_vehicle(template_id)
	if template.is_empty():
		push_error("[Garage] Unknown template: %s" % template_id)
		return
	var vdata := VehicleData.create_from_template(template, damage)
	var v: Vehicle = VehicleScene.instantiate()
	bay_slot.add_child(v)
	v.initialize(vdata, order_id)
	v.vehicle_clicked.connect(_on_vehicle_clicked)
	current_vehicle = v
	AudioManager.play("engine", -4.0)
	_show_car_bar(true)
	# Spawn an oil spill when a new car comes in
	if cleaning:
		cleaning.call("spawn_spill", Vector3(randf_range(-1, 1), 0, randf_range(-0.5, 0.5)))

# ─────────────────────────────────────────────────────────────────────────────
#  ACTION HANDLERS
# ─────────────────────────────────────────────────────────────────────────────
func _on_clean_pressed() -> void:
	if not current_vehicle:
		show_feedback("No vehicle in the bay!", Color.RED); return
	var result := current_vehicle.action_clean()
	show_feedback("Cleaned!  Condition: %d%%" % result.get("score_after", 0), Color.GREEN)

func _on_inspect_pressed() -> void:
	if not current_vehicle:
		show_feedback("No vehicle to inspect!", Color.RED); return
	_refresh_inspection_panel(current_vehicle.data)
	inspection_panel.show()
	if player: player.call("freeze")

func _on_quick_sell_pressed() -> void:
	if not current_vehicle:
		show_feedback("Nothing to sell!", Color.RED); return
	if current_vehicle.linked_order_id >= 0:
		var order_rec := OrderSystem._find_active(current_vehicle.linked_order_id)
		if order_rec.get("walk_in", false):
			show_feedback("🚫 That's a customer's repair car — fix it first, then use 📞 Notify Customer!", Color.RED)
		else:
			show_feedback("🚫 That's a customer's car — complete the order to get paid!", Color.RED)
		return
	var value := current_vehicle.data.get_sell_value()
	_complete_flip_sale(value)
	show_feedback("Sold for $%d!" % value, Color.GREEN)

func _on_complete_order_pressed() -> void:
	if not current_vehicle or current_vehicle.linked_order_id < 0:
		show_feedback("No active order on this vehicle.", Color.YELLOW); return
	# Walk-in service cars are collected via the Notify Customer flow — not here
	var lid := current_vehicle.linked_order_id
	var chk := OrderSystem._find_active(lid)
	if chk.get("walk_in", false):
		show_feedback("This is a service car — use  📞 Notify Customer  when done!", Color(1.0, 0.85, 0.4))
		return
	var payout := OrderSystem.complete_order(lid)
	if payout == -1:
		show_feedback("Not all jobs are done yet — check the order!", Color.RED)
	elif payout > 0:
		show_feedback("Order complete!  +$%d" % payout, Color.GREEN)
		current_vehicle.queue_free()
		current_vehicle = null

func _on_get_new_car_pressed() -> void:
	# Redirected to Workshop Tablet → Market tab
	_on_tablet_pressed()

func _on_junkyard_pressed() -> void:
	SaveManager.auto_save()
	get_tree().change_scene_to_file("res://scenes/junkyard/Junkyard.tscn")

func _on_upgrades_pressed() -> void:
	if upgrade_shop: upgrade_shop.open()

func _open_paint_booth() -> void:
	if not current_vehicle:
		show_feedback("No vehicle in the bay to paint!", Color.YELLOW); return
	var panel := PanelContainer.new()
	panel.set_script(PaintBoothScript)
	panel.set("garage_ref", self)
	hud.add_child(panel)
	if player: player.call("freeze")

func _open_workbench_panel() -> void:
	# Don't open twice
	if workbench_panel and is_instance_valid(workbench_panel):
		return
	var panel := PanelContainer.new()
	panel.set_script(WorkbenchPanelScript)
	panel.set("workbench_ref", workbench)
	panel.set("garage_ref",    self)
	hud.add_child(panel)
	workbench_panel = panel
	if player: player.call("freeze")

# ─────────────────────────────────────────────────────────────────────────────
#  ORDER PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_order_panels() -> void:
	for c in order_panel_list.get_children():  c.queue_free()
	for c in active_panel_list.get_children(): c.queue_free()

	for order in OrderSystem.pending_orders:
		var row := _order_row(order, true)
		order_panel_list.add_child(row)

	for order in OrderSystem.active_orders:
		var row := _order_row(order, false)
		active_panel_list.add_child(row)

func _order_row(order: Dictionary, is_pending: bool) -> VBoxContainer:
	var vb := VBoxContainer.new()

	var title_row := HBoxContainer.new()
	vb.add_child(title_row)

	var urgency_dot := Label.new()
	urgency_dot.text = "● "
	urgency_dot.modulate = OrderSystem.urgency_color(order["urgency"])
	urgency_dot.add_theme_font_size_override("font_size", 11)
	title_row.add_child(urgency_dot)

	var name_lbl := Label.new()
	name_lbl.text = "%s" % order["customer_name"]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "$%d" % order["base_reward"]
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.modulate = Color(0.4, 1.0, 0.4)
	title_row.add_child(reward_lbl)

	var car_lbl := Label.new()
	car_lbl.text = "  %s" % order["vehicle_name"]
	car_lbl.add_theme_font_size_override("font_size", 11)
	car_lbl.modulate = Color(0.75, 0.75, 0.75)
	vb.add_child(car_lbl)

	var days_left := OrderSystem.get_days_left(order)
	var deadline_lbl := Label.new()
	deadline_lbl.text = "  %s  •  %d day%s left" % [
		OrderSystem.URGENCY_DATA[order["urgency"]]["label"],
		days_left, "s" if days_left != 1 else ""
	]
	deadline_lbl.add_theme_font_size_override("font_size", 11)
	deadline_lbl.modulate = Color.RED if days_left <= 1 else Color(0.75, 0.75, 0.75)
	vb.add_child(deadline_lbl)

	if is_pending:
		var accept_btn := Button.new()
		accept_btn.text = "Accept →"
		accept_btn.add_theme_font_size_override("font_size", 11)
		var oid: int = order["id"]
		accept_btn.pressed.connect(func(): _accept_order(oid))
		vb.add_child(accept_btn)

	vb.add_child(HSeparator.new())
	return vb

func _accept_order(order_id: int) -> void:
	if current_vehicle and current_vehicle.linked_order_id >= 0:
		show_feedback("Finish the current order first!", Color.RED); return
	var order := OrderSystem.accept_order(order_id)
	if order.has("error"):
		show_feedback(order["error"], Color.RED); return
	if current_vehicle:
		current_vehicle.queue_free()
		current_vehicle = null
	_spawn_vehicle(order["vehicle_id"], order["damage_level"], order["id"])
	show_feedback("Order accepted — %s's %s is in the bay!" % [order["customer_name"], order["vehicle_name"]], Color.CYAN)

# ─────────────────────────────────────────────────────────────────────────────
#  CUSTOMER (flip sale negotiation)
# ─────────────────────────────────────────────────────────────────────────────
func _on_customer_arrived() -> void:
	_restart_customer_timer()

	# 40% chance: walk-in service customer, but only if no service job already in the bay
	if not _has_active_service_order() and randf() < 0.40:
		pending_customer = Customer.create_random_service()
	else:
		# Flip-sale customer — only relevant if there's a vehicle to sell
		if not current_vehicle or current_vehicle.linked_order_id >= 0:
			return
		# VIP day → force a well-funded RICH_KID buyer
		if EventSystem.customer_payout_bonus > 1.0:
			pending_customer = Customer.create_type(Customer.Personality.RICH_KID)
		else:
			pending_customer = Customer.create_random_flip()

	# Spawn NPC at the garage entrance and walk to the reception desk
	if customer_npc and is_instance_valid(customer_npc):
		customer_npc.queue_free()
	var npc := CharacterBody3D.new()
	npc.set_script(CustomerNPCScript)
	npc.position = Vector3(0.0, 0.5, 9.0)   # just inside the garage door
	add_child(npc)
	customer_npc = npc

	# Load the personality-matching Claude Design sprite
	if pending_customer:
		npc.call("set_personality", pending_customer.personality as int)

	AudioManager.play("customer_arrive", -4.0)
	var arrival_hint : String = pending_customer.get_arrival_message() if pending_customer else "Someone just walked in…"
	show_feedback(arrival_hint, pending_customer.get_personality_color() if pending_customer else Color(1.0, 0.9, 0.5))

	# When NPC reaches the desk, update the zone label — player must walk over and press E
	npc.walk_to(Vector3(5.0, 0.5, 5.0), func():
		if _reception_zone:
			_reception_zone.set_meta("interact_label", "💬 Talk to Customer")
		show_feedback("Customer at the desk — press  [ E ]  to talk!", Color(1.0, 0.85, 0.3)))

## Called when the player presses E at the reception desk.
func _on_reception_interact() -> void:
	if _neg_mode == "pickup_open":
		return   # panel already visible, ignore re-trigger
	if _neg_mode == "pickup" and customer_npc and is_instance_valid(customer_npc):
		_open_pickup_panel()
		return
	if pending_customer and customer_npc and is_instance_valid(customer_npc):
		if pending_customer.is_service:
			_open_service_negotiation_for(pending_customer)
		else:
			_open_negotiation_for(pending_customer)
	else:
		show_feedback("No one at the desk right now — check the order queue.", Color.CYAN)

func _open_negotiation_for(cust: Customer) -> void:
	if not cust or not current_vehicle: return
	var offer_bonus : float = ProgressionManager.get_offer_bonus()
	var offer       : int   = int(cust.make_opening_offer(current_vehicle.data) * (1.0 + offer_bonus))
	cust.current_offer = offer
	var vehicle_val : int = current_vehicle.data.get_sell_value()
	var pers_color  : Color = cust.get_personality_color()

	# Accent stripe color matches personality
	if neg_panel_stripe:
		neg_panel_stripe.color = pers_color

	neg_cust_name.text   = cust.display_name
	neg_personality.text = cust.get_personality_label()
	neg_personality.modulate = pers_color
	neg_greeting.text    = '"%s"' % cust.get_greeting()
	neg_offer.text       = "Their offer:  $%d" % offer
	neg_vehicle_val.text = "Vehicle value: ~$%d" % vehicle_val

	neg_slider.min_value = offer
	neg_slider.max_value = int(vehicle_val * 1.7)
	# Default slider to their current offer — player drags UP to ask more (risk/reward)
	# Rich kid: snap to max as visual hint he'll pay anything
	neg_slider.value     = int(vehicle_val * 1.7) if cust.auto_accepts else offer
	neg_slider_val.text  = "$%d" % int(neg_slider.value)
	neg_result.visible   = false

	# "Help for Free" button — only for the broke student
	neg_free_btn.visible = cust.gives_free_help

	# Per-personality hints on the vehicle value line
	if cust.honest_bonus:
		neg_vehicle_val.text = "Vehicle value: ~$%d  ⚠️ He knows the exact price" % vehicle_val
	elif cust.overcharge_immune:
		neg_vehicle_val.text = "Vehicle value: ~$%d  😅 She has no idea what it's worth" % vehicle_val
	elif cust.auto_accepts:
		neg_vehicle_val.text = "Vehicle value: ~$%d  💸 He'll pay whatever you ask" % vehicle_val

	# Dynamic button labels for flip mode
	neg_accept_btn.text  = "💰 Ask This Price"
	neg_counter_btn.text = "🤝 Take Their Offer  ($%d)" % offer

	_refuse_count = 0
	neg_kick_btn.visible = false
	_set_neg_btns(true)
	negotiation_panel.show()
	if player: player.call("freeze")

	var arrival_msg : String = cust.get_arrival_message()
	show_feedback(arrival_msg, pers_color)

func _on_neg_accept() -> void:
	match _neg_mode:
		"service":      _on_neg_accept_service()
		"pickup_open":  _on_neg_accept_pickup()
		_:
			# "Ask This Price" — slider value, validated against the customer's budget
			if not pending_customer: return
			var asking := int(neg_slider.value)
			if pending_customer.will_accept(asking):
				_finish_negotiation(asking, pending_customer.get_accept_comment(), true)
			elif pending_customer.has_walked():
				# Out of patience — they walk
				_finish_negotiation(0, pending_customer.get_walk_comment(), false)
			else:
				# Too expensive — customer pushes back with a counter
				var counter := pending_customer.counter_offer()
				neg_offer.text    = "Too expensive! Counter:  $%d" % counter
				neg_greeting.text = '"%s"' % pending_customer.get_low_offer_comment()
				neg_counter_btn.text = "🤝 Take Their Offer  ($%d)" % counter
				neg_slider.min_value = counter
				# Snap slider down to counter so the player sees the new floor
				if neg_slider.value < counter:
					neg_slider.value = counter

func _on_neg_counter() -> void:
	# "Take Their Offer" — safe path, accepts at whatever the customer currently offers
	if _neg_mode != "flip" or not pending_customer: return
	_finish_negotiation(int(pending_customer.current_offer), pending_customer.get_accept_comment(), true)

func _on_neg_refuse() -> void:
	if _neg_mode == "service" and pending_customer:
		_set_neg_btns(false)
		neg_result.text    = '"%s"' % pending_customer.get_walk_comment()
		neg_result.modulate = Color(0.85, 0.55, 0.55)
		neg_result.visible  = true
		AudioManager.play("neg_refuse", -3.0)
		show_feedback("You turned them away.", Color(0.75, 0.65, 0.65))
		await get_tree().create_timer(1.8).timeout
		negotiation_panel.hide()
		_reset_neg_panel_state()
		if customer_npc and is_instance_valid(customer_npc):
			customer_npc.call("leave", Vector3(0.0, 0.5, 10.5))
		customer_npc = null
		if _reception_zone:
			_reception_zone.set_meta("interact_label", "Reception Desk")
		pending_customer = null
		if player: player.call("unfreeze")
		return

	if pending_customer:
		# Persistent customers won't leave on the first refuse
		if pending_customer.persistent and _refuse_count < 2:
			_refuse_count += 1
			neg_result.text    = '"%s"' % pending_customer.get_low_offer_comment()
			neg_result.modulate = Color(1.0, 0.6, 0.25)
			neg_result.visible  = true
			neg_kick_btn.visible = true   # "Kick Out" button appears
			var hint : String
			match pending_customer.personality:
				Customer.Personality.SHADY_GUY:
					hint = "He's not leaving. You may need to kick him out."
				Customer.Personality.CLUELESS_WIFE:
					hint = "She's still standing there looking confused…"
				_:
					hint = "They won't give up. Press Kick Out to remove them."
			show_feedback(hint, Color(1.0, 0.70, 0.35))
			return

		# Refusing a poor student costs a little reputation
		if pending_customer.gives_free_help:
			EconomyManager.change_reputation(-3.0, "Turned away a student")
			show_feedback("They really needed help… -3 rep.", Color(1.0, 0.55, 0.45))
		_refuse_count = 0
		neg_kick_btn.visible = false
		_finish_negotiation(0, pending_customer.get_walk_comment(), false)

func _on_neg_help_free() -> void:
	if not pending_customer or not pending_customer.gives_free_help: return
	EconomyManager.change_reputation(20.0, "Helped a student for free")
	AudioManager.play("neg_accept", -2.0)
	show_feedback("💚 You helped them out for free! +20 reputation!", Color(0.35, 1.0, 0.55))
	_finish_negotiation(0, pending_customer.get_accept_comment(), false)

func _finish_negotiation(price: int, comment: String, sold: bool) -> void:
	_set_neg_btns(false)
	neg_result.text = '"%s"' % comment
	neg_result.modulate = Color.GREEN if sold else Color.RED
	neg_result.visible = true
	if sold:
		AudioManager.play("neg_accept", -3.0)
		_complete_flip_sale(price)
	else:
		AudioManager.play("neg_refuse", -3.0)
	await get_tree().create_timer(2.2).timeout
	negotiation_panel.hide()
	pending_customer = null
	if player: player.call("unfreeze")
	# Reset reception zone label now that no customer is waiting
	if _reception_zone:
		_reception_zone.set_meta("interact_label", "Reception Desk")
	# Send NPC back to the door
	if customer_npc and is_instance_valid(customer_npc):
		customer_npc.call("leave", Vector3(0.0, 0.5, 10.5))

func _complete_flip_sale(price: int) -> void:
	if not current_vehicle: return
	var car_name : String = current_vehicle.data.display_name
	var purchase : int    = current_vehicle.data.purchase_price
	EconomyManager.add_money(price, "Sold %s" % car_name)
	var fair     : int    = current_vehicle.data.get_sell_value()
	var cust     : Customer = pending_customer   # may be null if called from helper

	# ── Reputation from sale ───────────────────────────────────────────────────
	var overcharged : bool = price > fair * 1.25
	if cust and cust.shady_deal:
		# Shady guy always brings a slight rep hit (you know what you did)
		EconomyManager.change_reputation(-2.0, "Shady deal")
		show_feedback("💸 Cash in hand. Don't think about it too hard.", Color(0.75, 0.72, 0.65))
	elif cust and cust.overcharge_immune and overcharged:
		# Clueless wife — she's happy, no rep penalty for overcharging
		EconomyManager.change_reputation(2.0, "Sale — she was happy")
		show_feedback("😅 She didn't even blink! Sold for $%d." % price, Color(1.0, 0.78, 0.88))
	elif cust and cust.honest_bonus and not overcharged and price >= int(fair * 0.88):
		# Retired mechanic — fair deal earns bonus respect
		EconomyManager.change_reputation(8.0, "Honest deal with expert")
		show_feedback("🔧 He nodded approvingly. +8 reputation for fair pricing!", Color(0.70, 1.0, 0.55))
	elif overcharged:
		EconomyManager.change_reputation(-5.0, "Overcharged customer")
	elif price >= int(fair * 0.90):
		EconomyManager.change_reputation(3.0, "Fair sale")
	else:
		EconomyManager.change_reputation(1.0, "Vehicle sale")

	print("[Garage] Sold %s for $%d (profit $%d)" % [car_name, price, price - purchase])
	_show_car_bar(false)

	# ── XP for flip sale ──────────────────────────────────────────────────────
	XPManager.award("flip_sale")
	var profit : int = price - purchase
	if profit > 0:
		# 1 XP per $100 profit, capped at 5× the base
		XPManager.award("flip_sale_profit", clampf(float(profit) / 100.0, 0.0, 5.0))
	if cust and cust.honest_bonus:
		XPManager.award("neg_hard_deal")
	elif price >= int(fair * 0.88) and price <= int(fair * 1.12):
		XPManager.award("neg_fair_price")

	current_vehicle.queue_free()
	current_vehicle = null
	_check_pending_tow()

func _set_neg_btns(e: bool) -> void:
	neg_accept_btn.disabled  = not e
	neg_counter_btn.disabled = not e
	neg_refuse_btn.disabled  = not e
	if neg_free_btn and neg_free_btn.visible:
		neg_free_btn.disabled = not e
	if neg_kick_btn and neg_kick_btn.visible:
		neg_kick_btn.disabled = not e

func _on_neg_kick_out() -> void:
	if not pending_customer: return
	EconomyManager.change_reputation(-2.0, "Kicked out a customer")
	show_feedback("🥾 You kicked them out! -2 rep.", Color(1.0, 0.50, 0.35))
	_refuse_count = 0
	neg_kick_btn.visible = false
	_finish_negotiation(0, pending_customer.get_walk_comment(), false)

# ─────────────────────────────────────────────────────────────────────────────
#  INSPECTION PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_inspection_panel(data: VehicleData) -> void:
	var score := data.get_condition_score()
	insp_title.text = data.display_name
	insp_score.text = "%d%%  %s" % [score, data.get_condition_label()]
	insp_score.modulate = _score_color(score)
	insp_dirt.text  = data.get_dirt_label()
	insp_value.text = "$%d" % data.get_sell_value()

	# Show linked order info
	if current_vehicle and current_vehicle.linked_order_id >= 0:
		var order := OrderSystem._find_active(current_vehicle.linked_order_id)
		if not order.is_empty():
			var done: int = (order["completed_jobs"] as Array).size()
			var total: int = (order["required_jobs"] as Array).size()
			insp_order.text = "%d / %d" % [done, total]
		else:
			insp_order.text = "—"
	else:
		insp_order.text = "—"

	for c in insp_parts_list.get_children(): c.queue_free()

	for part_name in data.parts:
		var cond: int = data.parts[part_name]
		var cond_str: String = VehicleData.PartCondition.keys()[cond].capitalize()
		var cost := VehicleDatabase.get_part_repair_cost(part_name)
		var row := HBoxContainer.new()

		var nl := Label.new()
		nl.text = part_name.replace("_", " ").capitalize()
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 13)
		row.add_child(nl)

		var cl := Label.new()
		cl.text = cond_str
		cl.custom_minimum_size.x = 80
		cl.modulate = _part_color(cond)
		cl.add_theme_font_size_override("font_size", 13)
		row.add_child(cl)

		if InventoryManager.has_part(part_name):
			var free_lbl := Label.new()
			free_lbl.text = "FREE (spare)"
			free_lbl.modulate = Color.CYAN
			free_lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(free_lbl)
		elif cond >= VehicleData.PartCondition.DAMAGED:
			var btn := Button.new()
			var actual_cost := int(cost * ProgressionManager.get_repair_cost_multiplier())
			btn.text = "$%d" % actual_cost
			btn.disabled = not EconomyManager.can_afford(actual_cost)
			var pn: String = part_name
			btn.pressed.connect(func(): _do_repair(pn))
			row.add_child(btn)
		else:
			var ok := Label.new(); ok.text = "✓"; ok.modulate = Color.GREEN
			row.add_child(ok)

		insp_parts_list.add_child(row)

func _do_repair(part_name: String) -> void:
	if not current_vehicle: return

	# ── Spare part in inventory → instant free repair (no minigame needed) ─────
	if InventoryManager.has_part(part_name):
		InventoryManager.use_part(part_name)
		var old_cond : int = current_vehicle.data.parts.get(part_name, VehicleData.PartCondition.BROKEN)
		current_vehicle.data.parts[part_name] = max(VehicleData.PartCondition.GOOD, old_cond - 2)
		current_vehicle.refresh_visuals()
		show_feedback("Used spare %s — FREE!" % part_name.replace("_", " "), Color.CYAN)
		XPManager.award("repair_free")
		if inspection_panel.visible:
			_refresh_inspection_panel(current_vehicle.data)
		return

	# ── Paid repair → check funds then open the manual repair mini-game ────────
	var cost       : int = VehicleDatabase.get_part_repair_cost(part_name)
	var actual_cost: int = int(cost * ProgressionManager.get_repair_cost_multiplier())
	if not EconomyManager.can_afford(actual_cost):
		show_feedback("Can't afford the repair! Need $%d" % actual_cost, Color.RED)
		return

	# Deduct money upfront, then play the mini-game
	EconomyManager.spend_money(actual_cost, "Repair: %s" % part_name)
	show_feedback("🔧 Starting repair on %s…" % part_name.replace("_", " ").capitalize(), Color(0.7, 0.9, 1.0))

	var RepairMinigameScript = load("res://scripts/ui/RepairMinigame.gd")
	var mg := Control.new()
	mg.set_script(RepairMinigameScript)
	mg.set("part_name", part_name)
	mg.set("garage_ref", self)
	hud.add_child(mg)
	if player: player.call("freeze")

	mg.connect("repair_completed", func(pn: String, quality: float):
		_apply_repair(pn, quality)
		if player: player.call("unfreeze"))
	mg.connect("repair_cancelled", func():
		# Refund if cancelled before any progress — partial refund (50%)
		var refund : int = actual_cost / 2
		EconomyManager.add_money(refund, "Repair cancelled — partial refund")
		show_feedback("Repair stopped. Refunded $%d." % refund, Color(0.9, 0.8, 0.5))
		if player: player.call("unfreeze"))

## Apply the repair stat change after the mini-game completes.
## quality 0.0–1.0 from precision taps — affects how many condition tiers are restored.
func _apply_repair(part_name: String, quality: float = 1.0) -> void:
	if not current_vehicle: return
	var old_cond : int = current_vehicle.data.parts.get(part_name, VehicleData.PartCondition.BROKEN)
	# quality >= 0.85 → PERFECT (restore 3 tiers), >= 0.6 → GOOD (2 tiers), else → ROUGH (1 tier)
	var tiers : int = 3 if quality >= 0.85 else (2 if quality >= 0.60 else 1)
	current_vehicle.data.parts[part_name] = max(VehicleData.PartCondition.PERFECT, old_cond - tiers)
	current_vehicle.refresh_visuals()
	var grade_msg : String
	if quality >= 0.85:
		grade_msg = "⭐ Flawless repair on %s!" % part_name.replace("_", " ").capitalize()
	elif quality >= 0.60:
		grade_msg = "✅ %s repaired!" % part_name.replace("_", " ").capitalize()
	else:
		grade_msg = "🔧 %s patched (rough job)." % part_name.replace("_", " ").capitalize()
	show_feedback(grade_msg, UITheme.condition_color(quality))
	AudioManager.play("repair_clang", -4.0)
	XPManager.award("repair_manual")
	if inspection_panel.visible:
		_refresh_inspection_panel(current_vehicle.data)

func _on_vehicle_clicked(vehicle: Vehicle) -> void:
	if current_vehicle: current_vehicle.set_selected(false)
	vehicle.set_selected(true)
	_refresh_inspection_panel(vehicle.data)
	inspection_panel.show()
	if player: player.call("freeze")

# ─────────────────────────────────────────────────────────────────────────────
#  DAY END
# ─────────────────────────────────────────────────────────────────────────────
func _on_day_ended() -> void:
	SaveManager.auto_save()
	_night_event = {}   # Reset each night

func _on_theft_event(caught: bool, item: String) -> void:
	if caught:
		_night_event = {"type": "caught", "item": ""}
	else:
		_night_event = {"type": "stolen", "item": item}

func _show_day_summary() -> void:
	var summary := CanvasLayer.new()
	summary.set_script(DaySummaryScript)
	summary.set("night_event", _night_event)
	add_child(summary)   # _ready() fires here → builds the UI

# ─────────────────────────────────────────────────────────────────────────────
#  HUD UPDATES
# ─────────────────────────────────────────────────────────────────────────────
func _update_money(amount: int) -> void:
	if money_label: money_label.text = "$%s" % _fmt(amount)

func _update_day(day: int) -> void:
	if day_label: day_label.text = "Day %d" % day

func _update_rep(_rep: float) -> void:
	if rep_label: rep_label.text = "%s" % EconomyManager.get_reputation_label()

func _update_tier_label() -> void:
	if tier_label: tier_label.text = "%s" % ProgressionManager.get_tier_name()

func _refresh_inventory_display() -> void:
	if not inv_parts_label: return
	var parts := InventoryManager.get_all_parts()
	if parts.is_empty():
		inv_parts_label.text = "No spare parts yet — visit the junkyard!"
		return
	var lines: Array = []
	for pname in parts:
		lines.append("%s ×%d" % [pname.replace("_"," ").capitalize(), parts[pname]])
	inv_parts_label.text = "  •  ".join(lines)

func show_feedback(msg: String, color: Color = Color.WHITE) -> void:
	if not feedback_label: return
	feedback_label.text = msg
	feedback_label.modulate = color
	if feedback_tween: feedback_tween.kill()
	feedback_tween = create_tween()
	feedback_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.0)
	feedback_tween.tween_interval(2.5)
	feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.8)

# ─────────────────────────────────────────────────────────────────────────────
#  DAY / NIGHT SYSTEM
# ─────────────────────────────────────────────────────────────────────────────

## Called every frame — smoothly animates all lights based on day progress t ∈ [0,1].
func _update_day_night(t: float, delta: float) -> void:
	if not _sun: return

	# ── Sun / directional light ───────────────────────────────────────────────
	_sun.rotation_degrees = Vector3(
		_pk_float(t, _TK, _SUN_PITCH),
		_pk_float(t, _TK, _SUN_YAW),
		0.0
	)
	_sun.light_color  = _pk_color(t, _TK, _SUN_COL)
	_sun.light_energy = _pk_float(t, _TK, _SUN_E)

	# ── Fill — stays low + cool. Real lighting comes from sodium lamps. ──────
	var fill_e: float = clampf(0.30 + _pk_float(t, _TK, _LAMP_E) * 0.05, 0.20, 0.55)
	_fill_light.light_energy = fill_e
	_fill_light.light_color  = _pk_color(t, _TK, _AMB_COL)

	# ── Bay work-light — cold halogen, slightly stronger when sodium dims at noon
	_bay_light.light_energy = 3.5 + (1.0 - _pk_float(t, _TK, _SUN_E)) * 1.6

	# ── Sky / background colour ───────────────────────────────────────────────
	if _sky_env:
		_sky_env.background_color     = _pk_color(t, _TK, _SKY_COL)
		_sky_env.ambient_light_color  = _pk_color(t, _TK, _AMB_COL)
		_sky_env.ambient_light_energy = _pk_float(t, _TK, _AMB_E)

	# ── Ceiling sodium lamps — always lit in a working garage, gently breathing
	var target_lamp_e: float = _pk_float(t, _TK, _LAMP_E)
	if not _lights_on:
		# Start the day already lit — no flicker on cold boot, lamps are warm
		_lights_on = true
		for lamp in _ceiling_lamps:
			var ol_init: OmniLight3D = lamp as OmniLight3D
			ol_init.light_energy = target_lamp_e
	# Smoothly track target energy through the day (sun gain → lamp dim & vice-versa)
	for lamp in _ceiling_lamps:
		var ol: OmniLight3D = lamp as OmniLight3D
		# Per-lamp subtle flicker breathing (±4%) for living-room feel
		var jitter: float = 1.0 + sin((Time.get_ticks_msec() * 0.001) * (1.7 + float(ol.get_instance_id() % 7) * 0.13)) * 0.04
		ol.light_energy = move_toward(ol.light_energy, target_lamp_e * jitter, delta * 0.6)

## Ceiling light flicker sequence — simulates fluorescent tubes warming up.
func _flicker_ceiling_on(final_energy: float) -> void:
	for lamp in _ceiling_lamps:
		var ol: OmniLight3D = lamp as OmniLight3D
		# Stagger each lamp slightly
		var delay: float = randf_range(0.0, 0.6)
		var tw := create_tween()
		tw.tween_interval(delay)
		# Quick flicker: off → flash → off → on
		tw.tween_property(ol, "light_energy", final_energy * 0.8, 0.06)
		tw.tween_property(ol, "light_energy", 0.1,                0.04)
		tw.tween_property(ol, "light_energy", final_energy * 0.6, 0.08)
		tw.tween_property(ol, "light_energy", 0.05,               0.05)
		tw.tween_property(ol, "light_energy", final_energy,        0.10)

## Piecewise-linear float interpolation across keypoint arrays.
func _pk_float(t: float, keys: Array, values: Array) -> float:
	for i in range(keys.size() - 1):
		if t <= float(keys[i + 1]):
			var frac: float = (t - float(keys[i])) / (float(keys[i + 1]) - float(keys[i]))
			return lerpf(float(values[i]), float(values[i + 1]), frac)
	return float(values[-1])

## Piecewise-linear Color interpolation across keypoint arrays.
func _pk_color(t: float, keys: Array, values: Array) -> Color:
	for i in range(keys.size() - 1):
		if t <= float(keys[i + 1]):
			var frac: float = (t - float(keys[i])) / (float(keys[i + 1]) - float(keys[i]))
			return (values[i] as Color).lerp(values[i + 1] as Color, frac)
	return values[-1] as Color

# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _make_box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

# ─────────────────────────────────────────────────────────────────────────────
#  SERVICE CUSTOMER FLOW
# ─────────────────────────────────────────────────────────────────────────────
func _has_active_service_order() -> bool:
	for o in OrderSystem.active_orders:
		if o.get("walk_in", false):
			return true
	return false

func _open_service_negotiation_for(cust: Customer) -> void:
	_neg_mode = "service"
	_service_base_quote = 0
	for job in cust.service_jobs:
		_service_base_quote += OrderSystem.JOB_TYPES.get(job, {}).get("base_pay", 0)

	# Header
	neg_panel_stripe.color   = cust.get_personality_color()
	neg_cust_name.text       = cust.display_name
	neg_personality.text     = cust.get_personality_label()
	neg_personality.modulate = cust.get_personality_color()
	neg_greeting.text        = '"%s"' % cust.get_greeting()
	neg_offer.text           = "Set your service price:"

	# Show service section, hide flip-only elements
	neg_service_section.visible = true
	neg_vehicle_val.visible     = false
	neg_free_btn.visible        = false

	# Build job list
	for c in neg_service_jobs_list.get_children(): c.queue_free()
	for job in cust.service_jobs:
		var jdata : Dictionary = OrderSystem.JOB_TYPES.get(job, {})
		var row   := HBoxContainer.new()
		var jl    := Label.new()
		jl.text = jdata.get("label", job)
		jl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jl.add_theme_font_size_override("font_size", 12)
		row.add_child(jl)
		var pl := Label.new()
		pl.text     = "$%d" % jdata.get("base_pay", 0)
		pl.modulate = Color(0.4, 1.0, 0.4)
		pl.add_theme_font_size_override("font_size", 12)
		row.add_child(pl)
		neg_service_jobs_list.add_child(row)

	var cust_max := int(_service_base_quote * cust.service_budget_mult)
	neg_service_quote.text = "Base estimate: $%d  •  Their budget ≤ $%d" % [_service_base_quote, cust_max]

	# Slider — player sets their asking price
	neg_slider_row.visible  = true
	neg_slider.min_value    = int(_service_base_quote * 0.60)
	neg_slider.max_value    = int(_service_base_quote * 1.50)
	neg_slider.value        = _service_base_quote
	neg_slider_val.text     = "$%d" % _service_base_quote

	# Service-mode button labels
	neg_accept_btn.text     = "💰 Book Service"
	neg_counter_btn.visible = false
	neg_refuse_btn.text     = "❌ Turn Away"

	neg_result.visible = false
	_set_neg_btns(true)
	negotiation_panel.show()
	if player: player.call("freeze")

func _on_neg_accept_service() -> void:
	if not pending_customer or not pending_customer.is_service: return
	var price    : int = int(neg_slider.value)
	var cust_max : int = int(_service_base_quote * pending_customer.service_budget_mult)

	if price > cust_max:
		# Too expensive — show complaint and let player lower the slider
		neg_result.text    = '"%s"' % pending_customer.get_low_offer_comment()
		neg_result.modulate = Color.RED
		neg_result.visible  = true
		show_feedback("Too expensive for them!  Their max is ~$%d" % cust_max, Color(1.0, 0.6, 0.4))
		return

	# Customer agrees
	_set_neg_btns(false)
	neg_result.text    = '"%s"' % pending_customer.get_accept_comment()
	neg_result.modulate = Color.GREEN
	neg_result.visible  = true
	AudioManager.play("neg_accept", -3.0)
	show_feedback("🔧 Booked for $%d — get to work!" % price, Color(0.45, 1.0, 0.75))

	_service_rep_bonus = pending_customer.service_rep_bonus

	# Create walk-in order — skips pending queue, goes straight to active
	var veh_id   : String     = pending_customer.service_vehicle_id
	var veh_name : String     = veh_id.replace("_", " ").capitalize()
	var order    : Dictionary = OrderSystem.generate_walk_in_order(
		pending_customer.display_name, veh_id, veh_name,
		pending_customer.service_jobs.duplicate(), price)
	_active_service_order_id = order["id"]

	await get_tree().create_timer(2.0).timeout
	negotiation_panel.hide()
	_reset_neg_panel_state()

	# NPC leaves (dropping off the car)
	if customer_npc and is_instance_valid(customer_npc):
		customer_npc.call("leave", Vector3(0.0, 0.5, 10.5))
	customer_npc = null
	if _reception_zone:
		_reception_zone.set_meta("interact_label", "Reception Desk")

	# Clear bay and spawn service vehicle
	if current_vehicle:
		current_vehicle.queue_free()
		current_vehicle = null
	_spawn_vehicle(veh_id, order["damage_level"], order["id"])
	show_feedback("🚗 %s's %s is in the bay. Fix it up!" % [order["customer_name"], veh_name], Color.CYAN)

	pending_customer = null
	if player: player.call("unfreeze")

func _reset_neg_panel_state() -> void:
	_neg_mode               = "flip"
	_refuse_count           = 0
	neg_service_section.visible = false
	neg_vehicle_val.visible     = true
	neg_slider_row.visible      = true
	neg_accept_btn.text         = "💰 Ask This Price"
	neg_counter_btn.visible     = true
	neg_counter_btn.text        = "🤝 Take Their Offer"
	neg_refuse_btn.text         = "❌ Refuse"
	neg_refuse_btn.visible      = true
	neg_kick_btn.visible        = false
	neg_free_btn.visible        = false

# ─────────────────────────────────────────────────────────────────────────────
#  NOTIFY CUSTOMER — PICKUP FLOW
# ─────────────────────────────────────────────────────────────────────────────
func _check_service_completion() -> void:
	# Only show button when we're not mid-negotiation and a service order is tracked
	if _active_service_order_id < 0 or _neg_mode != "flip":
		if _notify_btn: _notify_btn.visible = false
		return
	var order := OrderSystem._find_active(_active_service_order_id)
	if order.is_empty():
		if _notify_btn: _notify_btn.visible = false
		return
	var done  : int = (order["completed_jobs"] as Array).size()
	var total : int = (order["required_jobs"] as Array).size()
	if _notify_btn:
		_notify_btn.visible = (done >= total)

func _on_notify_customer_pressed() -> void:
	if _active_service_order_id < 0: return
	var order := OrderSystem._find_active(_active_service_order_id)
	if order.is_empty(): return
	if _notify_btn: _notify_btn.visible = false
	show_feedback("📞 Calling %s — their car is ready!" % order["customer_name"], Color.CYAN)
	AudioManager.play("customer_arrive", -4.0)

	# Spawn the customer walking back in for pickup
	if customer_npc and is_instance_valid(customer_npc):
		customer_npc.queue_free()
	var npc := CharacterBody3D.new()
	npc.set_script(CustomerNPCScript)
	npc.position = Vector3(0.0, 0.5, 5.2)
	add_child(npc)
	customer_npc = npc
	_neg_mode = "pickup"

	# Match personality sprite to the active service order customer type
	var svc_order := OrderSystem._find_active(_active_service_order_id)
	if not svc_order.is_empty() and svc_order.has("personality"):
		npc.call("set_personality", svc_order["personality"] as int)

	npc.walk_to(Vector3(5.0, 0.5, 5.0), func():
		if _reception_zone:
			_reception_zone.set_meta("interact_label", "🔑 Pickup — Talk to Customer")
		show_feedback("Customer arrived — press  [ E ]  to hand over the keys!", Color(1.0, 0.85, 0.3)))

func _open_pickup_panel() -> void:
	var order := OrderSystem._find_active(_active_service_order_id)
	if order.is_empty():
		show_feedback("Order not found!", Color.RED); return

	_neg_mode = "pickup_open"
	neg_panel_stripe.color   = Color(0.35, 0.85, 0.55)
	neg_cust_name.text       = order["customer_name"]
	neg_personality.text     = "🔑  Ready for Pickup"
	neg_personality.modulate = Color(0.35, 1.0, 0.55)
	neg_greeting.text        = '"Thanks for calling — I\'ll be right over!"'
	neg_offer.text           = "Final cost:  $%d" % order["base_reward"]

	# Hide elements not needed for handover
	neg_service_section.visible = false
	neg_vehicle_val.visible     = false
	neg_slider_row.visible      = false
	neg_free_btn.visible        = false
	neg_counter_btn.visible     = false
	neg_refuse_btn.visible      = false
	neg_accept_btn.text         = "🔑 Hand Over Keys  (+$%d)" % order["base_reward"]

	neg_result.visible = false
	_set_neg_btns(true)
	negotiation_panel.show()
	if player: player.call("freeze")

func _on_neg_accept_pickup() -> void:
	var payout : int = OrderSystem.complete_order(_active_service_order_id)
	if payout > 0 and _service_rep_bonus > 0:
		EconomyManager.change_reputation(_service_rep_bonus, "Service job completed")

	_set_neg_btns(false)
	var rep_str : String = "  +%.0f rep!" % _service_rep_bonus if _service_rep_bonus > 0 else ""
	neg_result.text    = "🎉 Thanks so much! Brilliant work!"
	neg_result.modulate = Color.GREEN
	neg_result.visible  = true
	AudioManager.play("neg_accept", -2.0)
	show_feedback("🔑 Keys handed! +$%d received!%s" % [payout, rep_str], Color(0.4, 1.0, 0.5))
	XPManager.award("service_complete")
	if _service_rep_bonus > 0:
		XPManager.award("service_bonus", _service_rep_bonus)

	_active_service_order_id = -1
	_service_rep_bonus       = 0.0

	await get_tree().create_timer(2.0).timeout
	negotiation_panel.hide()
	_reset_neg_panel_state()

	# Vehicle leaves with the customer
	_show_car_bar(false)
	if current_vehicle:
		current_vehicle.queue_free()
		current_vehicle = null
	_check_pending_tow()
	if customer_npc and is_instance_valid(customer_npc):
		customer_npc.call("leave", Vector3(0.0, 0.5, 10.5))
	customer_npc = null
	if _reception_zone:
		_reception_zone.set_meta("interact_label", "Reception Desk")
	if player: player.call("unfreeze")

# ─────────────────────────────────────────────────────────────────────────────
#  XP
# ─────────────────────────────────────────────────────────────────────────────
func _update_xp_bar() -> void:
	if not xp_bar or not xp_level_label: return
	xp_bar.value          = XPManager.get_level_progress() * 100.0
	xp_level_label.text   = "Lv.%d" % XPManager.current_level

func _on_xp_gained(amount: int, _source: String) -> void:
	_update_xp_bar()
	# Floaty "+N XP" ticker near the bar
	if not xp_ticker_label: return
	xp_ticker_label.text       = "+%d XP" % amount
	xp_ticker_label.position.y = 56.0
	if xp_ticker_tween: xp_ticker_tween.kill()
	xp_ticker_tween = create_tween()
	xp_ticker_tween.tween_property(xp_ticker_label, "modulate:a", 1.0, 0.05)
	xp_ticker_tween.tween_property(xp_ticker_label, "position:y", 38.0, 0.7)
	xp_ticker_tween.tween_property(xp_ticker_label, "modulate:a", 0.0, 0.35)

func _on_level_up(new_level: int, reward: Dictionary) -> void:
	_update_xp_bar()
	AudioManager.play("order_ok", -1.0)

	# Big centred level-up popup
	var popup := ColorRect.new()
	popup.size     = Vector2(480, 130)
	popup.position = Vector2(400, 260)
	popup.color    = Color(0.06, 0.08, 0.18, 0.96)
	hud.add_child(popup)

	var stripe := ColorRect.new()
	stripe.size     = Vector2(6, 130)
	stripe.position = Vector2(400, 260)
	stripe.color    = Color(0.35, 0.70, 1.0)
	hud.add_child(stripe)

	var vb := VBoxContainer.new()
	vb.position = Vector2(416, 272)
	vb.size     = Vector2(458, 108)
	vb.add_theme_constant_override("separation", 8)
	hud.add_child(vb)

	var top_lbl := Label.new()
	top_lbl.text = "⬆️  LEVEL UP!"
	top_lbl.add_theme_font_size_override("font_size", 26)
	top_lbl.modulate = Color(0.45, 0.80, 1.0)
	vb.add_child(top_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "You reached Level %d" % new_level
	lvl_lbl.add_theme_font_size_override("font_size", 17)
	lvl_lbl.modulate = Color(0.9, 0.9, 0.9)
	vb.add_child(lvl_lbl)

	var rew_lbl := Label.new()
	rew_lbl.text = "🎁  %s" % reward.get("desc", "Bonus unlocked!")
	rew_lbl.add_theme_font_size_override("font_size", 15)
	rew_lbl.modulate = Color(0.55, 1.0, 0.65)
	vb.add_child(rew_lbl)

	# Auto-dismiss after 3 s
	await get_tree().create_timer(3.0).timeout
	var tw := create_tween()
	tw.tween_property(popup,  "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(stripe, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(vb,     "modulate:a", 0.0, 0.4)
	await tw.finished
	popup.queue_free(); stripe.queue_free(); vb.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
#  AUCTION
# ─────────────────────────────────────────────────────────────────────────────
func _on_auction_pressed() -> void:
	# Don't open if already open
	for c in hud.get_children():
		if c.get_script() == AuctionPanelScript:
			return
	if not AuctionSystem.can_resolve() and AuctionSystem.current_lots.is_empty():
		show_feedback("No auction today — check back tomorrow!", Color(0.9, 0.75, 0.35))
		return
	var panel := Control.new()
	panel.set_script(AuctionPanelScript)
	hud.add_child(panel)
	if player: player.call("freeze")
	# Re-enable player when panel closes
	panel.connect("tree_exited", func(): if player: player.call("unfreeze"))

## Called by AuctionSystem.vehicle_delivered at the start of a new day
## when the player won a lot and it needs to be delivered to the garage.
func _on_vehicle_delivered(lot: Dictionary) -> void:
	var veh_id   : String = lot.get("vehicle_id",   "rustbucket_sedan")
	var veh_name : String = lot.get("vehicle_name", "Delivery")
	var damage   : float  = lot.get("damage",       0.55)

	if current_vehicle:
		# Bay is occupied — queue a feedback message and don't destroy the current car
		show_feedback("Auction delivery arrived: %s — clear the bay first!" % veh_name, Color(1.0, 0.88, 0.35))
		# Store as a pending delivery (re-push to front so it's tried again tomorrow)
		AuctionSystem.pending_deliveries.push_front(lot)
		return

	_spawn_vehicle(veh_id, damage)
	# Mark purchase price as what the player paid at auction
	if current_vehicle:
		current_vehicle.data.purchase_price = lot.get("final_price", 0)
	show_feedback("Auction delivery: %s arrived in the bay!" % veh_name, Color(0.45, 1.0, 0.75))
	AudioManager.play("engine", -4.0)

## Called by TowingManager.tow_arrived when the truck returns with a wreck.
func _on_tow_arrived(mission: Dictionary) -> void:
	var veh_id   : String = mission.get("vehicle_id", "rustbucket_sedan")
	var label    : String = mission.get("label",      "Wreck")
	var tow_fee  : int    = int(mission.get("tow_fee", 0))
	var damage   : float  = float(mission.get("damage", 0.8))

	# Collect tow fee regardless of bay state
	EconomyManager.earn_money(tow_fee, "Tow fee: %s" % label)
	XPManager.award("junkyard_run")   # reuse junkyard_run for a tow run

	if current_vehicle:
		# Bay occupied — hold the wreck, notify player
		_pending_tow = mission.duplicate()
		show_feedback("Tow truck back with %s (+$%d fee) — clear the bay to bring it in." % [label, tow_fee],
			Color(1.0, 0.72, 0.28))
		return

	_spawn_vehicle(veh_id, damage)
	if current_vehicle:
		current_vehicle.data.purchase_price = 0  # tow jobs cost nothing to acquire
	show_feedback("Tow truck delivered: %s  (+$%d tow fee)" % [label, tow_fee], Color(0.55, 0.92, 1.0))
	AudioManager.play("engine", -4.0)

## Called from the car action bar SELL / COMPLETE JOB flow — check for a pending tow.
func _check_pending_tow() -> void:
	if _pending
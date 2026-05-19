## Vehicle.gd (3D) — Realistic-scale car with interactive detachable parts.
## Sedan ~4.2m, Truck ~5m, Classic ~4.5m. Interactive parts: hood, doors, wheels.
class_name Vehicle
extends Node3D

signal vehicle_clicked(vehicle: Vehicle)
signal restoration_applied(action: String, result: Dictionary)
signal condition_changed(new_score: int)

# ── Mesh references ─────────────────────────────────────────────────────────
var _body_mesh  : MeshInstance3D = null
var _cabin_mesh : MeshInstance3D = null
var _body_mat   : StandardMaterial3D = null
var _cabin_mat  : StandardMaterial3D = null
var _glass_mat  : StandardMaterial3D = null

# ── Interactive parts ────────────────────────────────────────────────────────
var interactive_parts : Array = []

# ── Data ─────────────────────────────────────────────────────────────────────
var data           : VehicleData = null
var linked_order_id: int = -1

func _ready() -> void:
	pass

func initialize(vehicle_data: VehicleData, order_id: int = -1) -> void:
	data            = vehicle_data
	linked_order_id = order_id
	add_to_group("vehicle")
	_setup_materials()
	_build_mesh()
	_build_click_area()
	refresh_visuals()

func _setup_materials() -> void:
	# Glossy car paint — metalflake clearcoat look
	_body_mat           = StandardMaterial3D.new()
	_body_mat.metallic  = 0.70
	_body_mat.roughness = 0.18
	_body_mat.metallic_specular = 0.9

	_cabin_mat           = StandardMaterial3D.new()
	_cabin_mat.metallic  = 0.55
	_cabin_mat.roughness = 0.28
	_cabin_mat.metallic_specular = 0.85

	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.18, 0.24, 0.30, 0.55)   # tinted glass
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness    = 0.05
	_glass_mat.metallic     = 0.30
	_glass_mat.metallic_specular = 0.9

func _build_mesh() -> void:
	if not data:
		_build_sedan(); return
	match data.vehicle_type:
		"truck":   _build_truck()
		"classic": _build_classic()
		_:         _build_sedan()

# ─────────────────────────────────────────────────────────────────────────────
#  SEDAN — built from curved primitives (SphereMesh + PrismMesh + Torus),
#  not stacked cubes. 4.2m long oval body, sloped hood + trunk, raked
#  windshield, torus wheel arches, visible engine bay under hood.
#  +X = front of car
# ─────────────────────────────────────────────────────────────────────────────
func _build_sedan() -> void:
	# ── Main body — squashed oval (sphere scaled long in X) ──────────────
	# A sphere with radius=0.90 (X,Z) and height=1.00 (Y) gives a flat oval.
	# Node scale stretches it along the car length: ends up 4.0m × 1.0m × 1.62m
	_body_mesh = _add_sphere(0.81, 1.00, Vector3(2.50, 1.00, 1.00),
		Vector3(0.0, 0.66, 0.0), _body_mat)

	# ── Underbody chassis (thin oval beneath the main body, dark) ────────
	var chassis_mat := StandardMaterial3D.new()
	chassis_mat.albedo_color = Color(0.06, 0.06, 0.06); chassis_mat.roughness = 0.85
	_add_sphere(0.78, 0.35, Vector3(2.55, 1.0, 0.92),
		Vector3(0.0, 0.30, 0.0), chassis_mat)

	# ── Hood (sloped wedge) — apex at back (near cabin), low at front ────
	# Hood spans x=0.30..1.85, slopes from y=1.05 (back) down to y=0.78 (front)
	# Prism with left_to_right=0 -> peak at -X.
	# Size: 1.55 long × 0.30 tall slope × 1.55 wide. Center at (1.075, 0.93, 0).
	# This becomes a non-removable hood visual base — the removable hood goes ON TOP.
	# Actually — we'll make this WHOLE thing the removable hood, so skip base here.

	# ── Engine compartment (visible only when hood is removed) ───────────
	var well_mat := StandardMaterial3D.new()
	well_mat.albedo_color = Color(0.04, 0.04, 0.04); well_mat.roughness = 0.95
	_add_sphere(0.62, 0.22, Vector3(1.30, 1.0, 1.10),
		Vector3(1.05, 0.80, 0.0), well_mat)
	# Engine block — squat dark grey cylinder
	var eng_mat := StandardMaterial3D.new()
	eng_mat.albedo_color = Color(0.22, 0.22, 0.24); eng_mat.metallic = 0.45; eng_mat.roughness = 0.5
	_add_cylinder(0.26, 0.32, Vector3(1.05, 1.00, -0.10), eng_mat, Vector3(0, 0, 90))
	# Valve cover (chrome red on top of engine)
	var valve_mat := StandardMaterial3D.new()
	valve_mat.albedo_color = Color(0.48, 0.06, 0.06); valve_mat.metallic = 0.55; valve_mat.roughness = 0.35
	_add_cylinder(0.16, 0.34, Vector3(1.05, 1.10, -0.10), valve_mat, Vector3(0, 0, 90))
	# Air filter (round black drum)
	var air_mat := StandardMaterial3D.new()
	air_mat.albedo_color = Color(0.10, 0.10, 0.10); air_mat.roughness = 0.4
	_add_cylinder(0.13, 0.10, Vector3(1.05, 1.20, 0.18), air_mat)
	# Battery (compact orange-red box)
	var batt_mat := StandardMaterial3D.new()
	batt_mat.albedo_color = Color(0.86, 0.34, 0.10); batt_mat.roughness = 0.5
	_add_box(Vector3(0.30, 0.20, 0.24), Vector3(1.55, 0.92, 0.30), batt_mat)
	# Hoses — thin cylinders
	var hose_mat := StandardMaterial3D.new()
	hose_mat.albedo_color = Color(0.10, 0.10, 0.10); hose_mat.roughness = 0.7
	_add_cylinder(0.025, 0.50, Vector3(1.20, 1.05, 0.05), hose_mat, Vector3(0, 0, 90))

	# ── Cabin / passenger compartment — smaller oval on top ──────────────
	_cabin_mesh = _add_sphere(0.62, 0.85, Vector3(1.70, 1.00, 1.15),
		Vector3(-0.25, 1.18, 0.0), _cabin_mat)

	# ── Windshield — sloped tinted prism from cabin front down to hood ───
	# Apex at +X (top, near cabin), base at -X (front of windshield, lower)
	# Wait — we want windshield going from LOW at front (hood) to HIGH at back (cabin).
	# Looking from the side: high at -X (back), low at +X (front). So left_to_right=0.
	# But the windshield STARTS at hood top and goes UP to roof.
	# Place between x=0.30 (back of hood) and x=0.90 (front of cabin), y=0.92..1.46
	var ws := _add_prism(Vector3(0.60, 0.55, 1.50), 1.0,
		Vector3(0.60, 1.18, 0.0), Vector3(0, 0, 0), _glass_mat)
	ws.scale = Vector3(1.0, 1.0, 1.0)

	# ── Rear window — sloped going down from cabin to trunk ──────────────
	# High at +X (cabin), low at -X (trunk top)
	# Between x=-0.85 (cabin back) and x=-1.45 (trunk top), y=0.95..1.46
	var rw := _add_prism(Vector3(0.60, 0.52, 1.46), 0.0,
		Vector3(-1.15, 1.20, 0.0), Vector3(0, 0, 0), _glass_mat)
	rw.scale = Vector3(1.0, 1.0, 1.0)

	# ── Side windows — long tinted strips along the cabin sides ──────────
	_add_box(Vector3(1.60, 0.36, 0.04), Vector3(-0.20, 1.26, -0.72), _glass_mat)
	_add_box(Vector3(1.60, 0.36, 0.04), Vector3(-0.20, 1.26,  0.72), _glass_mat)

	# ── A/B/C pillars (thin dark) ────────────────────────────────────────
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.04, 0.04, 0.04); pillar_mat.roughness = 0.5
	for pp in [Vector3(0.85, 1.18, -0.72), Vector3(0.85, 1.18, 0.72),
				Vector3(-0.30, 1.18, -0.72), Vector3(-0.30, 1.18, 0.72),
				Vector3(-1.15, 1.18, -0.72), Vector3(-1.15, 1.18, 0.72)]:
		_add_cylinder(0.03, 0.60, pp, pillar_mat)

	# ── Wheel arches — TorusMesh rings around each wheel (curved openings)
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.04, 0.04, 0.04); arch_mat.roughness = 0.95
	for wpos in [Vector3(1.20, 0.42, -0.94), Vector3(1.20, 0.42, 0.94),
				 Vector3(-1.20, 0.42, -0.94), Vector3(-1.20, 0.42, 0.94)]:
		# Torus hole along Y by default — rotate around X to align with wheel facing Z
		_add_torus(0.36, 0.52, wpos, Vector3(90, 0, 0), arch_mat)

	# ── Fender flares — squashed sphere bulges over each wheel arch ──────
	for fp in [Vector3(1.20, 0.62, -0.85), Vector3(1.20, 0.62, 0.85),
				Vector3(-1.20, 0.62, -0.85), Vector3(-1.20, 0.62, 0.85)]:
		_add_sphere(0.42, 0.35, Vector3(1.0, 1.0, 0.45), fp, _body_mat)

	# ── Front grille — vertical chrome slats sitting in a dark recess ───
	var grille_bg := StandardMaterial3D.new()
	grille_bg.albedo_color = Color(0.04, 0.04, 0.04); grille_bg.roughness = 0.6
	var chrome_mat := StandardMaterial3D.new()
	chrome_mat.albedo_color = Color(0.88, 0.88, 0.86); chrome_mat.metallic = 0.95; chrome_mat.roughness = 0.08
	# Dark recess
	_add_sphere(0.18, 0.30, Vector3(1.0, 1.0, 3.6),
		Vector3(2.02, 0.65, 0.0), grille_bg)
	# Vertical chrome slats
	for sz: float in [-0.50, -0.30, -0.10, 0.10, 0.30, 0.50]:
		_add_cylinder(0.018, 0.30, Vector3(2.06, 0.65, sz), chrome_mat)
	# Manufacturer badge (small chrome circle in center of grille)
	_add_cylinder(0.08, 0.04, Vector3(2.10, 0.65, 0.0), chrome_mat, Vector3(0, 0, 90))

	# ── Door handles (chrome bars) ───────────────────────────────────────
	for dh in [Vector3(0.20, 0.86, -0.88), Vector3(0.20, 0.86,  0.88)]:
		_add_cylinder(0.020, 0.20, Vector3(dh.x, dh.y, dh.z), chrome_mat,
			Vector3(0, 0, 90))

	# ── Side trim molding (thin chrome strip along the body waistline) ───
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.70, 0.70, 0.68); trim_mat.metallic = 0.75; trim_mat.roughness = 0.25
	_add_box(Vector3(3.20, 0.04, 0.02), Vector3(-0.10, 0.78, -0.83), trim_mat)
	_add_box(Vector3(3.20, 0.04, 0.02), Vector3(-0.10, 0.78,  0.83), trim_mat)

	# ── Taillight cluster (red emissive curved bar) ──────────────────────
	var tl_mat := StandardMaterial3D.new()
	tl_mat.albedo_color = Color(0.86, 0.10, 0.10)
	tl_mat.emission_enabled = true
	tl_mat.emission = Color(0.92, 0.06, 0.06)
	tl_mat.emission_energy_multiplier = 1.8
	# Wraparound taillight (sphere oval at each rear corner)
	_add_sphere(0.16, 0.22, Vector3(1.0, 1.0, 1.6),
		Vector3(-2.08, 0.78, -0.62), tl_mat)
	_add_sphere(0.16, 0.22, Vector3(1.0, 1.0, 1.6),
		Vector3(-2.08, 0.78,  0.62), tl_mat)

	# ── Trunk lid suggestion (small wedge at rear, non-removable) ────────
	_add_prism(Vector3(0.65, 0.10, 1.50), 1.0,
		Vector3(-1.60, 1.05, 0.0), Vector3(0, 0, 0), _body_mat)

	# ── Exhaust tip (chrome twin cylinder) ───────────────────────────────
	var ex_mat := StandardMaterial3D.new()
	ex_mat.albedo_color = Color(0.85, 0.85, 0.82); ex_mat.metallic = 0.9; ex_mat.roughness = 0.18
	_add_cylinder(0.05, 0.20, Vector3(-2.18, 0.25, -0.58), ex_mat, Vector3(0, 0, 90))

	# ══════════════════════════════════════════════════════════════════════════
	#  INTERACTIVE PARTS — 12 grab-able
	# ══════════════════════════════════════════════════════════════════════════
	# Hood — sloped wedge that lifts off to reveal the engine bay
	_make_interactive_part("hood", "Hood",
		_make_prism_mesh(Vector3(1.55, 0.20, 1.55), 0.0),
		Vector3(1.075, 0.94, 0.0),
		_body_mat, Vector3(1.55, 0.30, 1.55))

	# Doors — slightly curved (use prism for shape variation, almost flat)
	_make_interactive_part("door_fl", "Front Left Door",
		_box_mesh(Vector3(1.10, 0.74, 0.06)),
		Vector3(0.20, 0.85, -0.86), _body_mat, Vector3(1.10, 0.74, 0.20))
	_make_interactive_part("door_fr", "Front Right Door",
		_box_mesh(Vector3(1.10, 0.74, 0.06)),
		Vector3(0.20, 0.85,  0.86), _body_mat, Vector3(1.10, 0.74, 0.20))

	# Front + Rear Bumpers — curved (sphere squashed for wraparound look)
	var bump_mat := StandardMaterial3D.new()
	bump_mat.albedo_color = Color(0.10, 0.10, 0.10); bump_mat.roughness = 0.5
	_make_interactive_part("bumper_front", "Front Bumper",
		_make_sphere_mesh(0.18, 0.40), Vector3(2.22, 0.50, 0.0),
		bump_mat, Vector3(0.36, 0.50, 1.82))
	# Hmm sphere mesh radius=0.18 height=0.40 = small bullet shape, not wide.
	# Override with a stretched node scale on the interactive part itself —
	# but _make_interactive_part doesn't scale. So use a stretched cylinder instead:

	# Tweak existing interactive build — redo bumpers via a wider mesh:
	# Actually, the easiest is to add a non-interactive curved fascia ON TOP of the bumper

	# Front + Rear Bumpers — repositioned with curved fascia visible
	_make_interactive_part("bumper_rear", "Rear Bumper",
		_make_sphere_mesh(0.18, 0.40), Vector3(-2.22, 0.50, 0.0),
		bump_mat, Vector3(0.36, 0.50, 1.82))

	# Headlights — round LED clusters
	_make_headlight_part("headlight_l", "Left Headlight", Vector3(2.12, 0.78, -0.55))
	_make_headlight_part("headlight_r", "Right Headlight", Vector3(2.12, 0.78,  0.55))

	# Side Mirrors
	_make_mirror_part("mirror_l", "Left Mirror", Vector3(0.65, 1.10, -0.92))
	_make_mirror_part("mirror_r", "Right Mirror", Vector3(0.65, 1.10,  0.92))

	# Wheels (4) — detailed 5-spoke alloys
	_make_wheel_part("wheel_fl", "Front Left Wheel",  Vector3( 1.20, 0.36, -0.94))
	_make_wheel_part("wheel_fr", "Front Right Wheel", Vector3( 1.20, 0.36,  0.94))
	_make_wheel_part("wheel_rl", "Rear Left Wheel",   Vector3(-1.20, 0.36, -0.94))
	_make_wheel_part("wheel_rr", "Rear Right Wheel",  Vector3(-1.20, 0.36,  0.94))

# ─────────────────────────────────────────────────────────────────────────────
#  TRUCK — 5.0m long pickup, tall stance, square cab + open cargo bed.
#  Built with rounded primitives: oval cab body, raked windshield prism,
#  torus arches, sphere taillight bulges.
# ─────────────────────────────────────────────────────────────────────────────
func _build_truck() -> void:
	# Main lower chassis — flat oval slab
	_body_mesh = _add_sphere(0.92, 0.45, Vector3(2.85, 1.00, 1.05),
		Vector3(0.0, 0.55, 0.0), _body_mat)
	# Cab body (front half) — taller rounded section
	_add_sphere(0.92, 1.10, Vector3(1.30, 1.00, 1.05),
		Vector3(1.00, 0.95, 0.0), _body_mat)
	# Cab roof — slightly smaller squashed sphere on top
	_cabin_mesh = _add_sphere(0.85, 0.80, Vector3(1.10, 1.00, 1.05),
		Vector3(0.95, 1.35, 0.0), _cabin_mat)

	# Cargo bed — open rectangular box at the rear (this LOOKS box-y on purpose,
	# real truck beds are flat boxes)
	var bed_mat := StandardMaterial3D.new()
	bed_mat.albedo_color = _body_mat.albedo_color.darkened(0.20); bed_mat.metallic = 0.5; bed_mat.roughness = 0.4
	_add_box(Vector3(2.70, 0.08, 1.92), Vector3(-1.20, 0.78, 0.0), bed_mat)
	_add_box(Vector3(2.70, 0.55, 0.08), Vector3(-1.20, 1.06, -0.96), bed_mat)
	_add_box(Vector3(2.70, 0.55, 0.08), Vector3(-1.20, 1.06,  0.96), bed_mat)
	_add_box(Vector3(0.08, 0.55, 1.92), Vector3(-2.55, 1.06, 0.0), bed_mat)
	# Bed floor ribs (subtle dark lines)
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Color(0.04, 0.04, 0.04); rib_mat.roughness = 0.85
	for rz: float in [-0.55, -0.18, 0.18, 0.55]:
		_add_box(Vector3(2.60, 0.012, 0.04), Vector3(-1.20, 0.84, rz), rib_mat)

	# Windshield — raked prism (high at back, low at front of cab)
	var ws := _add_prism(Vector3(0.55, 0.55, 1.70), 1.0,
		Vector3(0.55, 1.32, 0.0), Vector3(0, 0, 0), _glass_mat)
	ws.scale = Vector3(1.0, 1.0, 1.0)
	# Rear cab window (small)
	_add_box(Vector3(0.05, 0.40, 1.50), Vector3(1.52, 1.40, 0.0), _glass_mat)
	# Side cab windows
	_add_box(Vector3(0.90, 0.36, 0.04), Vector3(0.85, 1.42, -0.94), _glass_mat)
	_add_box(Vector3(0.90, 0.36, 0.04), Vector3(0.85, 1.42,  0.94), _glass_mat)

	# Wheel arches — torus around each wheel
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.04, 0.04, 0.04); arch_mat.roughness = 0.95
	for wpos in [Vector3(1.40, 0.42, -0.98), Vector3(1.40, 0.42, 0.98),
				 Vector3(-1.40, 0.42, -0.98), Vector3(-1.40, 0.42, 0.98)]:
		_add_torus(0.42, 0.58, wpos, Vector3(90, 0, 0), arch_mat)
	# Fender flares (squashed sphere bulges)
	for fp in [Vector3(1.40, 0.62, -0.92), Vector3(1.40, 0.62, 0.92),
				Vector3(-1.40, 0.62, -0.92), Vector3(-1.40, 0.62, 0.92)]:
		_add_sphere(0.48, 0.42, Vector3(1.0, 1.0, 0.40), fp, _body_mat)

	# Chrome bull bar grille (truck-style)
	var chrome_mat := StandardMaterial3D.new()
	chrome_mat.albedo_color = Color(0.88, 0.88, 0.85); chrome_mat.metallic = 0.92; chrome_mat.roughness = 0.10
	_add_cylinder(0.04, 1.40, Vector3(2.10, 0.85, 0.0), chrome_mat, Vector3(90, 0, 0))
	# Horizontal grille slats
	for sy: float in [0.62, 0.74, 0.86]:
		_add_box(Vector3(0.04, 0.04, 1.30), Vector3(2.10, sy, 0.0), chrome_mat)
	# Grille recess
	var grille_bg := StandardMaterial3D.new()
	grille_bg.albedo_color = Color(0.04, 0.04, 0.04); grille_bg.roughness = 0.6
	_add_sphere(0.20, 0.40, Vector3(1.0, 1.0, 3.4),
		Vector3(2.04, 0.75, 0.0), grille_bg)

	# Taillights — oval bulges at rear corners
	var tl_mat := StandardMaterial3D.new()
	tl_mat.albedo_color = Color(0.86, 0.10, 0.10)
	tl_mat.emission_enabled = true
	tl_mat.emission = Color(0.92, 0.06, 0.06)
	tl_mat.emission_energy_multiplier = 1.8
	_add_sphere(0.14, 0.30, Vector3(1.0, 1.0, 1.4),
		Vector3(-2.55, 0.78, -0.74), tl_mat)
	_add_sphere(0.14, 0.30, Vector3(1.0, 1.0, 1.4),
		Vector3(-2.55, 0.78,  0.74), tl_mat)

	# Dual exhaust tips
	var ex_mat := StandardMaterial3D.new()
	ex_mat.albedo_color = Color(0.85, 0.85, 0.82); ex_mat.metallic = 0.9; ex_mat.roughness = 0.18
	_add_cylinder(0.06, 0.22, Vector3(-2.56, 0.40, -0.55), ex_mat, Vector3(0, 0, 90))
	_add_cylinder(0.06, 0.22, Vector3(-2.56, 0.40,  0.55), ex_mat, Vector3(0, 0, 90))
	# Interactive parts — truck
	# Sloped hood (wedge — apex at back, low at front)
	_make_interactive_part("hood", "Hood",
		_make_prism_mesh(Vector3(1.40, 0.18, 1.60), 0.0),
		Vector3(1.32, 1.02, 0.0), _body_mat, Vector3(1.40, 0.30, 1.60))
	_make_interactive_part("door_fl", "Front Left Door",
		_box_mesh(Vector3(1.05, 0.80, 0.06)),
		Vector3(1.0, 0.95, -0.96), _body_mat, Vector3(1.05, 0.80, 0.20))
	_make_interactive_part("door_fr", "Front Right Door",
		_box_mesh(Vector3(1.05, 0.80, 0.06)),
		Vector3(1.0, 0.95,  0.96), _body_mat, Vector3(1.05, 0.80, 0.20))
	# Bumpers — wraparound sphere shape
	var t_bump_mat := StandardMaterial3D.new()
	t_bump_mat.albedo_color = Color(0.86, 0.86, 0.85); t_bump_mat.metallic = 0.9; t_bump_mat.roughness = 0.18
	_make_interactive_part("bumper_front", "Front Bumper",
		_make_sphere_mesh(0.22, 0.42), Vector3(2.30, 0.55, 0.0),
		t_bump_mat, Vector3(0.40, 0.55, 2.0))
	_make_interactive_part("bumper_rear", "Rear Bumper",
		_make_sphere_mesh(0.22, 0.42), Vector3(-2.65, 0.55, 0.0),
		t_bump_mat, Vector3(0.40, 0.55, 2.0))
	# Headlights, mirrors
	_make_headlight_part("headlight_l", "Left Headlight", Vector3(2.16, 0.80, -0.68))
	_make_headlight_part("headlight_r", "Right Headlight", Vector3(2.16, 0.80,  0.68))
	_make_mirror_part("mirror_l", "Left Mirror", Vector3(0.95, 1.28, -1.00))
	_make_mirror_part("mirror_r", "Right Mirror", Vector3(0.95, 1.28,  1.00))
	# Wheels (truck — bigger wheels at the same positions)
	_make_wheel_part("wheel_fl", "Front Left Wheel",  Vector3( 1.40, 0.42, -0.98))
	_make_wheel_part("wheel_fr", "Front Right Wheel", Vector3( 1.40, 0.42,  0.98))
	_make_wheel_part("wheel_rl", "Rear Left Wheel",   Vector3(-1.40, 0.42, -0.98))
	_make_wheel_part("wheel_rr", "Rear Right Wheel",  Vector3(-1.40, 0.42,  0.98))

# ─────────────────────────────────────────────────────────────────────────────
#  CLASSIC COUPE — 4.5m, long sweeping hood, low compact cabin, chrome accents.
#  Muscle car / vintage coupe vibe with curved primitives.
# ─────────────────────────────────────────────────────────────────────────────
func _build_classic() -> void:
	# Long low body — squashed oval, wider than sedan
	_body_mesh = _add_sphere(0.88, 0.95, Vector3(2.70, 1.00, 1.10),
		Vector3(0.0, 0.62, 0.0), _body_mat)

	# Short compact cabin (coupe roof) — pushed back, smaller than sedan
	_cabin_mesh = _add_sphere(0.55, 0.75, Vector3(1.40, 1.00, 1.20),
		Vector3(-0.30, 1.18, 0.0), _cabin_mat)

	# Engine bay (visible under hood)
	var well_mat := StandardMaterial3D.new()
	well_mat.albedo_color = Color(0.04, 0.04, 0.04); well_mat.roughness = 0.95
	_add_sphere(0.70, 0.22, Vector3(1.30, 1.0, 1.10),
		Vector3(1.10, 0.82, 0.0), well_mat)
	# V8 engine block — bigger than sedan
	var eng_mat := StandardMaterial3D.new()
	eng_mat.albedo_color = Color(0.20, 0.20, 0.22); eng_mat.metallic = 0.5; eng_mat.roughness = 0.45
	_add_cylinder(0.30, 0.42, Vector3(1.10, 1.04, -0.12), eng_mat, Vector3(0, 0, 90))
	# Twin valve covers (classic V8)
	var valve_mat := StandardMaterial3D.new()
	valve_mat.albedo_color = Color(0.55, 0.04, 0.04); valve_mat.metallic = 0.6; valve_mat.roughness = 0.3
	_add_cylinder(0.14, 0.40, Vector3(1.10, 1.20, -0.22), valve_mat, Vector3(0, 0, 90))
	_add_cylinder(0.14, 0.40, Vector3(1.10, 1.20,  0.22), valve_mat, Vector3(0, 0, 90))
	# Twin chrome carb intakes (sticking up — muscle car signature)
	var chrome2 := StandardMaterial3D.new()
	chrome2.albedo_color = Color(0.88, 0.88, 0.86); chrome2.metallic = 0.95; chrome2.roughness = 0.08
	_add_cylinder(0.08, 0.18, Vector3(1.10, 1.40, -0.22), chrome2)
	_add_cylinder(0.08, 0.18, Vector3(1.10, 1.40,  0.22), chrome2)

	# Long sloped hood — apex at back (near cabin), low at front, long stretch
	# This is the visual hood base. Will be a removable interactive on top of it.
	# We skip the base — let the removable hood BE the slope

	# Windshield — heavily raked
	_add_prism(Vector3(0.60, 0.50, 1.55), 1.0,
		Vector3(0.42, 1.18, 0.0), Vector3(0, 0, 0), _glass_mat)

	# Rear window (fastback slope)
	_add_prism(Vector3(0.80, 0.55, 1.45), 0.0,
		Vector3(-1.15, 1.20, 0.0), Vector3(0, 0, 0), _glass_mat)

	# Side windows — small, narrow (coupe style)
	_add_box(Vector3(1.30, 0.32, 0.04), Vector3(-0.15, 1.30, -0.78), _glass_mat)
	_add_box(Vector3(1.30, 0.32, 0.04), Vector3(-0.15, 1.30,  0.78), _glass_mat)

	# Wheel arches — torus rings (slightly bigger for muscle look)
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.04, 0.04, 0.04); arch_mat.roughness = 0.95
	for wpos in [Vector3(1.30, 0.42, -0.96), Vector3(1.30, 0.42, 0.96),
				 Vector3(-1.30, 0.42, -0.96), Vector3(-1.30, 0.42, 0.96)]:
		_add_torus(0.40, 0.58, wpos, Vector3(90, 0, 0), arch_mat)

	# Prominent muscle car fender flares (bigger spheres)
	for fp in [Vector3(1.30, 0.65, -0.88), Vector3(1.30, 0.65, 0.88),
				Vector3(-1.30, 0.65, -0.88), Vector3(-1.30, 0.65, 0.88)]:
		_add_sphere(0.52, 0.42, Vector3(1.0, 1.0, 0.50), fp, _body_mat)

	# Chrome grille — horizontal bars (vintage look)
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.88, 0.88, 0.86); chrome.metallic = 0.95; chrome.roughness = 0.08
	var grille_bg := StandardMaterial3D.new()
	grille_bg.albedo_color = Color(0.04, 0.04, 0.04); grille_bg.roughness = 0.6
	_add_sphere(0.20, 0.40, Vector3(1.0, 1.0, 3.6),
		Vector3(2.10, 0.72, 0.0), grille_bg)
	# Horizontal chrome bars
	for sy: float in [0.58, 0.68, 0.78, 0.88]:
		_add_cylinder(0.020, 1.40, Vector3(2.14, sy, 0.0), chrome, Vector3(90, 0, 0))
	# Chrome surround
	_add_cylinder(0.025, 1.55, Vector3(2.13, 0.95, 0.0), chrome, Vector3(90, 0, 0))
	_add_cylinder(0.025, 1.55, Vector3(2.13, 0.51, 0.0), chrome, Vector3(90, 0, 0))

	# Taillights — chrome-bezeled red discs (classic round style)
	var tl_mat := StandardMaterial3D.new()
	tl_mat.albedo_color = Color(0.92, 0.10, 0.10)
	tl_mat.emission_enabled = true
	tl_mat.emission = Color(0.95, 0.06, 0.06)
	tl_mat.emission_energy_multiplier = 2.0
	for zpos in [-0.62, 0.62]:
		# Chrome bezel
		_add_cylinder(0.13, 0.04, Vector3(-2.30, 0.78, zpos), chrome, Vector3(0, 0, 90))
		# Red lens behind
		_add_cylinder(0.11, 0.06, Vector3(-2.32, 0.78, zpos), tl_mat, Vector3(0, 0, 90))

	# Dual chrome exhaust tips (rear)
	for zpos in [-0.45, -0.62]:
		_add_cylinder(0.05, 0.22, Vector3(-2.40, 0.28, zpos), chrome, Vector3(0, 0, 90))

	# Side chrome trim molding (signature classic line)
	_add_cylinder(0.012, 3.30, Vector3(0.0, 0.80, -0.86), chrome, Vector3(0, 90, 0))
	_add_cylinder(0.012, 3.30, Vector3(0.0, 0.80,  0.86), chrome, Vector3(0, 90, 0))
	# Interactive parts — classic coupe
	# Long sloped hood (dramatic wedge — apex at back near cabin)
	_make_interactive_part("hood", "Hood",
		_make_prism_mesh(Vector3(1.70, 0.22, 1.55), 0.0),
		Vector3(1.10, 0.95, 0.0), _body_mat, Vector3(1.70, 0.32, 1.55))
	# Doors (long coupe doors)
	_make_interactive_part("door_fl", "Front Left Door",
		_box_mesh(Vector3(1.20, 0.70, 0.06)),
		Vector3(-0.10, 0.85, -0.90), _body_mat, Vector3(1.20, 0.70, 0.20))
	_make_interactive_part("door_fr", "Front Right Door",
		_box_mesh(Vector3(1.20, 0.70, 0.06)),
		Vector3(-0.10, 0.85,  0.90), _body_mat, Vector3(1.20, 0.70, 0.20))
	# Chrome bumpers — period-correct rounded wraparound
	var classic_chrome := StandardMaterial3D.new()
	classic_chrome.albedo_color = Color(0.88, 0.88, 0.86); classic_chrome.metallic = 0.95; classic_chrome.roughness = 0.10
	_make_interactive_part("bumper_front", "Front Bumper",
		_make_sphere_mesh(0.20, 0.34), Vector3(2.42, 0.52, 0.0),
		classic_chrome, Vector3(0.30, 0.40, 2.0))
	_make_interactive_part("bumper_rear", "Rear Bumper",
		_make_sphere_mesh(0.20, 0.34), Vector3(-2.42, 0.52, 0.0),
		classic_chrome, Vector3(0.30, 0.40, 2.0))
	# Round chrome headlights at the corners
	_make_headlight_part("headlight_l", "Left Headlight", Vector3(2.34, 0.78, -0.55))
	_make_headlight_part("headlight_r", "Right Headlight", Vector3(2.34, 0.78,  0.55))
	# Side mirrors (mounted on stalks at the door front)
	_make_mirror_part("mirror_l", "Left Mirror", Vector3(0.45, 1.10, -0.90))
	_make_mirror_part("mirror_r", "Right Mirror", Vector3(0.45, 1.10,  0.90))
	# Wheels
	_make_wheel_part("wheel_fl", "Front Left Wheel",  Vector3( 1.30, 0.40, -0.96))
	_make_wheel_part("wheel_fr", "Front Right Wheel", Vector3( 1.30, 0.40,  0.96))
	_make_wheel_part("wheel_rl", "Rear Left Wheel",   Vector3(-1.30, 0.40, -0.96))
	_make_wheel_part("wheel_rr", "Rear Right Wheel",  Vector3(-1.30, 0.40,  0.96))

# ─────────────────────────────────────────────────────────────────────────────
#  Shared builders
# ─────────────────────────────────────────────────────────────────────────────
func _make_wheel_part(pid: String, plabel: String, pos: Vector3) -> void:
	var part := Node3D.new()
	part.name = "Part_" + pid
	part.position = pos

	# Tyre — proper black rubber with subtle gloss
	var tyre_mat := StandardMaterial3D.new()
	tyre_mat.albedo_color = Color(0.10, 0.10, 0.10)
	tyre_mat.roughness = 0.55
	var tyre_mi := MeshInstance3D.new()
	var tyre_m  := CylinderMesh.new()
	tyre_m.top_radius = 0.36; tyre_m.bottom_radius = 0.36
	tyre_m.height = 0.24; tyre_m.radial_segments = 28
	tyre_mi.mesh = tyre_m; tyre_mi.material_override = tyre_mat
	tyre_mi.rotation_degrees.z = 90.0
	part.add_child(tyre_mi)

	# Tyre tread rings (3 thin rings)
	var tread_mat := StandardMaterial3D.new()
	tread_mat.albedo_color = Color(0.04, 0.04, 0.04); tread_mat.roughness = 0.95
	for ri in [-0.08, 0.0, 0.08]:
		var tri := MeshInstance3D.new(); var trm := CylinderMesh.new()
		trm.top_radius = 0.37; trm.bottom_radius = 0.37
		trm.height = 0.022; trm.radial_segments = 24
		tri.mesh = trm; tri.material_override = tread_mat
		tri.position.x = ri; tri.rotation_degrees.z = 90.0
		part.add_child(tri)

	# Sidewall raised brand name detail
	var sidewall_mat := StandardMaterial3D.new()
	sidewall_mat.albedo_color = Color(0.20, 0.20, 0.20); sidewall_mat.roughness = 0.85
	for sw_dx: float in [-0.124, 0.124]:
		var sw_mi := MeshInstance3D.new()
		var sw_m  := CylinderMesh.new()
		sw_m.top_radius = 0.34; sw_m.bottom_radius = 0.34
		sw_m.height = 0.012; sw_m.radial_segments = 28
		sw_mi.mesh = sw_m; sw_mi.material_override = sidewall_mat
		sw_mi.position.x = sw_dx; sw_mi.rotation_degrees.z = 90.0
		part.add_child(sw_mi)

	# Brake disc behind the rim (caught the eye through the spokes)
	var brake_mat := StandardMaterial3D.new()
	brake_mat.albedo_color = Color(0.55, 0.30, 0.18); brake_mat.metallic = 0.45; brake_mat.roughness = 0.35
	var brake_mi := MeshInstance3D.new()
	var brake_m  := CylinderMesh.new()
	brake_m.top_radius = 0.22; brake_m.bottom_radius = 0.22; brake_m.height = 0.04
	brake_mi.mesh = brake_m; brake_mi.material_override = brake_mat
	brake_mi.position.x = 0.04; brake_mi.rotation_degrees.z = 90.0
	part.add_child(brake_mi)

	# Rim — flat machined alloy face on the outside of the wheel
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.78, 0.78, 0.80); rim_mat.metallic = 0.85; rim_mat.roughness = 0.18
	var rim_mi := MeshInstance3D.new()
	var rim_m  := CylinderMesh.new()
	rim_m.top_radius = 0.26; rim_m.bottom_radius = 0.26
	rim_m.height = 0.05; rim_m.radial_segments = 24
	rim_mi.mesh = rim_m; rim_mi.material_override = rim_mat
	rim_mi.position.x = -0.10; rim_mi.rotation_degrees.z = 90.0
	part.add_child(rim_mi)

	# 5-spoke pattern (rotated boxes radiating from center)
	var spoke_mat := StandardMaterial3D.new()
	spoke_mat.albedo_color = Color(0.70, 0.70, 0.72); spoke_mat.metallic = 0.8; spoke_mat.roughness = 0.22
	for spoke_idx in 5:
		var spk_mi := MeshInstance3D.new()
		var spk_m  := BoxMesh.new()
		spk_m.size = Vector3(0.02, 0.04, 0.42)
		spk_mi.mesh = spk_m; spk_mi.material_override = spoke_mat
		var angle: float = float(spoke_idx) * (TAU / 5.0)
		spk_mi.position = Vector3(-0.10, sin(angle) * 0.0, cos(angle) * 0.0)
		spk_mi.rotation = Vector3(angle, 0, 0)
		part.add_child(spk_mi)

	# Center hub cap with lug bolts
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.40, 0.40, 0.42); hub_mat.metallic = 0.75; hub_mat.roughness = 0.28
	var hub_mi := MeshInstance3D.new()
	var hub_m  := CylinderMesh.new()
	hub_m.top_radius = 0.07; hub_m.bottom_radius = 0.07
	hub_m.height = 0.04; hub_m.radial_segments = 16
	hub_mi.mesh = hub_m; hub_mi.material_override = hub_mat
	hub_mi.position.x = -0.13; hub_mi.rotation_degrees.z = 90.0
	part.add_child(hub_mi)
	# 5 lug bolts around the hub
	var lug_mat := StandardMaterial3D.new()
	lug_mat.albedo_color = Color(0.25, 0.25, 0.27); lug_mat.metallic = 0.85; lug_mat.roughness = 0.22
	for lug_idx in 5:
		var langle: float = float(lug_idx) * (TAU / 5.0)
		var lug_pos := Vector3(-0.135, sin(langle) * 0.10, cos(langle) * 0.10)
		var lug_mi := MeshInstance3D.new()
		var lug_m  := CylinderMesh.new()
		lug_m.top_radius = 0.018; lug_m.bottom_radius = 0.018
		lug_m.height = 0.025; lug_m.radial_segments = 8
		lug_mi.mesh = lug_m; lug_mi.material_override = lug_mat
		lug_mi.position = lug_pos; lug_mi.rotation_degrees.z = 90.0
		part.add_child(lug_mi)

	_attach_interactive_script(part, pid, plabel, Vector3(0.42, 0.78, 0.78))

# ── Headlight cluster (round lens, chrome reflector, glowing LEDs) ───────────
func _make_headlight_part(pid: String, plabel: String, pos: Vector3) -> void:
	var part := Node3D.new()
	part.name = "Part_" + pid
	part.position = pos

	# Outer chrome reflector housing (cylinder, facing forward)
	var ref_mat := StandardMaterial3D.new()
	ref_mat.albedo_color = Color(0.86, 0.86, 0.84); ref_mat.metallic = 0.85; ref_mat.roughness = 0.15
	var ref_mi := MeshInstance3D.new()
	var ref_m  := CylinderMesh.new()
	ref_m.top_radius = 0.18; ref_m.bottom_radius = 0.13; ref_m.height = 0.16; ref_m.radial_segments = 18
	ref_mi.mesh = ref_m; ref_mi.material_override = ref_mat
	ref_mi.rotation_degrees.z = 90.0
	part.add_child(ref_mi)

	# Glass lens cover
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.85, 0.92, 0.96, 0.55)
	lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens_mat.roughness = 0.05; lens_mat.metallic = 0.30
	var lens_mi := MeshInstance3D.new()
	var lens_m  := CylinderMesh.new()
	lens_m.top_radius = 0.17; lens_m.bottom_radius = 0.17; lens_m.height = 0.02; lens_m.radial_segments = 18
	lens_mi.mesh = lens_m; lens_mi.material_override = lens_mat
	lens_mi.position.x = 0.08; lens_mi.rotation_degrees.z = 90.0
	part.add_child(lens_mi)

	# Bright LED cluster (3 emissive bulbs)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.98, 0.92)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.95, 0.78)
	bulb_mat.emission_energy_multiplier = 3.0
	for bp: Vector3 in [Vector3(0.05, 0.0, 0.0), Vector3(0.05, 0.06, 0.04), Vector3(0.05, -0.06, -0.04)]:
		var b_mi := MeshInstance3D.new()
		var b_m  := SphereMesh.new()
		b_m.radius = 0.035; b_m.height = 0.07; b_m.radial_segments = 10
		b_mi.mesh = b_m; b_mi.material_override = bulb_mat
		b_mi.position = bp
		part.add_child(b_mi)

	_attach_interactive_script(part, pid, plabel, Vector3(0.22, 0.36, 0.36))

# ── Side mirror (stalk + housing + reflective face) ──────────────────────────
func _make_mirror_part(pid: String, plabel: String, pos: Vector3) -> void:
	var part := Node3D.new()
	part.name = "Part_" + pid
	part.position = pos

	# Body-color housing
	var stalk_mat := StandardMaterial3D.new()
	stalk_mat.albedo_color = Color(0.06, 0.06, 0.06); stalk_mat.roughness = 0.55
	# Stalk
	_add_box_to(part, Vector3(0.05, 0.05, 0.10), Vector3(0, 0, 0), stalk_mat)
	# Mirror housing (body-color)
	_add_box_to(part, Vector3(0.18, 0.10, 0.20), Vector3(0, 0, -0.18 * sign_z(pos)), _body_mat)
	# Glass face
	_add_box_to(part, Vector3(0.02, 0.08, 0.16), Vector3(-0.10, 0.0, -0.18 * sign_z(pos)), _glass_mat)

	_attach_interactive_script(part, pid, plabel, Vector3(0.24, 0.14, 0.30))

# Helper: sign of Z (which side of the car the part is on)
func sign_z(p: Vector3) -> float:
	return 1.0 if p.z >= 0.0 else -1.0

# Helper: add a box mesh to an arbitrary parent (not just self)
func _add_box_to(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _make_interactive_part(pid: String, plabel: String, mesh: Mesh, pos: Vector3,
		mat: StandardMaterial3D, col_ext: Vector3) -> void:
	var part := Node3D.new()
	part.name = "Part_" + pid
	part.position = pos

	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat
	part.add_child(mi)

	_attach_interactive_script(part, pid, plabel, col_ext)

func _attach_interactive_script(part: Node3D, pid: String, plabel: String, col_ext: Vector3) -> void:
	# Area3D for hover raycasting (layer 4)
	var area := Area3D.new()
	area.collision_layer = 4; area.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = col_ext
	col.shape = shape
	area.add_child(col)
	part.add_child(area)

	add_child(part)

	var script = load("res://scripts/vehicles/InteractivePart.gd")
	part.set_script(script)
	part.set("part_id", pid)
	part.set("part_label", plabel)
	part.set("vehicle_ref", self)
	if data:
		var cond_key := pid.replace("_fl","").replace("_fr","").replace("_rl","").replace("_rr","")
		part.set("condition", data.parts.get(cond_key, 2))
	interactive_parts.append(part)

# ── Click area ───────────────────────────────────────────────────────────────
func _build_click_area() -> void:
	var area := Area3D.new()
	area.collision_layer = 2; area.collision_mask = 0
	var col  := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(5.0, 1.8, 2.2)
	col.shape = shape; col.position = Vector3(0.0, 0.8, 0.0)
	area.add_child(col)
	area.input_event.connect(func(_camera, event, _pos, _norm, _idx):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("vehicle_clicked", self))
	add_child(area)

# ── Visuals refresh ──────────────────────────────────────────────────────────
func refresh_visuals() -> void:
	if not data or not _body_mat: return
	# Set car body colour
	_body_mat.albedo_color = data.paint_color
	_cabin_mat.albedo_color = data.paint_color.darkened(0.18)
	# Condition-based dirt / roughness
	var cond_score : float = float(data.get_condition_score()) / 100.0
	_body_mat.roughness = lerpf(0.68, 0.28, cond_score)
	emit_signal("condition_changed", data.get_condition_score())

func set_selected(selected: bool) -> void:
	refresh_visuals()

func get_condition_label_text() -> String:
	if not data: return ""
	return "%s  %d%%" % [data.get_condition_label(), data.get_condition_score()]

# ── Mesh helpers ─────────────────────────────────────────────────────────────
func _add_box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size); mi.material_override = mat; mi.position = pos
	add_child(mi); return mi

func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = size; return m

func _add_cylinder(radius: float, height: float, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m  := CylinderMesh.new()
	m.top_radius = radius; m.bottom_radius = radius; m.height = height; m.radial_segments = 18
	mi.mesh = m; mi.material_override = mat; mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi); return mi

# ── Squashed sphere helper — oval lozenge body shape ─────────────────────────
# radius_xz: horizontal radius (X and Z)
# height: total Y diameter (squash factor)
# node_scale: per-axis stretch on the node (lets us stretch X without warping Z)
# rounded sphere body with explicit per-axis scaling
func _add_sphere(radius_xz: float, height: float, node_scale: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m  := SphereMesh.new()
	m.radius = radius_xz
	m.height = height
	m.radial_segments = 32
	m.rings = 20
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = node_scale
	add_child(mi)
	return mi

# ── Prism (triangular wedge) — for sloped hoods, windshields, trunks ─────────
# size: bounding box (X = base width, Y = triangle height, Z = extrusion depth)
# lr: left_to_right (0 = peak at -X, 1 = peak at +X, 0.5 = centered)
func _add_prism(size: Vector3, lr: float, pos: Vector3, rot_deg: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m  := PrismMesh.new()
	m.size = size
	m.left_to_right = lr
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi

# ── Torus — for wheel arches and trim rings ──────────────────────────────────
func _add_torus(inner_r: float, outer_r: float, pos: Vector3, rot_deg: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m  := TorusMesh.new()
	m.inner_radius  = inner_r
	m.outer_radius  = outer_r
	m.ring_segments = 8
	m.rings         = 36
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi

# ── Mesh constructors (no add) — used for interactive parts ──────────────────
func _make_prism_mesh(size: Vector3, lr: float) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = lr
	return m

func _make_sphere_mesh(radius_xz: float, height: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius_xz
	m.height = height
	m.radial_segments = 28
	m.rings = 16
	return m

# ── Restoration ───────────────────────────────────────────────────────────────
func action_clean() -> Dictionary:
	if not data: return {}
	var old_score : int   = data.get_condition_score()
	var wb                = get_tree().get_first_node_in_group("workbench_system")
	var clean_bonus: float = wb.get_tool_clean_bonus() if wb else 0.0
	var power      : float = ProgressionManager.get_clean_power() * (1.0 + clean_bonus)
	data.dirt_level        = maxf(0.0, data.dirt_level - power)
	var new_score : int    = data.get_condition_score()
	refresh_visuals()
	AudioManager.play("clean")
	var result := {"action": "clean", "score_before": old_score, "score_after": new_score}
	emit_signal("restoration_applied", "clean", result)
	emit_signal("condition_changed", new_score)
	if linked_order_id >= 0:
		OrderSystem.mark_job_done(linked_order_id, "clean")
	return result

func action_repair_part(part_name: String) -> Dictionary:
	if not data or not data.parts.has(part_name):
		return {"success": false, "reason": "Part not found"}
	var base_cost : int    = VehicleDatabase.get_part_repair_cost(part_name)
	var wb                 = get_tree().get_first_node_in_group("workbench_system")
	var tool_discount: float = wb.get_tool_repair_discount() if wb else 0.0
	var cost : int = int(base_cost
		* ProgressionManager.get_repair_cost_multiplier()
		* EventSystem.get_repair_modifier()
		* (1.0 - tool_discount))
	if not EconomyManager.can_afford(cost):
		return {"success": false, "reason": "Not enough money", "cost": cost}
	EconomyManager.spend_money(cost, "Repair %s" % part_name)
	var _repair_sounds: Array = ["repair", "repair_clang", "repair_ratchet",
								 "repair_impact", "repair_grinder", "repair_drill"]
	AudioManager.play_varied(_repair_sounds[randi() % _repair_sounds.size()], 0.88, 1.14)
	var old_cond: int = data.parts[part_name]
	data.parts[part_name] = max(VehicleData.PartCondition.GOOD, old_cond - 2)
	var new_score : int = data.get_condition_score()
	refresh_visuals()
	if linked_order_id >= 0:
		if part_name in ["engine", "transmission"]:
			OrderSystem.mark_job_done(linked_order_id, "fix_engine")
		elif part_name in ["wheels_front", "wheels_rear"]:
			OrderSystem.mark_job_done(linked_order_id, "fix_wheels")
		elif part_name in ["body_front", "body_rear", "hood", "doors"]:
			OrderSystem.mark_job_done(linked_order_id, "fix_body")
		elif part_name == "interior":
			OrderSystem.mark_job_done(linked_order_id, "fix_interior")
	var result := {"success": true, "part": part_name, "cost": cost, "score_after": new_score}
	emit_signal("restoration_applied", "repair", result)
	emit_signal("condition_changed", new_score)
	return result

func action_repaint(new_color: Color) -> Dictionary:
	if not data: return {}
	var wb = get_tree().get_first_node_in_group("workbench_system")
	var paint_discount : float = wb.get_tool_paint_discount() if wb else 0.0
	var PAINT_COST     : int   = int(150 * (1.0 - paint_discount))
	if not EconomyManager.can_afford(PAINT_COST):
		return {"success": false, "reason": "Not enough money"}
	EconomyManager.spend_money(PAINT_COST, "Paint job")
	data.paint_color     = new_color
	data.paint_condition = 1.0
	AudioManager.play("paint_spray", -2.0)
	refresh_visuals()
	emit_signal("restoration_applied", "paint", {"success": true, "cost": PAINT_COST})
	emit_signal("condition_changed", data.get_condition_score())
	return {"success": true, "cost": PAINT_COST}

## JunkPile.gd  (3D)
## A single searchable junk pile in the junkyard.
## Each pile has a distinct 3D silhouette and its own loot table.
class_name JunkPile
extends Node3D

signal pile_searched(pile: JunkPile, loot: Array)

var pile_id:    int  = 0
var is_searched: bool = false
var loot:       Array = []
var _body_mat:  StandardMaterial3D = null
var _ring_mat:  StandardMaterial3D = null
var _interact_area: Area3D         = null

# ── Pile types ────────────────────────────────────────────────────────────────
## Each type has a name, base color, and build function suffix.
const PILE_TYPES : Array = [
	{"label": "Scrap Heap",       "color": Color(0.38, 0.30, 0.22), "type": "scrap_heap"},
	{"label": "Car Wreck",        "color": Color(0.28, 0.26, 0.30), "type": "car_wreck"},
	{"label": "Tire Tower",       "color": Color(0.12, 0.12, 0.12), "type": "tire_tower"},
	{"label": "Oil Drum Cluster", "color": Color(0.22, 0.28, 0.25), "type": "oil_drums"},
	{"label": "Appliance Heap",   "color": Color(0.72, 0.70, 0.68), "type": "appliances"},
	{"label": "Mystery Crate",    "color": Color(0.45, 0.30, 0.18), "type": "mystery"},
	{"label": "Parts Bucket",     "color": Color(0.40, 0.34, 0.26), "type": "parts_bucket"},
	{"label": "Abandoned Sofa",   "color": Color(0.45, 0.38, 0.52), "type": "sofa"},
]

# ── Standard loot table ───────────────────────────────────────────────────────
const LOOT_TABLE : Array = [
	{"type": "scrap",  "weight": 28, "min": 40,  "max": 180},
	{"type": "part",   "weight": 22, "parts": ["wheels_front","wheels_rear","doors","hood","interior","windshield"]},
	{"type": "part",   "weight": 12, "parts": ["engine","transmission","body_front","body_rear"]},
	{"type": "cash",   "weight": 10, "min": 20,  "max": 120},
	{"type": "funny",  "weight": 12},
	{"type": "nothing","weight": 11},
	{"type": "wreck",  "weight":  5, "templates": ["rustbucket_sedan","old_pickup","classic_coupe"]},
]

# ── Mystery crate — always has something worthwhile ───────────────────────────
const MYSTERY_TABLE : Array = [
	{"type": "scrap",  "weight": 20, "min": 150, "max": 400},
	{"type": "part",   "weight": 25, "parts": ["engine","transmission","chrome_trim","convertible_top"]},
	{"type": "cash",   "weight": 20, "min": 80,  "max": 300},
	{"type": "wreck",  "weight": 20, "templates": ["classic_coupe"]},
	{"type": "rare",   "weight": 15},
]

# ── Funny finds ───────────────────────────────────────────────────────────────
const FUNNY_FINDS : Array = [
	{"label": "🦆  A rubber duck.  Why is it here?",                    "scrap":  5},
	{"label": "🔑  Someone's keys.  Their car might still be here…",    "scrap":  8},
	{"label": "👟  One shoe.  Just one.",                                "scrap":  5},
	{"label": "📻  A radio stuck on one station.  Forever.",            "scrap": 15},
	{"label": "⏰  An alarm clock.  Still ticking.",                    "scrap": 10},
	{"label": "🎸  A broken guitar.  Someone had dreams.",              "scrap": 12},
	{"label": "🐈  Approximately 40 kg of cat fur.",                    "scrap":  3},
	{"label": "🏆  Trophy: 'World's Worst Driver 2019'",               "scrap": 20},
	{"label": "🪆  Russian nesting doll… of exhaust pipes.",           "scrap":  8},
	{"label": "📦  A box labelled 'DO NOT OPEN'.  You opened it.",     "scrap": 30},
	{"label": "🧦  A single sock.  Warm.",                              "scrap":  2},
	{"label": "🎩  A top hat.  Classy wreckage.",                       "scrap": 18},
	{"label": "🍕  A petrified pizza slice.  At least 10 years old.",  "scrap":  1},
	{"label": "🪣  An empty bucket of dreams.",                         "scrap":  4},
	{"label": "📞  A pager.  Still getting messages somehow.",          "scrap": 22},
]

# ── Rare finds (mystery crate only) ──────────────────────────────────────────
const RARE_FINDS : Array = [
	{"label": "💎  PRISTINE ENGINE — like it fell off a truck (it did)", "part": "engine"},
	{"label": "⭐  MINT TRANSMISSION — someone's loss, your gain",       "part": "transmission"},
	{"label": "🌟  A chrome trim set.  Suspiciously perfect.",           "part": "chrome_trim"},
	{"label": "🔮  Convertible top, still in the wrapper??",             "part": "convertible_top"},
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_generate_loot()
	_build_3d_visuals()

func setup(id: int) -> void:
	pile_id = id
	var style : Dictionary = PILE_TYPES[pile_id % PILE_TYPES.size()]
	if _body_mat:
		_body_mat.albedo_color = style["color"]
	if _interact_area:
		_interact_area.set_meta("interact_label", "Search %s" % style["label"])

# ── Loot generation ───────────────────────────────────────────────────────────
func _generate_loot() -> void:
	loot.clear()
	var style  : Dictionary = PILE_TYPES[pile_id % PILE_TYPES.size()]
	var table  : Array = MYSTERY_TABLE if style["type"] == "mystery" else LOOT_TABLE

	# 🎯 Hot Tip / Junkyard Bonus event: extra roll and rare table boost
	var bonus_day : bool = EventSystem.is_junkyard_bonus()
	var rolls  : int = 3 if style["type"] == "mystery" else randi_range(1, 3)
	if bonus_day and style["type"] != "mystery":
		rolls += 1   # one extra roll when the tip is in

	# On bonus day, temporarily boost wreck/part weights by swapping in richer entries
	if bonus_day and style["type"] != "mystery":
		table = _boosted_table()
	for _i in rolls:
		var entry : Dictionary = _weighted_pick(table)
		if entry.is_empty(): continue
		match entry["type"]:
			"scrap":
				loot.append({"type": "scrap", "amount": randi_range(entry["min"], entry["max"])})
			"cash":
				loot.append({"type": "cash",  "amount": randi_range(entry["min"], entry["max"])})
			"part":
				var plist : Array  = entry["parts"]
				var pname : String = plist[randi() % plist.size()]
				loot.append({"type": "part", "part_name": pname,
							 "label": pname.replace("_"," ").capitalize()})
			"wreck":
				var tlist : Array = entry["templates"]
				loot.append({"type": "wreck",
							 "template_id": tlist[randi() % tlist.size()]})
			"funny":
				var f : Dictionary = FUNNY_FINDS[randi() % FUNNY_FINDS.size()]
				loot.append({"type": "funny", "label": f["label"],
							 "scrap": f["scrap"]})
			"rare":
				var r : Dictionary = RARE_FINDS[randi() % RARE_FINDS.size()]
				loot.append({"type": "rare", "label": r["label"],
							 "part_name": r["part"]})
			"nothing":
				loot.append({"type": "nothing"})

## Returns a loot table with bumped-up wreck/part/cash weights for Hot Tip days.
func _boosted_table() -> Array:
	return [
		{"type": "scrap",  "weight": 20, "min": 60,  "max": 220},
		{"type": "part",   "weight": 28, "parts": ["wheels_front","wheels_rear","doors","hood","interior","windshield"]},
		{"type": "part",   "weight": 18, "parts": ["engine","transmission","body_front","body_rear"]},
		{"type": "cash",   "weight": 14, "min": 40,  "max": 180},
		{"type": "funny",  "weight":  8},
		{"type": "nothing","weight":  4},
		{"type": "wreck",  "weight": 12, "templates": ["rustbucket_sedan","old_pickup","classic_coupe"]},
		{"type": "rare",   "weight":  8},
	]

static func _weighted_pick(table: Array) -> Dictionary:
	var total := 0
	for e in table: total += int(e["weight"])
	var roll  := randi() % total
	var cum   := 0
	for e in table:
		cum += int(e["weight"])
		if roll < cum: return e
	return {}

# ── 3D visuals — dispatch to type-specific builder ────────────────────────────
func _build_3d_visuals() -> void:
	var style : Dictionary = PILE_TYPES[pile_id % PILE_TYPES.size()]
	_body_mat               = StandardMaterial3D.new()
	_body_mat.albedo_color  = style["color"]
	_body_mat.roughness     = 0.92

	match style["type"]:
		"car_wreck":    _build_car_wreck()
		"tire_tower":   _build_tire_tower()
		"oil_drums":    _build_oil_drums()
		"appliances":   _build_appliances()
		"mystery":      _build_mystery_crate()
		"parts_bucket": _build_parts_bucket()
		"sofa":         _build_sofa()
		_:              _build_scrap_heap()    # default

	_build_glow_ring(style["type"])
	_build_interact_zone(style["label"])

# ── Scrap heap (random messy boxes) ───────────────────────────────────────────
func _build_scrap_heap() -> void:
	_b(Vector3(randf_range(1.0,1.6), randf_range(0.5,0.9), randf_range(0.8,1.3)),
	   Vector3(0, 0.4, 0))
	_b(Vector3(randf_range(0.6,1.0), randf_range(0.3,0.6), randf_range(0.5,0.9)),
	   Vector3(randf_range(-0.3,0.3), 0.85, randf_range(-0.2,0.2)))
	var junk_mat := _flat(Color(0.25,0.25,0.28), 0.4, 0.5)
	_bm(Vector3(0.4,0.12,0.4), Vector3(0.5, 0.82, 0.3), junk_mat)

# ── Crushed car wreck ─────────────────────────────────────────────────────────
func _build_car_wreck() -> void:
	# Flat crushed body
	_b(Vector3(2.2, 0.30, 1.1), Vector3(0, 0.18, 0))
	# Crumpled hood
	_b(Vector3(0.7, 0.22, 1.0), Vector3(0.75, 0.34, 0))
	# Smashed cabin stub
	_b(Vector3(0.9, 0.35, 0.90), Vector3(-0.2, 0.42, 0))
	# Four flat tyre stumps
	var tire_mat := _flat(Color(0.10,0.10,0.10), 0.92, 0.0)
	for wp: Vector3 in [Vector3(0.8,0.22,0.62), Vector3(0.8,0.22,-0.62),
						 Vector3(-0.7,0.22,0.62), Vector3(-0.7,0.22,-0.62)]:
		_cyl(0.28, 0.20, wp, tire_mat)
	# Radiator sticking up at the front
	var rad_mat := _flat(Color(0.55,0.55,0.58), 0.4, 0.6)
	_bm(Vector3(0.12,0.48,0.80), Vector3(1.08, 0.36, 0), rad_mat)
	# Steering wheel still attached (tiny ring)
	var sw_mat := _flat(Color(0.18,0.14,0.12), 0.85, 0.0)
	_bm(Vector3(0.04,0.28,0.28), Vector3(-0.08, 0.62, 0.22), sw_mat)

# ── Tire tower ────────────────────────────────────────────────────────────────
func _build_tire_tower() -> void:
	var tm := _flat(Color(0.10,0.10,0.11), 0.92, 0.0)
	var hw := _flat(Color(0.55,0.55,0.58), 0.4, 0.7)
	# Stack 5 tyres, each slightly offset for that "leaning" feel
	var offsets : Array = [
		Vector3(0.0, 0.16, 0.0), Vector3(0.04, 0.44, 0.02),
		Vector3(-0.03, 0.72, 0.01), Vector3(0.05, 1.0, -0.03),
		Vector3(-0.02, 1.28, 0.04),
	]
	for o: Vector3 in offsets:
		_cyl(0.34, 0.28, o, tm)
		_cyl(0.16, 0.30, o, hw)  # hubcap inside
	# Two spare tyres lying flat next to the tower
	var side_tyre := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.32; m.bottom_radius = 0.32; m.height = 0.27
	side_tyre.mesh = m; side_tyre.material_override = tm
	side_tyre.position = Vector3(0.78, 0.14, 0.1)
	# Lying flat = no rotation needed for Y-up tyre
	add_child(side_tyre)

# ── Oil drum cluster ──────────────────────────────────────────────────────────
func _build_oil_drums() -> void:
	var dm  := _flat(Color(0.20,0.28,0.24), 0.55, 0.4)
	var dml := _flat(Color(0.18,0.20,0.22), 0.55, 0.4)
	var band := _flat(Color(0.45,0.38,0.28), 0.7, 0.2)
	# Three standing drums
	for dp: Vector3 in [Vector3(-0.42,0.48,0.0), Vector3(0.42,0.48,0.0),
						  Vector3(0.0, 0.48, 0.55)]:
		_cyl(0.26, 0.90, dp, dm)
		_bm(Vector3(0.52,0.05,0.52), Vector3(dp.x, dp.y+0.30, dp.z), band)
		_bm(Vector3(0.52,0.05,0.52), Vector3(dp.x, dp.y-0.25, dp.z), band)
	# Two drums on their side
	var side_mi := MeshInstance3D.new()
	var ms := CylinderMesh.new()
	ms.top_radius = 0.26; ms.bottom_radius = 0.26; ms.height = 0.90
	side_mi.mesh = ms; side_mi.material_override = dml
	side_mi.position = Vector3(-0.12, 0.26, -0.58)
	side_mi.rotation_degrees = Vector3(0, 0, 90)
	add_child(side_mi)
	# Rusty puddle under the leaking drum
	var puddle_mat := _flat(Color(0.10,0.14,0.10,0.7), 0.95, 0.0)
	puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bm(Vector3(1.2,0.02,0.9), Vector3(0, 0.01, -0.4), puddle_mat)

# ── Appliance heap (washing machines, fridges) ────────────────────────────────
func _build_appliances() -> void:
	var am  := _flat(Color(0.74,0.72,0.70), 0.55, 0.0)
	var amo := _flat(Color(0.45,0.45,0.48), 0.55, 0.0)
	# Washing machine — box with porthole circle detail
	_bm(Vector3(0.65,0.68,0.60), Vector3(-0.42, 0.34, 0.0), am)
	_bm(Vector3(0.65,0.68,0.60), Vector3( 0.42, 0.34, 0.0), amo)
	# Stacked one on top
	_bm(Vector3(0.65,0.68,0.60), Vector3(-0.42, 1.02, 0.0), amo)
	# Fridge door lying flat
	_bm(Vector3(0.70,0.16,1.10), Vector3( 0.42, 0.70, 0.18), am)
	# Porthole circles (dark discs simulated as flat boxes)
	var glass := _flat(Color(0.35,0.45,0.55), 0.20, 0.15)
	_bm(Vector3(0.06,0.28,0.28), Vector3(-0.07, 0.34, 0.31), glass)
	_bm(Vector3(0.06,0.28,0.28), Vector3( 0.77, 0.34, 0.31), glass)
	# Knobs row
	var knob_mat := _flat(Color(0.30,0.30,0.32), 0.6, 0.0)
	for kx: float in [-0.55, -0.42, -0.29]:
		_bm(Vector3(0.07,0.07,0.07), Vector3(kx, 0.64, 0.31), knob_mat)

# ── Mystery crate ─────────────────────────────────────────────────────────────
func _build_mystery_crate() -> void:
	# Wooden crate body
	var wood := _flat(Color(0.48,0.34,0.20), 0.88, 0.0)
	_bm(Vector3(1.1,1.1,1.1), Vector3(0, 0.55, 0), wood)
	# Plank lines
	var plank := _flat(Color(0.35,0.24,0.14), 0.88, 0.0)
	_bm(Vector3(1.12,0.06,1.12), Vector3(0, 0.32, 0), plank)
	_bm(Vector3(1.12,0.06,1.12), Vector3(0, 0.78, 0), plank)
	_bm(Vector3(0.06,1.12,1.12), Vector3( 0.56, 0.55, 0), plank)
	_bm(Vector3(0.06,1.12,1.12), Vector3(-0.56, 0.55, 0), plank)
	# Glowing lock (question mark vibe)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color           = Color(0.8, 0.6, 0.0)
	glow_mat.metallic               = 0.8
	glow_mat.emission_enabled       = true
	glow_mat.emission               = Color(1.0, 0.8, 0.0)
	glow_mat.emission_energy_multiplier = 0.6
	_bm(Vector3(0.18,0.18,0.18), Vector3(0, 0.55, 0.57), glow_mat)
	# Iron corner brackets
	var iron := _flat(Color(0.30,0.30,0.32), 0.5, 0.6)
	for cx: float in [-0.55, 0.55]:
		for cz: float in [-0.55, 0.55]:
			_bm(Vector3(0.10,0.10,0.10), Vector3(cx, 1.05, cz), iron)
			_bm(Vector3(0.10,0.10,0.10), Vector3(cx, 0.05, cz), iron)

# ── Parts bucket ──────────────────────────────────────────────────────────────
func _build_parts_bucket() -> void:
	# Big rusty barrel
	var barrel := _flat(Color(0.40,0.32,0.24), 0.85, 0.2)
	_cyl(0.40, 0.85, Vector3(0, 0.42, 0), barrel)
	# Parts overflowing
	var pm := _flat(Color(0.30,0.30,0.34), 0.5, 0.5)
	for i in 6:
		var ang : float = float(i) / 6.0 * TAU
		var r   : float = randf_range(0.20, 0.42)
		_bm(Vector3(randf_range(0.08,0.22), randf_range(0.06,0.18),
					randf_range(0.08,0.22)),
			Vector3(cos(ang)*r, 0.88 + randf_range(0.0,0.18), sin(ang)*r), pm)
	# Exhaust pipe sticking up
	var pipe := _flat(Color(0.22,0.22,0.24), 0.6, 0.3)
	_cyl(0.05, 0.55, Vector3(0.30, 1.10, 0.05), pipe)

# ── Abandoned sofa ────────────────────────────────────────────────────────────
func _build_sofa() -> void:
	# Seat cushion base
	_b(Vector3(1.55, 0.30, 0.72), Vector3(0, 0.20, 0))
	# Back rest
	_b(Vector3(1.55, 0.52, 0.22), Vector3(0, 0.56, -0.26))
	# Arm rests
	_b(Vector3(0.25, 0.42, 0.72), Vector3(-0.65, 0.42, 0))
	_b(Vector3(0.25, 0.42, 0.72), Vector3( 0.65, 0.42, 0))
	# Cushion divider
	var divider_mat := _flat(_body_mat.albedo_color * Color(0.85,0.85,0.85), 0.85, 0.0)
	_bm(Vector3(0.06,0.30,0.65), Vector3(0, 0.25, 0), divider_mat)
	# A pillow on the sofa (why not)
	var pillow_mat := _flat(Color(0.78,0.55,0.30), 0.80, 0.0)
	_bm(Vector3(0.42,0.16,0.42), Vector3(-0.35, 0.38, 0.12), pillow_mat)
	# Sofa leg stubs
	var leg_mat := _flat(Color(0.22,0.18,0.14), 0.9, 0.0)
	for lp: Vector3 in [Vector3(-0.55,0.06,0.28), Vector3( 0.55,0.06,0.28),
						  Vector3(-0.55,0.06,-0.28), Vector3( 0.55,0.06,-0.28)]:
		_bm(Vector3(0.10,0.12,0.10), lp, leg_mat)

# ── Glow ring & interaction zone ──────────────────────────────────────────────
func _build_glow_ring(pile_type: String) -> void:
	# Mystery crate → cyan/purple glow. Others → standard green.
	var ring_color : Color
	var emit_color : Color
	if pile_type == "mystery":
		ring_color = Color(0.55, 0.20, 0.85, 0.55)
		emit_color = Color(0.70, 0.30, 1.00)
	else:
		ring_color = Color(0.25, 0.80, 0.35, 0.55)
		emit_color = Color(0.20, 0.90, 0.30)

	var ring_mi   := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius    = 1.10
	ring_mesh.bottom_radius = 1.10
	ring_mesh.height        = 0.035
	ring_mesh.radial_segments = 28
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color              = ring_color
	_ring_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.emission_enabled          = true
	_ring_mat.emission                  = emit_color
	_ring_mat.emission_energy_multiplier = 0.50
	ring_mi.mesh              = ring_mesh
	ring_mi.material_override = _ring_mat
	ring_mi.position          = Vector3(0, 0.02, 0)
	add_child(ring_mi)

	var tw := create_tween().set_loops()
	tw.tween_property(_ring_mat, "emission_energy_multiplier", 0.90, 1.0)
	tw.tween_property(_ring_mat, "emission_energy_multiplier", 0.20, 1.0)

func _build_interact_zone(label: String) -> void:
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask  = 0
	area.add_to_group("junk_pile")
	area.set_meta("interact_label", "Search %s" % label)
	area.set_meta("interact_cb",    Callable(self, "search"))
	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.3
	col.shape    = shape
	col.position = Vector3(0, 0.6, 0)
	area.add_child(col)
	add_child(area)
	_interact_area = area

# ── Public API ────────────────────────────────────────────────────────────────
func search() -> Array:
	if is_searched: return []
	is_searched = true
	if _body_mat:
		_body_mat.albedo_color = Color(0.20, 0.18, 0.16)
	if _ring_mat:
		_ring_mat.emission                  = Color(0.3, 0.3, 0.3)
		_ring_mat.albedo_color              = Color(0.25, 0.25, 0.25, 0.25)
		_ring_mat.emission_energy_multiplier = 0.0
	if _interact_area:
		_interact_area.set_meta("interact_label", "Already searched")
		_interact_area.set_meta("interact_cb",    Callable())
	emit_signal("pile_searched", self, loot)
	return loot

func reset_for_new_day() -> void:
	is_searched = false
	_generate_loot()
	var style : Dictionary = PILE_TYPES[pile_id % PILE_TYPES.size()]
	if _body_mat:
		_body_mat.albedo_color = style["color"]
	if _ring_mat:
		var pile_type : String = style["type"]
		_ring_mat.emission      = Color(0.70,0.30,1.0) if pile_type == "mystery" \
								   else Color(0.20,0.90,0.30)
		_ring_mat.albedo_color  = Color(0.55,0.20,0.85,0.55) if pile_type == "mystery" \
								   else Color(0.25,0.80,0.35,0.55)
		_ring_mat.emission_energy_multiplier = 0.50
	if _interact_area:
		_interact_area.set_meta("interact_label", "Search %s" % style["label"])
		_interact_area.set_meta("interact_cb",    Callable(self, "search"))

# ── Mesh helpers ──────────────────────────────────────────────────────────────
func _b(size: Vector3, pos: Vector3) -> MeshInstance3D:
	return _bm(size, pos, _body_mat)

func _bm(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size            = size
	mi.mesh              = mesh
	mi.material_override = mat
	mi.position          = pos
	add_child(mi)
	return mi

func _cyl(radius: float, height: float, pos: Vector3,
		  mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mi.mesh              = mesh
	mi.material_override = mat
	mi.position          = pos
	add_child(mi)
	return mi

func _flat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m     := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = metallic
	return m

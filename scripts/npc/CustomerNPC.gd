## CustomerNPC.gd — clean sim-style adult NPCs, 4 customer personalities.
##   0 = BUDGET_BUYER  → Kai        (yellow hoodie, red headphones, blue jeans)
##   1 = COLLECTOR     → Mrs Pemberton (purple coat, white bun, handbag)
##   2 = RESTORER      → Dale Henson  (green puffer, red beanie, brown beard)
##   3 = FLIPPER       → Vinny "Cash" (brown hoodie, sunglasses, gold chain)
##
## Adult proportions ~1.72m tall (head ~13% of body height). No more chibi.
extends CharacterBody3D

const GRAVITY    : float = -22.0
const TURN_SPEED : float = 8.0

# ── Per-personality colour tables ─────────────────────────────────────────────
const PERSONALITY_SKIN : Array = [
	Color(0.44, 0.29, 0.19),  # 0 Kai          — deep warm brown
	Color(0.96, 0.84, 0.72),  # 1 Mrs Pemberton — pale peachy
	Color(0.78, 0.62, 0.46),  # 2 Dale          — medium tan
	Color(0.30, 0.19, 0.12),  # 3 Vinny         — very dark brown
]
const PERSONALITY_TOP : Array = [
	Color(0.95, 0.78, 0.10),  # 0 Kai          — bright yellow hoodie
	Color(0.50, 0.24, 0.70),  # 1 Mrs Pemberton — purple coat
	Color(0.22, 0.56, 0.28),  # 2 Dale          — forest green puffer
	Color(0.34, 0.22, 0.12),  # 3 Vinny         — dark brown hoodie
]
const PERSONALITY_PANTS : Array = [
	Color(0.22, 0.36, 0.72),  # 0 Kai          — blue jeans
	Color(0.50, 0.24, 0.70),  # 1 Mrs Pemberton — purple (dress continues)
	Color(0.36, 0.24, 0.14),  # 2 Dale          — dark brown trousers
	Color(0.12, 0.18, 0.38),  # 3 Vinny         — dark navy jeans
]
const PERSONALITY_SHOE : Array = [
	Color(0.15, 0.15, 0.18),  # 0 Kai          — dark sneakers
	Color(0.55, 0.28, 0.28),  # 1 Mrs Pemberton — dark red flats
	Color(0.18, 0.12, 0.08),  # 2 Dale          — dark work boots
	Color(0.10, 0.10, 0.12),  # 3 Vinny         — black sneakers
]

# ── Per-instance state ────────────────────────────────────────────────────────
var _walk_speed : float    = 2.8
var _target     : Vector3  = Vector3.ZERO
var _on_arrived : Callable = Callable()
var _walking    : bool     = false
var _anim_t     : float    = 0.0
var _idle_t     : float    = 0.0
var _bob_t      : float    = 0.0

var _head_node  : Node3D   = null
var _head_y0    : float    = 0.0
var _L_arm      : Node3D   = null
var _R_arm      : Node3D   = null
var _L_leg      : Node3D   = null
var _R_leg      : Node3D   = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	var p : int = get_meta("personality_pending", 0) as int
	_walk_speed = randf_range(2.2, 3.4)
	_build_visuals(p)

# ── Public API ────────────────────────────────────────────────────────────────
func set_personality(personality_int: int) -> void:
	# Called from Garage.gd after add_child — rebuild if _ready already fired
	# (If set_meta was used before add_child, _ready already used it — skip)
	if _head_node != null:
		# Already built — tear down and rebuild with correct personality
		for c in get_children():
			if c is MeshInstance3D or c is Node3D:
				c.queue_free()
		_head_node = null; _L_arm = null; _R_arm = null; _L_leg = null; _R_leg = null
		_build_visuals(personality_int)

func walk_to(dest: Vector3, on_arrived: Callable) -> void:
	_target     = Vector3(dest.x, position.y, dest.z)
	_on_arrived = on_arrived
	_walking    = true

func leave(door_pos: Vector3) -> void:
	walk_to(door_pos, func(): queue_free())

# ── Build 3D chibi character for given personality ────────────────────────────
func _build_visuals(p: int) -> void:
	var s    : float = randf_range(0.92, 1.08)   # slight height variation
	var skin  : Color = PERSONALITY_SKIN [clamp(p, 0, 3)]
	var top   : Color = PERSONALITY_TOP  [clamp(p, 0, 3)]
	var pants : Color = PERSONALITY_PANTS[clamp(p, 0, 3)]
	var shoe  : Color = PERSONALITY_SHOE [clamp(p, 0, 3)]

	var skin_m  := _mat(skin,              0.60)
	var skin_d  := _mat(skin.darkened(0.18), 0.65)         # slightly darker skin shadow
	var top_m   := _mat(top,               0.62)
	var top_d   := _mat(top.darkened(0.20), 0.65)
	var pants_m := _mat(pants,             0.70)
	var shoe_m  := _mat(shoe,              0.55)
	var sole_m  := _mat(Color(0.10,0.10,0.10), 0.92)
	var eye_w   := _mat(Color(0.94,0.94,0.96), 0.40)
	var pupil   := _mat(Color(0.04,0.04,0.06), 0.28)
	var iris_m  := _mat(Color(0.34,0.42,0.50), 0.40)       # subtle eye color

	# ── Adult layout constants (1.72m * s tall, head ~13% of body) ────────────
	var leg_y  := 1.00 * s    # hip pivot
	var shld_y := 1.55 * s    # shoulder pivot
	var head_y := 1.71 * s    # head center
	var head_r := 0.105 * s   # head radius (~21cm)

	# ── LEGS ──────────────────────────────────────────────────────────────────
	_L_leg = Node3D.new(); _L_leg.position = Vector3(-0.11*s, leg_y, 0.0); add_child(_L_leg)
	_build_leg(_L_leg, pants_m, shoe_m, sole_m, s)
	_R_leg = Node3D.new(); _R_leg.position = Vector3( 0.11*s, leg_y, 0.0); add_child(_R_leg)
	_build_leg(_R_leg, pants_m, shoe_m, sole_m, s)

	# ── TORSO (cylindrical, not sphere) ──────────────────────────────────────
	var torso_lo_mi   := MeshInstance3D.new()
	var torso_lo_mesh := CylinderMesh.new()
	torso_lo_mesh.top_radius = 0.24*s; torso_lo_mesh.bottom_radius = 0.21*s; torso_lo_mesh.height = 0.30*s
	torso_lo_mi.mesh = torso_lo_mesh; torso_lo_mi.material_override = top_m
	torso_lo_mi.position = Vector3(0, 1.20*s, 0); add_child(torso_lo_mi)
	var torso_hi_mi   := MeshInstance3D.new()
	var torso_hi_mesh := CylinderMesh.new()
	torso_hi_mesh.top_radius = 0.26*s; torso_hi_mesh.bottom_radius = 0.24*s; torso_hi_mesh.height = 0.22*s
	torso_hi_mi.mesh = torso_hi_mesh; torso_hi_mi.material_override = top_m
	torso_hi_mi.position = Vector3(0, 1.46*s, 0); add_child(torso_hi_mi)
	# Shoulder caps
	_sphere(0.13*s, Vector3(-0.24*s, 1.54*s, 0.0), top_m)
	_sphere(0.13*s, Vector3( 0.24*s, 1.54*s, 0.0), top_m)

	# Subtle waist accent stripe (slightly darker)
	_box(Vector3(0.50*s, 0.025*s, 0.46*s), Vector3(0, 1.045*s, 0), top_d)

	# ── ARMS ──────────────────────────────────────────────────────────────────
	_L_arm = Node3D.new(); _L_arm.position = Vector3(-0.30*s, shld_y, 0); add_child(_L_arm)
	_build_arm(_L_arm, top_m, skin_m, s, -1.0)
	_R_arm = Node3D.new(); _R_arm.position = Vector3( 0.30*s, shld_y, 0); add_child(_R_arm)
	_build_arm(_R_arm, top_m, skin_m, s,  1.0)

	# Neck
	var neck_mi   := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.062*s; neck_mesh.bottom_radius = 0.07*s; neck_mesh.height = 0.07*s
	neck_mi.mesh = neck_mesh
	neck_mi.material_override = skin_m
	neck_mi.position = Vector3(0, 1.595*s, 0)
	add_child(neck_mi)

	# ── HEAD (normal adult proportions, simple features) ─────────────────────
	_head_node = Node3D.new(); _head_node.position = Vector3(0, head_y, 0); add_child(_head_node)
	_head_y0   = head_y

	var head_mi   := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = head_r; head_mesh.height = head_r*2.2; head_mesh.radial_segments = 16
	head_mi.mesh = head_mesh; head_mi.material_override = skin_m
	_head_node.add_child(head_mi)

	# Eyes — small, plain
	for sx in [-0.42, 0.42]:
		_hs(head_r*0.18, Vector3(sx*head_r, head_r*0.05, -head_r*0.88), eye_w)
		_hs(head_r*0.10, Vector3(sx*head_r, head_r*0.05, -head_r*0.96), iris_m)
		_hs(head_r*0.045, Vector3(sx*head_r, head_r*0.05, -head_r*1.01), pupil)

	# Subtle nose hint
	_hb(Vector3(head_r*0.10, head_r*0.18, head_r*0.20),
		Vector3(0, -head_r*0.10, -head_r*0.96), skin_d)
	# Mouth thin line
	_hb(Vector3(head_r*0.32, head_r*0.04, head_r*0.04),
		Vector3(0, -head_r*0.42, -head_r*0.92), pupil)
	# Ears
	_hb(Vector3(head_r*0.10, head_r*0.22, head_r*0.18),
		Vector3(-head_r*0.98, -head_r*0.02, 0.0), skin_m)
	_hb(Vector3(head_r*0.10, head_r*0.22, head_r*0.18),
		Vector3( head_r*0.98, -head_r*0.02, 0.0), skin_m)

	# ── PERSONALITY ACCESSORIES ───────────────────────────────────────────────
	match p:
		0: _accessories_kai(head_r, s)
		1: _accessories_pemberton(head_r, s, top_m)
		2: _accessories_dale(head_r, s, top)
		3: _accessories_vinny(head_r, s)

	# ── Collision capsule — adult-sized ───────────────────────────────────────
	var col   := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28*s; shape.height = 1.16*s
	col.shape    = shape; col.position = Vector3(0, 0.88*s, 0)
	add_child(col)

# ── Kai (BUDGET_BUYER) — yellow hoodie, red headphones, blue jeans ────────────
func _accessories_kai(hr: float, s: float) -> void:
	var hp_col := _mat(Color(0.88, 0.14, 0.14), 0.55)  # red headphones
	var hp_pad := _mat(Color(0.72, 0.10, 0.10), 0.60)
	# Arc over head
	_hb(Vector3(hr*0.10, hr*1.40, hr*0.10), Vector3(0, hr*0.80, 0), hp_col)
	# Ear pads
	_hb(Vector3(hr*0.28, hr*0.28, hr*0.18), Vector3(-hr*1.08, hr*0.10, 0), hp_pad)
	_hb(Vector3(hr*0.28, hr*0.28, hr*0.18), Vector3( hr*1.08, hr*0.10, 0), hp_pad)
	# Hoodie front pocket
	_box(Vector3(0.34*s, 0.10*s, 0.02*s), Vector3(0, 1.18*s, -0.235*s),
		_mat(Color(0.78, 0.62, 0.04), 0.65))
	# Hoodie drawstrings
	_box(Vector3(0.018*s, 0.18*s, 0.02*s), Vector3(-0.07*s, 1.46*s, -0.235*s),
		_mat(Color(0.96, 0.80, 0.10), 0.55))
	_box(Vector3(0.018*s, 0.18*s, 0.02*s), Vector3( 0.07*s, 1.46*s, -0.235*s),
		_mat(Color(0.96, 0.80, 0.10), 0.55))

# ── Mrs. Pemberton (COLLECTOR) — white bun, glasses, handbag ─────────────────
func _accessories_pemberton(hr: float, s: float, _top_m: StandardMaterial3D) -> void:
	var white_m := _mat(Color(0.92, 0.91, 0.89), 0.78)  # white-grey hair
	var glass_m := _mat(Color(0.22, 0.16, 0.12), 0.50)  # dark frame
	# Hair bun on top + sides
	_hs(hr*0.62, Vector3(0, hr*1.08, hr*0.10), white_m)
	_hs(hr*0.36, Vector3(-hr*0.84, hr*0.44, 0), white_m)
	_hs(hr*0.36, Vector3( hr*0.84, hr*0.44, 0), white_m)
	# Glasses frames
	_hb(Vector3(hr*0.46, hr*0.12, hr*0.05), Vector3(-hr*0.38, hr*0.06, -hr*0.97), glass_m)
	_hb(Vector3(hr*0.46, hr*0.12, hr*0.05), Vector3( hr*0.38, hr*0.06, -hr*0.97), glass_m)
	# Bridge
	_hb(Vector3(hr*0.16, hr*0.05, hr*0.05), Vector3(0, hr*0.08, -hr*0.97), glass_m)
	# Pearl necklace at collar (subtle string of small spheres)
	for nci in 7:
		var nx: float = (-0.18 + nci * 0.06) * s
		_sphere(0.024*s, Vector3(nx, 1.56*s - abs(nx) * 0.4, -0.20*s),
			_mat(Color(0.96, 0.94, 0.90), 0.30))
	# Handbag — held at right hand height
	var bag_m := _mat(Color(0.62, 0.14, 0.14), 0.50)
	_box(Vector3(0.16*s, 0.14*s, 0.08*s), Vector3(0.40*s, 0.88*s, 0.08*s), bag_m)
	# Bag handle (thin arc)
	_box(Vector3(0.02*s, 0.10*s, 0.02*s), Vector3(0.40*s, 1.00*s, 0.05*s), bag_m)

# ── Dale Henson (RESTORER) — red beanie, brown beard ─────────────────────────
func _accessories_dale(hr: float, s: float, top_col: Color) -> void:
	var beanie_m := _mat(Color(0.78, 0.14, 0.12), 0.65)  # red beanie
	var beanie_d := _mat(Color(0.60, 0.08, 0.08), 0.70)
	var beard_m  := _mat(Color(0.40, 0.26, 0.14), 0.78)  # brown beard
	# Beanie body
	_hb(Vector3(hr*2.00, hr*1.00, hr*1.92), Vector3(0, hr*0.85, hr*0.05), beanie_m)
	# Beanie folded brim
	_hb(Vector3(hr*2.05, hr*0.26, hr*1.98), Vector3(0, hr*0.45, hr*0.05), beanie_d)
	# Beard around lower face / chin
	_hb(Vector3(hr*1.30, hr*0.46, hr*0.40),
		Vector3(0, -hr*0.55, -hr*0.55), beard_m)
	# Mustache
	_hb(Vector3(hr*0.80, hr*0.10, hr*0.18),
		Vector3(0, -hr*0.36, -hr*0.92), beard_m)
	# Puffer jacket quilting lines (horizontal stripes on the new tall torso)
	for qi in 4:
		_box(Vector3(0.54*s, 0.025*s, 0.50*s),
			Vector3(0, (1.10 + qi*0.10)*s, 0),
			_mat(top_col * Color(0.84, 0.84, 0.86), 0.72))

# ── Vinny "Cash" (FLIPPER) — sunglasses, gold chain ──────────────────────────
func _accessories_vinny(hr: float, s: float) -> void:
	var glass_m := _mat(Color(0.04, 0.04, 0.06), 0.20)   # dark lens
	var frame_m := _mat(Color(0.16, 0.12, 0.08), 0.45)   # dark frame
	var gold_m  := _mat(Color(0.92, 0.72, 0.16), 0.28)   # gold chain
	gold_m.metallic = 0.6
	# Lens blocks
	_hb(Vector3(hr*0.50, hr*0.18, hr*0.06), Vector3(-hr*0.42, hr*0.05, -hr*0.97), glass_m)
	_hb(Vector3(hr*0.50, hr*0.18, hr*0.06), Vector3( hr*0.42, hr*0.05, -hr*0.97), glass_m)
	# Frame bar
	_hb(Vector3(hr*0.18, hr*0.06, hr*0.06), Vector3(0, hr*0.07, -hr*0.97), frame_m)
	# Gold chain — small spheres draped at collar height (world ~1.50)
	for ci in 7:
		var cx : float = (-0.18 + ci * 0.06) * s
		_sphere(0.022*s,
			Vector3(cx, 1.52*s - abs(cx) * 0.5, -0.22*s),
			gold_m)

# ── Leg: thigh + knee + shin + boot + sole (adult proportions) ───────────────
func _build_leg(pivot: Node3D, pant: StandardMaterial3D,
				shoe: StandardMaterial3D, sole: StandardMaterial3D, s: float) -> void:
	# Thigh
	var t_mi := MeshInstance3D.new(); var t_m := CylinderMesh.new()
	t_m.top_radius = 0.115*s; t_m.bottom_radius = 0.095*s; t_m.height = 0.40*s
	t_mi.mesh = t_m; t_mi.material_override = pant
	t_mi.position = Vector3(0, -0.20*s, 0); pivot.add_child(t_mi)
	# Knee
	var k_mi := MeshInstance3D.new(); var k_m := SphereMesh.new()
	k_m.radius = 0.10*s; k_m.height = 0.20*s; k_m.radial_segments = 10
	k_mi.mesh = k_m; k_mi.material_override = pant
	k_mi.position = Vector3(0, -0.40*s, 0); pivot.add_child(k_mi)
	# Shin
	var sh_mi := MeshInstance3D.new(); var sh_m := CylinderMesh.new()
	sh_m.top_radius = 0.095*s; sh_m.bottom_radius = 0.080*s; sh_m.height = 0.40*s
	sh_mi.mesh = sh_m; sh_mi.material_override = pant
	sh_mi.position = Vector3(0, -0.62*s, 0); pivot.add_child(sh_mi)
	# Boot
	var b_mi := MeshInstance3D.new(); var b_m := BoxMesh.new()
	b_m.size = Vector3(0.18*s, 0.14*s, 0.24*s)
	b_mi.mesh = b_m; b_mi.material_override = shoe
	b_mi.position = Vector3(0, -0.88*s, 0.04*s); pivot.add_child(b_mi)
	# Rounded toe
	var bt_mi := MeshInstance3D.new(); var bt_m := SphereMesh.new()
	bt_m.radius = 0.09*s; bt_m.height = 0.16*s; bt_m.radial_segments = 10
	bt_mi.mesh = bt_m; bt_mi.material_override = shoe
	bt_mi.position = Vector3(0, -0.90*s, -0.10*s); pivot.add_child(bt_mi)
	# Sole
	var so_mi := MeshInstance3D.new(); var so_m := BoxMesh.new()
	so_m.size = Vector3(0.20*s, 0.04*s, 0.30*s)
	so_mi.mesh = so_m; so_mi.material_override = sole
	so_mi.position = Vector3(0, -0.97*s, 0.02*s); pivot.add_child(so_mi)

# ── Arm: upper + elbow + forearm + hand (adult proportions) ──────────────────
func _build_arm(pivot: Node3D, sleeve: StandardMaterial3D,
				skin: StandardMaterial3D, s: float, _side: float) -> void:
	# Upper arm (sleeve)
	var u_mi := MeshInstance3D.new(); var u_m := CylinderMesh.new()
	u_m.top_radius = 0.090*s; u_m.bottom_radius = 0.078*s; u_m.height = 0.32*s
	u_mi.mesh = u_m; u_mi.material_override = sleeve
	u_mi.position = Vector3(0, -0.16*s, 0); pivot.add_child(u_mi)
	# Elbow
	var e_mi := MeshInstance3D.new(); var e_m := SphereMesh.new()
	e_m.radius = 0.077*s; e_m.height = 0.15*s; e_m.radial_segments = 10
	e_mi.mesh = e_m; e_mi.material_override = sleeve
	e_mi.position = Vector3(0, -0.32*s, 0); pivot.add_child(e_mi)
	# Forearm (in sleeve too — most NPC outfits are long sleeve)
	var f_mi := MeshInstance3D.new(); var f_m := CylinderMesh.new()
	f_m.top_radius = 0.072*s; f_m.bottom_radius = 0.062*s; f_m.height = 0.28*s
	f_mi.mesh = f_m; f_mi.material_override = sleeve
	f_mi.position = Vector3(0, -0.47*s, 0); pivot.add_child(f_mi)
	# Hand (skin)
	var h_mi := MeshInstance3D.new(); var h_m := SphereMesh.new()
	h_m.radius = 0.072*s; h_m.height = 0.14*s; h_m.radial_segments = 10
	h_mi.mesh = h_m; h_mi.material_override = skin
	h_mi.position = Vector3(0, -0.68*s, 0); pivot.add_child(h_mi)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = roughness; return m

func _sphere(radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var mesh := SphereMesh.new()
	mesh.radius = radius; mesh.height = radius * 2.0; mesh.radial_segments = 12
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos; add_child(mi); return mi

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos; add_child(mi); return mi

# Head-relative helpers (add to _head_node)
func _hs(radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var mesh := SphereMesh.new()
	mesh.radius = radius; mesh.height = radius * 2.0; mesh.radial_segments = 12
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	_head_node.add_child(mi); return mi

func _hb(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	_head_node.add_child(mi); return mi

# ── Physics + animation ───────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor(): velocity.y += GRAVITY * delta
	else: velocity.y = 0.0

	if _walking:
		var diff := Vector3(_target.x, position.y, _target.z) - position
		if diff.length() < 0.25:
			velocity.x = 0.0; velocity.z = 0.0
			_walking = false; _bob_t = 0.0
			_settle(delta)
			var cb := _on_arrived; _on_arrived = Callable()
			if cb.is_valid(): cb.call()
		else:
			var dir := diff.normalized()
			velocity.x = dir.x * _walk_speed; velocity.z = dir.z * _walk_speed
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), TURN_SPEED * delta)
			_anim_t += delta * _walk_speed * 3.0
			_bob_t  += delta * 2.2 * TAU
			if _head_node: _head_node.position.y = _head_y0 + sin(_bob_t) * 0.04
			var sw : float = sin(_anim_t) * 0.36
			if _L_arm: _L_arm.rotation.x =  sw
			if _R_arm: _R_arm.rotation.x = -sw
			if _L_leg: _L_leg.rotation.x = -sw * 0.78
			if _R_leg: _R_leg.rotation.x =  sw * 0.78
	else:
		velocity.x = 0.0; velocity.z = 0.0
		_idle_t += delta * 1.0
		if _head_node: _head_node.position.y = _head_y0 + sin(_idle_t) * 0.014
		_settle(delta)

	move_and_slide()

func _settle(delta: float) -> void:
	if _L_arm:
		_L_arm.rotation.x = lerp(_L_arm.rotation.x,  0.04, delta * 5.0)
		_L_arm.rotation.z = lerp(_L_arm.rotation.z,  0.07, delta * 4.0)
	if _R_arm:
		_R_arm.rotation.x = lerp(_R_arm.rotation.x,  0.04, delta * 5.0)
		_R_arm.rotation.z = lerp(_R_arm.rotation.z, -0.07, delta * 4.0)
	if _L_leg: _L_leg.rotation.x = lerp(_L_leg.rotation.x, 0.0, delta * 8.0)
	if _R_leg: _R_leg.rotation.x = lerp(_R_leg.rotation.x, 0.0, delta * 8.0)

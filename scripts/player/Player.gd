## Player.gd — Mac the Mechanic, clean sim-style adult mechanic.
## Navy mechanic coveralls, white shirt underneath, work belt, work boots,
## low-key baseball cap, plain face with subtle features. Adult proportions
## (~1.78m tall, head ~13% of body height — no more chibi).
extends CharacterBody3D

# ── Movement ──────────────────────────────────────────────────────────────────
const SPEED        : float = 7.0
const SPRINT_SPEED : float = 13.0
const GRAVITY      : float = -22.0
const MOUSE_SENS   : float = 0.003
const PITCH_MIN    : float = -0.55
const PITCH_MAX    : float =  0.70
const TURN_SPEED   : float = 12.0

# ── Camera ────────────────────────────────────────────────────────────────────
var _cam_pivot  : Node3D      = null
var _spring_arm : SpringArm3D = null
var _camera     : Camera3D    = null
var _yaw        : float       = 0.0
var _pitch      : float       = -0.22

# ── Interaction ───────────────────────────────────────────────────────────────
var _nearby_zone    : Area3D = null
var _interact_label : Label  = null
var _frozen         : bool   = false

# ── Footsteps ─────────────────────────────────────────────────────────────────
var _step_accum          : float = 0.0
const STEP_INTERVAL_WALK   : float = 0.44
const STEP_INTERVAL_SPRINT : float = 0.27

# ── Limb pivots (animation) ───────────────────────────────────────────────────
var _L_arm  : Node3D = null
var _R_arm  : Node3D = null
var _L_leg  : Node3D = null
var _R_leg  : Node3D = null
var _anim_t : float  = 0.0

# ── Part grab system ──────────────────────────────────────────────────────────
var _held_part    : Node3D   = null
var _hovered_part : Node3D   = null
var _hold_node    : Node3D   = null
var _raycast      : RayCast3D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_visuals()
	_build_camera()
	_build_sensor()
	_build_grab_system()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ══════════════════════════════════════════════════════════════════════════════
#  MAC THE MECHANIC — clean adult sim-style mechanic, ~1.78m tall
#  Palette: navy coveralls, white tee, brown work belt, brown boots, gray cap
# ══════════════════════════════════════════════════════════════════════════════
func _build_visuals() -> void:
	# ── Materials ────────────────────────────────────────────────────────────
	var overall := _mat(Color(0.16, 0.24, 0.36), 0.62)   # navy mechanic coveralls
	var over_d  := _mat(Color(0.10, 0.16, 0.26), 0.70)   # darker accent
	var white   := _mat(Color(0.92, 0.92, 0.94), 0.55)   # undershirt
	var skin    := _mat(Color(0.86, 0.66, 0.48), 0.60)   # warm tan skin
	var belt    := _mat(Color(0.28, 0.18, 0.10), 0.75)   # brown leather belt
	var buckle  := _mat(Color(0.78, 0.74, 0.42), 0.30)   # brass buckle
	buckle.metallic = 0.7
	var cap_m   := _mat(Color(0.22, 0.22, 0.25), 0.65)   # gray cap
	var cap_d   := _mat(Color(0.16, 0.16, 0.18), 0.70)   # darker brim
	var boot    := _mat(Color(0.18, 0.12, 0.07), 0.80)   # dark brown boot
	var sole    := _mat(Color(0.10, 0.10, 0.10), 0.95)
	var hair    := _mat(Color(0.18, 0.13, 0.08), 0.85)   # dark brown hair
	var eye_w   := _mat(Color(0.94, 0.94, 0.96), 0.40)
	var iris    := _mat(Color(0.36, 0.46, 0.52), 0.40)   # blue-gray iris
	var pupil   := _mat(Color(0.04, 0.04, 0.06), 0.30)
	var stubble := _mat(Color(0.36, 0.24, 0.16), 0.85)   # 5 o'clock shadow
	var glove_m := _mat(Color(0.20, 0.16, 0.12), 0.7)    # work gloves

	# Layout reference (no scale multiplier at the end — coords are world meters):
	# y=0       floor
	# y=0..0.08 boot sole
	# y=0.08..0.18 boot
	# y=0.18..0.60 shin (in pant leg)
	# y=0.60..1.00 thigh (in pant leg)
	# y=1.00..1.05 belt
	# y=1.05..1.55 torso (coveralls)
	# y=1.55..1.62 neck
	# y=1.62..1.80 head + cap

	# ── LEGS ─────────────────────────────────────────────────────────────────
	_L_leg = Node3D.new(); _L_leg.position = Vector3(-0.11, 1.00, 0.0); add_child(_L_leg)
	_build_leg(_L_leg, overall, over_d, boot, sole, -1.0)
	_R_leg = Node3D.new(); _R_leg.position = Vector3( 0.11, 1.00, 0.0); add_child(_R_leg)
	_build_leg(_R_leg, overall, over_d, boot, sole,  1.0)

	# ── Belt at waist ────────────────────────────────────────────────────────
	_box(Vector3(0.46, 0.06, 0.32), Vector3(0.0, 1.02, 0.0), belt)
	_box(Vector3(0.10, 0.08, 0.04), Vector3(0.0, 1.02, -0.18), buckle)

	# ── Torso (mechanic coveralls, capsule-ish) ──────────────────────────────
	# Lower torso (waist-up taper)
	var torso_lo_mi   := MeshInstance3D.new()
	var torso_lo_mesh := CylinderMesh.new()
	torso_lo_mesh.top_radius = 0.24; torso_lo_mesh.bottom_radius = 0.21; torso_lo_mesh.height = 0.30
	torso_lo_mi.mesh = torso_lo_mesh
	torso_lo_mi.material_override = overall
	torso_lo_mi.position = Vector3(0.0, 1.22, 0.0)
	add_child(torso_lo_mi)
	# Upper torso (chest, broader at shoulders)
	var torso_hi_mi   := MeshInstance3D.new()
	var torso_hi_mesh := CylinderMesh.new()
	torso_hi_mesh.top_radius = 0.26; torso_hi_mesh.bottom_radius = 0.24; torso_hi_mesh.height = 0.22
	torso_hi_mi.mesh = torso_hi_mesh
	torso_hi_mi.material_override = overall
	torso_hi_mi.position = Vector3(0.0, 1.48, 0.0)
	add_child(torso_hi_mi)
	# Shoulder caps
	_sphere(0.13, Vector3(-0.24, 1.55, 0.0), overall)
	_sphere(0.13, Vector3( 0.24, 1.55, 0.0), overall)

	# White undershirt collar peek (front of neck)
	_box(Vector3(0.16, 0.08, 0.04), Vector3(0.0, 1.55, -0.20), white)

	# Vertical zip line down the front of the coveralls
	_box(Vector3(0.020, 0.42, 0.012), Vector3(0.0, 1.34, -0.235), over_d)

	# Two small chest pockets
	_box(Vector3(0.10, 0.08, 0.012), Vector3(-0.13, 1.50, -0.232), over_d)
	_box(Vector3(0.10, 0.08, 0.012), Vector3( 0.13, 1.50, -0.232), over_d)
	# "G" name patch (lighter rectangle)
	var patch_m := _mat(Color(0.85, 0.82, 0.74), 0.6)
	_box(Vector3(0.10, 0.06, 0.012), Vector3(0.13, 1.40, -0.232), patch_m)

	# ── ARMS ─────────────────────────────────────────────────────────────────
	_L_arm = Node3D.new(); _L_arm.position = Vector3(-0.30, 1.56, 0.0); add_child(_L_arm)
	_build_arm(_L_arm, overall, glove_m, skin, -1.0)
	_R_arm = Node3D.new(); _R_arm.position = Vector3( 0.30, 1.56, 0.0); add_child(_R_arm)
	_build_arm(_R_arm, overall, glove_m, skin,  1.0)

	# ── Neck ─────────────────────────────────────────────────────────────────
	var neck_mi   := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.065; neck_mesh.bottom_radius = 0.072; neck_mesh.height = 0.07
	neck_mi.mesh = neck_mesh
	neck_mi.material_override = skin
	neck_mi.position = Vector3(0.0, 1.605, 0.0)
	add_child(neck_mi)

	# ══════════════════════════════════════════════════════════════════════════
	#  HEAD — normal adult proportions, simple features
	# ══════════════════════════════════════════════════════════════════════════
	var head_node := Node3D.new(); head_node.position = Vector3(0.0, 1.74, 0.0); add_child(head_node)
	const hr : float = 0.105   # head radius — ~21cm head, 13% of body height

	# Head sphere — slightly elongated vertically (skull shape)
	var head_mi   := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = hr; head_mesh.height = hr * 2.20; head_mesh.radial_segments = 16
	head_mi.mesh = head_mesh; head_mi.material_override = skin
	head_node.add_child(head_mi)

	# Hair — dark brown swept top (behind the cap brim)
	_hn(head_node, _hs_mesh(hr * 1.03),
		Vector3(0.0, hr * 0.28, hr * 0.08), hair)
	# Sideburns (small dark patches beside ears)
	_hn(head_node, _hb_mesh(Vector3(hr * 0.18, hr * 0.45, hr * 0.18)),
		Vector3(-hr * 0.92, -hr * 0.10, hr * 0.10), hair)
	_hn(head_node, _hb_mesh(Vector3(hr * 0.18, hr * 0.45, hr * 0.18)),
		Vector3( hr * 0.92, -hr * 0.10, hr * 0.10), hair)

	# Eyes — small, subtle, normal-looking
	for sx in [-0.42, 0.42]:
		_hn(head_node, _hs_mesh(hr * 0.18),
			Vector3(sx * hr, hr * 0.05, -hr * 0.88), eye_w)
		_hn(head_node, _hs_mesh(hr * 0.10),
			Vector3(sx * hr, hr * 0.05, -hr * 0.97), iris)
		_hn(head_node, _hs_mesh(hr * 0.045),
			Vector3(sx * hr, hr * 0.05, -hr * 1.01), pupil)
		# Thin eyebrow
		_hn(head_node, _hb_mesh(Vector3(hr * 0.32, hr * 0.05, hr * 0.05)),
			Vector3(sx * hr, hr * 0.32, -hr * 0.92), hair)

	# Nose hint — small angular nub
	_hn(head_node, _hb_mesh(Vector3(hr * 0.10, hr * 0.18, hr * 0.20)),
		Vector3(0.0, -hr * 0.08, -hr * 0.96), skin)

	# Mouth — thin dark line
	_hn(head_node, _hb_mesh(Vector3(hr * 0.32, hr * 0.04, hr * 0.04)),
		Vector3(0.0, -hr * 0.42, -hr * 0.92), pupil)

	# Light stubble on jawline
	_hn(head_node, _hb_mesh(Vector3(hr * 1.30, hr * 0.18, hr * 0.30)),
		Vector3(0.0, -hr * 0.52, -hr * 0.45), stubble)

	# Ears (small dark patches on the sides of the head)
	_hn(head_node, _hb_mesh(Vector3(hr * 0.10, hr * 0.22, hr * 0.18)),
		Vector3(-hr * 0.98, -hr * 0.02, 0.0), skin)
	_hn(head_node, _hb_mesh(Vector3(hr * 0.10, hr * 0.22, hr * 0.18)),
		Vector3( hr * 0.98, -hr * 0.02, 0.0), skin)

	# ── Cap (low-profile, gray, not flashy) ──────────────────────────────────
	_hn(head_node, _hb_mesh(Vector3(hr * 2.10, hr * 0.55, hr * 2.05)),
		Vector3(0.0, hr * 0.95, hr * 0.05), cap_m)
	# Brim (flatter, sticks forward)
	_hn(head_node, _hb_mesh(Vector3(hr * 1.90, hr * 0.06, hr * 0.85)),
		Vector3(0.0, hr * 0.78, -hr * 1.05), cap_d)
	# Small embroidered logo on front of cap (subtle accent)
	_hn(head_node, _hb_mesh(Vector3(hr * 0.32, hr * 0.20, hr * 0.04)),
		Vector3(0.0, hr * 1.00, -hr * 1.00), _mat(Color(0.96, 0.94, 0.90), 0.55))

	# ── Collision (adult human capsule, scale=1.0) ───────────────────────────
	var col   := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = 1.20      # capsule total = height + 2*radius = 1.80m
	col.shape = shape
	col.position = Vector3(0.0, 0.90, 0.0)
	add_child(col)
	# No scale multiplier — coords above are real meters
	scale = Vector3(1.0, 1.0, 1.0)

# ── Leg ──────────────────────────────────────────────────────────────────────
# Adult proportions: thigh 0.40m, shin 0.42m, foot 0.10m + boot 0.22m forward.
# Pivot is at the hip (y≈1.00 in world). Everything else is local.
func _build_leg(pivot: Node3D, pant: StandardMaterial3D, pant_d: StandardMaterial3D,
				boot: StandardMaterial3D, sole: StandardMaterial3D, _side: float) -> void:
	# Thigh
	var t_mi := MeshInstance3D.new(); var t_m := CylinderMesh.new()
	t_m.top_radius = 0.12; t_m.bottom_radius = 0.10; t_m.height = 0.40
	t_mi.mesh = t_m; t_mi.material_override = pant
	t_mi.position = Vector3(0, -0.20, 0)
	pivot.add_child(t_mi)
	# Knee accent (subtle darker band)
	var k_mi := MeshInstance3D.new(); var k_m := CylinderMesh.new()
	k_m.top_radius = 0.105; k_m.bottom_radius = 0.105; k_m.height = 0.04
	k_mi.mesh = k_m; k_mi.material_override = pant_d
	k_mi.position = Vector3(0, -0.40, 0)
	pivot.add_child(k_mi)
	# Shin
	var sh_mi := MeshInstance3D.new(); var sh_m := CylinderMesh.new()
	sh_m.top_radius = 0.10; sh_m.bottom_radius = 0.085; sh_m.height = 0.42
	sh_mi.mesh = sh_m; sh_mi.material_override = pant
	sh_mi.position = Vector3(0, -0.63, 0)
	pivot.add_child(sh_mi)
	# Boot upper (around ankle)
	var b_mi := MeshInstance3D.new(); var b_m := BoxMesh.new()
	b_m.size = Vector3(0.20, 0.16, 0.26)
	b_mi.mesh = b_m; b_mi.material_override = boot
	b_mi.position = Vector3(0, -0.90, 0.05)
	pivot.add_child(b_mi)
	# Boot toe (rounded extension forward)
	var bt_mi := MeshInstance3D.new(); var bt_m := SphereMesh.new()
	bt_m.radius = 0.10; bt_m.height = 0.16; bt_m.radial_segments = 10
	bt_mi.mesh = bt_m; bt_mi.material_override = boot
	bt_mi.position = Vector3(0, -0.92, -0.10)
	pivot.add_child(bt_mi)
	# Rubber sole
	var so_mi := MeshInstance3D.new(); var so_m := BoxMesh.new()
	so_m.size = Vector3(0.22, 0.04, 0.32)
	so_mi.mesh = so_m; so_mi.material_override = sole
	so_mi.position = Vector3(0, -1.00, 0.03)
	pivot.add_child(so_mi)

# ── Arm ──────────────────────────────────────────────────────────────────────
# Adult proportions: upper arm 0.32m, forearm 0.30m, hand 0.14m.
# Pivot at the shoulder (y≈1.56 in world).
func _build_arm(pivot: Node3D, sleeve: StandardMaterial3D,
				glove: StandardMaterial3D, skin: StandardMaterial3D, _side: float) -> void:
	# Upper arm (in sleeve)
	var u_mi := MeshInstance3D.new(); var u_m := CylinderMesh.new()
	u_m.top_radius = 0.095; u_m.bottom_radius = 0.080; u_m.height = 0.32
	u_mi.mesh = u_m; u_mi.material_override = sleeve
	u_mi.position = Vector3(0, -0.16, 0)
	pivot.add_child(u_mi)
	# Elbow
	var e_mi := MeshInstance3D.new(); var e_m := SphereMesh.new()
	e_m.radius = 0.078; e_m.height = 0.156; e_m.radial_segments = 10
	e_mi.mesh = e_m; e_mi.material_override = sleeve
	e_mi.position = Vector3(0, -0.32, 0)
	pivot.add_child(e_mi)
	# Forearm (bare skin — rolled up sleeves)
	var f_mi := MeshInstance3D.new(); var f_m := CylinderMesh.new()
	f_m.top_radius = 0.072; f_m.bottom_radius = 0.060; f_m.height = 0.30
	f_mi.mesh = f_m; f_mi.material_override = skin
	f_mi.position = Vector3(0, -0.48, 0)
	pivot.add_child(f_mi)
	# Glove cuff
	var c_mi := MeshInstance3D.new(); var c_m := CylinderMesh.new()
	c_m.top_radius = 0.078; c_m.bottom_radius = 0.078; c_m.height = 0.05
	c_mi.mesh = c_m; c_mi.material_override = glove
	c_mi.position = Vector3(0, -0.66, 0)
	pivot.add_child(c_mi)
	# Hand
	var h_mi := MeshInstance3D.new(); var h_m := SphereMesh.new()
	h_m.radius = 0.075; h_m.height = 0.14; h_m.radial_segments = 10
	h_mi.mesh = h_m; h_mi.material_override = glove
	h_mi.position = Vector3(0, -0.74, 0)
	pivot.add_child(h_mi)

# ── Mesh factories (used for head children) ────────────────────────────────────
func _hs_mesh(radius: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = radius; m.height = radius*2.0; m.radial_segments = 12; return m

func _hb_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = size; return m

func _hn(parent: Node3D, mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	parent.add_child(mi); return mi

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

# ── Camera ────────────────────────────────────────────────────────────────────
func _build_camera() -> void:
	_cam_pivot = Node3D.new(); _cam_pivot.name = "CamPivot"
	_cam_pivot.position = Vector3(0, 1.80, 0); add_child(_cam_pivot)
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 8.0; _spring_arm.collision_mask = 1
	_spring_arm.rotation.x = _pitch; _cam_pivot.add_child(_spring_arm)
	_camera = Camera3D.new(); _camera.fov = 68.0; _spring_arm.add_child(_camera)

# ── Sensor ────────────────────────────────────────────────────────────────────
func _build_sensor() -> void:
	var area  := Area3D.new(); area.name = "InteractSensor"
	area.collision_layer = 0; area.collision_mask = 2
	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new(); shape.radius = 2.2
	col.shape = shape; col.position = Vector3(0, 0.70, 0)
	area.add_child(col)
	area.area_entered.connect(_on_zone_entered)
	area.area_exited.connect(_on_zone_exited)
	add_child(area)

func _on_zone_entered(zone: Area3D) -> void:
	if zone.has_meta("interact_label"):
		_nearby_zone = zone; _update_prompt()

func _on_zone_exited(zone: Area3D) -> void:
	if _nearby_zone == zone:
		_nearby_zone = null; _update_prompt()

func _update_prompt() -> void:
	if not _interact_label: return
	if _nearby_zone and _nearby_zone.has_meta("interact_label"):
		_interact_label.text = "[  E  ]   %s" % _nearby_zone.get_meta("interact_label")
		_interact_label.visible = true
	else:
		_interact_label.visible = false

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _frozen:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw   -= event.relative.x * MOUSE_SENS
			_pitch -= event.relative.y * MOUSE_SENS
			_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
			_spring_arm.rotation.x = _pitch
			_cam_pivot.rotation.y  = _yaw - rotation.y

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			KEY_E:
				if _frozen: return
				if _held_part and is_instance_valid(_held_part):
					var car = _held_part.get("vehicle_ref")
					var installed := false
					if car and is_instance_valid(car):
						if global_position.distance_to(car.global_position) < 5.0:
							_held_part.call("install")
							installed = true
					if not installed:
						_held_part.call("drop")
					_held_part = null
					if _interact_label: _interact_label.visible = false
				elif _hovered_part and is_instance_valid(_hovered_part):
					if _hovered_part.get("state") == 0:  ## ATTACHED
						_hovered_part.call("grab", _hold_node)
						_held_part = _hovered_part
						_hovered_part = null
						if _interact_label:
							_interact_label.text = "[  E  ]   Install / Drop"
							_interact_label.visible = true
				elif _nearby_zone and _nearby_zone.has_meta("interact_cb"):
					var cb: Callable = _nearby_zone.get_meta("interact_cb")
					if cb.is_valid():
						AudioManager.play("zone_enter", -6.0)
						cb.call()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _frozen:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _frozen:
		velocity.x = 0.0; velocity.z = 0.0; _idle_anim(delta); return

	if not is_on_floor(): velocity.y += GRAVITY * delta
	else: velocity.y = 0.0

	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_key_pressed(KEY_S): input.y += 1.0
	if Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_D): input.x += 1.0
	var speed : float = SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED

	if input.length() > 0.01:
		input = input.normalized()
		var dir := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
		velocity.x = dir.x * speed; velocity.z = dir.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), TURN_SPEED * delta)
		_walk_anim(delta, speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)
		_idle_anim(delta)

	if input.length() > 0.01 and is_on_floor():
		var iv : float = STEP_INTERVAL_SPRINT if Input.is_key_pressed(KEY_SHIFT) else STEP_INTERVAL_WALK
		_step_accum += delta
		if _step_accum >= iv:
			_step_accum = 0.0
			AudioManager.play_varied("footstep", 0.85, 1.15, -10.0)
	else:
		_step_accum = 0.0

	_cam_pivot.rotation.y = _yaw - rotation.y

	# Update hold point position (1.4m ahead, chest height)
	if _hold_node and _spring_arm:
		var fwd := -_spring_arm.global_basis.z
		_hold_node.global_position = global_position + Vector3(0, 1.1, 0) + fwd * 1.4
		_hold_node.global_basis = _spring_arm.global_basis

	# Raycast part hover
	_update_part_hover()

	move_and_slide()

func _walk_anim(delta: float, speed: float) -> void:
	_anim_t += delta * (speed / SPEED) * 6.0
	var s : float = sin(_anim_t) * 0.42
	if _L_arm: _L_arm.rotation.x =  s; _L_arm.rotation.z = -0.08
	if _R_arm: _R_arm.rotation.x = -s; _R_arm.rotation.z =  0.08
	if _L_leg: _L_leg.rotation.x = -s * 0.80
	if _R_leg: _R_leg.rotation.x =  s * 0.80

func _idle_anim(delta: float) -> void:
	_anim_t += delta * 1.4
	var breathe : float = sin(_anim_t * 0.80) * 0.012
	if _L_arm:
		_L_arm.rotation.x = lerp(_L_arm.rotation.x,  0.04 + breathe, delta * 5.0)
		_L_arm.rotation.z = lerp(_L_arm.rotation.z, -0.10, delta * 4.0)
	if _R_arm:
		_R_arm.rotation.x = lerp(_R_arm.rotation.x,  0.04 + breathe, delta * 5.0)
		_R_arm.rotation.z = lerp(_R_arm.rotation.z,  0.10, delta * 4.0)
	if _L_leg: _L_leg.rotation.x = lerp(_L_leg.rotation.x, 0.0, delta * 8.0)
	if _R_leg: _R_leg.rotation.x = lerp(_R_leg.rotation.x, 0.0, delta * 8.0)

func _build_grab_system() -> void:
	_hold_node = Node3D.new()
	_hold_node.name = "HoldPoint"
	add_child(_hold_node)

	_raycast = RayCast3D.new()
	_raycast.enabled = true
	_raycast.target_position = Vector3(0, 0, -7.0)
	_raycast.collision_mask  = 4
	if _spring_arm:
		_spring_arm.add_child(_raycast)

func _update_part_hover() -> void:
	if _frozen or not _raycast or _held_part: return
	var new_hover : Node3D = null
	if _raycast.is_colliding():
		var col = _raycast.get_collider()
		if col and col.get_parent() and col.get_parent().has_method("grab"):
			new_hover = col.get_parent()
	if new_hover != _hovered_part:
		if _hovered_part and is_instance_valid(_hovered_part):
			_hovered_part.call("set_hovered", false)
		_hovered_part = new_hover
		if _hovered_part and is_instance_valid(_hovered_part):
			_hovered_part.call("set_hovered", true)
			var lbl : String = _hovered_part.get("part_label") if _hovered_part.get("part_label") else "Part"
			if _interact_label:
				_interact_label.text = "[  E  ]   Grab %s" % lbl
				_interact_label.visible = true
		elif _nearby_zone == null and _interact_label:
			_interact_label.visible = false

func freeze() -> void:
	_frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unfreeze() -> void:
	_frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

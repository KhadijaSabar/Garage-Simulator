## InteractivePart.gd — A detachable car part the player can grab, move, and reinstall.
## Add this script to a Node3D that has a MeshInstance3D child and an Area3D child.
## Highlights cyan on hover, bobs gently when held, smooth-snaps back on install.
extends Node3D

signal grabbed(part: Node3D)
signal dropped(part: Node3D)
signal installed(part: Node3D)

enum State { ATTACHED, HELD, DROPPED }

var part_id    : String  = ""
var part_label : String  = ""
var condition  : int     = 0
var vehicle_ref          = null

var state : State = State.ATTACHED

var _hold_node      : Node3D = null
var _home_local     : Transform3D
var _mesh_nodes     : Array[MeshInstance3D] = []
var _hover_mat      : StandardMaterial3D = null
var _bob_time       : float = 0.0
var _install_tween  : Tween  = null

func _ready() -> void:
	_home_local = transform
	# Collect ALL MeshInstance3D children (parts can be multi-mesh: wheel has rim, tyre, spokes)
	_collect_meshes(self)

func _collect_meshes(node: Node) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			_mesh_nodes.append(c)
		if c.get_child_count() > 0:
			_collect_meshes(c)

func _process(delta: float) -> void:
	if state == State.HELD and is_instance_valid(_hold_node):
		# Smooth follow with subtle bob to feel like the player is holding it
		_bob_time += delta * 4.0
		var bob: Vector3 = Vector3(0, sin(_bob_time) * 0.02, cos(_bob_time * 0.7) * 0.015)
		global_position = _hold_node.global_position + bob
		# Gentle rotation drift while held (looks alive)
		var target_basis := _hold_node.global_basis
		global_basis = global_basis.slerp(target_basis, clampf(delta * 12.0, 0.0, 1.0))

func set_hovered(on: bool) -> void:
	if _mesh_nodes.is_empty(): return
	if on:
		if not _hover_mat:
			_hover_mat = StandardMaterial3D.new()
			_hover_mat.albedo_color = Color(0.30, 0.95, 1.00, 0.45)
			_hover_mat.emission_enabled = true
			_hover_mat.emission = Color(0.30, 0.95, 1.00)
			_hover_mat.emission_energy_multiplier = 0.9
			_hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_hover_mat.no_depth_test = false
			_hover_mat.grow = true
			_hover_mat.grow_amount = 0.012      # subtle outer outline halo
		for m in _mesh_nodes:
			m.material_overlay = _hover_mat
	else:
		for m in _mesh_nodes:
			m.material_overlay = null

func grab(hold_point: Node3D) -> void:
	state = State.HELD
	_hold_node = hold_point
	_bob_time = 0.0
	set_hovered(false)
	if _install_tween: _install_tween.kill()
	emit_signal("grabbed", self)

func drop() -> void:
	state = State.DROPPED
	_hold_node = null
	emit_signal("dropped", self)

func install() -> void:
	# Smooth snap home — tween position+rotation over 0.35s for satisfying feel
	state = State.ATTACHED
	_hold_node = null
	set_hovered(false)
	if _install_tween: _install_tween.kill()
	_install_tween = create_tween().set_parallel(true)
	_install_tween.tween_property(self, "position", _home_local.origin, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_install_tween.tween_property(self, "quaternion", _home_local.basis.get_rotation_quaternion(), 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emit_signal("installed", self)

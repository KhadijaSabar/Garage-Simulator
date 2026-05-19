## ReceptionDesk.gd
## 3D reception desk near the garage entrance.
## Clicking it opens the orders panel in the HUD.
extends Node3D

func _ready() -> void:
	_build_desk()

func _build_desk() -> void:
	# Main desk body
	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.55, 0.42, 0.28)
	desk_mat.roughness = 0.75
	_box(Vector3(1.6, 0.9, 0.65), Vector3(0, 0.45, 0), desk_mat)

	# Desk top surface
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.35, 0.28, 0.20)
	_box(Vector3(1.6, 0.05, 0.65), Vector3(0, 0.93, 0), top_mat)

	# Computer monitor
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.08, 0.45, 0.85)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 0.5, 1.0)
	screen_mat.emission_energy_multiplier = 0.6
	_box(Vector3(0.5, 0.35, 0.04), Vector3(-0.3, 1.12, -0.22), screen_mat)

	# Monitor stand
	var stand_mat := StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_box(Vector3(0.06, 0.18, 0.06), Vector3(-0.3, 0.96, -0.22), stand_mat)

	# Paper tray / order tickets
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.95, 0.92, 0.85)
	_box(Vector3(0.35, 0.02, 0.28), Vector3(0.4, 0.94, 0), paper_mat)

	# Bell
	var bell_mat := StandardMaterial3D.new()
	bell_mat.albedo_color = Color(0.85, 0.78, 0.2)
	bell_mat.metallic = 0.8
	var bell_mi := MeshInstance3D.new()
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.0
	bell_mesh.bottom_radius = 0.08
	bell_mesh.height = 0.12
	bell_mi.mesh = bell_mesh
	bell_mi.material_override = bell_mat
	bell_mi.position = Vector3(0.55, 0.98, 0)
	add_child(bell_mi)

	# Sign above desk
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.15, 0.35, 0.65)
	_box(Vector3(1.4, 0.3, 0.05), Vector3(0, 1.6, -0.3), sign_mat)

	# Click area (whole desk)
	var area := Area3D.new()
	area.add_to_group("reception")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.2, 0.8)
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	area.add_child(col)
	area.input_event.connect(_on_desk_clicked)
	add_child(area)

func _on_desk_clicked(_camera, event: InputEvent, _pos, _normal, _idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var garage = get_tree().get_first_node_in_group("garage")
		if garage:
			garage.show_feedback("📋 Check the Orders panel on the left!", Color.CYAN)

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

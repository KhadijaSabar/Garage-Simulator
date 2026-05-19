## GarageCleaning.gd
## Manages oil spills and floor dirt. Click spills to clean them.
## Cleanliness affects reputation and customer satisfaction.
extends Node

signal cleanliness_changed(level: float)

# ── State ─────────────────────────────────────────────────────────────────────
var spills: Array[Node3D] = []
var cleanliness: float = 1.0   ## 1.0 = spotless, 0.0 = filthy
const MAX_SPILLS := 8

# ── Spill visuals ─────────────────────────────────────────────────────────────
const SPILL_COLORS := [
	Color(0.08, 0.06, 0.04, 0.85),   # engine oil (very dark)
	Color(0.3,  0.20, 0.05, 0.75),   # transmission fluid (brown)
	Color(0.15, 0.25, 0.10, 0.70),   # coolant (dark green)
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("garage_cleaning")
	GameManager.day_started.connect(_on_day_started)

# ── Public API ────────────────────────────────────────────────────────────────
func spawn_spill(local_pos: Vector3 = Vector3.ZERO) -> void:
	if spills.size() >= MAX_SPILLS:
		return
	var garage = get_tree().get_first_node_in_group("garage")
	if not garage:
		return

	var spill := Node3D.new()
	spill.name = "Spill_%d" % spills.size()

	# Flat ellipse-like spill using a squashed cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SPILL_COLORS[randi() % SPILL_COLORS.size()]
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.9

	var mesh_inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius    = randf_range(0.35, 0.70)
	mesh.bottom_radius = mesh.top_radius
	mesh.height        = 0.02
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	spill.add_child(mesh_inst)

	# E-key interaction zone (same layer 2 as all other interactive objects)
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask  = 0
	area.add_to_group("oil_spill")
	area.set_meta("interact_label", "Clean Oil Spill")
	area.set_meta("interact_cb", func(): clean_spill(spill))
	var col   := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = mesh.top_radius + 0.30   # slightly wider than visual
	shape.height = 0.15
	col.shape = shape
	area.add_child(col)
	spill.add_child(area)

	# Position on garage floor near bay
	var offset := local_pos + Vector3(
		randf_range(-1.5, 1.5),
		0.01,
		randf_range(-1.0, 1.0)
	)
	spill.position = Vector3(-2.0, 0.01, 0.0) + offset
	garage.add_child(spill)
	spills.append(spill)
	_recalculate_cleanliness()

func clean_spill(spill: Node3D) -> void:
	if not is_instance_valid(spill):
		return
	spills.erase(spill)
	spill.queue_free()
	_recalculate_cleanliness()
	EconomyManager.change_reputation(0.5, "Cleaned a spill")
	var garage = get_tree().get_first_node_in_group("garage")
	if garage:
		garage.show_feedback("Spill cleaned! ✓", Color(0.5, 0.9, 0.6))

func clean_all() -> void:
	for s in spills:
		if is_instance_valid(s):
			s.queue_free()
	spills.clear()
	cleanliness = 1.0
	emit_signal("cleanliness_changed", cleanliness)

func get_cleanliness_label() -> String:
	if cleanliness >= 0.9: return "Spotless"
	if cleanliness >= 0.7: return "Tidy"
	if cleanliness >= 0.5: return "Acceptable"
	if cleanliness >= 0.3: return "Dirty"
	return "Disgusting"

# ── Internal ──────────────────────────────────────────────────────────────────
func _recalculate_cleanliness() -> void:
	cleanliness = 1.0 - (float(spills.size()) / float(MAX_SPILLS))
	emit_signal("cleanliness_changed", cleanliness)
	# Dirty garage hurts rep gradually
	if spills.size() >= 4:
		EconomyManager.change_reputation(-0.3, "Dirty garage")

func _on_day_started(_day: int) -> void:
	# Old spills get harder to clean (just cosmetic for now)
	pass

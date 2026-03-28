extends Node3D

func _ready() -> void:
	var pylons = get_tree().get_nodes_in_group("pylon_mesh") as Array[MeshInstance3D]
	for pylon in pylons:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(
			randf_range(0, 1),
			randf_range(0, 1),
			randf_range(0, 1)
		)
		pylon.mesh = pylon.mesh.duplicate()
		pylon.mesh.surface_set_material(0, mat)

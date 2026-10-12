extends SceneTree
func _initialize() -> void:
	var inv := Node3D.new()
	inv.name = "Inventory"
	root.add_child(inv)
	var prefabs := [
		"building_small", "building_tall", "building_tower", "warehouse",
		"car_sedan", "car_van",
		"tree_small", "tree_med", "tree_big",
		"ped_walk", "ped_idle", "ped_civil",
		"barrier", "cone", "statue",
	]
	for i in prefabs.size():
		var ps := load("res://scenes/prefabs/%s.tscn" % prefabs[i]) as PackedScene
		if ps == null:
			print("FAIL ", prefabs[i])
			continue
		var inst: Node3D = ps.instantiate() as Node3D
		inst.position = Vector3(80, 0, -40 - i * 24.0)
		inv.add_child(inst)
		print("%02d %-15s local_z=%.1f global_z=%.1f name=%s" % [i, prefabs[i], inst.transform.origin.z, inst.global_position.z, inst.name])
	quit(0)
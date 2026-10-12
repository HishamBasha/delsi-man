extends SceneTree
## Smoke test for scripts/models.gd: builds every registry key, prints surface
## counts and sizes, and checks facade anchoring.

const Models = preload("res://scripts/models.gd")

const FITS := {
	"house_a": {"height": 9.0, "length": 16.0, "depth": 12.0},
	"block_a": {"height": 9.0, "length": 16.0, "depth": 12.0},
	"tower_a": {"height": 12.0, "length": 16.0, "depth": 12.0},
	"warehouse_a": {"height": 7.0, "length": 16.0, "depth": 12.0},
	"warehouse_b": {"height": 9.0, "length": 16.0, "depth": 12.0},
	"wall_long": {"height": 9.0, "length": 26.0},
	"tree_small": {"height": 3.2},
	"tree_med": {"height": 4.5},
	"tree_big": {"height": 6.0},
	"bush": {"height": 2.2},
	"tree_sway": {"height": 4.0},
	"car_sedan": {"length": 4.6},
	"car_pickup": {"length": 5.2},
	"car_van": {"length": 5.8},
	"car_btr": {"length": 7.8},
	"maint_truck": {"length": 5.5},
	"ped_walk": {"height": 1.75},
	"ped_idle": {"height": 1.75},
	"ped_civil": {"height": 1.75},
	"ped_arrest": {"height": 1.7},
	"ped_kneel": {"height": 1.4},
	"barrier": {"height": 1.0},
	"cone": {"height": 0.5},
	"sofa": {"height": 1.05},
	"pepsi_statue": {"height": 2.6},
	"overpass": {"length": 16.0, "depth": 16.0},
}

func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var fails := 0
	for key in Models.keys():
		var opts: Dictionary = FITS.get(key, {})
		var node: Node3D = Models.spawn(host, key, Vector3.ZERO, opts)
		if node == null:
			print("REG FAIL %s -> null" % key)
			fails += 1
			continue
		var size: Vector3 = node.get_meta("size")
		var meshes := 0
		var surfaces := 0
		var stack: Array[Node] = [node]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				meshes += 1
				surfaces += (n as MeshInstance3D).mesh.get_surface_count()
		if meshes == 0:
			print("REG FAIL %s -> no mesh" % key)
			fails += 1
			continue
		print("REG %s meshes=%d surfaces=%d size=%.2f x %.2f x %.2f" % [
			key, meshes, surfaces, size.x, size.y, size.z])
	# facade check: face must land exactly on +/- face_x
	for key in ["house_a", "block_a", "warehouse_a"]:
		var opts := {"height": 9.0, "length": 16.0, "depth": 12.0}
		var a := Models.spawn_face(host, key, 7.1, -15.0, 1, opts)
		var b := Models.spawn_face(host, key, 7.1, -15.0, -1, opts)
		if a == null or b == null:
			print("REG FAIL face %s" % key)
			fails += 1
			continue
		var sa: Vector3 = a.get_meta("size")
		var sb: Vector3 = b.get_meta("size")
		var fa: float = a.position.x - sa.x * 0.5
		var fb: float = b.position.x + sb.x * 0.5
		print("REG face %s right=%.3f (want 7.1) left=%.3f (want -7.1)" % [key, fa, fb])
		if absf(fa - 7.1) > 0.001 or absf(fb + 7.1) > 0.001:
			fails += 1
	print("REG DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)

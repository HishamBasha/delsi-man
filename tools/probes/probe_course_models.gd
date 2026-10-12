extends SceneTree
## Counts GLB model buildings vs procedural box buildings in the generated
## course and checks each model facade sits at the road face (7.1 / 6.8).

const Course = preload("res://scripts/course.gd")

func _initialize() -> void:
	var flavors: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavors.json"))
	var host := Node3D.new()
	root.add_child(host)
	var course: Node3D = Course.new()
	host.add_child(course)
	course.build(flavors)
	var counts := {}
	var total := 0
	var trees := 0
	var worst := 0.0
	for chunk in course.chunks:
		for c in chunk.get_children():
			if not (c is Node3D) or not c.has_meta("model"):
				continue
			var key := str(c.get_meta("model"))
			# planter trees are street props, not facade buildings — they sit
			# on the sidewalk, so the road-face check does not apply to them
			if key.begins_with("tree"):
				trees += 1
				continue
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
			var size: Vector3 = c.get_meta("size")
			var chunk_z: float = -chunk.position.z
			var world_x: float = c.position.x + chunk.position.x
			var world_z: float = chunk.position.z + c.position.z
			var face := 6.8 if chunk_z >= 600.0 and chunk_z < 900.0 else 7.1
			var facade := absf(c.position.x) - size.x * 0.5
			var err := absf(facade - face)
			worst = maxf(worst, err)
			if err > 0.35:
				print("BAD %s z=%.0f local_x=%.2f size=(%.2f, %.2f, %.2f) facade=%.2f want=%.2f" % [
					key, world_z, c.position.x, size.x, size.y, size.z, facade, face])
			if total <= 4:
				print("SAMPLE %s z=%.0f world=(%.2f, %.2f) size=(%.2f, %.2f, %.2f) facade=%.2f want=%.2f" % [
					key, world_z, world_x, world_z, size.x, size.y, size.z, facade, face])
	print("PROBE models=%d trees=%d worst_facade_error=%.3f" % [total, trees, worst])
	var keys := counts.keys()
	keys.sort()
	for k in keys:
		print("  %s x%d" % [k, counts[k]])
	var ok := total == 30 and worst < 0.35
	print("PROBE DONE fails=%d" % (0 if ok else 1))
	quit(0 if ok else 1)

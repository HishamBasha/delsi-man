extends SceneTree
## Lists visible meshes (name + world AABB) inside key prefabs at frame 30.

var frame := 0
var targets := {}

func _collect(n: Node, out: Array) -> void:
	var stack: Array = [n]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var vis := true
			var p: Node = c
			while p != null and p != n.get_parent():
				if p is Node3D and not p.visible:
					vis = false
					break
				p = p.get_parent()
			if vis:
				var b: AABB = c.global_transform * c.get_aabb()
				out.append("%s box=(%.1f,%.1f,%.1f)-(%.1f,%.1f,%.1f)" % [
					str(c.name), b.position.x, b.position.y, b.position.z,
					b.end.x, b.end.y, b.end.z])
		for ch in c.get_children():
			stack.append(ch)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		for key in targets:
			var out := []
			_collect(targets[key], out)
			print("MESHES %s (%d visible):" % [key, out.size()])
			for line in out:
				print("   ", line)
		print("MESHPROBE DONE")
		quit(0)
	return false

func _initialize() -> void:
	var level: Node3D = load("res://scenes/levels/manual_sample_level.tscn").instantiate()
	root.add_child(level)
	targets["Car1(sedan)"] = level.get_node("Car1")
	targets["Car2(van)"] = level.get_node("Car2")
	targets["Tree1"] = level.get_node("Tree1")
	targets["Ped1"] = level.get_node("Ped1")
	targets["L2(asia)"] = level.get_node("LeftBuildings/L2")
	targets["R1(asia)"] = level.get_node("RightBuildings/R1")

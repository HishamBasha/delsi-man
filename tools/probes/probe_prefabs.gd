extends SceneTree
## Instantiates every prefab, counts visible meshes, reports failures.

const DIR := "res://scenes/prefabs"

func _count_visible(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and n.visible:
		c += 1
	for ch in n.get_children():
		c += _count_visible(ch)
	return c

func _initialize() -> void:
	var fails := 0
	var files := DirAccess.open(DIR)
	var names := []
	if files:
		for f in files.get_files():
			if f.ends_with(".tscn"):
				names.append(f)
	names.sort()
	for f in names:
		var ps := load(DIR + "/" + f) as PackedScene
		if ps == null:
			print("FAIL load ", f)
			fails += 1
			continue
		var inst := ps.instantiate()
		var vis := _count_visible(inst)
		var total := 0
		var stack: Array = [inst]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				total += 1
			for ch in n.get_children():
				stack.append(ch)
		var ok := vis > 0
		if not ok:
			fails += 1
		print("%s %s visible=%d/%d scale=%.3f" % ["OK  " if ok else "FAIL", f, vis, total, inst.scale.x])
		inst.free()
	print("PREFABPROBE fails=%d" % fails)
	quit(0 if fails == 0 else 1)

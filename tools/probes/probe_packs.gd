extends SceneTree
## Prints child indices of RootNode-level variant groups (for prefab hide overrides).

const TARGETS := [
	"res://assets/models/vehicles/low_poly_vehicle_mini_pack.glb",
	"res://assets/models/people/posed_police_people.glb",
	"res://assets/models/nature/oak_trees.glb",
]

func _walk(n: Node, prefix: String, depth: int) -> void:
	var i := 0
	for c in n.get_children():
		if depth <= 4:
			print("  %s/%s index=%d kids=%d [%s]" % [prefix, str(c.name), i, c.get_child_count(), c.get_class()])
		if depth < 4:
			_walk(c, prefix + "/" + str(c.name), depth + 1)
		i += 1

func _initialize() -> void:
	for path in TARGETS:
		var ps := load(path) as PackedScene
		var inst := ps.instantiate()
		print("PACK ", path.get_file())
		_walk(inst, "", 1)
		inst.free()
	print("PACKPROBE2 DONE")
	quit(0)

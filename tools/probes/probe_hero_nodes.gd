extends SceneTree
## Dumps the node hierarchy and mesh material of a hero FBX so the multi-clip
## loader knows which node paths the imported animation tracks resolve against.

const FILES := [
	"res://assets/models/hero/Catwalk Walk Turn 180 Tight.fbx",
	"res://assets/models/hero/Running.fbx",
]

func _initialize() -> void:
	for path in FILES:
		var scene: PackedScene = load(path)
		var inst: Node = scene.instantiate()
		print("FILE %s root=%s" % [path.get_file(), inst.name])
		_dump(inst, 0)
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D:
				var mat: Material = node.get_surface_override_material(0)
				if mat == null and node.mesh != null and node.mesh.get_surface_count() > 0:
					mat = node.mesh.surface_get_material(0)
				print("  MESH %s mat=%s" % [node.name, mat])
				if mat is BaseMaterial3D:
					var bm: BaseMaterial3D = mat
					print("    albedo=%s tex=%s" % [
						bm.albedo_color,
						bm.albedo_texture.resource_path if bm.albedo_texture else "none"])
			if node is AnimationPlayer:
				print("  PLAYER %s root_node=%s libs=%s" % [
					node.name, node.root_node, str(node.get_animation_library_list())])
			stack.append_array(node.get_children())
		inst.free()
	quit(0)

func _dump(node: Node, depth: int) -> void:
	print("  %s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])
	for child in node.get_children():
		_dump(child, depth + 1)

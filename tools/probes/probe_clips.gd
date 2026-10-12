extends SceneTree
## Dumps every FBX in assets/models/hero: animation names, lengths, track
## formats and skeleton layout so the hero state map can be written.

const DIR := "res://assets/models/hero"

func _initialize() -> void:
	var files := Array(DirAccess.open(DIR).get_files())
	files.sort()
	for file in files:
		if not file.to_lower().ends_with(".fbx"):
			continue
		var scene: PackedScene = load(DIR + "/" + file)
		if scene == null:
			print("CLIP %s -> LOAD FAILED" % file)
			continue
		var inst: Node = scene.instantiate()
		var skeleton: Skeleton3D = null
		var player: AnimationPlayer = null
		var mesh: MeshInstance3D = null
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is Skeleton3D and skeleton == null:
				skeleton = node
			elif node is AnimationPlayer and player == null:
				player = node
			elif node is MeshInstance3D and mesh == null:
				mesh = node
			stack.append_array(node.get_children())
		print("FILE %s" % file)
		print("  root=%s skeleton=%s player=%s mesh=%s" % [
			inst.name,
			skeleton.get_path() if skeleton else "none",
			player.get_path() if player else "none",
			mesh.name if mesh else "none"])
		if skeleton:
			print("  bones=%d hips=%d rest=%s" % [
				skeleton.get_bone_count(),
				skeleton.find_bone("mixamorig_Hips"),
				skeleton.get_bone_rest(skeleton.find_bone("mixamorig_Hips")).origin
					if skeleton.find_bone("mixamorig_Hips") >= 0 else "n/a"])
		if player == null:
			print("  (no AnimationPlayer)")
			inst.free()
			continue
		print("  libraries=%s" % str(player.get_animation_library_list()))
		for anim_name in player.get_animation_list():
			var anim: Animation = player.get_animation(anim_name)
			var types := {}
			var paths: Array[String] = []
			for index in range(anim.get_track_count()):
				types[anim.track_get_type(index)] = int(types.get(anim.track_get_type(index), 0)) + 1
				if paths.size() < 3:
					paths.append(String(anim.track_get_path(index)))
			print("  anim=%s len=%.3f loop=%d tracks=%d types=%s" % [
				anim_name, anim.length, anim.loop_mode, anim.get_track_count(), str(types)])
			print("    sample_paths=%s" % str(paths))
		inst.free()
	quit(0)

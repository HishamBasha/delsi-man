extends SceneTree
## Dumps the hero skeleton's bone names and rest poses so pose-layer code
## can target real bones. Run: godot --headless -s res://tools/probes/probe_bones.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://assets/models/hero/Catwalk Walk Turn 180 Tight.fbx")
	if scene == null:
		print("PROBE-FAIL: no scene")
		quit(1)
		return
	var instance: Node = scene.instantiate()
	var skeleton: Skeleton3D = null
	var player: AnimationPlayer = null
	var stack: Array[Node] = [instance]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Skeleton3D and skeleton == null:
			skeleton = node
		elif node is AnimationPlayer and player == null:
			player = node
		stack.append_array(node.get_children())
	if skeleton == null:
		print("PROBE-FAIL: no skeleton")
		quit(1)
		return
	print("PROBE bones=%d" % skeleton.get_bone_count())
	for i in range(skeleton.get_bone_count()):
		var rest: Transform3D = skeleton.get_bone_rest(i)
		print("BONE %d %s parent=%d rest_o=%s rest_e=%s" % [
			i, skeleton.get_bone_name(i), skeleton.get_bone_parent(i),
			str(rest.origin), str(rest.basis.get_euler(EULER_ORDER_YXZ))])
	if player != null:
		for anim in player.get_animation_list():
			print("ANIM %s len=%.3f" % [anim, player.get_animation(anim).length])
	quit(0)

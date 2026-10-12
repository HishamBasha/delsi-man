extends SceneTree
## Prints per-clip hips yaw and travel so the in-place bake can pin a facing
## that matches the shipped hero direction for every state.

const Hero = preload("res://scripts/hero.gd")
const DIR := "res://assets/models/hero"
const HIPS := "mixamorig_Hips"
const SAMPLES := [0.0, 0.25, 0.5, 0.75, 1.0]

func _initialize() -> void:
	var files := Array(DirAccess.open(DIR).get_files())
	files.sort()
	for file in files:
		if not file.to_lower().ends_with(".fbx"):
			continue
		var scene: PackedScene = load(DIR + "/" + file)
		var inst: Node = scene.instantiate()
		var skeleton: Skeleton3D = null
		var player: AnimationPlayer = null
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is Skeleton3D and skeleton == null:
				skeleton = node
			elif node is AnimationPlayer and player == null:
				player = node
			stack.append_array(node.get_children())
		var anim: Animation = player.get_animation(player.get_animation_list()[0])
		var hips: int = skeleton.find_bone(HIPS)
		var rest: Transform3D = skeleton.get_bone_rest(hips)
		var yaw_line := ""
		var yawy_line := ""
		var pos_line := ""
		for fraction in SAMPLES:
			var when: float = anim.length * float(fraction)
			var yaw := rad_to_deg(Hero._facing_yaw(anim, when))
			var yaw_y := rad_to_deg(_hips_yaw(anim, when))
			var origin := _hips_origin(anim, when)
			yaw_line += " %6.1f" % yaw
			yawy_line += " %6.1f" % yaw_y
			pos_line += " (%.2f,%.2f,%.2f)" % [origin.x, origin.y, origin.z]
		print("%-32s len=%.2f rest_origin=%s" % [file, anim.length, str(rest.origin)])
		print("    hipx@0/25/50/75/100:%s" % yaw_line)
		print("    hipy@0/25/50/75/100:%s" % yawy_line)
		print("    hips:%s" % pos_line)
		inst.free()
	quit(0)

## euler.y of the hips in YXZ order: the world-space heading of the body.
func _hips_yaw(anim: Animation, time: float) -> float:
	for index in range(anim.get_track_count()):
		if anim.track_get_type(index) != Animation.TYPE_ROTATION_3D:
			continue
		if not String(anim.track_get_path(index)).ends_with(":" + HIPS):
			continue
		var value: Variant = Hero._sample(anim, index, time)
		if value is Quaternion:
			return Basis(value).get_euler(EULER_ORDER_YXZ).y
	return 0.0

func _hips_origin(anim: Animation, time: float) -> Vector3:
	for index in range(anim.get_track_count()):
		if anim.track_get_type(index) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(index)).ends_with(":" + HIPS):
			continue
		var value: Variant = Hero._sample(anim, index, time)
		if value is Vector3:
			return value
	return Vector3.ZERO

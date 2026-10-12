extends SceneTree
## Reports the shape of one source take: length, tracks, loop seam and hip bob,
## so a new clip can be configured (trim/loop/rate) from data.
##   godot --headless --path <proj> -s res://tools/probes/probe_take.gd -- [hero/Name.fbx]

var file_path := "res://assets/models/hero/Unbalanced _Walking.fbx"
const CLIP := "mixamo_com"
const HIPS := "mixamorig_Hips"

func _anim() -> Animation:
	var scene: PackedScene = load(file_path)
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	var found: Animation = null
	var stack: Array[Node] = [instance]
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		if node is AnimationPlayer and node.has_animation(CLIP):
			found = node.get_animation(CLIP)
			break
		stack.append_array(node.get_children())
	instance.free()
	return found

func _track(anim: Animation, bone: String, kind: int) -> int:
	for i in range(anim.get_track_count()):
		if String(anim.track_get_path(i)).ends_with(":" + bone) and anim.track_get_type(i) == kind:
			return i
	return -1

func _sample(anim: Animation, track: int, when: float) -> Variant:
	if track < 0 or anim.track_get_key_count(track) == 0:
		return null
	var lo := 0
	var hi := anim.track_get_key_count(track) - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if anim.track_get_key_time(track, mid) <= when:
			lo = mid
		else:
			hi = mid - 1
	var value: Variant = anim.track_get_key_value(track, lo)
	var next := lo + 1
	if next < anim.track_get_key_count(track) and anim.track_get_key_time(track, next) > when:
		var t0: float = anim.track_get_key_time(track, lo)
		var t1: float = anim.track_get_key_time(track, next)
		var w := 0.0 if t1 <= t0 else (when - t0) / (t1 - t0)
		if value is Quaternion:
			value = (value as Quaternion).slerp(anim.track_get_key_value(track, next) as Quaternion, w)
		elif value is Vector3:
			value = (value as Vector3).lerp(anim.track_get_key_value(track, next) as Vector3, w)
	return value

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var given := str(args[0])
		file_path = given if given.begins_with("res://") else "res://assets/models/hero/" + given
	var anim: Animation = _anim()
	if anim == null:
		print("TAKE missing " + file_path)
		quit(1)
		return
	print("TAKE %s len=%.3f tracks=%d keys=%d" % [file_path.get_file(), anim.length, anim.get_track_count(),
		anim.track_get_key_count(_track(anim, HIPS, Animation.TYPE_POSITION_3D))])
	var hips_pos := _track(anim, HIPS, Animation.TYPE_POSITION_3D)
	var hips_rot := _track(anim, HIPS, Animation.TYPE_ROTATION_3D)
	var foot := _track(anim, "mixamorig_LeftFoot", Animation.TYPE_POSITION_3D)
	# seam: how far the pose jumps when the take wraps
	var r0: Variant = _sample(anim, hips_rot, 0.0)
	var r1: Variant = _sample(anim, hips_rot, anim.length)
	var rot_gap := -1.0
	if r0 is Quaternion and r1 is Quaternion:
		rot_gap = rad_to_deg((r0 as Quaternion).angle_to(r1 as Quaternion))
	var p0: Variant = _sample(anim, hips_pos, 0.0)
	var p1: Variant = _sample(anim, hips_pos, anim.length)
	var pos_gap := -1.0
	if p0 is Vector3 and p1 is Vector3:
		pos_gap = (p0 as Vector3).distance_to(p1 as Vector3)
	print("TAKE seam rot_gap=%.2fdeg hips_gap=%.4f" % [rot_gap, pos_gap])
	# hip height + foot height over the take: bob range and whether it reads as a walk
	var low := Vector3(9, 9, 9)
	var high := Vector3(-9, -9, -9)
	var flow := ""
	for i in range(25):
		var when := anim.length * float(i) / 24.0
		var h: Variant = _sample(anim, hips_pos, when)
		if h is Vector3:
			low = low.min(h)
			high = high.max(h)
		var lf: Variant = _sample(anim, foot, when)
		var fy := (lf as Vector3).y if lf is Vector3 else -99.0
		flow += "%.2f:%.3f " % [when, fy]
	print("TAKE hips y %.4f..%.4f (range %.4f)" % [low.y, high.y, high.y - low.y])
	# seam in the pinned channel (x/z get pinned to rest, y is kept): a step
	# there means the loop wraps on a different pose
	var y0: Variant = _sample(anim, hips_pos, 0.0)
	var y1: Variant = _sample(anim, hips_pos, anim.length)
	if y0 is Vector3 and y1 is Vector3:
		print("TAKE seam hips_y %.4f -> %.4f (gap %.4f)" % [(y0 as Vector3).y, (y1 as Vector3).y,
			absf((y0 as Vector3).y - (y1 as Vector3).y)])
	# count gait cycles: hips rises twice per stride, so peaks/2 is the stride count
	var series: Array[float] = []
	var fine := 120
	for i in range(fine + 1):
		var h: Variant = _sample(anim, hips_pos, anim.length * float(i) / float(fine))
		series.append((h as Vector3).y if h is Vector3 else 0.0)
	var peaks := 0
	var stride := ""
	for i in range(1, fine):
		if series[i] > series[i - 1] and series[i] >= series[i + 1] and series[i] > (low.y + high.y) * 0.5:
			peaks += 1
			stride += "%.2f " % (anim.length * float(i) / float(fine))
	print("TAKE bob peaks=%d (~%.1f strides) at %s" % [peaks, peaks / 2.0, stride.strip_edges()])
	# forward speed at authoring time (x/z root motion over the take)
	if p0 is Vector3 and p1 is Vector3:
		var a: Vector3 = p0
		var b: Vector3 = p1
		print("TAKE root travel %.3f m over %.2fs = %.3f m/s" % [
			Vector2(b.x - a.x, b.z - a.x * 0.0 - a.z).length(), anim.length,
			Vector2(b.x - a.x, b.z - a.z).length() / anim.length,
		])
	print("TAKE lfoot_y %s" % flow.strip_edges())
	quit(0)

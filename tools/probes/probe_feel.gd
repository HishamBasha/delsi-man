extends SceneTree
## Feel probe: measures the loop seam of every looping take (how far the pose
## jumps at the wrap) and the vertical shape of the jump take, so the seam
## crossfade and the jump trim/rate can be chosen from data.

const HIPS := "mixamorig_Hips"
const DIR := "res://assets/models/hero/"
const Hero = preload("res://scripts/hero.gd")



func _anim(file: String) -> Animation:
	var scene: PackedScene = load(DIR + file)
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	var found: Animation = null
	var stack: Array[Node] = [instance]
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		if node is AnimationPlayer and node.has_animation("mixamo_com"):
			found = node.get_animation("mixamo_com")
			break
		stack.append_array(node.get_children())
	instance.free()
	return found

func _bone_track(anim: Animation, bone: String) -> int:
	for i in range(anim.get_track_count()):
		if String(anim.track_get_path(i)).ends_with(":" + bone) and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			return i
	return -1

func _rot_track(anim: Animation, bone: String) -> int:
	for i in range(anim.get_track_count()):
		if String(anim.track_get_path(i)).ends_with(":" + bone) and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
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
		if value is Vector3:
			value = (value as Vector3).lerp(anim.track_get_key_value(track, next) as Vector3, w)
		elif value is Quaternion:
			value = (value as Quaternion).slerp(anim.track_get_key_value(track, next) as Quaternion, w)
	return value

func _initialize() -> void:
	var seams := {
		"Walking.fbx": true, "Running.fbx": true, "Standing Idle.fbx": true,
		"Falling Idle.fbx": true, "Crouched To Sprinting.fbx": false,
		"Jogging Stumble.fbx": false, "Injured Stumble Idle.fbx": false,
		"Catwalk Walk Turn 180 Tight.fbx": false,
		"Unbalanced _Walking.fbx": true,
	}
	for file in seams:
		var anim: Animation = _anim(str(file))
		if anim == null:
			print("MISS %s" % file)
			continue
		var hips_rot := _rot_track(anim, HIPS)
		var foot_pos := _bone_track(anim, "mixamorig_LeftFoot")
		var r0: Variant = _sample(anim, hips_rot, 0.0)
		var r1: Variant = _sample(anim, hips_rot, anim.length)
		var p0: Variant = _sample(anim, foot_pos, 0.0)
		var p1: Variant = _sample(anim, foot_pos, anim.length)
		var rot_deg := 0.0
		if r0 is Quaternion and r1 is Quaternion:
			rot_deg = rad_to_deg((r0 as Quaternion).angle_to(r1 as Quaternion))
		var foot_gap := 0.0
		if p0 is Vector3 and p1 is Vector3:
			foot_gap = (p0 as Vector3).distance_to(p1 as Vector3)
		# motion inside the last FADE window: how much of the take actually
		# moves there (a dead seam means the appended crossfade reads as a freeze)
		var mid: Variant = _sample(anim, foot_pos, maxf(0.0, anim.length - 0.25))
		var travel := 0.0
		if mid is Vector3 and p1 is Vector3:
			travel = (mid as Vector3).distance_to(p1 as Vector3)
		print("SEAM %-34s len=%.3f hips_rot_gap=%.2fdeg foot_gap=%.4f tail_travel=%.4f" % [
			file, anim.length, rot_deg, foot_gap, travel,
		])
	var jump: Animation = _anim("Jumping.fbx")
	if jump != null:
		var head := _bone_track(jump, "mixamorig_Head")
		var lfoot := _bone_track(jump, "mixamorig_LeftFoot")
		var rfoot := _bone_track(jump, "mixamorig_RightFoot")
		var hips_pos := _bone_track(jump, HIPS)
		print("JUMP len=%.3f" % jump.length)
		for i in range(0, 40):
			var when := jump.length * float(i) / 39.0
			var h: Variant = _sample(jump, hips_pos, when)
			var lf: Variant = _sample(jump, lfoot, when)
			var rf: Variant = _sample(jump, rfoot, when)
			var hd: Variant = _sample(jump, head, when)
			print("JUMPS t=%.3f hips_y=%.3f head_y=%.3f lfoot_y=%.3f rfoot_y=%.3f" % [
				when,
				(h as Vector3).y if h is Vector3 else -99.0,
				(hd as Vector3).y if hd is Vector3 else -99.0,
				(lf as Vector3).y if lf is Vector3 else -99.0,
				(rf as Vector3).y if rf is Vector3 else -99.0,
			])
	# Baked state clips as the player really serves them: a loop should keep
	# moving through its wrap (a run of zero-motion samples is a visible freeze)
	# and the jump should cover its own takeoff -> impact span at the set rate.
	var host := Node3D.new()
	root.add_child(host)
	var hero := Hero.create(host)
	var player: AnimationPlayer = hero.get("player")
	if player == null:
		print("BAKE no fbx hero")
	else:
		for state in ["idle", "walk", "run", "unbalanced", "fall", "jump", "stumble"]:
			var clip: Animation = player.get_animation(Hero.CLIP_PREFIX + str(state))
			if clip == null:
				print("BAKE MISS %s" % state)
				continue
			var track := _rot_track(clip, "mixamorig_LeftFoot")
			var steps := int(round(clip.length * 60.0))
			var freeze := 0
			var max_freeze := 0
			var moving := 0
			var prev: Variant = _sample(clip, track, 0.0)
			for i in range(1, steps + 1):
				var cur: Variant = _sample(clip, track, clip.length * float(i) / float(steps))
				var d := 0.0
				if prev is Quaternion and cur is Quaternion:
					d = rad_to_deg((prev as Quaternion).angle_to(cur as Quaternion))
				if d < 0.05:
					freeze += 1
					max_freeze = maxi(max_freeze, freeze)
				else:
					freeze = 0
					moving += 1
				prev = cur
			var rate := 0.0
			if state == "run" or state == "walk":
				rate = clip.length * 13.0 * Hero.SWING_RATIO / TAU
			elif state == "unbalanced":
				var speeds: Dictionary = hero.get("speeds", {})
				var authored := float(speeds.get(state, 0.0))
				# nominal road speed at the start of level_01 (speed 13 + 0.8)
				rate = 13.8 / maxf(0.01, authored)
				print("BAKE unbalanced authored=%.3f m/s, road 13.8 -> cycle %.3fs" % [
					authored, clip.length / rate,
				])
			elif state == "jump":
				rate = float(Hero.CLIPS["jump"].get("rate", 1.0))
			var seen := clip.length / maxf(0.01, rate)
			print("BAKE %-8s len=%.3f rate=%.3f seen=%.3f freeze_steps=%d/%d max_freeze=%d" % [
				str(state), clip.length, rate, seen, steps - moving, steps, max_freeze,
			])
			if state == "jump":
				# take time covered by the hop itself (airtime from the runner)
				var airtime := 10.8 / 25.0 * 2.0
				print("BAKE jump trims=%0.3f..%0.3f of take (airtime %.3fs)" % [
					float(Hero.CLIPS["jump"].get("trim", 0.0)),
					float(Hero.CLIPS["jump"].get("trim", 0.0)) + airtime * rate,
					airtime,
				])
	quit(0)


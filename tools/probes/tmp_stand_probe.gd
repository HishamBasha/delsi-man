extends SceneTree
## Temporary: fine-grained hips curve of Standing Up.fbx to find where the
## rise starts/ends, plus the tail of Stumble Backwards (the take the get-up
## has to continue from) and the trimmed get-up we have now.

func _hips_track(anim: Animation) -> int:
	for index in range(anim.get_track_count()):
		if anim.track_get_type(index) == Animation.TYPE_POSITION_3D \
				and String(anim.track_get_path(index)).ends_with(":mixamorig_Hips"):
			return index
	return -1

func _report(file: String, from: float, to: float, step: float) -> void:
	var path := "res://assets/models/hero/" + file
	if not ResourceLoader.exists(path):
		print("SRC %s MISSING" % file)
		return
	var scene: PackedScene = load(path)
	var instance: Node = scene.instantiate()
	var player: AnimationPlayer = null
	var stack: Array[Node] = [instance]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer and player == null:
			player = node
		stack.append_array(node.get_children())
	if player == null or not player.has_animation("mixamo_com"):
		instance.free()
		return
	var anim: Animation = player.get_animation("mixamo_com")
	var track: int = _hips_track(anim)
	print("SRC %-20s len=%.2f" % [file, anim.length])
	if track < 0:
		instance.free()
		return
	var t: float = from
	while t <= to + 0.001:
		var value: Vector3 = anim.track_get_key_value(track, 0) as Vector3
		# keys on imported tracks are sparse; step through keys only
		var count: int = anim.track_get_key_count(track)
		if t <= anim.track_get_key_time(track, 0):
			value = anim.track_get_key_value(track, 0) as Vector3
		elif t >= anim.track_get_key_time(track, count - 1):
			value = anim.track_get_key_value(track, count - 1) as Vector3
		else:
			var before: int = 0
			for key in range(count - 1):
				if anim.track_get_key_time(track, key + 1) <= t:
					before = key + 1
				else:
					break
			var t0: float = anim.track_get_key_time(track, before)
			var t1: float = anim.track_get_key_time(track, before + 1)
			var alpha := 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
			var a := anim.track_get_key_value(track, before) as Vector3
			var b := anim.track_get_key_value(track, before + 1) as Vector3
			value = a.lerp(b, alpha)
		print("  t=%.2f hips_y=%.3f" % [t, value.y])
		t += step
	instance.free()

func _initialize() -> void:
	_report("Standing Up.fbx", 1.0, 5.0, 0.25)
	_report("Stumble Backwards.fbx", 2.0, 3.33, 0.2)
	quit(0)

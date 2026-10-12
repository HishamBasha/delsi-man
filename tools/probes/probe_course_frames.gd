extends SceneTree
## Projects the generated course's model buildings (and procedural box
## buildings) into each shot_course.gd camera so framing can be verified
## without eyeballing the PNGs.

const Course = preload("res://scripts/course.gd")

var sub: SubViewport = null
var cam: Camera3D = null
var frame := 0
var idx := 0
var targets: Array[Array] = []
var shots: Array = []
var fails := 0

func _initialize() -> void:
	sub = SubViewport.new()
	sub.size = Vector2i(1280, 720)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.own_world_3d = false
	root.add_child(sub)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	sub.add_child(we)

	var flavors: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavors.json"))
	var course: Node3D = Course.new()
	sub.add_child(course)
	course.build(flavors)

	for chunk in course.chunks:
		var zc: float = -chunk.position.z
		for c in chunk.get_children():
			if not (c is Node3D):
				continue
			if c.has_meta("model"):
				targets.append(["model/%.0f/%s" % [zc, str(c.get_meta("model"))], c])
			elif absf(c.position.x) > 5.0 and c.get_child_count() > 0:
				targets.append(["box/%.0f" % zc, c])

	cam = Camera3D.new()
	cam.far = 5000.0
	sub.add_child(cam)
	cam.current = true

	shots = [
		["course_overview", Vector3(0, 55, 40), Vector3(0, 0, -700), 60.0],
		["course_start_models", Vector3(course.center_at(0.0), 2.4, 9.0),
			Vector3(course.center_at(0.0), 5.0, -17.0), 70.0],
		["course_mix_street", Vector3(course.center_at(330.0), 3.0, -330.0),
			Vector3(course.center_at(440.0), 6.0, -445.0), 62.0],
		["course_bend_models", Vector3(course.center_at(430.0), 3.0, -430.0),
			Vector3(course.center_at(487.0), 6.0, -487.0), 62.0],
		["course_warehouse_row", Vector3(course.center_at(1160.0), 3.0, -1160.0),
			Vector3(course.center_at(1240.0), 5.0, -1240.0), 66.0],
	]
	print("PROBE targets=%d (models=%d)" % [targets.size(), _count_models()])

func _count_models() -> int:
	var n := 0
	for t in targets:
		if str(t[0]).begins_with("model/"):
			n += 1
	return n

func _aim(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look)

func _meshes_of(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and n.mesh != null and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_meshes_of(c, out)

func _dump(tag: String) -> void:
	var camt := cam.global_transform
	var models_seen := 0
	var boxes_seen := 0
	print("=== %s cam=(%.1f,%.1f,%.1f) ===" % [tag, cam.global_position.x, cam.global_position.y, cam.global_position.z])
	for t in targets:
		var n: Node = t[1]
		if n == null or not n.is_visible_in_tree():
			continue
		var ms: Array[MeshInstance3D] = []
		_meshes_of(n, ms)
		if ms.is_empty():
			continue
		var minx := 1e9; var maxx := -1e9; var miny := 1e9; var maxy := -1e9
		var behind := true
		for m in ms:
			var aabb := m.get_global_transform() * m.get_aabb()
			for i in 8:
				var c := aabb.get_endpoint(i)
				var p := camt.affine_inverse() * c
				if p.z > -0.05:
					continue
				behind = false
				var pr := cam.unproject_position(c)
				minx = min(minx, pr.x); maxx = max(maxx, pr.x)
				miny = min(miny, pr.y); maxy = max(maxy, pr.y)
		if behind:
			continue
		var onscreen := maxx > 0.0 and minx < 1280.0 and maxy > 0.0 and miny < 720.0
		if not onscreen:
			continue
		var is_model := str(t[0]).begins_with("model/")
		if is_model:
			models_seen += 1
		else:
			boxes_seen += 1
		if is_model:
			print("  %-22s screen=(%4.0f..%4.0f, %4.0f..%4.0f)" % [t[0], minx, maxx, miny, maxy])
	var ok := models_seen > 0
	if not ok:
		fails += 1
	print("  -> models_on_screen=%d boxes_on_screen=%d %s" % [models_seen, boxes_seen, "ok" if ok else "FAIL-NOMODEL"])

func _process(_d: float) -> bool:
	frame += 1
	if frame >= 6 and idx < shots.size():
		var s: Array = shots[idx]
		_aim(s[1], s[2], s[3])
		_dump(s[0])
		idx += 1
		if idx >= shots.size():
			print("PROBE DONE fails=%d" % fails)
			quit(1 if fails > 0 else 0)
	return false

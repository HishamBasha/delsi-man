extends SceneTree
## Screenshots of the GENERATED (played) course into docs/shots/course_*.png
## showing where City box buildings were swapped for imported GLB models.
## Run windowed (NO --headless):  godot --path <proj> -s res://tools/shots/shot_course.gd

const Course = preload("res://scripts/course.gd")

var sub: SubViewport = null
var course: Node3D = null
var cam: Camera3D = null
var frame := 0
var shots := 0

func _initialize() -> void:
	print("SHOT0 display=%s" % DisplayServer.get_name())
	sub = SubViewport.new()
	sub.size = Vector2i(1280, 720)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.own_world_3d = false
	root.add_child(sub)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	sub.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sub.add_child(sun)

	var flavors: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/flavors.json"))
	course = Course.new()
	sub.add_child(course)
	course.build(flavors)
	var model_chunks := 0
	for chunk in course.chunks:
		var keys := ""
		for c in chunk.get_children():
			if c is Node3D and c.has_meta("model"):
				keys += str(c.get_meta("model")) + " "
		if keys != "":
			model_chunks += 1
			print("MODELCHUNK z=%.0f x=%.2f rot=%.3f -> %s" % [
				-chunk.position.z, chunk.position.x, chunk.rotation.y, keys])
	print("SHOT1 course built chunks=%d model_chunks=%d" % [course.chunks.size(), model_chunks])

	cam = Camera3D.new()
	cam.far = 5000.0
	cam.near = 0.1
	sub.add_child(cam)
	cam.current = true

func _aim(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look)

func _capture(tag: String) -> void:
	var p := cam.global_transform
	print("CAMPOS %s pos=(%.1f, %.1f, %.1f) fwd=(%.2f, %.2f, %.2f) fov=%.0f" % [
		tag, p.origin.x, p.origin.y, p.origin.z, -p.basis.z.x, -p.basis.z.y, -p.basis.z.z, cam.fov])
	var tex := sub.get_texture()
	if tex == null:
		print("SHOT-FAIL %s: no sub texture" % tag)
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		print("SHOT-FAIL %s: empty image" % tag)
		return
	var path := "res://docs/shots/%s.png" % tag
	var err := img.save_png(path)
	shots += 1
	print("SHOT %s -> %s size=%s err=%d" % [tag, ProjectSettings.globalize_path(path), img.get_size(), err])

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		25:
			_aim(Vector3(0, 55, 40), Vector3(0, 0, -700), 60.0)
		30:
			_capture("course_overview")
		50:
			_aim(Vector3(course.center_at(0.0), 2.4, 9.0), Vector3(course.center_at(0.0), 5.0, -17.0), 70.0)
		55:
			_capture("course_start_models")
		75:
			_aim(Vector3(course.center_at(330.0), 3.0, -330.0), Vector3(course.center_at(440.0), 6.0, -445.0), 62.0)
		80:
			_capture("course_mix_street")
		100:
			_aim(Vector3(course.center_at(430.0), 3.0, -430.0), Vector3(course.center_at(487.0), 6.0, -487.0), 62.0)
		105:
			_capture("course_bend_models")
		125:
			_aim(Vector3(course.center_at(1160.0), 3.0, -1160.0), Vector3(course.center_at(1240.0), 5.0, -1240.0), 66.0)
		130:
			_capture("course_warehouse_row")
		_:
			if frame > 130:
				print("DONE shots=%d" % shots)
				quit(0)
	return false

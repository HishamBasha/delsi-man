extends SceneTree
## Rough frame-rate cost of the generated course (run WINDOWED, NO --headless):
##   godot --path <proj> -s res://tools/probes/probe_fps.gd
## Builds the course, then flies the chase camera down the street. Measurement:
## vsync off, 0.6 s warmup so the window is actually painting, then 3 s of wall
## time; every frame reads the window texture back so the CPU waits for the GPU
## (without that sync the loop free-runs before the first paint and the numbers
## are meaningless). A/B: comment _build_backdrop() in scripts/course.gd for
## the baseline run.

const Course = preload("res://scripts/course.gd")

var sub: SubViewport = null
var cam: Camera3D = null
var course: Node3D = null
var frame := 0
var last := 0
var measure_start := 0
var measuring := false
var frames_measured := 0
var worst := 0.0
var total := 0.0

func _initialize() -> void:
	print("FPS0 display=%s" % DisplayServer.get_name())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	print("FPS1 built chunks=%d entities=%d" % [course.chunks.size(), course.objects.size()])

	cam = Camera3D.new()
	sub.add_child(cam)
	cam.fov = 70.0
	cam.position = Vector3(course.center_at(330.0), 1.6, -330.0)
	last = Time.get_ticks_msec()

func _process(_dt: float) -> bool:
	frame += 1
	var now := Time.get_ticks_msec()
	var dt_ms := float(now - last)
	last = now
	if frame == 1:
		cam.current = true
		_aim()
		return false
	# sweep the camera down the street so the frustum sees fresh scenery
	cam.position.z -= 0.55
	_aim()
	# GPU sync point: full window readback every frame (same call the shot
	# tools use, so it definitely waits for the frame to finish)
	var img = root.get_texture().get_image()
	if img == null:
		print("FPS warn: no window image at frame %d" % frame)
	if not measuring:
		if now >= _start_ms() + 600:
			measuring = true
			measure_start = now
			print("FPS2 measuring starts at frame %d" % frame)
		return false
	if now - measure_start >= 3000:
		var avg_ms = total / float(maxi(1, frames_measured))
		print("FPS result frames=%d avg_ms=%.2f avg_fps=%.1f worst_ms=%.2f worst_fps=%.1f" % [
			frames_measured, avg_ms, 1000.0 / avg_ms, worst, 1000.0 / worst])
		quit(0)
		return true
	frames_measured += 1
	total += dt_ms
	worst = maxf(worst, dt_ms)
	return false

var _boot_ms := 0

func _start_ms() -> int:
	if _boot_ms == 0:
		_boot_ms = Time.get_ticks_msec()
	return _boot_ms

func _aim() -> void:
	var dist := -cam.position.z
	cam.position.x = course.center_at(dist)
	cam.look_at(Vector3(course.center_at(dist + 55.0), 1.2, -(dist + 55.0)))

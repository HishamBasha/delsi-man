extends SceneTree
## Filmstrips: one across the run loop wrap, one across a whole jump, so loop
## continuity and the single-take hop can be judged frame by frame.
## Run windowed (NO --headless):
##   godot --path <proj> -s res://tools/shots/shot_strip.gd

const OUT := "C:/Users/Hisham/AppData/Local/Temp/opencode/strip"

var game: Node3D = null
var follow: Camera3D = null
var frame := 0
var strip := ""
var total := 0
var index := 0
var every := 1
var wait := 0
var run_armed := true
var jump_armed := true
var jump_called := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	follow = Camera3D.new()
	follow.fov = 50
	root.add_child(follow)
	follow.current = true
	print("STRIP ready")

func _hero() -> Dictionary:
	return game.get("hero")

func _start(tag: String, count: int, stride: int) -> void:
	strip = tag
	total = count
	every = stride
	index = 0
	wait = 0
	print("STRIP start %s x%d every %d" % [tag, total, every])

func _capture() -> void:
	var hero := _hero()
	var runner: Node = game.get("runner")
	var player: AnimationPlayer = hero.get("player")
	var root_node: Node3D = hero.get("root")
	# The texture is the last rendered frame, so force the view state a frame
	# early: current camera, unblinking hero.
	var game_cam: Variant = game.get("camera")
	var vis_before := root_node.visible
	if game_cam != null:
		game_cam.current = false
	follow.current = true
	root_node.call_deferred("set_visible", true)
	root_node.visible = true
	if runner != null:
		runner.set("invulnerable", 10.079)
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("SHOT-FAIL %s %d" % [strip, index])
		return
	img.resize(320, 180, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	var path := "%s/%s_%02d.png" % [OUT, strip, index]
	img.save_png(path)
	var dist := follow.global_position.distance_to(root_node.global_position)
	print("SHOT %s t=%.3f ss=%.3f pos=%.3f anim=%s state=%s h=%.2f vy=%.2f dist=%.2f vis0=%s inv=%.3f hero=%s" % [
		path,
		float(Time.get_ticks_msec()) / 1000.0,
		player.speed_scale if player != null else -1.0,
		player.current_animation_position if player != null else -1.0,
		player.current_animation if player != null else "?",
		str(hero.get("state")),
		float(runner.get("height")) if runner != null else -1.0,
		float(runner.get("vertical_speed")) if runner != null else -1.0,
		dist,
		str(vis_before),
		float(runner.get("invulnerable")) if runner != null else -1.0,
		str(root_node.global_position),
	])
	index += 1
	if index >= total:
		print("STRIP done %s" % strip)
		strip = ""

func _process(_delta: float) -> bool:
	frame += 1
	var run: Node = game.get("runner")
	if run != null:
		# update_visuals blinks the body on `fmod(invulnerable, 0.16) > 0.06`
		# while counting down, so keep the window parked just under a multiple of
		# 0.16: unhit (still > 0) and visible for any frame under ~0.1s.
		run.set("invulnerable", 10.079)
	var hero := _hero()
	if not hero.is_empty() and hero.get("root") != null:
		# update_visuals blinks the body during the invulnerable window; defer the
		# override so it lands after the game's own pass and before the draw.
		(hero.root as Node3D).call_deferred("set_visible", true)
		var target: Vector3 = (hero.root as Node3D).global_position
		follow.global_position = target + Vector3(1.1, 1.1, 2.7)
		follow.look_at(target + Vector3(0, 0.6, 0))
		var game_cam: Variant = game.get("camera")
		if game_cam != null:
			game_cam.current = false
		follow.current = true
	if hero.is_empty() or hero.get("root") == null or run == null:
		return false
	if not strip.is_empty():
		if wait > 0:
			wait -= 1
			return false
		_capture()
		if strip.is_empty():
			return false
		wait = every - 1
		return false
	var player: AnimationPlayer = hero.get("player")
	match frame:
		6:
			for menu_key in ["menu", "main_menu"]:
				var menu: Variant = game.get(menu_key)
				if menu != null:
					menu.call("hide")
		30:
			game.call("start_or_resume")
		300:
			print("STRIP no more captures")
			quit(0)
	if player == null:
		return false
	# The hop starts only once the loop strip is in, so both bursts are seen.
	if not jump_called and not run_armed and strip.is_empty() and frame > 40:
		run.call("jump")
		jump_called = true
	if run_armed and player.current_animation == "delsi/run" \
			and player.current_animation_position > player.current_animation_length - 0.17:
		run_armed = false
		_start("runwrap", 14, 1)
	elif jump_armed and float(run.get("vertical_speed")) > 0.0:
		jump_armed = false
		_start("jump", 20, 1)
	return false

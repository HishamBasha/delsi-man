extends SceneTree
## Barrel obstruction: a filmstrip while the barrel rides the runner's head,
## which is also when the controls are reversed and the hero must play the
## unbalanced walk instead of the run. Captures through the game's own camera
## (the player's view) and prints the clip, state, playback rate (the ground
## pacing) and where the barrel projects on screen for every frame.
## Run windowed (NO --headless):
##   godot --path <proj> -s res://tools/shots/shot_barrel.gd

const OUT := "C:/Users/Hisham/AppData/Local/Temp/opencode/barrel"

var game: Node3D = null
var frame := 0
var shot := 0
var wait := 0
var started := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	print("BARREL ready")

func _capture() -> void:
	var hero: Dictionary = game.get("hero")
	var runner: Node = game.get("runner")
	var player: AnimationPlayer = hero.get("player")
	var root_node: Node3D = hero.get("root")
	var game_cam: Camera3D = game.get("camera")
	var barrel: Node3D = game.get("barrel_node")
	root_node.call_deferred("set_visible", true)
	root_node.visible = true
	if runner != null:
		runner.set("invulnerable", 10.079)
	if barrel != null:
		barrel.call_deferred("set_visible", true)
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("SHOT-FAIL %d" % shot)
		return
	img.resize(320, 180, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	var path := "%s/barrel_%02d.png" % [OUT, shot]
	img.save_png(path)
	var barrel_screen := Vector2(-999, -999)
	var barrel_visible := false
	if barrel != null:
		barrel_visible = barrel.visible
		if game_cam != null and barrel_visible:
			barrel_screen = game_cam.unproject_position(barrel.global_position + Vector3(0, 0.55, 0))
	print("SHOT %s ss=%.3f anim=%s state=%s barrel=%.2f vis=%s barrel_screen=%s hero=%s" % [
		path,
		player.speed_scale if player != null else -1.0,
		player.current_animation if player != null else "?",
		str(hero.get("state")),
		float(game.get("barrel_left")),
		str(barrel_visible),
		str(barrel_screen),
		str(root_node.global_position),
	])
	shot += 1

func _process(_delta: float) -> bool:
	frame += 1
	var runner: Node = game.get("runner")
	if runner != null:
		runner.set("invulnerable", 10.079)
	var hero: Dictionary = game.get("hero")
	if hero.is_empty() or hero.get("root") == null:
		return false
	(hero.root as Node3D).call_deferred("set_visible", true)
	var barrel: Node3D = game.get("barrel_node")
	if barrel != null and started:
		barrel.call_deferred("set_visible", true)
	match frame:
		6:
			for menu_key in ["menu", "main_menu"]:
				var menu: Variant = game.get(menu_key)
				if menu != null:
					menu.call("hide")
		30:
			game.call("start_or_resume")
		38:
			# the event itself, straight from the game: sets barrel_left and the
			# reversed controls with it
			game.call("_barrel_event")
			started = true
		260:
			print("BARREL done shots=%d barrel=%.2f state=%s clip=%s" % [
				shot, float(game.get("barrel_left")), str(hero.get("state")),
				str(hero.get("clip")),
			])
			quit(0)
	if not started:
		return false
	if shot >= 14:
		return false
	if wait > 0:
		wait -= 1
		return false
	_capture()
	# 4 frames apart = 15 frames = ~0.25s at 60fps: one full cycle of the
	# unbalanced take per roughly three shots
	wait = 3
	return false

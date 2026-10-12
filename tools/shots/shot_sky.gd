extends SceneTree
## Sky check: a couple of frames of gameplay with the panorama background, plus
## the environment values it was built with.
## Run windowed (NO --headless):
##   godot --path <proj> -s res://tools/shots/shot_sky.gd

const OUT := "C:/Users/Hisham/AppData/Local/Temp/opencode/sky"

var game: Node3D = null
var frame := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	print("SKY ready")

func _capture(tag: String) -> void:
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("SHOT-FAIL %s" % tag)
		return
	var path := "%s/frame_%s.png" % [OUT, tag]
	img.save_png(path)
	var env: Variant = _environment()
	if env != null:
		var settings: Environment = env
		var mode := "sky" if settings.background_mode == Environment.BG_SKY else "color"
		print("SHOT %s mode=%s fog_sky_affect=%.2f fog=%s -> %s" % [
			tag, mode, settings.fog_sky_affect, str(settings.fog_light_color), path,
		])
	else:
		print("SHOT %s (no environment) -> %s" % [tag, path])

func _environment() -> Environment:
	for child in game.get_children():
		if child is WorldEnvironment:
			return (child as WorldEnvironment).environment
	return null

func _process(_delta: float) -> bool:
	frame += 1
	var runner: Node = game.get("runner")
	if runner != null:
		runner.set("invulnerable", 10.079)
	var hero: Variant = game.get("hero")
	if hero is Dictionary and not (hero as Dictionary).is_empty() and (hero as Dictionary).get("root") != null:
		(((hero as Dictionary).root) as Node3D).call_deferred("set_visible", true)
	match frame:
		40:
			game.call("start_or_resume")
		120:
			_capture("run")
		180:
			_capture("run2")
			print("SKY done")
			quit(0)
	return false

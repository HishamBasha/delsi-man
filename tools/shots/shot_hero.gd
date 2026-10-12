extends SceneTree
## Screenshots of every baked hero state into contact sheets, filmed from a
## camera that follows behind the runner (the direction the game travels).
## Run windowed (NO --headless):
##   godot --path <proj> -s res://tools/shots/shot_hero.gd

const OUT := "C:/Users/Hisham/AppData/Local/Temp/opencode/hero"
const CELL := Vector2i(640, 360)
const COLS := 2
const ROWS := 2

var game: Node3D = null
var follow: Camera3D = null
var label: Label = null
var frame := 0
var sheet: Image = null
var sheet_index := 0
var cell := 0
var pending := ""

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	follow = Camera3D.new()
	follow.fov = 50
	root.add_child(follow)
	follow.current = true
	label = Label.new()
	label.position = Vector2(10, 6)
	label.add_theme_font_size_override("font_size", 26)
	root.add_child(label)
	sheet = Image.create_empty(CELL.x * COLS, CELL.y * ROWS, false, Image.FORMAT_RGB8)
	print("SHOT0 hero sheet ready")

func _shoot(tag: String) -> void:
	label.text = tag
	pending = tag
	print("STEP %s (frame %d)" % [tag, frame])

func _capture(tag: String) -> void:
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("SHOT-FAIL %s" % tag)
		return
	var hero: Dictionary = game.get("hero")
	print("SHOT %s anim=%s pos=%s visible=%s" % [
		tag,
		str(hero.get("player").current_animation) if hero.get("player") != null else "?",
		str((hero.get("root") as Node3D).global_position),
		str(hero.get("root").visible),
	])
	img.save_png("%s/full_%s.png" % [OUT, tag])
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	var at := Vector2i(CELL.x * (cell % COLS), CELL.y * (cell / COLS))
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
	cell += 1
	print("SHOT %s -> cell %d" % [tag, cell - 1])
	if cell >= COLS * ROWS:
		_save()

func _save() -> void:
	var path := "%s/sheet_%d.png" % [OUT, sheet_index]
	print("SHEET %d err=%d -> %s" % [sheet_index, sheet.save_png(path), path])
	sheet_index += 1
	cell = 0
	sheet = Image.create_empty(CELL.x * COLS, CELL.y * ROWS, false, Image.FORMAT_RGB8)

func _runner() -> Node:
	return game.get("runner")

func _process(_delta: float) -> bool:
	if not pending.is_empty():
		var tag := pending
		pending = ""
		_capture(tag)
		return false
	frame += 1
	var run: Node = _runner()
	if run != null:
		run.set("invulnerable", 10.0)
	var hero: Dictionary = game.get("hero")
	if not hero.is_empty() and hero.get("root") != null:
		(hero.root as Node3D).visible = true
	if hero.is_empty() or hero.get("root") == null:
		return false
	var target: Vector3 = (hero.root as Node3D).global_position
	follow.global_position = target + Vector3(1.1, 1.1, 2.7)
	follow.look_at(target + Vector3(0, 0.6, 0))
	var game_cam: Variant = game.get("camera")
	if game_cam != null:
		game_cam.current = false
	follow.current = true
	match frame:
		5:
			var menu: Variant = game.get("menu")
			if menu != null:
				menu.call("hide")
			var main_menu: Variant = game.get("main_menu")
			if main_menu != null:
				main_menu.call("hide")
			_shoot("idle")
		25:
			game.call("start_or_resume")
		30:
			_shoot("walk")
		60:
			_shoot("run")
		61:
			Input.action_press("sprint")
		68:
			hero["sprint_left"] = 0.35
		72:
			_shoot("sprint")
		76:
			Input.action_release("sprint")
		80:
			_runner().call("jump")
		95:
			_shoot("jump")
		112:
			_shoot("fall")
		140:
			_runner().call("slide")
		152:
			_shoot("slide")
		195:
			_runner().call("stumble", 1.0, 0)
		225:
			_shoot("stumble")
		250:
			_shoot("stumble_end")
		290:
			# A light hit has no second phase: he is back on the run by now.
			_shoot("run_after")
		315:
			_runner().call("stumble", 1.0, 1)
		345:
			_shoot("knock")
		430:
			_shoot("getup")
		500:
			_runner().call("stumble", 1.0, 4)
		530:
			_shoot("hole")
		600:
			if cell > 0:
				_save()
			print("DONE sheets=%d" % (sheet_index + (1 if cell > 0 else 0)))
			quit(0)
	return false

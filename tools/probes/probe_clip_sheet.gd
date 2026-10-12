extends SceneTree
## Renders every hero FBX at four timestamps into contact sheets so clip
## choice, trim windows and facing can be judged from screenshots.
## Run windowed (NO --headless):
##   godot --path <proj> -s res://tools/probes/probe_clip_sheet.gd

const DIR := "res://assets/models/hero"
const OUT := "C:/Users/Hisham/AppData/Local/Temp/opencode/clips"
const FRACTIONS := [0.0, 0.3, 0.6, 0.9]
const CELL := Vector2i(320, 180)
const ROWS_PER_SHEET := 4
const SETTLE := 4

var files: Array[String] = []
var file_index := 0
var shot_index := 0
var settle := 0
var instance: Node = null
var player: AnimationPlayer = null
var camera: Camera3D = null
var label: Label = null
var sheet: Image = null
var sheet_index := 0
var row := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var all := Array(DirAccess.open(DIR).get_files())
	all.sort()
	for file in all:
		if file.to_lower().ends_with(".fbx"):
			files.append(file)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.12, 0.16, 0.22)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.7, 0.7, 0.75)
	settings.ambient_light_energy = 1.0
	env.environment = settings
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.4
	root.add_child(light)
	camera = Camera3D.new()
	camera.fov = 55
	root.add_child(camera)
	camera.current = true
	label = Label.new()
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)
	_new_sheet()
	_next_file()

func _new_sheet() -> void:
	sheet = Image.create_empty(
		CELL.x * FRACTIONS.size(),
		CELL.y * ROWS_PER_SHEET,
		false, Image.FORMAT_RGB8)

func _next_file() -> void:
	if instance != null:
		instance.free()
		instance = null
	if file_index >= files.size():
		_save_sheet()
		print("SHEET done -> %s" % OUT)
		quit(0)
		return
	var file := files[file_index]
	label.text = "%d  %s" % [file_index, file]
	print("FILE %s" % file)
	var scene: PackedScene = load(DIR + "/" + file)
	instance = scene.instantiate()
	player = null
	var stack: Array[Node] = [instance]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D or node is Light3D:
			node.get_parent().remove_child(node)
			node.free()
			continue
		if node is AnimationPlayer and player == null:
			player = node
		stack.append_array(node.get_children())
	root.add_child(instance)
	var from := Vector3(1.7, 1.5, 3.1)
	var to := Vector3(0, 1.0, 0)
	camera.transform = Transform3D(Basis.looking_at((to - from).normalized()), from)
	shot_index = 0
	settle = 0
	player.play(player.get_animation_list()[0])
	_seek()

func _seek() -> void:
	var anim: Animation = player.get_animation(player.current_animation)
	player.seek(anim.length * FRACTIONS[shot_index], true)

func _capture() -> void:
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("  CAPTURE-EMPTY shot=%d" % shot_index)
	else:
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL),
			Vector2i(CELL.x * shot_index, CELL.y * row))
		print("  shot=%d t=%.2f" % [shot_index, FRACTIONS[shot_index]])
	shot_index += 1
	if shot_index >= FRACTIONS.size():
		row += 1
		file_index += 1
		if row >= ROWS_PER_SHEET:
			_save_sheet()
			sheet_index += 1
			row = 0
			_new_sheet()
		_next_file()
	else:
		_seek()
		settle = 0

func _save_sheet() -> void:
	if sheet == null or row == 0:
		return
	var path := "%s/sheet_%d.png" % [OUT, sheet_index]
	var err := sheet.save_png(path)
	print("SHEET %d rows=%d err=%d -> %s" % [sheet_index, row, err, path])

func _process(_delta: float) -> bool:
	if instance == null:
		return false
	settle += 1
	if settle >= SETTLE:
		_capture()
	return false

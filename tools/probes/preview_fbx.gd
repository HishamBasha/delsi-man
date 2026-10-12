extends SceneTree

var inst: Node = null
var player: AnimationPlayer = null
var skel: Skeleton3D = null
var camera: Camera3D = null
var frame := 0
var shot := 0
const SHOTS := [0.0, 0.25, 0.5, 0.8]

func _initialize() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.6
	root.add_child(light)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.4, 0.5, 0.55)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 1.0
	env.environment = settings
	root.add_child(env)
	var ps: PackedScene = load("res://assets/models/hero/Catwalk Walk Turn 180 Tight.fbx")
	inst = ps.instantiate()
	root.add_child(inst)
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Camera3D or n is Light3D:
			n.get_parent().remove_child(n)
			n.queue_free()
			continue
		if n is AnimationPlayer and player == null:
			player = n
		if n is Skeleton3D and skel == null:
			skel = n
		for c in n.get_children():
			stack.append(c)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 60
	camera.position = Vector3(0, 1.4, 3.4)
	camera.rotation_degrees = Vector3(-4, 0, 0)
	player.play(player.get_animation_list()[0])
	print("PREVIEW: anim=", player.get_animation_list()[0], " len=", player.get_animation(player.get_animation_list()[0]).length)

func _process(_delta: float) -> bool:
	frame += 1
	if frame % 30 != 0:
		return false
	if shot >= SHOTS.size():
		return false
	player.seek(SHOTS[shot], true)
	var img := root.get_texture().get_image()
	var path := "user://preview_%d.png" % shot
	img.save_png(path)
	var abs_path := OS.get_user_data_dir().path_join("preview_%d.png" % shot)
	print("PREVIEW: saved t=%.2f -> %s (size=%s)" % [SHOTS[shot], abs_path, img.get_size()])
	shot += 1
	if shot >= SHOTS.size():
		var hips := skel.get_bone_global_pose(0)
		print("PREVIEW: hips global=", hips)
		quit(0)
	return false


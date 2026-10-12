extends SceneTree
## Screenshots of the demo level (manual_sample_level) into docs/shots/level_*.png
## Renders inside an offscreen SubViewport (immune to window occlusion stalls).
## Run windowed (NO --headless):  godot --path <proj> -s res://tools/shots/shot_level.gd

const LEVEL := "res://scenes/levels/manual_sample_level.tscn"
const PREFABS := [
	"building_small", "building_tall", "building_tower", "warehouse",
	"car_sedan", "car_van",
	"tree_small", "tree_med", "tree_big",
	"ped_walk", "ped_idle", "ped_civil",
	"barrier", "cone", "statue",
]

var sub: SubViewport = null
var level: Node3D = null
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

	level = load(LEVEL).instantiate()
	sub.add_child(level)
	print("SHOT1 level added children=%d" % level.get_child_count())

	cam = Camera3D.new()
	cam.far = 5000.0
	cam.near = 0.1
	sub.add_child(cam)
	cam.current = true
	print("SHOT2 subviewport+env+light+cam ready")

func _aim(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look)

func _capture(tag: String) -> void:
	var p := cam.global_transform
	print("CAMPOS %s pos=(%.1f, %.1f, %.1f) fwd=(%.2f, %.2f, %.2f) current=%s fov=%.0f" % [
		tag, p.origin.x, p.origin.y, p.origin.z, -p.basis.z.x, -p.basis.z.y, -p.basis.z.z,
		str(cam.current), cam.fov])
	var ac := sub.get_camera_3d()
	if ac != null:
		var ap := ac.global_transform
		print("ACTUALCAM %s path=%s pos=(%.1f, %.1f, %.1f) fov=%.0f" % [
			tag, ac.get_path(), ap.origin.x, ap.origin.y, ap.origin.z, ac.fov])
	else:
		print("ACTUALCAM %s NONE" % tag)
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

func _spawn_inventory() -> void:
	var inv := Node3D.new()
	inv.name = "Inventory"
	sub.add_child(inv)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(60, 1, 430)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(80, -0.5, -200)
	inv.add_child(floor_mi)
	for i in PREFABS.size():
		var ps := load("res://scenes/prefabs/%s.tscn" % PREFABS[i]) as PackedScene
		if ps == null:
			print("SHOT-FAIL inventory load ", PREFABS[i])
			continue
		var inst := ps.instantiate()
		inst.position = Vector3(80, 0, -40 - i * 24.0)
		inv.add_child(inst)
	print("SHOT inventory spawned count=%d" % PREFABS.size())

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		25:
			_aim(Vector3(0, 45, 50), Vector3(0, 8, -750), 60.0)
		30:
			_capture("level_overview")
		50:
			_aim(Vector3(0, 2.2, -120), Vector3(-6, 4, -300), 70.0)
		55:
			_capture("level_street")
		75:
			_aim(Vector3(-7.5, 1.6, -193), Vector3(-11.0, 3.0, -199), 60.0)
		80:
			_capture("level_close_tree")
		100:
			_aim(Vector3(7.8, 1.6, -173), Vector3(11.2, 1.0, -176.8), 60.0)
		105:
			_capture("level_close_ped")
		125:
			_aim(Vector3(2.0, 1.7, -240), Vector3(-3.2, 0.9, -250), 60.0)
		130:
			_capture("level_close_car")
		150:
			_aim(Vector3(4.5, 1.6, -690), Vector3(7.5, 1.0, -700), 60.0)
		155:
			_capture("level_close_barrier")
		160:
			_aim(Vector3(0.5, 1.7, -548), Vector3(3.2, 1.0, -560), 60.0)
		165:
			_capture("level_close_van")
		175:
			_aim(Vector3(1.0, 2.0, -1718), Vector3(4.2, 1.5, -1735), 55.0)
		180:
			_capture("level_finish")
		181:
			_spawn_inventory()
		185:
			_aim(Vector3(-6.0, 3.0, -1120), Vector3(-18.5, 5.0, -1150), 60.0)
		190:
			_capture("level_close_warehouse")
		195:
			_aim(Vector3(4.8, 1.0, -116.5), Vector3(6.6, 0.35, -120), 55.0)
		200:
			_capture("level_close_cone")
		205:
			_aim(Vector3(40, 5, -88), Vector3(80, 3, -88), 80.0)
		210:
			_capture("level_inventory_1")
		230:
			_aim(Vector3(40, 5, -208), Vector3(80, 3, -208), 80.0)
		235:
			_capture("level_inventory_2")
		255:
			_aim(Vector3(40, 4, -328), Vector3(80, 2, -328), 80.0)
		260:
			_capture("level_inventory_3")
		265:
			_aim(Vector3(1.0, 1.6, -1727), Vector3(4.2, 1.1, -1735), 60.0)
		270:
			_capture("level_close_statue")
		_:
			if frame > 272:
				print("DONE shots=%d" % shots)
				quit(0)
	return false

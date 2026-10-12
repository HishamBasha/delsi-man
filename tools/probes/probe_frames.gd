extends SceneTree
## For each shot camera: print one line per placed instance (top-level node)
## with its world AABB center and projected screen bbox.

const LEVEL := "res://scenes/levels/manual_sample_level.tscn"

var sub: SubViewport = null
var cam: Camera3D = null
var frame := 0

var shots := [
	["level_overview", Vector3(0, 45, 50), Vector3(0, 8, -750), 60.0],
	["level_street", Vector3(0, 2.2, -120), Vector3(-6, 4, -300), 70.0],
	["level_close_tree", Vector3(-7.5, 1.6, -193), Vector3(-11.0, 3.0, -199), 60.0],
	["level_close_ped", Vector3(7.8, 1.6, -173), Vector3(11.2, 1.0, -176.8), 60.0],
	["level_close_car", Vector3(2.0, 1.7, -240), Vector3(-3.2, 0.9, -250), 60.0],
	["level_close_barrier", Vector3(4.5, 1.6, -690), Vector3(7.5, 1.0, -700), 60.0],
	["level_close_van", Vector3(0.5, 1.7, -548), Vector3(3.2, 1.0, -560), 60.0],
	["level_close_warehouse", Vector3(-6.0, 3.0, -1120), Vector3(-18.5, 5.0, -1150), 60.0],
	["level_close_cone", Vector3(4.8, 1.0, -116.5), Vector3(6.6, 0.35, -120), 55.0],
	["level_close_statue", Vector3(1.0, 1.6, -1727), Vector3(4.2, 1.1, -1735), 60.0],
	["level_finish", Vector3(1.0, 2.0, -1718), Vector3(4.2, 1.5, -1735), 55.0],
	["level_inventory_1", Vector3(40, 5, -88), Vector3(80, 3, -88), 80.0],
	["level_inventory_2", Vector3(40, 5, -208), Vector3(80, 3, -208), 80.0],
	["level_inventory_3", Vector3(40, 4, -328), Vector3(80, 2, -328), 80.0],
]
var idx := 0
var targets: Array[Array] = []

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
	var level := (load(LEVEL) as PackedScene).instantiate()
	sub.add_child(level)
	cam = Camera3D.new()
	cam.far = 5000.0
	sub.add_child(cam)
	cam.current = true
	for c in level.get_children():
		if c is Node3D:
			_targets_for(c)
	print("PROBE targets=%d" % targets.size())

func _targets_for(rootn: Node) -> void:
	# groups (LeftBuildings etc.): one target per child; else one target for whole node
	if rootn.get_child_count() > 0 and (rootn.name == "LeftBuildings" or rootn.name == "RightBuildings"):
		for c in rootn.get_children():
			targets.append([rootn.name + "/" + c.name, c])
	elif rootn.name == "Ground":
		targets.append(["Ground/Road", rootn.get_node_or_null("Road")])
	else:
		targets.append([String(rootn.name), rootn])

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
	print("=== %s cam=(%.1f,%.1f,%.1f) ===" % [tag, cam.global_position.x, cam.global_position.y, cam.global_position.z])
	var camt := cam.global_transform
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
		var wmin := Vector3(1e9, 1e9, 1e9); var wmax := Vector3(-1e9, -1e9, -1e9)
		for m in ms:
			var aabb := m.get_global_transform() * m.get_aabb()
			wmin = wmin.min(aabb.position); wmax = wmax.max(aabb.end)
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
		var ctr := (wmin + wmax) * 0.5
		print("  %-22s screen=(%4.0f..%4.0f, %4.0f..%4.0f) world=(%.1f,%.1f,%.1f) size=%s" % [
			t[0], minx, maxx, miny, maxy, ctr.x, ctr.y, ctr.z, (wmax - wmin)])

func _process(_d: float) -> bool:
	frame += 1
	if frame == 10:
		_spawn_inventory()
	if frame >= 12 and idx < shots.size():
		var s: Array = shots[idx]
		_aim(s[1], s[2], s[3])
		_dump(s[0])
		idx += 1
		if idx >= shots.size():
			print("PROBE DONE")
			quit(0)
	return false

func _spawn_inventory() -> void:
	var inv := Node3D.new()
	inv.name = "Inventory"
	sub.add_child(inv)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(60, 1, 430)
	var fmi := MeshInstance3D.new()
	fmi.mesh = floor_mesh
	fmi.position = Vector3(80, -0.5, -200)
	inv.add_child(fmi)
	var prefabs := [
		"building_small", "building_tall", "building_tower", "warehouse",
		"car_sedan", "car_van", "tree_small", "tree_med", "tree_big",
		"ped_walk", "ped_idle", "ped_civil", "barrier", "cone", "statue",
	]
	for i in prefabs.size():
		var ps := load("res://scenes/prefabs/%s.tscn" % prefabs[i]) as PackedScene
		var inst := ps.instantiate()
		inst.position = Vector3(80, 0, -40 - i * 24.0)
		inv.add_child(inst)
	for c in inv.get_children():
		targets.append(["inv/" + String(c.name), c])

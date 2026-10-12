extends Node3D
const Art = preload("res://scripts/art.gd")
const City = preload("res://scripts/city.gd")
const Models = preload("res://scripts/models.gd")
const RoadHazardScene = preload("res://scripts/entities/road_hazard.gd")
const HOLE_SCENE: PackedScene = preload("res://scenes/hazards/hole_obstacle.tscn")
const TRUCK_SCENE: PackedScene = preload("res://scenes/hazards/truck_thrower.tscn")
const THROWN_OBJECT_SCENE: PackedScene = preload("res://scenes/hazards/thrown_object.tscn")
const STAIRS_SCENE: PackedScene = preload("res://scenes/hazards/stairs.tscn")
@export var use_in_game := false
@export var curved := false
var objects: Array[Dictionary] = []
var chunks: Array[Node3D] = []
var props: Array[Dictionary] = []
var colors: Array[Color] = []
var bends: Array[Dictionary] = []
var length := 1800.0
var finish_at := 0.0
const ROAD_LIMIT := 5.8

func load_from_scene(level_root: Node) -> void:
	objects.clear()
	finish_at = 0.0
	_collect_scene_items(level_root)
	if objects.is_empty():
		return
	if finish_at > 0.0:
		length = finish_at
	for item in objects:
		if item.has("node") and item.node is Node3D:
			item.node.visible = true
			item.node.scale = Vector3.ONE

func _collect_scene_items(node: Node) -> void:
	if node is Node3D and node.has_meta("kind"):
		var kind = int(node.get_meta("kind"))
		var distance = node.global_position.z * -1.0
		if kind == 11:
			finish_at = maxf(finish_at, distance)
		elif kind < 10 or kind == 12:
			var radius = float(node.get_meta("radius")) if node.has_meta("radius") else (0.72 if kind == 3 else 1.05)
			var item = {
				"id": node.name,
				"at": distance,
				"kind": kind,
				"node": node,
				"x": float(node.position.x),
				"radius": radius,
				"done": false,
			}
			if node.has_meta("clear"):
				item["clear"] = float(node.get_meta("clear"))
			if kind == 5 and float(node.get_meta("throw_offset", 0.0)) > 0.0:
				item.throw_start = distance - float(node.get_meta("throw_offset", 28.0))
				item.start_x = float(node.get_meta("start_x", 6.7))
				item.land_x = float(node.position.x)
				item.arc = float(node.get_meta("arc", 2.1))
				item.spin = float(node.get_meta("spin", 0.0))
			elif kind < 3 and float(node.get_meta("drift_amp", 0.0)) > 0.0:
				item.base_x = float(node.position.x)
				item.drift_amp = float(node.get_meta("drift_amp", 0.0))
				item.drift_speed = float(node.get_meta("drift_speed", 0.04))
				item.drift_phase = distance * 0.71
			objects.append(item)
	for child in node.get_children():
		_collect_scene_items(child)

func center_at(at: float) -> float:
	if bends.is_empty():
		return 0.0
	var c := 0.0
	for b in bends:
		var t := clampf((at - (float(b.at) - 45.0)) / 90.0, 0.0, 1.0)
		c += float(b.delta) * (t * t * (3.0 - 2.0 * t))
	return c

func build(flavors: Array) -> void:
	objects.clear()
	chunks.clear()
	props.clear()
	colors.clear()
	bends.clear()
	for f in flavors:
		colors.append(Color(f.color))
	var rng = RandomNumberGenerator.new()
	rng.seed = 62109
	curved = true
	bends = [
		{"at": 330.0, "delta": 4.0},
		{"at": 585.0, "delta": -6.0},
		{"at": 960.0, "delta": 5.0},
		{"at": 1255.0, "delta": -5.0},
		{"at": 1560.0, "delta": 3.0},
	]
	for index in range(61):
		var at = index * 30.0
		var chapter = mini(5, int(at / 300.0))
		var color = colors[chapter % colors.size()]
		var chunk = Node3D.new()
		add_child(chunk)
		var c0 = center_at(at)
		chunk.position = Vector3(c0, 0, -at)
		chunk.rotation.y = atan2(-(center_at(at + 30.0) - c0), 30.0)
		chunks.append(chunk)
		_build_env(chunk, index, at, chapter, color, flavors, rng)
	_build_stages(rng)
	_spawn_stair_sets()
	_finish_gate()
	_build_backdrop()

func _build_env(chunk: Node3D, index: int, at: float, chapter: int, color: Color, flavors: Array, rng: RandomNumberGenerator) -> void:
	Art.box(chunk, Vector3(0, -0.35, -15), Vector3(12.4, 0.6, 30), Color("263947"))
	for side in [-1, 1]:
		Art.box(chunk, Vector3(side * 6.5, 0, -15), Vector3(1, 0.8, 30), Color("ead4ad"))
		Art.box(chunk, Vector3(side * 5.8, 0.06, -15), Vector3(0.09, 0.08, 29), color, true)
	for stripe in range(5):
		Art.box(chunk, Vector3(0, 0.02, -4 - stripe * 5.6), Vector3(0.14, 0.05, 1.7), Color("e8e3d5"))
	for tx in [-1.7, 1.7]:
		Art.box(chunk, Vector3(tx, -0.01, -15), Vector3(0.55, 0.05, 29), Color("1f2e3a"))
	for side in [-1, 1]:
		Art.box(chunk, Vector3(side * 4.9, 0.015, -15), Vector3(0.12, 0.05, 29), Color("d8d5c8"))
		Art.box(chunk, Vector3(side * 5.5, -0.02, -15), Vector3(0.7, 0.05, 29), Color("1a2630"))
		Art.box(chunk, Vector3(side * 5.93, 0.2, -15), Vector3(0.06, 0.38, 29), Color("e0c04a") if index % 2 == 0 else Color("d8d2c4"))
		for groove in [4, 13, 22]:
			Art.box(chunk, Vector3(side * 6.5, 0.405, -groove), Vector3(0.96, 0.02, 0.12), Color("8f8674"))
	for p in range(2):
		Art.box(chunk, Vector3(rng.randf_range(-3.4, 3.4), -0.02, rng.randf_range(-5, -26)), Vector3(rng.randf_range(2.0, 4.5), 0.05, rng.randf_range(3.0, 7.0)), Color("20313e"))
	if index % 4 == 2:
		Art.cylinder(chunk, Vector3(rng.randf_range(-3.0, 3.0), -0.01, rng.randf_range(-6, -24)), 0.5, 0.06, Color("39424b"))
	if index % 3 == 1:
		for side in [-1, 1]:
			Art.box(chunk, Vector3(side * 5.2, 0.01, -15), Vector3(0.5, 0.04, 28), Color("8a7a5e"))
	if index in [10, 20, 30, 40, 50]:
		for s in range(6):
			Art.box(chunk, Vector3(-4.5 + s * 1.8, 0.02, -3.5), Vector3(1.0, 0.05, 2.6), Color("e8e3d5"))
	var suppress = index in [21, 22, 23, 26, 27, 28, 29]
	if not suppress:
		if index % 2 == 0:
			for side in [-1, 1]:
				var h = rng.randf_range(7.0, 13.5)
				if chapter == 2:
					h = rng.randf_range(9.0, 15.0)
				var face = 6.8 if chapter == 2 else 7.1
				var style = _building_style(chapter, rng)
				var model := _model_building_key(index, side, chapter)
				# Always run the procedural builder so the rng stream (and every
				# hazard it seeds downstream) stays identical; keep or discard
				# the result depending on whether this slot gets a model.
				var built := Node3D.new()
				City.building(built, face, -15, side, h, style, rng, 16.0)
				if model.is_empty():
					chunk.add_child(built)
					if chapter == 3 and index % 3 == 1:
						City.scaffold(chunk, face, -15, side, h)
				else:
					built.free()
					Models.spawn_face(chunk, model, face, -15.0, side, {"height": h, "length": 16.0})
		else:
			for side in [-1, 1]:
				var h2 = rng.randf_range(5.0, 11.0)
				var wall = Color("be9673").lerp(Color("344963"), chapter / 8.0)
				Art.box(chunk, Vector3(side * 9.4, h2 * 0.5, -14), Vector3(5, h2, 26), wall)
				for floor_n in range(int(h2 / 2)):
					for z in [-22, -16, -10, -4]:
						Art.box(chunk, Vector3(side * 6.95, floor_n * 2 + 1.4, z), Vector3(0.08, 1.1, 0.9), Color("ffe6a7"), true)
				Art.box(chunk, Vector3(side * 7.4, h2 + 0.15, -14), Vector3(5.2, 0.25, 26.2), Color("f3dec0"))
	if index % 3 == 0 and not suppress:
		for side in [-1, 1]:
			City.pole(chunk, Vector3(side * 6.95, 0, -7))
			City.cable(chunk, Vector3(side * 6.95, 5.1, -7), Vector3(side * 6.95, 5.1, -25))
	match chapter:
		0:
			if index % 3 == 1:
				City.vehicle(chunk, Vector3(-6.4, 0, -10), Color(["c94f4f", "388bff", "f0c04a"][index % 3]), 0)
		1:
			if index % 2 == 1:
				City.market_stall(chunk, Vector3(6.4, 0, -9), color, rng)
				City.pedestrian(chunk, Vector3(-6.3, 0, -20), Color(["f2efe6", "4a7fb5", "c9566a"][index % 3]), index % 5)
			if index % 3 == 0:
				_planter_tree(chunk, index, Vector3(-6.4, 0, -5), rng)
			if index % 3 == 1:
				City.light_string(chunk, -18, 6.6, ["f6e05e", "6bd7d4", "f15a8d"], rng)
		2:
			if index % 3 == 1:
				City.pedestrian(chunk, Vector3(6.4, 0, -16), Color("e8e2d2"), 4)
		3:
			if index % 2 == 0:
				match index % 5:
					0: City.brick_stack(chunk, Vector3(-6.4, 0, -8))
					1: City.cement_stack(chunk, Vector3(6.4, 0, -12))
					2: City.pipe_stack(chunk, Vector3(-6.5, 0, -18))
					3: City.sand_pile(chunk, Vector3(6.3, 0, -7))
					4: City.road_barrier(chunk, Vector3(6.3, 0, -14))
			if index % 3 == 2:
				City.vehicle(chunk, Vector3(-6.3, 0, -22), Color("f0c04a"), 1)
		4:
			if index % 3 == 1:
				City.billboard(chunk, Vector3(6.6, 0, -14), str(flavors[int(index / 3) % flavors.size()].name), color)
			if index % 4 == 2:
				City.vehicle(chunk, Vector3(-6.4, 0, -9), Color("dfe8ea"), 1)
				City.vehicle(chunk, Vector3(6.4, 0, -24), Color("388bff"), 2, PI)
		5:
			if index % 2 == 0:
				City.vehicle(chunk, Vector3(6.4, 0, -11), Color("e05b4a"), 0)
			if index % 3 == 0:
				City.pedestrian(chunk, Vector3(-6.3, 0, -19), Color("4a7fb5"), index % 5)
	if index == 0:
		City.banner(chunk, -8, 7.0, "DELSI MAN · صنعاء", color)
	if index in [10, 20, 30, 40, 50]:
		City.banner(chunk, -8, 7.0, "DELSI · " + str(flavors[chapter % flavors.size()].name), color)

func _building_style(chapter: int, rng: RandomNumberGenerator) -> int:
	match chapter:
		0: return 0 if rng.randf() > 0.3 else 1
		1: return 1
		2: return 0 if rng.randf() > 0.25 else 3
		3: return 2 if rng.randf() > 0.5 else 3
		4: return 1 if rng.randf() > 0.4 else 2
		_: return 1 if rng.randf() > 0.5 else 0

## "" keeps the procedural box building; anything else is a GLB model key.
## Every fourth building chunk (index % 4 == 0) swaps both of its buildings for
## models, so the played course mixes imported GLBs with the primitive kit.
func _model_building_key(index: int, side: int, chapter: int) -> String:
	if index % 4 != 0:
		return ""
	if chapter == 4:
		return "warehouse_a" if side > 0 else "warehouse_b"
	var keys := ["house_a", "block_a", "tower_a"]
	return keys[(int(index / 4.0) + (1 if side > 0 else 0)) % keys.size()]

## Garden-walk planter trees: imported oak GLBs from assets/models/nature
## (registry keys in scripts/models.gd) instead of the primitive box tree.
## The size cycles small/med/big across the chapter and the single rng draw
## (as in City.planter_tree) keeps the seeded hazard layout downstream intact.
func _planter_tree(chunk: Node3D, index: int, pos: Vector3, rng: RandomNumberGenerator) -> void:
	Art.box(chunk, pos + Vector3(0, 0.28, 0), Vector3(1.1, 0.56, 1.1), Color("b0a08c"))
	var pick := rng.randf()
	var key: String = ["tree_small", "tree_med", "tree_big"][int(index / 3.0) % 3]
	Models.spawn(chunk, key, pos + Vector3(0, 0.5, 0), {
		"height": lerpf(3.2, 4.8, pick),
		"yaw": pick * TAU,
	})

## Procedural backdrop for the whole course: a ground apron so nothing floats
## over void behind the sidewalks, a hazy skyline row past the buildings, low
## hills, mountain ridges, and ranges across the horizon before and after the
## finish. Runs on its own seeded rng so the shared hazard stream stays
## byte-identical (the 309 course entities must not move).
func _build_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var haze := Color("859eaa").lerp(Color("3f7fd0"), 0.35)
	var ground := Color("27353f")
	var towers := [Color("44506b").lerp(haze, 0.30), Color("4d5a77").lerp(haze, 0.42), Color("3b4763").lerp(haze, 0.24)]
	var hills := [Color("35514a").lerp(haze, 0.45), Color("3d5a52").lerp(haze, 0.58)]
	var mounts := [Color("4a5578").lerp(haze, 0.40), Color("44506e").lerp(haze, 0.55), Color("565f86").lerp(haze, 0.66)]
	# Ground apron past both sidewalk rows: tops out below the road surface so
	# there is never a void under or behind a building. No shadow casting —
	# these are background fills, the shadow pass is the expensive part.
	for side in [-1, 1]:
		var slab = Art.box(self, Vector3(side * 213.15, -0.62, -890), Vector3(413.7, 1.0, 2420), ground)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Distant city: hazy towers with lit facades, stepping back from the road.
	var z := 24.0
	while z > -1870.0:
		for side in [-1, 1]:
			var h := rng.randf_range(7.0, 30.0)
			var w := rng.randf_range(8.0, 16.0)
			var d := rng.randf_range(9.0, 18.0)
			var x: float = side * rng.randf_range(30.0, 54.0)
			var tz := z + rng.randf_range(-7.0, 7.0)
			var cy := h * 0.5 - 0.15
			var tower = Art.box(self, Vector3(x, cy, tz), Vector3(w, h, d), towers[rng.randi_range(0, 2)])
			tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if rng.randf() > 0.45:
				var win = Art.box(self, Vector3(x - side * (w * 0.5 + 0.05), cy, tz),
					Vector3(0.06, h * 0.6, d * 0.4), Color("ffe6a7"), true)
				win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		z -= rng.randf_range(34.0, 46.0)
	# Low hills between skyline and mountains.
	var hz := 60.0
	while hz > -1870.0:
		for side in [-1, 1]:
			var hx := rng.randf_range(62.0, 112.0)
			var hr := minf(rng.randf_range(24.0, 55.0), hx - 14.0)
			_peak(side * hx, hz + rng.randf_range(-20.0, 20.0),
				hr, rng.randf_range(9.0, 18.0), 6, hills[rng.randi_range(0, 1)])
		hz -= rng.randf_range(130.0, 170.0)
	# Mountain ridges beyond the hills (bases clamped clear of the road).
	var mz := 40.0
	while mz > -1880.0:
		for side in [-1, 1]:
			var mx := rng.randf_range(140.0, 260.0)
			var mr := minf(rng.randf_range(70.0, 150.0), mx - 18.0)
			_peak(side * mx, mz + rng.randf_range(-25.0, 25.0),
				mr, rng.randf_range(30.0, 95.0), 5, mounts[rng.randi_range(0, 2)])
		mz -= rng.randf_range(95.0, 130.0)
	# Horizon ranges ahead of and behind the finish gate.
	for i in range(8):
		_peak(-310.0 + i * 88.0 + rng.randf_range(-24.0, 24.0),
			-1960.0 + rng.randf_range(-50.0, 50.0),
			rng.randf_range(80.0, 175.0), rng.randf_range(60.0, 140.0), 5,
			Color("4a5578").lerp(haze, 0.74))
	for i in range(7):
		_peak(-310.0 + i * 102.0 + rng.randf_range(-24.0, 24.0),
			170.0 + rng.randf_range(-50.0, 50.0),
			rng.randf_range(60.0, 130.0), rng.randf_range(50.0, 110.0), 5,
			Color("4a5578").lerp(haze, 0.62))

## One low-poly peak: a triangular pyramid sunk a little into the apron so the
## base never floats. radius = base half-width, peak = apex height.
func _peak(x: float, z: float, radius: float, peak: float, segments: int, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = peak
	mesh.radial_segments = segments
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = Art.material(color)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.position = Vector3(x, peak * 0.5 - 0.6, z)
	n.rotation.y = _peak_yaw(x, z)

## Stable pseudo-angle so neighbouring peaks do not all face the same way.
func _peak_yaw(x: float, z: float) -> float:
	return absf(sin(x * 12.9898 + z * 78.233)) * TAU

func _finish_gate() -> void:
	var c = center_at(1796.0)
	Art.box(self, Vector3(c, 5.4, -1796), Vector3(15, 0.6, 0.5), Color("2c3540"))
	for side in [-1, 1]:
		Art.box(self, Vector3(c + side * 7.2, 2.7, -1796), Vector3(0.7, 5.4, 0.7), Color("3c4652"))
	Art.label(self, Vector3(c, 4.5, -1795.6), "THE FLAVOR FESTIVAL", Color("fff3c4"), 64)
	var c2 = center_at(1806.0)
	Art.box(self, Vector3(c2, -0.2, -1808), Vector3(18, 0.8, 18), Color("e5cfaa"))
	for i in range(5):
		var b = Art.bottle(self, Vector3(c2 + (i - 2) * 2.4, 1, -1812), colors[i % colors.size()])
		b.scale = Vector3.ONE * 2

func _build_stages(rng: RandomNumberGenerator) -> void:
	for stage in range(6):
		var st = stage * 300.0
		var diff = stage / 5.0
		var at = st + (36.0 if stage > 0 else 30.0)
		match stage:
			0:
				while at < st + 288.0:
					match int((at - st) / 34.0) % 6:
						0, 3: _beat_simple(at, rng, diff)
						1: _beat_hole(at, rng, diff)
						2: _beat_gate(at, rng, diff)
						4: _beat_bottles(at, rng, diff)
						5: _beat_dual(at, rng, diff)
					at += 34.0 + rng.randf_range(-3.0, 3.0)
			1:
				while at < st + 288.0:
					match int((at - st) / 36.0) % 6:
						0: _beat_cross_ground(at, rng, diff, 1)
						1: _beat_simple(at, rng, diff)
						2: _beat_cross_ground(at, rng, diff, 2)
						3: _beat_drift(at, rng, diff)
						4: _beat_gate(at, rng, diff)
						5: _beat_slide_truck(at, rng, diff)
					at += 36.0
			2:
				_beat_walls(st + 4.0, rng, diff)
				_beat_simple(st + 26.0, rng, diff)
				_spawn_interior(640.0, 80.0, rng, false)
				_beat_cross_toss(st + 130.0, rng, diff, 0)
				_beat_walls(st + 155.0, rng, diff)
				_beat_dual(st + 178.0, rng, diff)
				_beat_cross_ground(st + 225.0, rng, diff, 3)
				_beat_gate(st + 250.0, rng, diff)
				_spawn_interior(800.0, 90.0, rng, true)
			3:
				while at < st + 288.0:
					match int((at - st) / 30.0) % 7:
						0: _beat_hole(at, rng, diff)
						1: _beat_truck_reversed(at, rng, diff)
						2: _beat_simple(at, rng, diff)
						3: _beat_hole(at, rng, diff)
						4: _beat_drift(at, rng, diff)
						5: _beat_gate(at, rng, diff)
						6: _beat_slide_truck(at, rng, diff)
					at += 30.0
			4:
				while at < st + 288.0:
					match int((at - st) / 24.0) % 7:
						0: _beat_triple(at, rng, diff)
						1: _beat_cross_ground(at, rng, diff, 4)
						2: _beat_gate(at, rng, diff)
						3: _beat_hole(at, rng, diff)
						4: _beat_cross_toss(at, rng, diff, 0)
						5: _beat_drift(at, rng, diff)
						6: _beat_slide_truck(at, rng, diff)
					at += 24.0
			5:
				while at < st + 232.0:
					match int((at - st) / 22.0) % 7:
						0: _beat_gate(at, rng, diff)
						1: _beat_triple(at, rng, diff)
						2: _beat_cross_ground(at, rng, diff, 5)
						3: _beat_hole(at, rng, diff)
						4: _beat_walls(at, rng, diff)
						5: _beat_simple(at, rng, diff)
						6: _beat_slide_truck(at, rng, diff)
					at += 22.0
				_beat_bottles(1748.0, rng, diff)
				_beat_cross_ground(1766.0, rng, diff, 1)
				_beat_bottles(1782.0, rng, diff)

func _beat_simple(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var center = rng.randf_range(-2.2, 2.2)
	var kind = rng.randi_range(0, 1)
	_spawn_hazard(0, 0, at, center, kind, 0.95 + diff * 0.25)
	_spawn_bottle_trail(0, at, center + (2.0 if center < 0.0 else -2.0), 3)

func _beat_dual(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var center = rng.randf_range(-1.4, 1.4)
	_spawn_hazard(0, 0, at, center - 2.1, 0, 1.0 + diff * 0.2)
	_spawn_hazard(0, 1, at, center + 2.1, 1, 1.1 + diff * 0.2)
	_spawn_bottle_trail(0, at, center, 3)

func _beat_hole(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var hx = clampf(rng.randf_range(-3.4, 3.4), -4.3, 4.3)
	_spawn_hole(0, at, hx, 1.4 + diff * 0.2)
	_spawn_bottle_trail(0, at, hx + (2.5 if hx < 0.0 else -2.5), 4)

func _beat_gate(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var open_side = 1 if rng.randf() > 0.5 else -1
	var gap_pos = open_side * rng.randf_range(1.6, 3.4)
	var far_edge = -open_side * 5.7
	var wall_x = (gap_pos + far_edge) * 0.5
	var radius = clampf(absf(gap_pos - far_edge) * 0.5, 1.2, 4.4)
	_spawn_hazard(0, 0, at, wall_x, 2, radius, 0.0, 0.0, 1 + rng.randi_range(0, 2))
	_spawn_bottle_trail(0, at, gap_pos + open_side * 0.7, 4)

func _beat_walls(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var look = 1 + rng.randi_range(0, 2)
	_spawn_hazard(0, 0, at, 3.5, 2, 1.15 + diff * 0.15, 0.0, 0.0, look)
	_spawn_hazard(0, 1, at + 9.0, -3.5, 2, 1.15 + diff * 0.15, 0.0, 0.0, look)
	_spawn_bottle_trail(0, at + 4.0, 0.0, 3)

func _beat_triple(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var open_index = rng.randi_range(0, 2)
	var offsets = [-3.4, 0.0, 3.4]
	for i in range(3):
		if i == open_index:
			continue
		_spawn_hazard(0, i, at, offsets[i] + rng.randf_range(-0.3, 0.3), i % 2, 1.05 + diff * 0.2)
	_spawn_bottle_trail(0, at, offsets[open_index], 3)

func _beat_drift(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var x = rng.randf_range(-2.6, 2.6)
	_spawn_hazard(0, 0, at, x, 0, 1.0 + diff * 0.15, 0.9 + diff * 0.5, 0.05 + diff * 0.02)
	_spawn_bottle_trail(0, at, -x * 0.6, 3)

func _beat_slide_truck(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var x = rng.randf_range(-1.6, 1.6)
	_spawn_hazard(0, 0, at, x, 1, 1.6 + diff * 0.3, 0.0, 0.0, 4)
	_spawn_bottle_trail(0, at, x, 3)

func _beat_bottles(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	_spawn_bottle_trail(0, at, rng.randf_range(-3.0, 3.0), 5)
	_spawn_bottle_trail(0, at + 10.0, rng.randf_range(-3.0, 3.0), 5)

func _beat_cross_ground(at: float, rng: RandomNumberGenerator, diff: float, style: int) -> void:
	var from_side = 1 if rng.randf() > 0.5 else -1
	_spawn_crossing(at, style, from_side, diff)
	_spawn_bottle_trail(0, at + 6.0, -from_side * 2.4, 3)

func _beat_cross_toss(at: float, rng: RandomNumberGenerator, diff: float, style: int) -> void:
	var side = 1 if rng.randf() > 0.5 else -1
	var land_x = clampf(rng.randf_range(-4.2, 4.2), -4.5, 4.5)
	_spawn_truck_throw(0, at, side, land_x, diff, style, false)
	_spawn_bottle_trail(0, at, land_x + (2.2 if land_x < 0.0 else -2.2), 3)

func _beat_truck_reversed(at: float, rng: RandomNumberGenerator, diff: float) -> void:
	var side = 1 if rng.randf() > 0.5 else -1
	var land_x = clampf(rng.randf_range(-4.0, 4.0), -4.5, 4.5)
	_spawn_truck_throw(0, at, side, land_x, diff, 6, true)
	_spawn_bottle_trail(0, at, land_x + (2.4 if land_x < 0.0 else -2.4), 3)

func _spawn_hole(row: int, at: float, x_pos: float, radius: float) -> void:
	x_pos = clampf(x_pos, -ROAD_LIMIT + radius, ROAD_LIMIT - radius)
	var node = HOLE_SCENE.instantiate()
	if node.has_method("configure"):
		node.configure(radius, colors[mini(4, int(at / 300))])
	add_child(node)
	node.position = Vector3(center_at(at) + x_pos, 0, -at)
	objects.append({
		"id": "hole_%d" % int(at * 10),
		"at": at,
		"x": x_pos,
		"kind": 4,
		"node": node,
		"radius": radius,
		"done": false,
	})

func _spawn_truck_throw(row: int, at: float, side: int, land_x: float, difficulty: float, style: int, flip: bool) -> void:
	side = 1 if side >= 0 else -1
	var color = colors[mini(4, int(at / 300))]
	var truck = TRUCK_SCENE.instantiate()
	if truck.has_method("configure"):
		truck.configure(side, color)
	add_child(truck)
	truck.position = Vector3(center_at(at) + side * 7.75, 0, -at + 3.0)
	if flip:
		truck.rotation.y = PI
	props.append({"id": "truck_%d" % int(at * 10), "at": at, "node": truck})
	var radius = 0.82 + difficulty * 0.14
	var spin_speed = 1.8 if style == 6 else 0.0
	var thrown = THROWN_OBJECT_SCENE.instantiate()
	if thrown.has_method("configure"):
		thrown.configure(radius, color.lerp(Color("ef8064"), 0.3), style, spin_speed)
	add_child(thrown)
	var start_at = at - 28.0
	var start_x = side * 6.7
	thrown.position = Vector3(center_at(at) + land_x, 0.0, -at)
	thrown.rotation = Vector3(0.0, PI * 0.5 if land_x > start_x else -PI * 0.5, 0.0)
	objects.append({
		"id": "thrown_%d" % int(at * 10),
		"at": at,
		"x": land_x,
		"kind": 5,
		"node": thrown,
		"radius": radius,
		"done": false,
		"throw_start": start_at,
		"start_x": start_x,
		"land_x": land_x,
		"arc": 2.1 + difficulty * 0.8,
		"spin": spin_speed,
	})

func _spawn_crossing(at: float, style: int, from_side: int, difficulty: float) -> void:
	var dir = 1.0 if from_side >= 0 else -1.0
	var start_x = dir * 6.9
	var land_x = -dir * 6.9
	var radius = 0.9
	if style == 4:
		radius = 1.9
	elif style == 5:
		radius = 2.0
	elif style == 3:
		radius = 0.75
	var spin_speed = 2.6 if style == 6 else 0.0
	var node = THROWN_OBJECT_SCENE.instantiate()
	if node.has_method("configure"):
		node.configure(radius, colors[mini(4, int(at / 300))], style, spin_speed)
	add_child(node)
	node.position = Vector3(center_at(at), 0.0, -at)
	node.rotation = Vector3(0.0, PI * 0.5 if land_x > start_x else -PI * 0.5, 0.0)
	objects.append({
		"id": "cross_%d" % int(at * 10),
		"at": at,
		"x": 0.0,
		"kind": 5,
		"node": node,
		"radius": radius,
		"done": false,
		"throw_start": at - 15.0,
		"cross_end": at + 15.0,
		"start_x": start_x,
		"land_x": land_x,
		"arc": 0.0,
		"spin": spin_speed,
	})

func _spawn_hazard(row: int, hazard_index: int, at: float, x_pos: float, kind: int, radius: float, drift_amp: float = 0.0, drift_speed: float = 0.0, look: int = 0) -> void:
	x_pos = clampf(x_pos, -ROAD_LIMIT + radius, ROAD_LIMIT - radius)
	var node = RoadHazardScene.new()
	node.hazard_type = kind
	node.radius = radius
	if kind == 1 or kind == 2:
		node.look = look
	add_child(node)
	node.position = Vector3(center_at(at) + x_pos, 0, -at)
	var item = {
		"id": "hazard_%d_%d" % [int(at * 10), hazard_index],
		"at": at,
		"x": x_pos,
		"base_x": x_pos,
		"kind": kind,
		"node": node,
		"radius": radius,
		"done": false,
	}
	if drift_amp > 0.0:
		item.drift_amp = drift_amp
		item.drift_speed = drift_speed
		item.drift_phase = at * 0.9 + hazard_index * 2.1
	objects.append(item)

func _spawn_bottle_trail(row: int, at: float, guide_x: float, count: int) -> void:
	for j in range(count):
		var z = at - 7.0 + j * 2.05
		var wave = sin((int(at) + j) * 0.85) * 0.7
		var x_pos = clampf(guide_x + wave, -ROAD_LIMIT + 0.45, ROAD_LIMIT - 0.45)
		var color = colors[mini(4, int(at / 300))]
		var b = Art.bottle(self, Vector3(center_at(z) + x_pos, 0.35, -z), color)
		objects.append({
			"id": "bottle_%d" % int(z * 10),
			"at": z,
			"x": x_pos,
			"kind": 3,
			"node": b,
			"radius": 0.9,
			"done": false,
		})

func _spawn_interior(at0: float, ins_len: float, rng: RandomNumberGenerator, blocked: bool) -> void:
	var root = Node3D.new()
	add_child(root)
	root.position = Vector3(center_at(at0), 0, -at0)
	City.interior_shell(root, ins_len, Color(["d9c9ae", "c2a179", "b89b77"][rng.randi_range(0, 2)]), rng)
	props.append({"id": "interior_%d" % int(at0), "at": at0, "end": at0 + ins_len, "node": root})
	var step = 7.0
	var count = int(ins_len / step)
	for i in range(count):
		var at = at0 + 4.0 + i * step
		if at > at0 + ins_len - 5.0:
			continue
		for side in [-1, 1]:
			if blocked and side == -1 and at > at0 + 50.0:
				continue
			_spawn_hazard(0, 1 if side > 0 else 0, at, side * 4.1, 2, 1.4, 0.0, 0.0, 1)
	if blocked:
		_spawn_hazard(0, 2, at0 + 55.0, -3.2, 2, 2.4, 0.0, 0.0, 2)
		_spawn_trigger("barrel_gate", at0 + 43.0)
		_spawn_bottle_trail(0, at0 + 55.0, 1.4, 4)
	_spawn_bottle_trail(0, at0 + ins_len * 0.4, rng.randf_range(-1.5, 1.5), 3)

func _spawn_trigger(id: String, at: float) -> void:
	var node = Node3D.new()
	add_child(node)
	node.position = Vector3(center_at(at), 0, -at)
	node.set_meta("kind", 12)
	objects.append({
		"id": id,
		"at": at,
		"x": 0.0,
		"kind": 12,
		"node": node,
		"radius": 0.1,
		"done": false,
	})

## Three-jump stair sets dropped into the played course. They run on their own
## seeded rng and clear a small working zone of the pre-placed hazards first,
## so the shared hazard stream (and every entity seeded from it) never moves.
## Six sets: one per section, alternating the big stair flight (style 0) and
## the building stair (style 1).
func _spawn_stair_sets() -> void:
	var pick := RandomNumberGenerator.new()
	pick.seed = 5150
	var spots := [170.0, 470.0, 735.0, 1080.0, 1330.0, 1550.0]
	for i in range(spots.size()):
		_place_stair_set(spots[i], i % 2, pick)

## One set: three jumpable steps on the road.
## style 0 (big stairs): rising flights with uneven gaps (16m, 19m) so the
## three hops land on different timings, each one clearing higher than the last.
## style 1 (building stair): small -> bigger -> third block, equal gaps (16m),
## all three at the same height.
func _place_stair_set(at: float, style: int, pick: RandomNumberGenerator) -> void:
	var gaps := [0.0, 16.0, 35.0] if style == 0 else [0.0, 16.0, 32.0]
	var radii := [1.15, 1.3, 1.45] if style == 0 else [1.05, 1.5, 1.95]
	var heights := [1.3, 1.7, 2.1] if style == 0 else [1.5, 1.5, 1.5]
	var clears := [1.15, 1.45, 1.75] if style == 0 else [1.35, 1.35, 1.35]
	var drifts := [0.0, 0.6, -0.5] if style == 0 else [0.0, 0.0, 0.0]
	var steps: Array = []
	for gap in gaps:
		steps.append(at + gap)
	_clear_zone(at - 10.0, at + gaps[2] + 6.0, steps)
	var x0 = clampf(pick.randf_range(-2.4, 2.4), -ROAD_LIMIT + 1.45, ROAD_LIMIT - 1.45)
	for i in range(3):
		var step_at = float(steps[i])
		var radius = float(radii[i])
		var x_pos = clampf(x0 + float(drifts[i]), -ROAD_LIMIT + radius, ROAD_LIMIT - radius)
		var node = STAIRS_SCENE.instantiate()
		if node.has_method("configure"):
			node.configure(style, radius, float(heights[i]), float(clears[i]), i)
		add_child(node)
		node.position = Vector3(center_at(step_at) + x_pos, 0, -step_at)
		objects.append({
			"id": "stair_%d_%d" % [int(at * 10), i],
			"at": step_at,
			"x": x_pos,
			"kind": 6 + style,
			"node": node,
			"radius": radius,
			"clear": float(clears[i]),
			"done": false,
		})

## Empties the stretch a stair set takes over: every solid hazard in the zone
## is dropped (so each jump has a clean approach) and any bottle buried in a
## step goes with it. Bottles between the steps stay for the ground stretches.
func _clear_zone(from_at: float, to_at: float, steps: Array) -> void:
	var kept: Array[Dictionary] = []
	for item in objects:
		var kind = int(item.kind)
		var drop := false
		if kind in [0, 1, 2, 4, 5]:
			drop = float(item.at) >= from_at and float(item.at) <= to_at
		elif kind == 3:
			for s in steps:
				if absf(float(item.at) - float(s)) < 2.6:
					drop = true
					break
		if not drop:
			kept.append(item)
			continue
		var node = item.get("node")
		if node != null and is_instance_valid(node):
			for p in props.duplicate():
				if p.get("node") == node:
					props.erase(p)
			node.free()
	objects = kept

func update_dynamic(_at: float) -> void:
	pass

func update_visibility(at: float) -> void:
	for chunk in chunks:
		chunk.visible = absf(-chunk.position.z - at) < 170
	for prop in props:
		var p_end = float(prop.get("end", prop.at))
		prop.node.visible = p_end > at - 40.0 and prop.at < at + 160.0
	for item in objects:
		if item.kind == 12:
			item.node.visible = false
			continue
		if item.kind == 3 and item.done:
			item.node.visible = false
			continue
		var back = 34.0 if item.has("throw_start") else 18.0
		item.node.visible = item.at > at - back and item.at < at + 150.0
		item.node.scale = Vector3.ONE

func restore(at: float, claimed: Dictionary) -> void:
	for item in objects:
		item.done = item.at < at or claimed.has(item.id)

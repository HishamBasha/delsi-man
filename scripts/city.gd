extends RefCounted
## Original procedural Yemeni city kit built from primitives.
const Art = preload("res://scripts/art.gd")
const STONE := ["cbb79a", "b89b77", "d9c9ae", "9d8265", "c2a179", "a98d68"]
const TRIM := "f4efe4"
const SHSIGNS := ["بقالة", "مطعم", "سوبر ماركت", "مخبز", "قهوة", "صيدلية", "تمور وعسل", "عصير طازج", "محل الديسي", "لحوم ودواجن", "خضار وفواكه", "عطور وبخور"]

static func ar_sign(parent: Node3D, pos: Vector3, text: String, color: Color, size: int = 40) -> Label3D:
	return Art.label(parent, pos, text, color, size)

static func qamariya(parent: Node3D, pos: Vector3, side: int, color: Color) -> void:
	var ring = Art.cylinder(parent, pos, 0.42, 0.1, Color(TRIM))
	ring.rotation.z = PI / 2
	var glass = Art.cylinder(parent, pos + Vector3(side * 0.05, 0, 0), 0.3, 0.1, color)
	glass.rotation.z = PI / 2

static func window(parent: Node3D, pos: Vector3, side: int, color: Color, glow: bool = true) -> void:
	Art.box(parent, pos, Vector3(0.14, 1.15, 0.95), Color(TRIM))
	Art.box(parent, pos + Vector3(side * 0.05, 0, 0), Vector3(0.1, 0.9, 0.72), color, glow)

static func parapet(parent: Node3D, x: float, z: float, width: float, top: float, color: Color) -> void:
	Art.box(parent, Vector3(x, top + 0.18, z), Vector3(0.5, 0.36, width), color.darkened(0.15))
	var merlons = mini(8, int(width / 1.6))
	for i in range(merlons):
		var mz = z - width * 0.5 + 0.8 + i * (width / maxi(1, merlons))
		Art.box(parent, Vector3(x, top + 0.55, mz), Vector3(0.45, 0.4, 0.55), color.darkened(0.05))

static func shopfront(parent: Node3D, face_x: float, z: float, side: int, sign: String, accent: Color) -> void:
	var fx = side * face_x
	Art.box(parent, Vector3(fx - side * 0.06, 1.35, z), Vector3(0.28, 2.7, 4.6), Color("453a30"))
	Art.box(parent, Vector3(fx - side * 0.12, 2.9, z), Vector3(0.34, 0.5, 4.8), accent, true)
	for i in range(5):
		var aw = accent if i % 2 == 0 else Color(TRIM)
		Art.box(parent, Vector3(fx - side * 0.55, 3.35, z - 2.1 + i * 1.05), Vector3(1.4, 0.1, 1.0), aw)
	Art.box(parent, Vector3(fx - side * 0.3, 3.9, z), Vector3(0.35, 0.75, 4.4), Color("2c3540"))
	ar_sign(parent, Vector3(fx - side * 0.52, 3.9, z), sign, Color("ffe9a8"), 40)
	Art.box(parent, Vector3(fx - side * 0.7, 0.35, z + 1.7), Vector3(0.9, 0.7, 0.9), Color("8a5a33"))
	Art.box(parent, Vector3(fx - side * 0.7, 0.5, z - 1.5), Vector3(0.8, 0.4, 1.2), accent)

static func building(parent: Node3D, face_x: float, z: float, side: int, h: float, style: int, rng: RandomNumberGenerator, width_override: float = 0.0) -> void:
	var body = Color(STONE[rng.randi_range(0, STONE.size() - 1)])
	if style == 3:
		body = Color("a8a49c")
	var depth = rng.randf_range(9.0, 13.0) if style == 2 else rng.randf_range(6.0, 9.5)
	var width = rng.randf_range(10.0, 14.0) if style == 2 else rng.randf_range(7.0, 11.0)
	if width_override > 0.0:
		width = width_override
	var cx = side * (face_x + depth * 0.5)
	var floors = maxi(2, int(h / 2.6))
	if style == 2:
		floors = 1
	if style == 3:
		floors = maxi(3, floors)
	Art.box(parent, Vector3(cx, h * 0.5, z), Vector3(depth, h, width), body)
	if style == 2:
		for i in range(mini(10, int(width / 0.8))):
			Art.box(parent, Vector3(side * (face_x - 0.06), h * 0.5, z - width * 0.5 + 0.4 + i * 0.8), Vector3(0.12, h - 0.6, 0.14), body.lightened(0.18))
		Art.box(parent, Vector3(side * (face_x - 0.1), 1.6, z), Vector3(0.2, 3.0, width * 0.45), Color("3f5f7a"))
		ar_sign(parent, Vector3(side * (face_x - 0.22), h - 1.0, z), "مستودع", Color("ffe9a8"), 46)
		Art.box(parent, Vector3(cx, h + 0.2, z), Vector3(depth + 0.6, 0.4, width + 0.6), body.darkened(0.2))
		return
	if style == 3:
		for f in range(floors):
			var fy = f * 2.6
			Art.box(parent, Vector3(cx, fy + 2.5, z), Vector3(depth + 0.3, 0.3, width + 0.3), Color("9c9890"))
			if f % 2 == 1:
				Art.box(parent, Vector3(side * (face_x + depth * 0.45), fy + 1.2, z), Vector3(depth * 0.9, 2.2, width * 0.8), Color("a8563f"))
		for dx in [-0.35, 0.35]:
			for dz in [-0.3, 0.0, 0.3]:
				Art.cylinder(parent, Vector3(cx + dx * depth, h + 0.6, z + dz * width), 0.05, 1.4, Color("6b4a2f"))
		Art.box(parent, Vector3(side * (face_x - 0.12), 3.4, z), Vector3(0.24, 0.5, width * 0.6), Color("3f5f7a"))
		ar_sign(parent, Vector3(side * (face_x - 0.26), 5.6, z), "بناء", Color("ffd166"), 38)
		return
	if style == 1:
		shopfront(parent, face_x, z, side, SHSIGNS[rng.randi_range(0, SHSIGNS.size() - 1)], Color(["f15a8d", "388bff", "ffad45", "a5e85d", "eed189"][rng.randi_range(0, 4)]))
	for f in range(1, floors):
		var band_y = f * (h / floors)
		Art.box(parent, Vector3(side * (face_x - 0.05), band_y, z), Vector3(0.2, 0.22, width + 0.1), Color(TRIM))
		var wins = clampi(int(width / 4.5), 1, 3)
		for w in range(wins):
			var wz = z - width * 0.5 + (w + 0.5) * (width / wins)
			window(parent, Vector3(side * (face_x - 0.06), band_y - 1.2, wz), side, Color("31404f"))
			qamariya(parent, Vector3(side * (face_x - 0.08), band_y - 0.35, wz), side, Color(["ffd9a0", "a5e85d", "9fe8ff"][rng.randi_range(0, 2)]))
	parapet(parent, side * face_x, z, width, h, body)
	Art.box(parent, Vector3(cx, h + 0.15, z), Vector3(depth + 0.4, 0.3, width + 0.4), body.darkened(0.25))

static func pole(parent: Node3D, pos: Vector3) -> void:
	Art.cylinder(parent, pos + Vector3(0, 2.7, 0), 0.11, 5.4, Color("6b5a4a"))
	Art.box(parent, pos + Vector3(0, 5.1, 0), Vector3(1.3, 0.12, 0.14), Color("54463a"))
	Art.box(parent, pos + Vector3(0, 4.5, 0), Vector3(0.5, 0.7, 0.42), Color("8894a0"))
	for sx in [-0.5, 0.5]:
		Art.cylinder(parent, pos + Vector3(sx, 5.25, 0), 0.06, 0.24, Color("d7e3ea"))

static func cable(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var mid = from.lerp(to, 0.5) + Vector3(0, -0.5, 0)
	for seg in [[from, mid], [mid, to]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var delta = b - a
		var n = Art.box(parent, (a + b) * 0.5, Vector3(0.05, 0.05, delta.length() + 0.1), Color("2a2f36"))
		n.look_at_from_position(n.position, b, Vector3.UP)

static func pedestrian(parent: Node3D, pos: Vector3, cloth: Color, pose: int) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = pos
	for s in [-1, 1]:
		var leg = Art.box(root, Vector3(s * 0.13, 0.36, 0), Vector3(0.15, 0.72, 0.17), Color("2f3542"))
		leg.rotation.x = 0.25 if pose == 0 and s > 0 else (-0.25 if pose == 0 else 0.0)
	if pose == 4:
		Art.cylinder(root, Vector3(0, 0.95, 0), 0.3, 1.2, cloth)
	else:
		Art.box(root, Vector3(0, 1.08, 0), Vector3(0.46, 0.72, 0.3), cloth)
		Art.box(root, Vector3(0, 1.44, 0), Vector3(0.48, 0.1, 0.32), cloth.darkened(0.2))
	Art.cylinder(root, Vector3(0, 1.68, 0), 0.15, 0.28, Color("c9956a"))
	Art.box(root, Vector3(0, 1.85, 0), Vector3(0.3, 0.1, 0.3), Color("f2efe6") if pose == 4 else Color("26292f"))
	for s in [-1, 1]:
		var arm = Art.box(root, Vector3(s * 0.3, 1.12, 0), Vector3(0.13, 0.52, 0.15), cloth.darkened(0.1))
		if pose == 2 and s > 0:
			arm.rotation.z = -2.4
	if pose == 3:
		Art.box(root, Vector3(0, 1.15, 0.34), Vector3(0.5, 0.4, 0.38), Color("b98a56"))
	return root

static func vehicle(parent: Node3D, pos: Vector3, body: Color, kind: int, rot_y: float = 0.0) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	if kind == 2:
		Art.box(root, Vector3(0, 0.62, 0), Vector3(0.3, 0.5, 1.7), Color("1d232c"))
		Art.box(root, Vector3(0, 1.0, -0.1), Vector3(0.34, 0.36, 0.7), body, true)
		for z in [-0.65, 0.65]:
			var w = Art.cylinder(root, Vector3(0, 0.33, z), 0.33, 0.12, Color("111923"))
			w.rotation.z = PI / 2
		Art.box(root, Vector3(0, 1.35, 0.15), Vector3(0.3, 0.5, 0.3), Color("c9956a"))
		return root
	if kind == 3:
		Art.box(root, Vector3(0, 0.6, 0), Vector3(1.1, 0.12, 1.9), Color("8a5a33"))
		Art.box(root, Vector3(0, 0.35, 0), Vector3(0.14, 0.4, 1.7), Color("5d4126"))
		for z in [-0.7, 0.7]:
			var w2 = Art.cylinder(root, Vector3(0.58, 0.3, z), 0.3, 0.1, Color("111923"))
			w2.rotation.z = PI / 2
		Art.box(root, Vector3(0, 0.9, -0.3), Vector3(0.8, 0.55, 0.8), Color("b98a56"))
		Art.box(root, Vector3(0, 0.85, 0.5), Vector3(0.7, 0.45, 0.7), body, true)
		return root
	if kind == 1:
		Art.box(root, Vector3(0, 1.35, 0), Vector3(2.1, 2.1, 4.8), body)
		Art.box(root, Vector3(0, 1.7, -2.42), Vector3(1.8, 1.1, 0.14), Color("9fd4e8"), true)
		Art.box(root, Vector3(0, 2.0, 0.4), Vector3(2.14, 0.8, 2.6), Color("dfe8ea"), true)
		for z in [-1.7, 1.7]:
			for sx in [-1.02, 1.02]:
				var bw = Art.cylinder(root, Vector3(sx, 0.42, z), 0.42, 0.24, Color("111923"))
				bw.rotation.z = PI / 2
		return root
	Art.box(root, Vector3(0, 0.62, 0), Vector3(1.85, 0.62, 4.3), body)
	Art.box(root, Vector3(0, 1.16, 0.2), Vector3(1.6, 0.55, 2.2), body.darkened(0.15))
	Art.box(root, Vector3(0, 1.18, 0.2), Vector3(1.64, 0.4, 2.0), Color("26333f"), true)
	Art.box(root, Vector3(0, 0.98, -2.16), Vector3(1.5, 0.24, 0.1), Color("fff3c4"), true)
	Art.box(root, Vector3(0, 0.98, 2.16), Vector3(1.4, 0.2, 0.1), Color("ff6a5f"), true)
	for z in [-1.4, 1.4]:
		for sx in [-0.92, 0.92]:
			var cw = Art.cylinder(root, Vector3(sx, 0.4, z), 0.4, 0.22, Color("111923"))
			cw.rotation.z = PI / 2
	return root

static func market_stall(parent: Node3D, pos: Vector3, accent: Color, rng: RandomNumberGenerator) -> void:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = pos
	for sx in [-0.85, 0.85]:
		for sz in [-1.2, 1.2]:
			Art.box(root, Vector3(sx, 1.3, sz), Vector3(0.09, 2.6, 0.09), Color("6b5a4a"))
	Art.box(root, Vector3(0, 0.85, 0), Vector3(1.7, 0.12, 2.6), Color("8a5a33"))
	for i in range(4):
		var c = accent if i % 2 == 0 else Color(TRIM)
		Art.box(root, Vector3(0, 2.62 - i * 0.05, -1.35 + i * 0.9), Vector3(1.9, 0.08, 0.88), c)
	for i in range(5):
		var g = Color(["e05b4a", "7ec850", "ffb347", "d94f8a", "f2e14c"][i % 5])
		Art.box(root, Vector3(-0.4 + (i % 3) * 0.4, 1.0, -0.9 + i * 0.45), Vector3(0.3, 0.2, 0.3), g, true)

static func planter_tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	Art.box(parent, pos + Vector3(0, 0.28, 0), Vector3(1.1, 0.56, 1.1), Color("b0a08c"))
	Art.cylinder(parent, pos + Vector3(0, 1.3, 0), 0.13, 1.7, Color("6b4a2f"))
	var leaf = Color("4f8f4a") if rng.randf() > 0.4 else Color("6aa552")
	Art.box(parent, pos + Vector3(0, 2.5, 0), Vector3(1.5, 1.1, 1.5), leaf)
	Art.box(parent, pos + Vector3(0.3, 3.1, 0.2), Vector3(0.9, 0.7, 0.9), leaf.lightened(0.12))

static func billboard(parent: Node3D, pos: Vector3, text: String, accent: Color) -> void:
	for sx in [-1.6, 1.6]:
		Art.box(parent, pos + Vector3(sx, 1.4, 0), Vector3(0.16, 2.8, 0.16), Color("424a55"))
	Art.box(parent, pos + Vector3(0, 3.3, 0), Vector3(4.6, 2.2, 0.18), Color("16222e"))
	Art.box(parent, pos + Vector3(0, 2.4, -0.1), Vector3(4.6, 0.3, 0.2), accent, true)
	Art.label(parent, pos + Vector3(0, 3.6, -0.14), "DELSI", accent, 64)
	Art.label(parent, pos + Vector3(0, 3.0, -0.14), text, Color.WHITE, 34)

static func banner(parent: Node3D, z: float, half_w: float, text: String, accent: Color) -> void:
	Art.box(parent, Vector3(0, 5.1, z), Vector3(half_w * 2.0, 1.4, 0.1), accent.darkened(0.25))
	Art.label(parent, Vector3(0, 5.1, z - 0.1), text, Color("fff3c4"), 56)

static func light_string(parent: Node3D, z: float, half_w: float, colors: Array, rng: RandomNumberGenerator) -> void:
	var count = 11
	var prev = Vector3(-half_w, 5.6, z)
	for i in range(count):
		var t = float(i) / (count - 1)
		var x = lerpf(-half_w, half_w, t)
		var y = 5.6 - sin(t * PI) * 0.9
		var c = colors[i % colors.size()]
		Art.box(parent, Vector3(x, y, z), Vector3(0.2, 0.2, 0.2), Color(c), true)
		if i > 0:
			var mid = (prev + Vector3(x, y, z)) * 0.5
			var delta = Vector3(x, y, z) - prev
			var wire = Art.box(parent, mid, Vector3(0.05, 0.05, delta.length() + 0.05), Color("2a2f36"))
			wire.look_at_from_position(mid, Vector3(x, y, z), Vector3.UP)
		prev = Vector3(x, y, z)

static func barrel(parent: Node3D, pos: Vector3, body: Color) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = pos
	Art.cylinder(root, Vector3(0, 0.55, 0), 0.4, 1.1, body)
	for y in [0.2, 0.9]:
		Art.cylinder(root, Vector3(0, y, 0), 0.42, 0.1, Color("3a2c22"))
	return root

static func brick_stack(parent: Node3D, pos: Vector3) -> void:
	for row in range(4):
		var cols = 3 - (row % 2)
		for i in range(cols):
			Art.box(parent, pos + Vector3((i - (cols - 1) * 0.5) * 0.42, 0.14 + row * 0.28, 0), Vector3(0.38, 0.26, 0.8), Color("a8563f"))

static func cement_stack(parent: Node3D, pos: Vector3) -> void:
	for row in range(3):
		for i in range(2):
			Art.box(parent, pos + Vector3((i - 0.5) * 0.9, 0.16 + row * 0.3, (row - 1) * 0.15), Vector3(0.85, 0.28, 1.2), Color("8f8d86"))

static func pipe_stack(parent: Node3D, pos: Vector3) -> void:
	var rows = [[-0.7, 0.7], [0.0], [-0.35, 0.35]]
	for row in range(rows.size()):
		for px in rows[row]:
			var p = Art.cylinder(parent, pos + Vector3(px, 0.28 + row * 0.5, 0), 0.24, 3.2, Color("b7653f"))
			p.rotation.x = PI / 2

static func sand_pile(parent: Node3D, pos: Vector3) -> void:
	var mound = Art.cylinder(parent, pos + Vector3(0, 0.3, 0), 1.5, 0.6, Color("d9b878"))
	var top = Art.cylinder(parent, pos + Vector3(0, 0.72, 0), 0.7, 0.4, Color("d9b878"))
	mound.scale.z = 0.8
	top.scale.z = 0.8

static func road_barrier(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> void:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	for sx in [-1.5, 1.5]:
		Art.box(root, Vector3(sx, 0.3, 0), Vector3(0.5, 0.16, 0.7), Color("4a4f57"))
		Art.box(root, Vector3(sx, 0.75, 0), Vector3(0.16, 0.9, 0.16), Color("8f979e"))
	for i in range(3):
		var c = Color("e05b4a") if i % 2 == 0 else Color(TRIM)
		Art.box(root, Vector3(0, 0.9 + i * 0.32, 0), Vector3(3.4, 0.24, 0.12), c)

static func scaffold(parent: Node3D, face_x: float, z: float, side: int, h: float) -> void:
	for sz in [-2.4, 0.0, 2.4]:
		Art.box(parent, Vector3(side * (face_x - 0.7), h * 0.5, z + sz), Vector3(0.14, h, 0.14), Color("9aa4ad"))
	for y in [1.4, 3.4, 5.4]:
		Art.box(parent, Vector3(side * (face_x - 0.7), y, z), Vector3(0.16, 0.12, 5.0), Color("b7653f"))
		Art.box(parent, Vector3(side * (face_x - 0.7), y + 0.6, z), Vector3(0.1, 1.1, 5.0), Color("e07a3c"))
		Art.box(parent, Vector3(side * (face_x - 0.9), y + 0.1, z), Vector3(0.5, 0.1, 5.0), Color("8a5a33"))

static func interior_shell(root: Node3D, length: float, color: Color, rng: RandomNumberGenerator) -> void:
	Art.box(root, Vector3(0, -0.05, -length * 0.5), Vector3(11.0, 0.1, length), Color("56545a"))
	Art.box(root, Vector3(0, 4.75, -length * 0.5), Vector3(11.0, 0.12, length), Color("3a3f47"))
	for s in [-1, 1]:
		Art.box(root, Vector3(s * 5.3, 2.3, -length * 0.5), Vector3(0.4, 4.6, length), color)
		for i in range(int(length / 6.0)):
			var sz = -3.0 - i * 6.0
			Art.box(root, Vector3(s * 4.9, 1.1, sz), Vector3(0.9, 2.2, 3.4), Color("8a5a33"))
			for g in range(3):
				var gc = Color(["e05b4a", "7ec850", "ffb347", "d94f8a"][g % 4])
				Art.box(root, Vector3(s * 4.9, 2.4 + g * 0.001, sz - 1.1 + g * 1.1), Vector3(0.7, 0.25, 0.7), gc, true)
	for i in range(int(length / 8.0)):
		var lz = -4.0 - i * 8.0
		Art.box(root, Vector3(0, 4.5, lz), Vector3(0.3, 0.24, 0.3), Color("ffe9a8"), true)
		Art.box(root, Vector3(0, 0.02, lz), Vector3(2.4, 0.04, 2.4), Color("f5d98a"), true)
	for s in [-1, 1]:
		Art.box(root, Vector3(s * 7.0, 3.2, 0.3), Vector3(4.0, 6.4, 0.5), color.lightened(0.12))
		Art.box(root, Vector3(s * 7.0, 3.2, -length - 0.3), Vector3(4.0, 6.4, 0.5), color.lightened(0.12))
	Art.box(root, Vector3(0, 6.6, 0.3), Vector3(18.0, 1.4, 0.5), color.darkened(0.1))
	Art.box(root, Vector3(0, 6.6, -length - 0.3), Vector3(18.0, 1.4, 0.5), color.darkened(0.1))
	ar_sign(root, Vector3(0, 7.6, 0.0), "ممر", Color("ffe9a8"), 52)
	for i in range(int(length / 4.0)):
		var pz = -2.0 - i * 4.0
		if rng.randf() > 0.55:
			Art.box(root, Vector3(rng.randf_range(-3.4, 3.4), 0.5, pz), Vector3(0.8, 1.0, 0.8), Color("b98a56"))

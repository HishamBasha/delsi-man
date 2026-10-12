extends RefCounted
## Original procedural art kit. Replace these factories with approved imported scenes.
static var materials: Dictionary = {}
static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key = str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	materials[key] = m
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color,glow)
	parent.add_child(n)
	n.position = pos
	return n

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	n.mesh = mesh
	n.material_override = material(color)
	parent.add_child(n)
	n.position = pos
	return n

static func label(parent: Node3D, pos: Vector3, value: String, color: Color = Color.WHITE, size: int = 54) -> Label3D:
	var n = Label3D.new()
	n.text = value
	n.font_size = size
	n.pixel_size = 0.012
	n.modulate = color
	n.outline_size = 4
	parent.add_child(n)
	n.position = pos
	return n

static func bottle(parent: Node3D, pos: Vector3, color: Color) -> Node3D:
	var n = Node3D.new()
	parent.add_child(n)
	n.position = pos
	cylinder(n,Vector3(0,0.5,0),0.23,0.85,color.darkened(0.3))
	cylinder(n,Vector3(0,0.9,0),0.11,0.28,Color.WHITE)
	cylinder(n,Vector3(0,0.52,0),0.24,0.37,color)
	label(n,Vector3(0,0.55,0.25),"D",Color.WHITE,35)
	return n

static func hero(parent: Node3D) -> Dictionary:
	var root = Node3D.new()
	parent.add_child(root)
	box(root, Vector3(0, 1.20, 0), Vector3(0.66, 0.76, 0.38), Color("1b68b8"))
	box(root, Vector3(0, 1.20, -0.20), Vector3(0.54, 0.70, 0.05), Color("f2efe6"))
	box(root, Vector3(0, 1.34, -0.235), Vector3(0.56, 0.10, 0.03), Color("ffd166"), true)
	box(root, Vector3(0, 1.06, -0.235), Vector3(0.56, 0.10, 0.03), Color("ffd166"), true)
	box(root, Vector3(0, 1.26, 0.30), Vector3(0.50, 0.62, 0.24), Color("dbe9ec"))
	box(root, Vector3(0, 1.32, 0.43), Vector3(0.42, 0.16, 0.04), Color("ff665f"))
	label(root, Vector3(0, 1.04, 0.435), "D", Color("1b68b8"), 30)
	for side in [-1, 1]:
		box(root, Vector3(side * 0.19, 1.36, 0.04), Vector3(0.09, 0.50, 0.44), Color("c9d6da"))
	box(root, Vector3(0, 1.58, 0), Vector3(0.44, 0.14, 0.32), Color("172f49"))
	cylinder(root, Vector3(0, 1.67, 0), 0.10, 0.14, Color("bc805a"))
	cylinder(root, Vector3(0, 1.90, 0), 0.23, 0.36, Color("c98d63"))
	for side in [-1, 1]:
		box(root, Vector3(side * 0.09, 1.95, -0.19), Vector3(0.06, 0.07, 0.06), Color("2b2118"))
	box(root, Vector3(0, 1.83, -0.21), Vector3(0.10, 0.04, 0.05), Color("8a5a3f"))
	cylinder(root, Vector3(0, 2.10, 0), 0.25, 0.11, Color("132535"))
	box(root, Vector3(0, 2.06, -0.25), Vector3(0.34, 0.04, 0.20), Color("132535"))
	box(root, Vector3(0, 2.145, 0), Vector3(0.30, 0.05, 0.30), Color("6bd7d4"))
	var limbs: Array[Node3D] = []
	for side in [-1, 1]:
		var leg = Node3D.new()
		root.add_child(leg)
		leg.position = Vector3(side * 0.20, 0.87, 0)
		box(leg, Vector3(0, -0.26, 0), Vector3(0.26, 0.52, 0.27), Color("172f49"))
		var knee = Node3D.new()
		knee.name = "lower"
		leg.add_child(knee)
		knee.position = Vector3(0, -0.52, 0)
		box(knee, Vector3(0, -0.14, 0), Vector3(0.22, 0.28, 0.23), Color("172f49"))
		box(knee, Vector3(0, -0.27, -0.10), Vector3(0.30, 0.16, 0.46), Color("f8f1dd"))
		box(knee, Vector3(0, -0.345, -0.10), Vector3(0.31, 0.03, 0.47), Color("c9c4b6"))
		limbs.append(leg)
		var arm = Node3D.new()
		root.add_child(arm)
		arm.position = Vector3(side * 0.47, 1.55, 0)
		box(arm, Vector3(0, -0.20, 0), Vector3(0.20, 0.42, 0.21), Color("388bff"))
		var elbow = Node3D.new()
		elbow.name = "lower"
		arm.add_child(elbow)
		elbow.position = Vector3(0, -0.42, 0)
		box(elbow, Vector3(0, -0.16, 0), Vector3(0.17, 0.34, 0.18), Color("c98d63"))
		box(elbow, Vector3(0, -0.37, 0), Vector3(0.16, 0.12, 0.17), Color("bc805a"))
		limbs.append(arm)
	return {"root": root, "limbs": limbs}

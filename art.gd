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
	box(root,Vector3(0,1.22,0),Vector3(0.68,0.78,0.4),Color("1b68b8"))
	box(root,Vector3(0,1.30,0.23),Vector3(0.58,0.17,0.06),Color("ff665f"))
	box(root,Vector3(0,1.22,0.35),Vector3(0.5,0.62,0.28),Color("dbe9ec"))
	cylinder(root,Vector3(0,1.91,0),0.24,0.40,Color("bc805a"))
	cylinder(root,Vector3(0,2.1,0),0.26,0.13,Color("132535"))
	var limbs: Array[Node3D] = []
	for side in [-1,1]:
		var leg = Node3D.new()
		root.add_child(leg)
		leg.position = Vector3(side*0.20,0.87,0)
		box(leg,Vector3(0,-0.32,0),Vector3(0.24,0.66,0.25),Color("172f49"))
		box(leg,Vector3(0,-0.68,-0.08),Vector3(0.3,0.17,0.48),Color("f8f1dd"))
		limbs.append(leg)
		var arm = Node3D.new()
		root.add_child(arm)
		arm.position = Vector3(side*0.47,1.55,0)
		box(arm,Vector3(0,-0.28,0),Vector3(0.22,0.60,0.23),Color("388bff"))
		limbs.append(arm)
	return {"root":root,"limbs":limbs}

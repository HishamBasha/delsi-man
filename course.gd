extends Node3D
const Art = preload("res://scripts/art.gd")
var objects: Array[Dictionary] = []
var chunks: Array[Node3D] = []
var colors: Array[Color] = []
var length := 1800.0

func build(flavors: Array) -> void:
	for f in flavors:
		colors.append(Color(f.color))
	var rng = RandomNumberGenerator.new()
	rng.seed = 62109
	for index in range(61):
		var at = index * 30.0
		var chapter = mini(5,int(at / 300))
		var color = colors[chapter % 5]
		var chunk = Node3D.new()
		add_child(chunk)
		chunk.position.z = -at
		chunks.append(chunk)
		Art.box(chunk,Vector3(0,-0.35,-15),Vector3(10,0.6,30),Color("263947"))
		for side in [-1,1]:
			Art.box(chunk,Vector3(side*5.5,0,-15),Vector3(1,0.8,30),Color("ead4ad"))
			Art.box(chunk,Vector3(side*4.85,0.06,-15),Vector3(0.09,0.08,29),color,true)
			var h = rng.randf_range(5,12)
			var wall = Color("be9673").lerp(Color("344963"),chapter/8.0)
			Art.box(chunk,Vector3(side*9,h/2,-14),Vector3(5,h,20),wall)
			for floor_n in range(int(h/2)):
				for z in [-20,-15,-10]:
					Art.box(chunk,Vector3(side*6.43,floor_n*2+1.4,z),Vector3(0.08,1.1,0.9),Color("ffe6a7"),true)
			Art.box(chunk,Vector3(side*7,h+0.15,-14),Vector3(5.2,0.25,20.2),Color("f3dec0"))
			Art.box(chunk,Vector3(side*5.6,3,-4),Vector3(0.13,6,0.13),Color("293442"))
			Art.box(chunk,Vector3(side*5.6,5.9,-4),Vector3(0.9,0.14,0.9),color,true)
			if index % 2 == 0:
				Art.box(chunk,Vector3(side*6.3,2.7,-12),Vector3(2,0.12,4),color)
		if index % 5 == 0:
			Art.box(chunk,Vector3(0,5,-5),Vector3(10,0.3,0.25),color)
			Art.label(chunk,Vector3(0,4.25,-4.8),"DELSI / " + str(flavors[chapter%5].name),Color.WHITE,58)
		for stripe in range(5):
			Art.box(chunk,Vector3(0,0,-stripe*6),Vector3(0.07,0.05,2),Color("6e8896"))
	# Authored cadence, seeded lanes: one obstacle per row always leaves a safe lane.
	for row in range(108):
		var at = 42.0 + row * 16.0
		if fmod(at,300) < 30:
			continue
		var lane = rng.randi_range(-1,1)
		var kind = row % 3
		var node = Node3D.new()
		add_child(node)
		node.position = Vector3(lane*2.7,0,-at)
		if kind == 0:
			Art.box(node,Vector3(0,0.55,0),Vector3(2,1.1,0.8),Color("ef8064"))
			Art.label(node,Vector3(0,0.65,0.45),"↑",Color.WHITE,55)
		elif kind == 1:
			Art.box(node,Vector3(0,2,0),Vector3(2.4,1.6,0.7),Color("489cbd"))
			Art.label(node,Vector3(0,2,0.4),"↓",Color.WHITE,55)
		else:
			Art.box(node,Vector3(0,1.6,0),Vector3(2,3.2,1.1),Color("d96160"))
			Art.label(node,Vector3(0,1.8,0.6),"↔",Color.WHITE,55)
		objects.append({"id":"hazard_%d"%row,"at":at,"lane":lane,"kind":kind,"node":node,"done":false})
		for j in range(3):
			var z = at-8+j*2.2
			var safe_lane = wrapi(lane+1,-1,2)
			var b = Art.bottle(self,Vector3(safe_lane*2.7,0.35,-z),colors[mini(4,int(at/300))])
			objects.append({"id":"bottle_%d_%d"%[row,j],"at":z,"lane":safe_lane,"kind":3,"node":b,"done":false})
	Art.box(self,Vector3(0,0,-1810),Vector3(18,0.8,18),Color("e5cfaa"))
	Art.label(self,Vector3(0,5,-1814),"THE FLAVOR FESTIVAL",Color.WHITE,90)
	for i in range(5):
		var b = Art.bottle(self,Vector3((i-2)*2.4,1,-1812),colors[i])
		b.scale = Vector3.ONE*2

func update_visibility(at: float) -> void:
	for chunk in chunks:
		chunk.visible = absf(-chunk.position.z-at) < 170
	for item in objects:
		item.node.visible = not item.done and item.at > at-12 and item.at < at+130

func restore(at: float, claimed: Dictionary) -> void:
	for item in objects:
		item.done = item.at < at or claimed.has(item.id)

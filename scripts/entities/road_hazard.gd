@tool
class_name RoadHazard
extends Node3D
const Art = preload("res://scripts/art.gd")
const City = preload("res://scripts/city.gd")

@export_enum("Jump Crate", "Duck Bar", "Dodge Wall") var hazard_type := 0:
	set(value):
		hazard_type = value
		_refresh()
@export_enum("Arcade", "Concrete", "Crates", "Container", "Trailer") var look := 0:
	set(value):
		look = value
		_refresh()
@export var radius := 1.05:
	set(value):
		radius = value
		_refresh()
@export var accent := Color("fff1ba"):
	set(value):
		accent = value
		_refresh()
@export var drift_amp := 0.0:
	set(value):
		drift_amp = value
		_refresh()
@export var drift_speed := 0.04:
	set(value):
		drift_speed = value
		_refresh()

var built := false

func _enter_tree() -> void:
	_write_meta()

func _ready() -> void:
	if built:
		return
	built = true
	_write_meta()
	_build()

func _refresh() -> void:
	_write_meta()
	if built and is_inside_tree():
		_rebuild()

func _write_meta() -> void:
	set_meta("kind", hazard_type)
	set_meta("radius", radius)
	set_meta("look", look)
	set_meta("drift_amp", drift_amp)
	set_meta("drift_speed", drift_speed)

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	if hazard_type == 0:
		Art.box(self, Vector3(0, 0.7, 0), Vector3(radius * 2.05, 1.3, 0.9), Color("ef8064"), true)
		Art.box(self, Vector3(0, 0.8, 0.55), Vector3(radius * 1.65, 0.8, 0.12), Color("f9cbb7"), true)
		Art.label(self, Vector3(0, 0.8, 0.64), "JUMP", Color("fff5d7"), 32)
	elif hazard_type == 1 and look == 4:
		var span = radius * 2.1
		Art.box(self, Vector3(0, 2.5, 0), Vector3(span, 1.9, 1.6), Color("d8d2c4"))
		Art.box(self, Vector3(0, 2.5, 0.84), Vector3(span, 1.7, 0.08), Color("c9c4b6"))
		for i in range(maxi(3, int(span / 0.9))):
			var rx = -span * 0.5 + (i + 0.5) * (span / maxi(3, int(span / 0.9)))
			Art.box(self, Vector3(rx, 2.5, 0.89), Vector3(0.09, 1.6, 0.06), Color("b3ad9f"))
		Art.box(self, Vector3(0, 3.18, 0.9), Vector3(span, 0.42, 0.06), Color("3f7d6c"), true)
		Art.label(self, Vector3(0, 2.45, 0.99), "DELSI CARGO", Color("3c3a35"), 34)
		Art.box(self, Vector3(0, 1.42, 0), Vector3(span, 0.24, 1.3), Color("4a4f57"))
		Art.box(self, Vector3(0, 1.28, 0.7), Vector3(span, 0.14, 0.14), Color("cfd6d3"), true)
		for sx in [-span * 0.36, span * 0.36]:
			for sz in [-0.55, 0.55]:
				var wheel = Art.cylinder(self, Vector3(sx, 0.5, sz), 0.5, 0.3, Color("141a20"))
				wheel.rotation.x = PI / 2
				Art.cylinder(self, Vector3(sx, 0.5, sz), 0.2, 0.32, Color("6f6a61")).rotation.x = PI / 2
		Art.box(self, Vector3(-span * 0.5 + 0.2, 0.6, 0), Vector3(0.16, 1.2, 1.0), Color("4a4f57"))
		Art.box(self, Vector3(span * 0.5 - 0.2, 0.6, 0), Vector3(0.16, 1.2, 1.0), Color("4a4f57"))
	elif hazard_type == 1:
		Art.box(self, Vector3(0, 2.0, 0), Vector3(radius * 2.1, 1.7, 0.8), Color("489cbd"), true)
		Art.box(self, Vector3(0, 2.0, 0.55), Vector3(radius * 1.7, 1.1, 0.12), Color("cfeaf8"), true)
		Art.label(self, Vector3(0, 2.0, 0.66), "DUCK", Color("ebfdff"), 32)
	elif look == 1:
		var span = radius * 2.02
		Art.box(self, Vector3(0, 1.5, 0), Vector3(span, 3.0, 0.9), Color("a9a49a"))
		var seams = maxi(2, int(span / 1.1))
		for i in range(seams):
			var sx = -span * 0.5 + (i + 0.5) * (span / seams)
			Art.box(self, Vector3(sx, 1.5, 0.44), Vector3(0.1, 2.9, 0.06), Color("8b867c"))
		Art.box(self, Vector3(0, 2.6, 0.55), Vector3(span, 0.5, 0.1), Color("f0c04a"))
		Art.box(self, Vector3(0, 0.4, 0.55), Vector3(span, 0.7, 0.1), Color("e05b4a"))
		Art.label(self, Vector3(0, 1.7, 0.65), "مغلق", Color("3c3a35"), 44)
		Art.box(self, Vector3(0, 0.1, 0), Vector3(span + 0.5, 0.2, 1.5), Color("6f6a61"))
	elif look == 2:
		var span2 = radius * 2.02
		var cols = maxi(2, int(span2 / 1.2))
		for row in range(3):
			for c in range(cols):
				var cw = span2 / cols
				var cx = -span2 * 0.5 + (c + 0.5) * cw
				var boxc = Color("b98a56").lerp(Color("8a5a33"), float((row + c) % 3) / 3.0)
				Art.box(self, Vector3(cx, 0.5 + row * 1.02, 0), Vector3(cw - 0.08, 0.96, 1.3), boxc)
				Art.box(self, Vector3(cx, 0.5 + row * 1.02, 0.66), Vector3(cw * 0.55, 0.5, 0.06), Color("6d4a2a"))
		Art.label(self, Vector3(0, 1.6, 0.74), "HANTAH", Color("f7e2bd"), 30)
	elif look == 3:
		var span3 = radius * 2.02
		Art.box(self, Vector3(0, 1.3, 0), Vector3(span3, 2.6, 1.4), Color("3f7d6c"))
		for i in range(int(span3 / 0.7)):
			Art.box(self, Vector3(-span3 * 0.5 + 0.35 + i * 0.7, 1.3, 0.72), Vector3(0.16, 2.5, 0.06), Color("356a5c"))
		for sx in [-0.5, 0.5]:
			Art.box(self, Vector3(sx * span3 * 0.9, 1.3, 0.74), Vector3(0.18, 2.6, 0.08), Color("d8d2c4"))
		Art.box(self, Vector3(0, 2.5, 0.74), Vector3(span3, 0.2, 0.08), Color("d8d2c4"))
		Art.label(self, Vector3(0, 1.4, 0.82), "DELSI CARGO", Color("e8f4ef"), 26)
		Art.box(self, Vector3(0, 0.08, 0), Vector3(span3 + 0.3, 0.16, 1.7), Color("33383d"))
	else:
		Art.box(self, Vector3(0, 1.6, 0), Vector3(radius * 2.02, 3.3, 1.1), Color("d96160"), true)
		Art.box(self, Vector3(0, 1.7, 0.62), Vector3(radius * 1.45, 2.9, 0.12), Color("ffd1d1"), true)
		Art.label(self, Vector3(0, 1.8, 0.72), "DODGE", Color("fff0f0"), 30)
	var pulse = Art.box(self, Vector3(0, -0.01, 0), Vector3(radius * 2.45, 0.14, 2.8), accent, false)
	pulse.rotation.x = 0.0

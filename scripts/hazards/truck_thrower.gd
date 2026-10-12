@tool
class_name TruckThrower
extends Node3D
const Art = preload("res://scripts/art.gd")

@export var side := 1:
	set(value):
		side = 1 if value >= 0 else -1
		_refresh()
@export var accent := Color("ffad45"):
	set(value):
		accent = value
		_refresh()

var built := false

func configure(new_side: int, new_accent: Color) -> void:
	side = 1 if new_side >= 0 else -1
	accent = new_accent

func _ready() -> void:
	if built:
		return
	built = true
	_build()

func _refresh() -> void:
	if built and is_inside_tree():
		_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	scale.x = float(side)
	Art.box(self, Vector3(0, 0.75, 0), Vector3(2.0, 1.25, 4.2), Color("294055"))
	Art.box(self, Vector3(-0.35, 1.38, -0.9), Vector3(1.4, 1.05, 1.55), accent, true)
	Art.box(self, Vector3(0.35, 1.08, 1.15), Vector3(1.55, 0.75, 1.6), Color("dfe8ea"))
	Art.box(self, Vector3(-1.25, 1.72, -0.55), Vector3(1.55, 0.2, 0.28), Color("ffefae"), true)
	Art.box(self, Vector3(-1.7, 1.45, -0.3), Vector3(0.38, 0.38, 0.38), Color("f15a8d"), true)
	for z in [-1.35, 1.35]:
		var wheel_a = Art.cylinder(self, Vector3(-0.82, 0.27, z), 0.34, 0.24, Color("111923"))
		wheel_a.rotation.z = PI / 2
		var wheel_b = Art.cylinder(self, Vector3(0.82, 0.27, z), 0.34, 0.24, Color("111923"))
		wheel_b.rotation.z = PI / 2
	Art.label(self, Vector3(-0.05, 1.45, 1.98), "DELSI", Color.WHITE, 32)

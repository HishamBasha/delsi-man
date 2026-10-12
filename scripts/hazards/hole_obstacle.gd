@tool
class_name HoleObstacle
extends Node3D
const Art = preload("res://scripts/art.gd")

@export var radius := 1.55:
	set(value):
		radius = value
		_refresh()
@export var accent := Color("f0c16b"):
	set(value):
		accent = value
		_refresh()

var built := false

func configure(new_radius: float, new_accent: Color) -> void:
	radius = new_radius
	accent = new_accent

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
	set_meta("kind", 4)
	set_meta("radius", radius)

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	var pit = Art.cylinder(self, Vector3(0, 0.015, 0), radius, 0.04, Color("071018"))
	pit.scale.z = 0.62
	Art.box(self, Vector3(0, 0.07, -radius * 0.65), Vector3(radius * 1.95, 0.1, 0.16), accent, true)
	Art.box(self, Vector3(0, 0.07, radius * 0.65), Vector3(radius * 1.95, 0.1, 0.16), accent.darkened(0.18), true)
	Art.box(self, Vector3(-radius * 0.94, 0.07, 0), Vector3(0.16, 0.1, radius * 1.0), accent.darkened(0.08), true)
	Art.box(self, Vector3(radius * 0.94, 0.07, 0), Vector3(0.16, 0.1, radius * 1.0), accent.darkened(0.08), true)
	Art.label(self, Vector3(0, 0.18, 0.08), "JUMP", Color("fff4d6"), 28)

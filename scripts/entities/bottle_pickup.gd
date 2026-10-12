@tool
class_name BottlePickup
extends Node3D
const Art = preload("res://scripts/art.gd")

@export var color := Color(0.219608, 0.545098, 1, 1):
	set(value):
		color = value
		_refresh()
@export var radius := 0.9:
	set(value):
		radius = value
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
	set_meta("kind", 3)
	set_meta("radius", radius)

func _rebuild() -> void:
	for child in get_children():
		child.free()
	_build()

func _build() -> void:
	Art.bottle(self, Vector3.ZERO, color)

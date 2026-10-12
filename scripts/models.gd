extends RefCounted
## GLB prop registry. Loads files from res://assets/models, normalizes orientation
## (up-axis + facade depth) and merges each variant into one cached ArrayMesh so
## the level can instance hundreds of props cheaply.
##
## Registry entry fields:
##   file     - GLB filename inside res://assets/models
##   variant  - child node name to extract (omit for whole scene)
##   variants - array of child names; spawn opts "variant" picks an index
##   up       - source up axis: "y" (default), "z" or "x"
##   depth    - raw horizontal axis holding facade depth: "x" (default) or "z"
##   yaw_deg  - extra fixed yaw baked into the cached mesh
##   instance - keep the original scene instead of merging (animations)
##
## Spawn opts: height/length/depth (fit targets), scale (extra multiplier),
## yaw (radians, applied on the wrapper), variant (index).

const OBJ_DIR := "res://assets/models"

const REGISTRY := {
	"house_a": {"file": "buildings/low_poly_building.glb", "up": "y", "depth": "x"},
	"block_a": {"file": "buildings/asia_building.glb", "up": "y", "depth": "x"},
	"tower_a": {"file": "buildings/futuristic_building.glb", "up": "y", "depth": "x"},
	"warehouse_a": {"file": "buildings/warehouse_building.glb", "variant": "Object_2", "up": "y", "depth": "x"},
	"warehouse_b": {"file": "buildings/warehouse_building_b.glb", "up": "y", "depth": "x"},
	"wall_long": {"file": "buildings/building_workshop_parking_workshop.glb", "variants": ["Object_2", "Object_4"], "up": "y", "depth": "z", "pitch_deg": 90.0},
	"tree_small": {"file": "nature/oak_trees.glb", "variant": "Treesmall", "up": "y"},
	"tree_med": {"file": "nature/oak_trees.glb", "variant": "Treemedium", "up": "y"},
	"tree_big": {"file": "nature/oak_trees.glb", "variant": "treelarge", "up": "y"},
	"bush": {"file": "nature/tree.glb", "up": "y"},
	"tree_sway": {"file": "nature/tree_animate.glb", "up": "x", "instance": true},
	"car_sedan": {"file": "vehicles/low_poly_vehicle_mini_pack.glb", "variants": ["sedan_body", "sedan_body_001", "sedan_body_002", "sedan_body_003"], "up": "y", "depth": "x"},
	"car_pickup": {"file": "vehicles/low_poly_vehicle_mini_pack.glb", "variants": ["pickup_body", "pickup_body_001", "pickup_body_002", "pickup_body_003"], "up": "y", "depth": "x"},
	"car_van": {"file": "vehicles/low_poly_vehicle_mini_pack.glb", "variants": ["van_body_extra1", "van_body_extra1_001", "van_body_extra1_002", "van_body_extra1_003", "van_body_extra1_004", "van_body_extra1_005", "van_body_extra1_006", "van_body_extra1_007"], "up": "y", "depth": "x"},
	"car_btr": {"file": "vehicles/low_poly_vehicle_mini_pack.glb", "variants": ["btr_body", "btr_body_001", "btr_body_002", "btr_body_003"], "up": "y", "depth": "x"},
	"maint_truck": {"file": "vehicles/maintenance_vehicles.glb", "variants": ["Object_2", "Object_3", "Object_5", "Object_6", "Object_7", "Object_8"], "up": "y", "depth": "x"},
	"ped_walk": {"file": "people/posed_police_people.glb", "variants": ["Police walk1_gameasset", "Police walk2_gameasset", "Police walk3_gameasset", "Police walk4_gameasset"], "up": "y", "depth": "x"},
	"ped_idle": {"file": "people/posed_police_people.glb", "variants": ["Police idle1_gameasset", "Police idle2_gameasset", "Police idle3_gameasset", "Police idle4_gameasset", "Police idle5_gameasset"], "up": "y", "depth": "x"},
	"ped_civil": {"file": "people/posed_police_people.glb", "variants": ["Detective_gameasset", "Drugdealer_gameasset", "Black guy what_gameasset"], "up": "y", "depth": "x"},
	"ped_arrest": {"file": "people/posed_police_people.glb", "variant": "Arrested guy_gameasset", "up": "y", "depth": "x"},
	"ped_kneel": {"file": "people/posed_police_people.glb", "variant": "Police kneeling aiming_gameasset", "up": "y", "depth": "x"},
	"barrier": {"file": "props/construction_barricades.glb", "up": "y", "depth": "x"},
	"cone": {"file": "props/traffic_cone.glb", "up": "y"},
	"sofa": {"file": "props/individual_sofa_leather.glb", "up": "y", "depth": "x"},
	"pepsi_statue": {"file": "people/pepsi_man.glb", "up": "y", "depth": "x"},
	"overpass": {"file": "props/modular_hallway_cross_type_02.glb", "up": "y", "depth": "x"},
}

static var _scenes: Dictionary = {}
static var _built: Dictionary = {}


static func has(key: String) -> bool:
	return REGISTRY.has(key)


static func keys() -> Array:
	return REGISTRY.keys()


static func spawn(parent: Node3D, key: String, pos: Vector3, opts: Dictionary = {}) -> Node3D:
	var entry: Dictionary = REGISTRY.get(key, {})
	if entry.is_empty():
		push_warning("Models: unknown key " + key)
		return null
	var vi := int(opts.get("variant", 0))
	var ckey := "%s:%d" % [key, vi]
	var built: Dictionary = _built.get(ckey, {})
	if built.is_empty():
		built = _build(key, entry, vi)
		if built.is_empty():
			return null
		_built[ckey] = built
	var aabb: AABB = built["aabb"]
	var s := INF
	if opts.has("height") and aabb.size.y > 0.0001:
		s = minf(s, float(opts["height"]) / aabb.size.y)
	if opts.has("length") and aabb.size.z > 0.0001:
		s = minf(s, float(opts["length"]) / aabb.size.z)
	if opts.has("depth") and aabb.size.x > 0.0001:
		s = minf(s, float(opts["depth"]) / aabb.size.x)
	if s == INF:
		s = 1.0
	if opts.has("scale"):
		s *= float(opts["scale"])
	if s <= 0.0001:
		s = 1.0
	var anchor := Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	var wrap := Node3D.new()
	parent.add_child(wrap)
	wrap.name = key
	wrap.position = pos
	wrap.rotation.y = float(opts.get("yaw", 0.0))
	wrap.scale = Vector3.ONE * s
	wrap.set_meta("model", key)
	wrap.set_meta("size", aabb.size * s)
	if built.has("packed"):
		var piv := Node3D.new()
		wrap.add_child(piv)
		var basis: Basis = built["basis"]
		piv.transform.basis = basis
		var holder := Node3D.new()
		piv.add_child(holder)
		holder.position = basis.inverse() * anchor
		var inner: Node = (built["packed"] as PackedScene).instantiate()
		holder.add_child(inner)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = built["mesh"]
		wrap.add_child(mi)
		mi.position = anchor
	return wrap


## Spawns with the model facade at x = side * face_x (facing the road).
static func spawn_face(parent: Node3D, key: String, face_x: float, z: float, side: int, opts: Dictionary = {}) -> Node3D:
	var node := spawn(parent, key, Vector3.ZERO, opts)
	if node == null:
		return null
	var size: Vector3 = node.get_meta("size")
	node.position = Vector3(side * (face_x + size.x * 0.5), float(opts.get("y", 0.0)), z)
	return node


static func _build(key: String, entry: Dictionary, vi: int) -> Dictionary:
	var file := String(entry.get("file", ""))
	var packed := _load(file)
	if packed == null:
		return {}
	var inst := packed.instantiate()
	if not (inst is Node3D):
		inst.free()
		return {}
	var temp := Node3D.new()
	temp.add_child(inst)
	var target: Node = inst
	if entry.has("variants"):
		var arr: Array = entry["variants"]
		var want := String(arr[clampi(vi, 0, arr.size() - 1)])
		target = _find(inst, want)
	elif entry.has("variant"):
		target = _find(inst, String(entry["variant"]))
	if target == null or not (target is Node3D):
		push_warning("Models: variant not found for " + key)
		temp.remove_child(inst)
		inst.free()
		temp.free()
		return {}
	var basis := _up_basis(String(entry.get("up", "y")))
	basis = Basis(Vector3.RIGHT, deg_to_rad(float(entry.get("pitch_deg", 0.0)))) * basis
	var yaw := deg_to_rad(float(entry.get("yaw_deg", 0.0)))
	if String(entry.get("depth", "x")) == "z":
		yaw += PI / 2.0
	basis = Basis(Vector3.UP, yaw) * basis
	var out := {}
	if entry.get("instance", false):
		out["aabb"] = _aabb_of(target, basis)
		out["basis"] = basis
		out["packed"] = packed
	else:
		var res := _merge(target, basis)
		temp.remove_child(inst)
		inst.free()
		temp.free()
		if res.is_empty():
			return {}
		out["aabb"] = res[1]
		out["mesh"] = res[0]
		return out
	temp.remove_child(inst)
	inst.free()
	temp.free()
	return out


static func _up_basis(up: String) -> Basis:
	match up:
		"z":
			return Basis(Vector3.RIGHT, -PI / 2.0)
		"x":
			return Basis(Vector3(0, 0, 1), PI / 2.0)
	return Basis.IDENTITY


static func _load(file: String) -> PackedScene:
	if _scenes.has(file):
		return _scenes[file]
	var p := load(OBJ_DIR.path_join(file)) as PackedScene
	if p == null:
		push_warning("Models: cannot load " + file)
	_scenes[file] = p
	return p


static func _find(root: Node, want: String) -> Node:
	if String(root.name) == want:
		return root
	for c in root.get_children():
		var hit := _find(c, want)
		if hit != null:
			return hit
	return null


static func _aabb_of(root: Node3D, basis: Basis) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var ab := _xform_aabb(Transform3D(basis, Vector3.ZERO) * _xf_of(mi), mi.get_aabb())
			if first:
				box = ab
				first = false
			else:
				box = box.merge(ab)
	return box if not first else AABB(Vector3.ZERO, Vector3.ONE)


static func _xform_aabb(xf: Transform3D, box: AABB) -> AABB:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for i in range(8):
		var w: Vector3 = xf * box.get_endpoint(i)
		mn = mn.min(w)
		mx = mx.max(w)
	return AABB(mn, mx - mn)


## World transform computed by walking parents: get_global_transform() needs a
## tree, but merging happens on orphaned instances.
static func _xf_of(n: Node) -> Transform3D:
	var chain: Array[Node3D] = []
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			chain.push_front(cur as Node3D)
		cur = cur.get_parent()
	var t := Transform3D.IDENTITY
	for c in chain:
		t = t * c.transform
	return t


## Materials are grouped by texture + quantized albedo/emission so a model with
## hundreds of near-identical materials collapses into a few draw calls.
static func _mat_key(mat: Material) -> Array:
	var albedo := Color.WHITE
	var tex := RID()
	var texres: Texture2D = null
	var em := Color.BLACK
	var em_e := 0.0
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		albedo = bm.albedo_color
		if bm.albedo_texture != null:
			tex = bm.albedo_texture.get_rid()
			texres = bm.albedo_texture
		if bm.emission_enabled:
			em = bm.emission
			em_e = bm.emission_energy_multiplier
	return [
		tex,
		int(albedo.r * 11.0 + 0.5), int(albedo.g * 11.0 + 0.5), int(albedo.b * 11.0 + 0.5),
		int(em.r * 7.0 + 0.5), int(em.g * 7.0 + 0.5), int(em.b * 7.0 + 0.5),
		int(minf(em_e, 8.0)),
	]


## Merges every mesh below root into one ArrayMesh, baking `basis` into the
## vertices. Returns [ArrayMesh, AABB] or [] on failure.
static func _merge(root: Node3D, basis: Basis) -> Array:
	var groups := {}
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D(basis, Vector3.ZERO) * _xf_of(mi)
		var flip := xf.basis.determinant() < 0.0
		for i in range(mi.mesh.get_surface_count()):
			var arrays := mi.mesh.surface_get_arrays(i)
			if arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var mat: Material = mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			var albedo := Color.WHITE
			var em := Color.BLACK
			var texres: Texture2D = null
			if mat is BaseMaterial3D:
				albedo = (mat as BaseMaterial3D).albedo_color
				texres = (mat as BaseMaterial3D).albedo_texture
				if (mat as BaseMaterial3D).emission_enabled:
					em = (mat as BaseMaterial3D).emission
			var mkey := _mat_key(mat)
			var g: Dictionary = groups.get(mkey, {})
			if g.is_empty():
				g = {
					"verts": PackedVector3Array(), "norms": PackedVector3Array(),
					"uvs": PackedVector2Array(), "uv2": PackedVector2Array(),
					"cols": PackedColorArray(), "tans": PackedFloat32Array(),
					"idx": PackedInt32Array(),
					"norm_ok": true, "tan_ok": true,
					"mats": {}, "first": mat, "albedo": albedo, "em": em,
					"texres": texres,
				}
			var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var base: int = g["verts"].size()
			var verts: PackedVector3Array = g["verts"]
			var norms: PackedVector3Array = g["norms"]
			var uvs: PackedVector2Array = g["uvs"]
			var uv2: PackedVector2Array = g["uv2"]
			var cols: PackedColorArray = g["cols"]
			var tans: PackedFloat32Array = g["tans"]
			var idx: PackedInt32Array = g["idx"]
			for v in src:
				var w := xf * v
				verts.append(w)
				mn.x = minf(mn.x, w.x)
				mn.y = minf(mn.y, w.y)
				mn.z = minf(mn.z, w.z)
				mx.x = maxf(mx.x, w.x)
				mx.y = maxf(mx.y, w.y)
				mx.z = maxf(mx.z, w.z)
			if arrays[Mesh.ARRAY_NORMAL] != null:
				for nv in (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array):
					norms.append(xf.basis * nv)
			else:
				g["norm_ok"] = false
			var src_uv = arrays[Mesh.ARRAY_TEX_UV]
			if src_uv != null and not (src_uv as PackedVector2Array).is_empty():
				uvs.append_array(src_uv)
			else:
				for t in range(src.size()):
					uvs.append(Vector2.ZERO)
			var src_uv2 = arrays[Mesh.ARRAY_TEX_UV2]
			if src_uv2 != null and not (src_uv2 as PackedVector2Array).is_empty():
				uv2.append_array(src_uv2)
			var src_col = arrays[Mesh.ARRAY_COLOR]
			if src_col != null and not (src_col as PackedColorArray).is_empty():
				cols.append_array(src_col)
			else:
				for t in range(src.size()):
					cols.append(albedo)
			var src_tan = arrays[Mesh.ARRAY_TANGENT]
			if src_tan != null and (src_tan as PackedFloat32Array).size() == src.size() * 4:
				var st: PackedFloat32Array = src_tan
				for t in range(src.size()):
					var tv := xf.basis * Vector3(st[t * 4], st[t * 4 + 1], st[t * 4 + 2])
					tans.append(tv.x)
					tans.append(tv.y)
					tans.append(tv.z)
					tans.append(st[t * 4 + 3])
			else:
				g["tan_ok"] = false
			var src_idx = arrays[Mesh.ARRAY_INDEX]
			if src_idx != null and not (src_idx as PackedInt32Array).is_empty():
				for ii in (src_idx as PackedInt32Array):
					idx.append(base + (src.size() - 1 - ii if flip else ii))
			else:
				for t in range(src.size()):
					idx.append(base + (src.size() - 1 - t if flip else t))
			if mat != null:
				var mats: Dictionary = g["mats"]
				mats[mat.get_rid()] = mat
				g["mats"] = mats
			g["verts"] = verts
			g["norms"] = norms
			g["uvs"] = uvs
			g["uv2"] = uv2
			g["cols"] = cols
			g["tans"] = tans
			g["idx"] = idx
			groups[mkey] = g
	if groups.is_empty() or mn.x == INF:
		return []
	var mesh := ArrayMesh.new()
	for k in groups:
		var g: Dictionary = groups[k]
		var verts: PackedVector3Array = g["verts"]
		if verts.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		if g["norm_ok"]:
			var norms: PackedVector3Array = g["norms"]
			if norms.size() == verts.size():
				arr[Mesh.ARRAY_NORMAL] = norms
		var uvs: PackedVector2Array = g["uvs"]
		if uvs.size() == verts.size():
			arr[Mesh.ARRAY_TEX_UV] = uvs
		var uv2: PackedVector2Array = g["uv2"]
		if uv2.size() == verts.size() and not uv2.is_empty():
			arr[Mesh.ARRAY_TEX_UV2] = uv2
		var cols: PackedColorArray = g["cols"]
		if cols.size() == verts.size():
			arr[Mesh.ARRAY_COLOR] = cols
		if g["tan_ok"]:
			var tans: PackedFloat32Array = g["tans"]
			if tans.size() == verts.size() * 4:
				arr[Mesh.ARRAY_TANGENT] = tans
		arr[Mesh.ARRAY_INDEX] = g["idx"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var surf := mesh.get_surface_count() - 1
		var mats: Dictionary = g["mats"]
		if mats.size() == 1 and g["first"] != null:
			mesh.surface_set_material(surf, g["first"])
		else:
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.roughness = 0.75
			sm.albedo_color = Color.WHITE
			if g["texres"] != null:
				sm.albedo_texture = g["texres"]
			if int(k[7]) > 0:
				sm.emission_enabled = true
				sm.emission = g["em"]
				sm.emission_energy_multiplier = float(int(k[7]))
			mesh.surface_set_material(surf, sm)
	if mesh.get_surface_count() == 0:
		return []
	if mesh.get_surface_count() > 48:
		push_warning("Models: high surface count (%d)" % mesh.get_surface_count())
	return [mesh, AABB(mn, mx - mn)]

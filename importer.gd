@tool
extends Node3D

const ByteBufferScript := preload("res://byte_buffer.gd")
const ByteBuffer := ByteBufferScript.ByteBuffer

@export_tool_button("Build Mesh") var parse_button := parse

@export_file_path() var path: String = "res://examples/03.txt"

var model: BlitzModel

func _ready() -> void:
	parse()



func parse() -> void:

	var buffer := ByteBuffer.file_as_buffer(path)

	var magic := buffer.get_type()
	assert(magic == "BB3D", "File not recognized")

	buffer = buffer.get_sub_buffer()

	var version: int = buffer.get_int()
	parse_version(version)

	parse_file(buffer)

class BlitzModel:
	var texs: Array[BlitzTexture] = []
	var brus: Array[BlitzBrush] = []
	var node: BlitzNode

	func to_dict() -> Dictionary:
		var t := texs.map(
			func(s: BlitzTexture) -> Dictionary:
				return s.to_dict()
		)
		return {
			"texs": t,
			"brus": brus,
			"node": node.to_dict()
		}


func parse_file(buffer: ByteBuffer) -> void:

	model = BlitzModel.new()

	while !buffer.eof_reached():
		var block_type: String
		block_type = buffer.get_type()

		match block_type:
			"TEXS":
				model.texs = process_texs(buffer)
			"BRUS":
				model.brus = process_brush(buffer)
			"NODE":
				model.node = process_node(buffer)
			_:
				printerr("Type %s not implemented" % block_type)
	print("Parsing complete.")
	print(JSON.stringify(model.to_dict(), "\t"))

class BlitzNode:
	var name: String
	var tform: Transform3D
	var children: Array[BlitzNode] = []

	func to_dict() -> Dictionary:
		var c := children.map(
			func(ch: BlitzNode) -> Dictionary:
				return ch.to_dict()
		)
		return {
			"name": name,
			"tform": tform,
			"children": c
		}

func process_node(buffer: ByteBuffer) -> BlitzNode:
	buffer = buffer.get_sub_buffer()

	var node: BlitzNode
	var node_name: String = buffer.get_string()

	var pos: Vector3 = buffer.get_vec3()
	var scl: Vector3 = buffer.get_vec3()
	var rot: Quaternion = buffer.get_quat()

	var node_basis := Basis(rot)
	node_basis = node_basis.scaled(scl)
	var tform := Transform3D(node_basis, pos)

	var node_type := buffer.get_type()
	match node_type:
		"BONE":
			var n := BlitzBoneNode.new()
			n.name = node_name
			n.tform = tform
			n.bones = process_bone(buffer)
			node = n
		"MESH":
			var n := process_mesh(buffer)
			n.name = node_name
			n.tform = tform
			node = n
		_:
			print("NodeType %s not found, default to pivot" % node_type)
			var n := BlitzNode.new()
			n.name = node_name
			n.tform = tform
			node = n

	while !buffer.eof_reached():
		var type: String = buffer.get_type()

		match type:
			"ANIM":
				process_anim(buffer)
			"SEQS":
				process_seqs(buffer)
			"NODE":
				var n := process_node(buffer)
				node.children.append(n)
			"KEYS":
				process_keys(buffer)
			_:
				printerr("%s not implemented" % type)
				break

	return node

class BlitzKey:
	var frame: int
	var tform: Transform3D

	func to_dict() -> Dictionary:
		return {
			"frame": frame,
			"tform": tform
		}

func process_keys(buffer: ByteBuffer) -> Array[BlitzKey]:
	buffer = buffer.get_sub_buffer()

	var flags: int = buffer.get_int()
	var has_pos: bool = flags & 0b001
	var has_scl: bool = flags & 0b010
	var has_rot: bool = flags & 0b100

	var keys: Array[BlitzKey] = []
	while !buffer.eof_reached():
		var key := BlitzKey.new()
		key.frame = buffer.get_int()

		var pos: Vector3 = Vector3.ZERO
		var scl: Vector3 = Vector3.ONE
		var rot: Quaternion = Quaternion.IDENTITY

		if has_pos:
			pos = buffer.get_vec3()
		if has_scl:
			scl = buffer.get_vec3()
		if has_rot:
			rot = buffer.get_quat()

		var node_basis := Basis(rot)
		node_basis = node_basis.scaled(scl)
		var tform := Transform3D(node_basis, pos)
		key.tform = tform
		keys.append(key)
	return keys

class BlitzBoneNode extends BlitzNode:
	var bones: Dictionary[int, float]

	func to_dict() -> Dictionary:
		var d := super.to_dict()
		d["bones"] = bones
		return d

class BlitzMeshNode extends BlitzNode:
	var mesh: ArrayMesh
	var brush_id: int

	func to_dict() -> Dictionary:
		var d := super.to_dict()
		d["brush_id"] = brush_id
		d["mesh"] = mesh
		return d

func process_bone(buffer: ByteBuffer) -> Dictionary[int, float]:
	buffer = buffer.get_sub_buffer()

	var bones: Dictionary[int, float] = {}
	while !buffer.eof_reached():
		var vertex_id := buffer.get_int()
		var weight := buffer.get_float()
		# TODO clamp weights??
		bones[vertex_id] = weight

	return bones

class BlitzSequence:
	var name: String
	var start: int
	var end: int
	var flags: int

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"start": start,
			"end": end,
			"flags": flags
		}

func process_seqs(buffer: ByteBuffer) -> BlitzSequence:
	buffer = buffer.get_sub_buffer()

	var seqs := BlitzSequence.new()
	seqs.name = buffer.get_string()
	seqs.start = buffer.get_int()
	seqs.end = buffer.get_int()

	return seqs


class BlitzAnim:
	var flags: int
	var frames: int
	var fps: float

	func to_dict() -> Dictionary:
		return {
			"flags": flags,
			"frames": frames,
			"fps": fps
		}

func process_anim(buffer: ByteBuffer) -> BlitzAnim:
	buffer = buffer.get_sub_buffer()

	var anim: BlitzAnim = BlitzAnim.new()
	anim.flags = buffer.get_int()
	anim.frames = buffer.get_int()
	anim.fps = buffer.get_float()

	return anim

func process_mesh(buffer: ByteBuffer) -> BlitzMeshNode:
	buffer = buffer.get_sub_buffer()

	var node := BlitzMeshNode.new()

	node.brush_id = buffer.get_int()

	var mesh_array: Array
	var indices: PackedInt32Array

	var mesh := ArrayMesh.new()

	while !buffer.eof_reached():
		var type: String = buffer.get_type()
		match type:
			"VRTS":
				mesh_array = process_vrts(buffer)
			"TRIS":
				indices = process_tris(buffer)
				_clear_children()
				var meshinst := MeshInstance3D.new()

				mesh_array[Mesh.ARRAY_INDEX] = indices
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
				meshinst.mesh = mesh
				add_child(meshinst)
				meshinst.owner = self
			_:
				printerr("%s not implemented" % type)
				return

	node.mesh = mesh
	return node

func process_tris(buffer: ByteBuffer) -> PackedInt32Array:
	buffer = buffer.get_sub_buffer()

	var brush_id: int = buffer.get_int()
	var tris: PackedInt32Array = []
	while !buffer.eof_reached():
		var v0 := buffer.get_int()
		var v1 := buffer.get_int()
		var v2 := buffer.get_int()
		var triangle: PackedInt32Array = [
			v0, v1, v2
		]
		tris.append_array(triangle)
	return tris

func _clear_children() -> void:
	for child: Node in get_children():
		child.queue_free()

func process_vrts(buffer: ByteBuffer) -> Array:
	buffer = buffer.get_sub_buffer()

	var flags: int = buffer.get_int()
	var normal_present: bool = bool(flags & 0b01)
	var color_present: bool = bool(flags & 0b10)

	print("Normals: %s" % normal_present)

	var tex_coord_sets: int = buffer.get_int()
	if tex_coord_sets > 1:
		printerr("Multiple UVs not supported")
	var set_size: int = buffer.get_int()
	if set_size != 2:
		printerr("Only 2D UV coordinates supported")

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	while !buffer.eof_reached():
		var pos: Vector3 = buffer.get_vec3()
		if normal_present:
			st.set_normal(buffer.get_vec3())
		if color_present:
			st.set_color(buffer.get_color())
		st.set_uv(buffer.get_vec2())
		st.add_vertex(pos)

	var mesh_array: Array = st.commit_to_arrays()
	return mesh_array


class BlitzBrush:
	var name: String
	var color: Color
	var shininess: float
	var blend: int
	var fx: int
	var texture_id: int

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"color": color,
			"shininess": shininess,
			"blend": blend,
			"fx": fx,
			"texture_id": texture_id
		}

	func _to_string() -> String:
		return str(to_dict())

func process_brush(buffer: ByteBuffer) -> Array[BlitzBrush]:
	buffer = buffer.get_sub_buffer()

	var count: int = buffer.get_int()
	var brushes: Array[BlitzBrush] = []

	for i: int in count:
		var brush: BlitzBrush = BlitzBrush.new()
		brush.name = buffer.get_string()
		brush.color = buffer.get_color()
		brush.shininess = buffer.get_float()
		brush.blend = buffer.get_int()
		brush.fx = buffer.get_int()
		brush.texture_id = buffer.get_int()
		brushes.append(brush)
	return brushes



enum BlendMode {
	NORMAL = 2
}

class BlitzTexture:
	var path: String
	var tform: Transform2D
	var flags: int
	var blend_mode: BlendMode = BlendMode.NORMAL

	func to_dict() -> Dictionary:
		return {
			"path": path,
			"tform": tform,
			"flags": flags,
			"blend_mode": blend_mode
		}

func process_texs(buffer: ByteBuffer) -> Array[BlitzTexture]:
	var texs: Array[BlitzTexture] = []
	buffer = buffer.get_sub_buffer()

	while !buffer.eof_reached():
		var tex: BlitzTexture = BlitzTexture.new()

		var texture_name: String = buffer.get_string()

		tex.flags = buffer.get_int()

		tex.blend_mode = buffer.get_int() as BlendMode

		var pos: Vector2 = buffer.get_vec2()
		var scl: Vector2 = buffer.get_vec2()
		var rot: float = buffer.get_float()

		tex.tform = Transform2D(rot, pos)
		tex.tform = tex.tform.scaled(scl)

		if tex.tform != Transform2D.IDENTITY:
			printerr("Mutated transform not supported: %s" % tex.tform)

		if tex.flags != 1 and tex.blend_mode != BlendMode.NORMAL:
			printerr("Used flags not supported")

		texs.append(tex)
	return texs

func parse_version(version: int) -> void:
	var minor: int = version % 100
	var major: int = floori(version / 100.0)

	var version_str: String = "%d.%d" % [major, minor]
	if major > 0: printerr("Version %s not supported" % version_str)
	if minor != 1: print("Version %s might not import correctly" % version_str)

	print("Parsing version %s" % version_str)

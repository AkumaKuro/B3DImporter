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

	var size: int = buffer.get_int()

	buffer = buffer.get_sub_buffer(size)

	var version: int = buffer.get_int()
	parse_version(version)

	parse_file(buffer)

class BlitzModel:
	var texs: Array[BlitzTexture] = []
	var brus: Array[BlitzBrush] = []
	var nodes: Array[BlitzNode] = []

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
				process_node(buffer)
			_:
				printerr("Type %s not implemented" % block_type)
	print("Parsing complete.")

enum NodeType {
	PIVOT,
	BONE,
	MESH
}

class BlitzNode:
	var name: String
	var tform: Transform3D
	var type: NodeType
	var children: Array[BlitzNode] = []

func process_node(buffer: ByteBuffer) -> BlitzNode:
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

	var node: BlitzNode = BlitzNode.new()
	node.name = buffer.get_string()

	var pos: Vector3 = buffer.get_vec3()
	var scl: Vector3 = buffer.get_vec3()
	var rot: Quaternion = buffer.get_quat()

	var basis := Basis(rot)
	basis = basis.scaled(scl)
	var tform := Transform3D(basis, pos)
	node.tform = tform

	var node_type := buffer.get_type()
	match node_type:
		"BONE":
			node.type = NodeType.BONE
			process_bone(buffer)
		"MESH":
			node.type = NodeType.MESH
			process_mesh(buffer)
		_:
			print("NodeType %s not found, default to pivot" % node_type)
			node.type = NodeType.PIVOT

	while !buffer.eof_reached():
		print("Parsing Node")
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

func process_keys(buffer: ByteBuffer) -> Array[BlitzKey]:
	print("Parsing Key")
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

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

		var basis := Basis(rot)
		basis = basis.scaled(scl)
		var tform := Transform3D(basis, pos)
		key.tform = tform
		keys.append(key)
	return keys

class BlitzBoneNode extends BlitzNode:
	var bones: Array[BlitzBone]

class BlitzMeshNode extends BlitzNode:
	var mesh: ArrayMesh

class BlitzBone:
	var vertex_id: int
	var weight: float

func process_bone(buffer: ByteBuffer) -> void:
	print("Parsing Bones")
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

	var bones: Array[BlitzBone] = []
	while !buffer.eof_reached():
		var bone := BlitzBone.new()
		bone.vertex_id = buffer.get_int()
		bone.weight = buffer.get_float()
		bones.append(bone)

class BlitzSequence:
	var name: String
	var start: int
	var end: int
	var flags: int

func process_seqs(buffer: ByteBuffer) -> BlitzSequence:
	print("Parsing Seqs")
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

	var seqs := BlitzSequence.new()
	seqs.name = buffer.get_string()
	seqs.start = buffer.get_int()
	seqs.end = buffer.get_int()

	return seqs


class BlitzAnim:
	var flags: int
	var frames: int
	var fps: float

func process_anim(buffer: ByteBuffer) -> BlitzAnim:
	print("Parsing Anim")
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

	var anim: BlitzAnim = BlitzAnim.new()
	anim.flags = buffer.get_int()
	anim.frames = buffer.get_int()
	anim.fps = buffer.get_float()

	return anim

func process_mesh(buffer: ByteBuffer) -> void:
	print("Parsing Mesh")
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)
	var brush_id: int = buffer.get_int()

	var mesh_array: Array
	var indices: PackedInt32Array

	while !buffer.eof_reached():
		var type: String = buffer.get_type()
		match type:
			"VRTS":
				mesh_array = process_vrts(buffer)
			"TRIS":
				indices = process_tris(buffer)
				_clear_children()
				var meshinst := MeshInstance3D.new()
				var mesh := ArrayMesh.new()
				mesh_array[Mesh.ARRAY_INDEX] = indices
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
				meshinst.mesh = mesh
				add_child(meshinst)
				meshinst.owner = self
			_:
				printerr("%s not implemented" % type)
				return

func process_tris(buffer: ByteBuffer) -> PackedInt32Array:
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

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
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

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

func process_brush(buffer: ByteBuffer) -> Array[BlitzBrush]:
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

	var count: int = buffer.get_int()
	var brushes: Array[BlitzBrush] = []

	for i: int in count:
		var brush: BlitzBrush = BlitzBrush.new()
		brush.name = buffer.get_string()
		print("Brush name: %s" % brush.name)
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

func process_texs(buffer: ByteBuffer) -> Array[BlitzTexture]:
	var texs: Array[BlitzTexture] = []
	var size: int = buffer.get_int()
	buffer = buffer.get_sub_buffer(size)

	while !buffer.eof_reached():
		var tex: BlitzTexture = BlitzTexture.new()

		print(buffer.buffer.size())

		var texture_name: String = buffer.get_string()
		print("Texture Name: %s" % texture_name)
		print(buffer.buffer.size() - buffer.cursor)

		tex.flags = buffer.get_int()


		tex.blend_mode = buffer.get_int() as BlendMode

		var pos: Vector2 = buffer.get_vec2()
		var scale: Vector2 = buffer.get_vec2()
		var rotation: float = buffer.get_float()

		tex.tform = Transform2D(rotation, pos)
		tex.tform = tex.tform.scaled(scale)

		if tex.tform != Transform2D.IDENTITY:
			printerr("Mutated transform not supported: %s" % tex.tform)

		print("Texture Flags: %s, Texture Blend: %s" % [tex.flags, tex.blend_mode])
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

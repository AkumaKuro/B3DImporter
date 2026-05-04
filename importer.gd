@tool
extends Node

@export_tool_button("Build Mesh") var parse_button := parse

@export_file_path() var path: String = "res://examples/03.txt"

func parse() -> void:
	var file: FileAccess
	file = FileAccess.open(path, FileAccess.READ)

	var magic := get_ascii(file, 4)
	assert(magic == "BB3D", "File not recognized")

	var block_size: int = file.get_32()
	var file_size: int = FileAccess.get_size(path)
	assert(block_size + 8 == file_size, "File incomplete")

	var version: int = file.get_32()
	parse_version(version)

	parse_file(file)

class BlitzModel:
	var texs: Array[BlitzTexture] = []
	var brus: Array[BlitzBrush] = []

func parse_file(file: FileAccess) -> void:

	var model: BlitzModel = BlitzModel.new()

	while !file.eof_reached():
		var block_type: String
		block_type = get_ascii(file, 4)

		match block_type:
			"TEXS":
				model.texs = process_texs(file)
			"BRUS":
				model.brus = process_brush(file)
			"NODE":
				process_node(file)
			_:
				break
	print("Parsing complete.")

class BlitzNode:
	var name: String
	var tform: Transform3D

func process_node(file: FileAccess) -> BlitzNode:
	var size: int = file.get_32()
	var buffer: ByteBuffer = ByteBuffer.new(
		file.get_buffer(size)
	)

	var node: BlitzNode = BlitzNode.new()
	node.name = buffer.get_string()

	var pos: Vector3 = buffer.get_vec3()
	var scl: Vector3 = buffer.get_vec3()
	var rot: Quaternion = buffer.get_quat()

	var basis := Basis(rot)
	basis = basis.scaled(scl)
	var tform := Transform3D(basis, pos)
	node.tform = tform

	while !buffer.eof_reached():

		var type: String = buffer.get_type()

		match type:
			"MESH":
				process_mesh(buffer)
			"ANIM":
				process_anim(buffer)
			_:
				printerr("%s not implemented" % type)
				break

	return node

class BlitzAnim:
	var flags: int
	var frames: int
	var fps: float

func process_anim(buffer: ByteBuffer) -> BlitzAnim:
	var size: int = buffer.get_int()
	buffer = ByteBuffer.new(buffer.get_buffer(size))

	var anim: BlitzAnim = BlitzAnim.new()
	anim.flags = buffer.get_int()
	anim.frames = buffer.get_int()
	anim.fps = buffer.get_float()

	return anim

func process_mesh(buffer: ByteBuffer) -> void:
	var size: int = buffer.get_int()
	buffer = ByteBuffer.new(buffer.get_buffer(size))
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
	buffer = ByteBuffer.new(buffer.get_buffer(size))

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
	buffer = ByteBuffer.new(buffer.get_buffer(size))

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

func process_brush(file: FileAccess) -> Array[BlitzBrush]:
	var size: int = file.get_32()
	var buffer: ByteBuffer = ByteBuffer.new(
		file.get_buffer(size)
	)

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


class ByteBuffer:
	var buffer: PackedByteArray
	var cursor: int = 0

	func _init(new_buffer: PackedByteArray) -> void:
		self.buffer = new_buffer

	func get_quat() -> Quaternion:
		var w: float = get_float()
		return Quaternion(
			get_float(),
			get_float(),
			get_float(),
			w
		)

	func get_color() -> Color:
		return Color(
			get_float(),
			get_float(),
			get_float(),
			get_float()
		)

	func get_byte() -> int:
		var byte: int = buffer[cursor]
		cursor += 1
		return byte

	func get_buffer(length: int) -> PackedByteArray:
		var b: PackedByteArray
		b = buffer.slice(cursor, cursor + length)
		cursor += length
		return b

	func get_int() -> int:
		var b: PackedByteArray = get_buffer(4)
		var i: int = b.to_int32_array()[0]
		return i

	func get_float() -> float:
		var b: PackedByteArray = get_buffer(4)
		var f: float = b.to_float32_array()[0]
		return f

	func get_type() -> String:
		var b: PackedByteArray = get_buffer(4)
		return b.get_string_from_ascii()

	func get_string() -> String:
		var res: String = ""
		var ch: int = get_byte()
		while ch != 0:
			res += char(ch)
			ch = get_byte()
		return res

	func get_vec2() -> Vector2:
		return Vector2(
			get_float(),
			get_float()
		)
	func get_vec3() -> Vector3:
		return Vector3(
			-get_float(),
			get_float(),
			get_float()
		)

	func eof_reached() -> bool:
		return cursor >= buffer.size()

enum BlendMode {
	NORMAL = 2
}

class BlitzTexture:
	var path: String
	var tform: Transform2D
	var flags: int
	var blend_mode: BlendMode = BlendMode.NORMAL

func process_texs(file: FileAccess) -> Array[BlitzTexture]:
	var texs: Array[BlitzTexture] = []
	var size: int = file.get_32()
	var buffer: ByteBuffer = ByteBuffer.new(
		file.get_buffer(size)
	)

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



func get_ascii(file: FileAccess, length: int) -> String:
	var buffer := file.get_buffer(length)
	return buffer.get_string_from_ascii()

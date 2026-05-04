extends Node

const path: String = "res://examples/03.txt"

func _ready() -> void:
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

func parse_file(file: FileAccess) -> void:

	while !file.eof_reached():
		var block_type: String
		block_type = get_ascii(file, 4)

		match block_type:
			"TEXS":
				process_texs(file)
			"BRUS":
				process_brush(file)
			"NODE":
				process_node(file)
			_:
				break
	print("Parsing complete.")

func process_node(file: FileAccess) -> void:
	var size: int = file.get_32()
	var buffer: ByteBuffer = ByteBuffer.new(
		file.get_buffer(size)
	)

	print("Not implemented")

func process_brush(file: FileAccess) -> void:
	var size: int = file.get_32()
	var buffer: ByteBuffer = ByteBuffer.new(
		file.get_buffer(size)
	)

	var a: int = buffer.get_int()
	var mat_name: String = buffer.get_string()
	print(mat_name)

	print("Not implemented")

class ByteBuffer:
	var buffer: PackedByteArray
	var cursor: int = 0

	func _init(buffer: PackedByteArray) -> void:
		self.buffer = buffer

	func get_byte() -> int:
		var byte: int = buffer[cursor]
		cursor += 1
		return byte

	func get_buffer(length: int) -> PackedByteArray:
		var b: PackedByteArray
		b = buffer.slice(cursor, length)
		cursor += length
		return b

	func get_int() -> int:
		var b: PackedByteArray = get_buffer(4)
		var i: int = b.to_int32_array()[0]
		return i

	func get_string() -> String:
		var res: String = ""
		var ch: int = get_byte()
		while ch != 0:
			res += char(ch)
			ch = get_byte()
		return res

func process_texs(file: FileAccess) -> void:
	var size: int = file.get_32()
	var buffer: ByteBuffer = ByteBuffer.new(
		file.get_buffer(size)
	)

	var str: String = buffer.get_string()
	print(str)

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

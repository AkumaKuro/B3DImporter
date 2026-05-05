class ByteBuffer:
	var buffer: PackedByteArray
	var cursor: int = 0
	var offset: int = 0

	func _init(new_buffer: PackedByteArray) -> void:
		self.buffer = new_buffer

	static func file_as_buffer(path: String) -> ByteBuffer:
		var data: PackedByteArray
		data = FileAccess.get_file_as_bytes(path)
		var new_buffer := ByteBuffer.new(data)
		return new_buffer

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

	func _get_buffer(length: int) -> PackedByteArray:
		var b: PackedByteArray
		b = buffer.slice(cursor, cursor + length)
		cursor += length
		return b

	func get_sub_buffer(length: int) -> ByteBuffer:
		var new_offset := offset + cursor
		var b := _get_buffer(length)
		var new_buffer := ByteBuffer.new(b)
		new_buffer.offset = new_offset
		return new_buffer

	func get_int() -> int:
		var b: PackedByteArray = _get_buffer(4)
		var i: int = b.to_int32_array()[0]
		return i

	func get_float() -> float:
		var b: PackedByteArray = _get_buffer(4)
		var f: float = b.to_float32_array()[0]
		return f

	func get_type() -> String:
		var b: PackedByteArray = _get_buffer(4)
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

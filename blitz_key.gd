const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer
const BlitzAnim := preload("res://blitz_anim.gd").BlitzAnim

class BlitzKey:
	var frame: int
	var tform: Transform3D

	func to_dict() -> Dictionary:
		return {
			"frame": frame,
			"tform": tform
		}

	static func process_keys(buffer: ByteBuffer):
		buffer = buffer.get_sub_buffer()

		var flags: int = buffer.get_int()
		var has_pos: bool = flags & 0b001
		var has_scl: bool = flags & 0b010
		var has_rot: bool = flags & 0b100

		var keys: Array[BlitzKey] = []
		while !buffer.eof_reached():
			var key := BlitzKey.new()
			key.frame = buffer.get_int()

			key.tform = buffer.get_tform(
				has_pos, has_scl, has_rot
			)
			keys.append(key)
		BlitzAnim.anim.keys.append_array(keys)

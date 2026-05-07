const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

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

	static func process_anim(buffer: ByteBuffer) -> BlitzAnim:
		buffer = buffer.get_sub_buffer()

		var anim: BlitzAnim = BlitzAnim.new()
		anim.flags = buffer.get_int()
		anim.frames = buffer.get_int()
		anim.fps = buffer.get_float()

		return anim

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

const BlitzKey := preload("res://blitz_key.gd").BlitzKey

class BlitzAnim:
	static var anim: BlitzAnim

	var flags: int
	var frames: int
	var fps: float

	var keys: Array[BlitzKey]

	func to_dict() -> Dictionary:
		return {
			"flags": flags,
			"frames": frames,
			"fps": fps,
			"keys": keys
		}

	static func process_anim(buffer: ByteBuffer) -> BlitzAnim:
		buffer = buffer.get_sub_buffer()

		if anim != null: printerr("Only one anim supported")
		anim = BlitzAnim.new()
		anim.flags = buffer.get_int()
		anim.frames = buffer.get_int()
		anim.fps = buffer.get_float()
		anim.keys = []

		return anim

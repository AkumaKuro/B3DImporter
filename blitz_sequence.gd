const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

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

	static func process_seqs(buffer: ByteBuffer) -> BlitzSequence:
		buffer = buffer.get_sub_buffer()

		var seqs := BlitzSequence.new()
		seqs.name = buffer.get_string()
		seqs.start = buffer.get_int()
		seqs.end = buffer.get_int()

		return seqs

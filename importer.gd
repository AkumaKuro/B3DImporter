@tool
extends Node

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

@export_tool_button("Build mesh") var parse_button := parse

func parse() -> void:
	print("Hello world")

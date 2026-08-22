class_name WalkthroughScript
extends RefCounted

const LINES_PATH := "res://tools/walkthrough/lines.json"
const VO_DIR := "res://tools/walkthrough/vo/"


static func lines() -> Dictionary:
	var txt := FileAccess.get_file_as_string(LINES_PATH)
	if txt.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	return {}


static func vo_path(id: String) -> String:
	return VO_DIR + id + ".mp3"

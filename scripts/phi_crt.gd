class_name PhiCrt
extends RefCounted
## phi.crt (特殊 Create レシピ) のモデル。FORMAT_SPEC §9。
## レシピ = [:L] :P/:F :S :S の厳密な並び。行は letter + rest で
## 保持し、グループ化は blocks() で行う。ライタはサーバにない。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []


static func parse(raw: PhiRawLines) -> PhiCrt:
	var crt := PhiCrt.new()
	crt.raw_lines = raw
	for i in raw.line_count():
		var line := raw.line_text(i)
		if line.length() >= 2 and line[0] == ":" and line[1] in "LPFS":
			crt.records.append({"kind": line[1],
					"fields": {"rest": line.substr(2)}, "modified": false})
		elif line == ".":
			crt.records.append({"kind": "term", "fields": {},
					"modified": false})
		else:
			crt.records.append({"kind": "raw", "fields": {},
					"modified": false})
	return crt


static func load_file(path: String) -> PhiCrt:
	var raw := PhiRawLines.load_file(path)
	if raw == null:
		return null
	return parse(raw)


func serialize() -> PackedByteArray:
	for i in records.size():
		if bool(records[i].get("modified", false)):
			raw_lines.set_line_text(i, build_line(records[i]))
	return raw_lines.to_bytes()


func touch(rec: Dictionary) -> void:
	rec["modified"] = true


func add_record(rec: Dictionary) -> int:
	raw_lines.lines.append(PackedByteArray())
	raw_lines.eols.append("\n".to_utf8_buffer())
	raw_lines.dirty.append(false)
	rec["modified"] = true
	records.append(rec)
	return records.size() - 1


func remove_record(idx: int) -> void:
	raw_lines.lines.remove_at(idx)
	raw_lines.eols.remove_at(idx)
	raw_lines.dirty.remove_at(idx)
	records.remove_at(idx)


static func build_line(rec: Dictionary) -> String:
	match String(rec["kind"]):
		"term":
			return "."
		"L", "P", "F", "S":
			return ":" + String(rec["kind"]) + String(rec["fields"]["rest"])
	return ""

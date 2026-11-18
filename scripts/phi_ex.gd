class_name PhiEx
extends RefCounted
## phi.ex (ゲート通過制限) のモデル。FORMAT_SPEC §10。
## グループ = :G/:g 1行 + :I/:i/:M/:m 任意件 + '.' 終端。
## :G/:g は座標・ゲート名 (空白2つで終端)・IP まで分解し、
## 制限行は letter + rest で保持する。ライタはサーバにない。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []


static func parse(raw: PhiRawLines) -> PhiEx:
	var ex := PhiEx.new()
	ex.raw_lines = raw
	for i in raw.line_count():
		ex.records.append(_parse_line(raw.line_text(i)))
	return ex


static func load_file(path: String) -> PhiEx:
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


static func _parse_line(line: String) -> Dictionary:
	if line == ".":
		return {"kind": "term", "fields": {}, "modified": false}
	if line.length() < 2 or line[0] != ":":
		return {"kind": "raw", "fields": {}, "modified": false}
	var letter := line[1]
	if letter in ["G", "g"]:
		var rest := line.substr(2).lstrip(" ")
		var t1 := _token(rest)
		var t2 := _token(t1[1])
		var tail := String(t2[1])
		var idx := tail.find("  ")
		var name := ""
		var after := ""
		var width := 0
		if idx >= 0:
			name = tail.substr(0, idx)
			var j := idx
			while j < tail.length() and tail[j] == " ":
				j += 1
			after = tail.substr(j)
			width = Cp932.encode(name).size() + (j - idx)
		else:
			name = tail
		var ip := ""
		var rest_after_ip := ""
		if after != "":
			var t3 := _token(after)
			ip = String(t3[0])
			rest_after_ip = String(t3[1])
		return {"kind": letter, "fields": {"x": String(t1[0]),
				"y": String(t2[0]), "name": name, "ip": ip,
				"rest": rest_after_ip, "name_width": width},
				"modified": false}
	if letter in ["I", "i", "M", "m"]:
		return {"kind": letter, "fields": {"rest": line.substr(2)},
				"modified": false}
	return {"kind": "raw", "fields": {}, "modified": false}


static func _token(s: String) -> Array:
	var t := s.lstrip(" ")
	var sp := t.find(" ")
	if sp < 0:
		return [t, ""]
	return [t.substr(0, sp), t.substr(sp + 1)]


static func build_line(rec: Dictionary) -> String:
	var f: Dictionary = rec.get("fields", {})
	match String(rec["kind"]):
		"term":
			return "."
		"G", "g":
			var name := String(f["name"])
			var width := int(f.get("name_width", 0))
			var nb := Cp932.encode(name).size()
			var padded := name
			while nb < width:
				padded += " "
				nb += 1
			if width == 0:
				padded += "  "
			var out := ":" + String(rec["kind"]) + " " + String(f["x"]) \
					+ " " + String(f["y"]) + " " + padded + String(f["ip"])
			if String(f.get("rest", "")) != "":
				out += " " + String(f["rest"])
			return out
		"I", "i", "M", "m":
			return ":" + String(rec["kind"]) + String(f["rest"])
	return ""

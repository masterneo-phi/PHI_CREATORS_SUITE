class_name PhiOd
extends RefCounted
## phi.od (オブジェクト) のモデル。FORMAT_SPEC §8。
## サーバのライタ save_obj() の正規形で再生成する:
##   :O %03d %03d <gname 15幅>  <dir>[T][D][K|P] "名前" [ID]
## 隠しオブジェクトは x=y=-1 で "--- ---" になる。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

const DIR_CHARS := "NESWBRFL"


static func parse(raw: PhiRawLines) -> PhiOd:
	var od := PhiOd.new()
	od.raw_lines = raw
	for i in raw.line_count():
		od.records.append(_parse_line(raw.line_text(i)))
	return od


static func load_file(path: String) -> PhiOd:
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
	if not line.begins_with(":O "):
		return {"kind": "raw", "fields": {}, "modified": false}
	var rest := line.substr(3)
	# X Y トークン
	var t1 := _token(rest)
	var t2 := _token(t1[1])
	var x := -1
	var y := -1
	if not String(t1[0]).begins_with("-"):
		x = String(t1[0]).to_int()
		y = String(t2[0]).to_int()
	rest = t2[1]
	# gname は空白2つで終端
	var idx := rest.find("  ")
	var gname := ""
	if idx >= 0:
		gname = rest.substr(0, idx).rstrip(" ")
		rest = rest.substr(idx).lstrip(" ")
	else:
		gname = rest.rstrip(" ")
		rest = ""
	# dir トークン (位置依存の接尾辞)
	var t3 := _token(rest)
	var dirtok := String(t3[0])
	rest = t3[1].lstrip(" ")
	var f := {"x": x, "y": y, "gname": gname, "dir": 0, "trace": false,
			"debu": false, "board": false, "push": false, "name": "",
			"id": ""}
	var pos := 0
	if pos < dirtok.length():
		var di := DIR_CHARS.find(dirtok[pos].to_upper())
		if di >= 0:
			f["dir"] = di
			pos += 1
	if pos < dirtok.length() and dirtok[pos] == "T":
		f["trace"] = true
		pos += 1
	if pos < dirtok.length() and dirtok[pos] == "D":
		f["debu"] = true
		pos += 1
	if pos < dirtok.length() and dirtok[pos] == "K":
		f["board"] = true
		pos += 1
	elif pos < dirtok.length() and dirtok[pos] == "P":
		f["push"] = true
		pos += 1
	# 表示名 (引用) と ObjID
	if rest.begins_with('"'):
		var end := rest.find('"', 1)
		if end > 0:
			f["name"] = rest.substr(1, end - 1)
			rest = rest.substr(end + 1).lstrip(" ")
			f["id"] = rest
	else:
		f["id"] = rest
	return {"kind": "O", "fields": f, "modified": false}


static func _token(s: String) -> Array:
	var t := s.lstrip(" ")
	var sp := t.find(" ")
	if sp < 0:
		return [t, ""]
	return [t.substr(0, sp), t.substr(sp + 1)]


static func build_line(rec: Dictionary) -> String:
	if String(rec["kind"]) != "O":
		return ""
	var f: Dictionary = rec["fields"]
	var head: String
	if int(f["x"]) < 0:
		head = ":O --- --- "
	else:
		head = ":O %03d %03d " % [int(f["x"]), int(f["y"])]
	var gname := String(f["gname"])
	var nb := Cp932.encode(gname).size()
	while nb < 15:
		gname += " "
		nb += 1
	var dirch := DIR_CHARS[int(f["dir"])]
	var suffix := ""
	if bool(f["trace"]):
		suffix += "T"
	if bool(f["debu"]):
		suffix += "D"
	if bool(f["board"]):
		suffix += "K"
	elif bool(f["push"]):
		suffix += "P"
	var out := head + gname + "  " + dirch + suffix
	out += ' "' + String(f["name"]) + '"'
	if String(f["id"]) != "":
		out += " " + String(f["id"])
	return out

class_name PhiAd
extends RefCounted
## phi.ad (マスター権限) のモデル。FORMAT_SPEC §13。
## ブロック = :<uid> <ip> <権限文字列> [:A 領土...] '.'
## ヘッダは uid/ip/auth に分解、:A は rest で保持する。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

## 権限文字 → 表示名 (A は全権で走査停止)
const AUTH_NAMES := {
	"A": "全権限", "B": "BAN", "K": "Kick", "U": "ロック解除",
	"D": "看板削除", "R": "Resource/Create", "I": "Wish/Dup/Cache",
	"L": "Load/Save", "S": "Shutdown", "T": "転送系", "Q": "フラグ/変数",
	"u": "ロック解除 (領土)", "d": "看板削除 (領土)",
	"r": "Resource (領土)",
}


static func parse(raw: PhiRawLines) -> PhiAd:
	var ad := PhiAd.new()
	ad.raw_lines = raw
	var in_block := false
	for i in raw.line_count():
		var line := raw.line_text(i)
		if not in_block and line.begins_with(":") and line.length() > 1:
			var rest := line.substr(1)
			var t1 := _token(rest)
			var t2 := _token(t1[1])
			ad.records.append({"kind": "head", "fields": {
					"uid": String(t1[0]), "ip": String(t2[0]),
					"auth": String(t2[1]).lstrip(" ")}, "modified": false})
			in_block = true
		elif in_block and line.begins_with(":A"):
			ad.records.append({"kind": "A", "fields": {
					"rest": line.substr(2)}, "modified": false})
		elif in_block and line == ".":
			ad.records.append({"kind": "term", "fields": {},
					"modified": false})
			in_block = false
		else:
			ad.records.append({"kind": "raw", "fields": {},
					"modified": false})
	return ad


static func load_file(path: String) -> PhiAd:
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


static func _token(s: String) -> Array:
	var t := s.lstrip(" ")
	var sp := t.find(" ")
	if sp < 0:
		return [t, ""]
	return [t.substr(0, sp), t.substr(sp + 1)]


static func build_line(rec: Dictionary) -> String:
	var f: Dictionary = rec.get("fields", {})
	match String(rec["kind"]):
		"head":
			var out := ":" + String(f["uid"]) + " " + String(f["ip"])
			if String(f["auth"]) != "":
				out += " " + String(f["auth"])
			return out
		"A":
			return ":A" + String(f["rest"])
		"term":
			return "."
	return ""

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


## レシピのブロック一覧 (第5段: 1ブロック = 1クリエイト設定)。
## 各ブロックは "." (term) で終わる。末尾に term の無い残りも1ブロック。
## 戻り値: [{"start": int, "end": int}] (end は term を含む最終 index)
func blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start := 0
	for i in records.size():
		if String(records[i]["kind"]) == "term":
			out.append({"start": start, "end": i})
			start = i + 1
	if start < records.size():
		# 末尾の空行だけの残りはレシピではない
		var has_recipe := false
		for i in range(start, records.size()):
			if String(records[i]["kind"]) in ["L", "P", "F", "S"]:
				has_recipe = true
				break
		if has_recipe:
			out.append({"start": start, "end": records.size() - 1})
	return out


## ブロックの見出し (一覧表示用): :L の値と生成物の名前。
func block_summary(b: Dictionary) -> String:
	var lv := ""
	var item := ""
	for i in range(int(b["start"]), int(b["end"]) + 1):
		var kind := String(records[i]["kind"])
		var rest := String(records[i].get("fields", {}).get("rest", ""))
		if kind == "L" and lv == "":
			lv = rest.strip_edges()
		elif kind == "P" and item == "":
			item = rest.strip_edges().substr(0, 24)
		elif kind == "F" and item == "":
			item = "(失敗時) " + rest.strip_edges().substr(0, 20)
	if item == "":
		item = "(生成物なし)"
	return ("Lv%s " % lv if lv != "" else "") + item


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

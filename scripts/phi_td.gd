class_name PhiTd
extends RefCounted
## phi.td (世界設定) のモデル。FORMAT_SPEC §1。
##
## 設計: 行と 1:1 に対応するレコード Dictionary の列として保持する。
## 未編集レコードは元の行バイトをそのまま書き戻し (PhiRawLines)、
## 編集したレコードだけ build_line() の正規形で再生成する。
## ':' で始まらない行・未知のレコードは kind="raw" として保持する
## (サーバの全リーダも無視する行なので、壊さず運ぶのが正しい)。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

const GATE_LABEL_FIELD := 29 ## :G ラベル+空白のバイト幅 (実測の最頻値)
const H_NAME_FIELD := 35 ## :H 世界名+空白のバイト幅 (実世界の全件)


static func parse(raw: PhiRawLines) -> PhiTd:
	var td := PhiTd.new()
	td.raw_lines = raw
	for i in raw.line_count():
		td.records.append(_parse_line(raw.line_text(i)))
	return td


static func load_file(path: String) -> PhiTd:
	var raw := PhiRawLines.load_file(path)
	if raw == null:
		return null
	return parse(raw)


func serialize() -> PackedByteArray:
	for i in records.size():
		if bool(records[i].get("modified", false)):
			raw_lines.set_line_text(i, build_line(records[i]))
	return raw_lines.to_bytes()


## レコードを編集済みとして印を付ける (fields を書き換えた後に呼ぶ)
func touch(rec: Dictionary) -> void:
	rec["modified"] = true


## 行と対応させてレコードを追加し、その番号を返す
func add_record(rec: Dictionary) -> int:
	raw_lines.lines.append(PackedByteArray())
	raw_lines.eols.append("\n".to_utf8_buffer())
	raw_lines.dirty.append(false)
	rec["modified"] = true
	records.append(rec)
	return records.size() - 1


## 行ごとレコードを削除する
func remove_record(idx: int) -> void:
	raw_lines.lines.remove_at(idx)
	raw_lines.eols.remove_at(idx)
	raw_lines.dirty.remove_at(idx)
	records.remove_at(idx)


## 種別で最初のレコードを探す (なければ空 Dictionary)
func find_record(kind: String) -> Dictionary:
	for rec in records:
		if String(rec["kind"]) == kind:
			return rec
	return {}


## 種別で全レコードの番号を返す
func record_indices(kind: String) -> Array[int]:
	var out: Array[int] = []
	for i in records.size():
		if String(records[i]["kind"]) == kind:
			out.append(i)
	return out


static func _rec(kind: String, fields: Dictionary) -> Dictionary:
	return {"kind": kind, "fields": fields, "modified": false}


## 空白区切りの先頭 n トークンを取り、残りを返す
static func _take_tokens(s: String, n: int) -> Array:
	var out: Array = []
	var rest := s
	for k in n:
		rest = rest.lstrip(" ")
		var sp := rest.find(" ")
		if sp < 0:
			out.append(rest)
			rest = ""
		else:
			out.append(rest.substr(0, sp))
			rest = rest.substr(sp + 1)
	out.append(rest)
	return out


## ラベル部の取り出し: 2連続空白で終端 (単一空白は内包可)。
## [ラベル, 残り, ラベル+空白のバイト幅] を返す
static func _take_label(s: String) -> Array:
	var idx := s.find("  ")
	if idx < 0:
		return [s, "", Cp932.encode(s).size()]
	var rest := s.substr(idx)
	var j := 0
	while j < rest.length() and rest[j] == " ":
		j += 1
	var label := s.substr(0, idx)
	return [label, rest.substr(j), Cp932.encode(label).size() + j]


static func _parse_line(line: String) -> Dictionary:
	if line.length() < 2 or line[0] != ":":
		return _rec("raw", {})
	var kind := line[1]
	var body := line.substr(2)
	match kind:
		"N":
			return _rec("N", {"name": body.lstrip(" ")})
		"T":
			return _rec("T", {"tslide": body.lstrip(" ").to_int()})
		"t":
			var p := _take_tokens(body, 1)
			return _rec("t", {"yslide": String(p[0]).to_int(),
					"yname": String(p[1]).lstrip(" ")})
		"O":
			var tokens := body.lstrip(" ").split(" ", false)
			var port := 0
			for ti in tokens.size():
				if tokens[ti] == "O" and ti + 1 < tokens.size():
					port = tokens[ti + 1].to_int()
			return _rec("O", {"tokens": tokens, "port": port})
		"U":
			return _rec("U", {"codes": body.lstrip(" ")})
		"R":
			var s := body.lstrip(" ")
			var xflag := false
			if s.begins_with("X"):
				xflag = true
				s = s.substr(1)
			var rate := s.substr(0, 4).to_int()
			var unit := s.substr(4).lstrip(" ") if s.length() > 4 else ""
			return _rec("R", {"x": xflag, "rate": rate, "unit": unit})
		"M":
			var p := _take_tokens(body, 1)
			return _rec("M", {"rate": String(p[0]).to_int(),
					"spell": String(p[1])})
		"F":
			return _rec("F", {"graphic": body.lstrip(" ")})
		"G", "g":
			var p := _take_tokens(body, 4)
			var lr := _take_label(String(p[4]))
			return _rec(kind, {"x": String(p[0]).to_int(),
					"y": String(p[1]).to_int(),
					"dx": String(p[2]).to_int(), "dy": String(p[3]).to_int(),
					"label": lr[0], "dest": lr[1], "label_width": int(lr[2])})
		"P":
			var num := -1
			var pw := body
			if body.length() > 0 and body[0] != " ":
				num = body.unicode_at(0)
				pw = body.substr(1)
			return _rec("P", {"num": num, "password": pw.lstrip(" ")})
		"H":
			var p := _take_tokens(body, 3)
			var lr := _take_label(String(p[3]))
			var tail := String(lr[1])
			var ip := tail
			var rest := ""
			var sp := tail.find(" ")
			if sp >= 0:
				ip = tail.substr(0, sp)
				rest = tail.substr(sp + 1)
			return _rec("H", {"x": String(p[0]), "y": String(p[1]),
					"flag": String(p[2]), "name": lr[0], "ip": ip,
					"rest": rest, "label_width": int(lr[2])})
		"B":
			return _rec("B", {"pattern": body.lstrip(" ")})
		"b":
			return _rec("b", {"id": body.lstrip(" ")})
	return _rec("raw", {})


## CP932 バイト数で右を空白埋めする
static func _pad_bytes(s: String, width: int) -> String:
	var n := Cp932.encode(s).size()
	var out := s
	while n < width:
		out += " "
		n += 1
	return out


static func build_line(rec: Dictionary) -> String:
	var f: Dictionary = rec["fields"]
	match String(rec["kind"]):
		"N":
			return ":N " + String(f["name"])
		"T":
			return ":T " + str(int(f["tslide"]))
		"t":
			var ys := int(f["yslide"])
			var ys_text := ("+" + str(ys)) if ys > 0 else str(ys)
			return ":t %s %s" % [ys_text, String(f["yname"])]
		"O":
			var tokens: PackedStringArray = f["tokens"]
			return ":O " + " ".join(tokens)
		"U":
			return ":U " + String(f["codes"])
		"R":
			return ":R %s%04d %s" % ["X" if bool(f["x"]) else "",
					int(f["rate"]), String(f["unit"])]
		"M":
			return ":M %d %s" % [int(f["rate"]), String(f["spell"])]
		"F":
			return ":F " + String(f["graphic"])
		"G", "g":
			var label := _pad_bytes(String(f["label"]),
					int(f.get("label_width", GATE_LABEL_FIELD)))
			return ":%s %03d %03d %03d %03d %s%s" % [String(rec["kind"]),
					int(f["x"]), int(f["y"]), int(f["dx"]), int(f["dy"]),
					label, String(f["dest"])]
		"P":
			if int(f["num"]) < 0:
				return ":P " + String(f["password"])
			return ":P" + char(int(f["num"])) + " " + String(f["password"])
		"H":
			var label := _pad_bytes(String(f["name"]),
					int(f.get("label_width", H_NAME_FIELD)))
			var tail := String(f["ip"])
			if String(f["rest"]) != "":
				tail += " " + String(f["rest"])
			return ":H %s %s %s %s%s" % [String(f["x"]), String(f["y"]),
					String(f["flag"]), label, tail]
		"B":
			return ":B " + String(f["pattern"])
		"b":
			return ":b " + String(f["id"])
	return ""

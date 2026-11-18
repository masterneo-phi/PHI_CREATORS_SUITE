class_name PhiEd
extends RefCounted
## phi.ed (敵マスタ) のモデル。FORMAT_SPEC §5。
##
## 1体 = ヘッダ行 + サブレコード行群 + '.' 終端。行と 1:1 の
## レコード列で保持し、ヘッダは15数値フィールドまで分解、
## サブレコードは letter + rest (原文) + 種別ごとの解析値を持つ。
## サーバにライタはなく、原文保持が往復の要。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

const HEADER_KEYS: Array[String] = [
	"nm", "type", "align", "moral", "sp", "flv", "wlv", "mhp", "mmp",
	"gp", "ix", "iy", "d", "st", "et",
]
const HEADER_WIDTHS: Array[int] = [
	2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 3, 2, 2, 2,
]


static func parse(raw: PhiRawLines) -> PhiEd:
	var ed := PhiEd.new()
	ed.raw_lines = raw
	var in_block := false
	for i in raw.line_count():
		var line := raw.line_text(i)
		var is_header := line.begins_with(":") and line.length() > 1
		if not in_block and is_header and line != ".":
			ed.records.append(_parse_header(line))
			in_block = true
		elif in_block and line == ".":
			ed.records.append({"kind": "term", "fields": {},
					"modified": false})
			in_block = false
		elif in_block:
			ed.records.append(_parse_sub(line))
		else:
			ed.records.append({"kind": "raw", "fields": {},
					"modified": false})
	return ed


static func load_file(path: String) -> PhiEd:
	var raw := PhiRawLines.load_file(path)
	if raw == null:
		return null
	return parse(raw)


func serialize() -> PackedByteArray:
	for i in records.size():
		if bool(records[i].get("modified", false)):
			raw_lines.set_line_text(i, build_line(records[i], i))
	return raw_lines.to_bytes()


func touch(rec: Dictionary) -> void:
	rec["modified"] = true


## 体の区切り: [{header: 番号, end: '.' の番号}] を返す
func blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start := -1
	for i in records.size():
		var kind := String(records[i]["kind"])
		if kind == "header":
			start = i
		elif kind == "term" and start >= 0:
			out.append({"header": start, "end": i})
			start = -1
	return out


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


static func _parse_header(line: String) -> Dictionary:
	# 名前は空白2連続か31バイトで終端。数値開始位置をバイトで測る
	var bytes := Cp932.encode(line)
	var name_end := -1
	var i := 1
	while i < bytes.size() - 1 and i < 32:
		if bytes[i] == 0x20 and bytes[i + 1] == 0x20:
			name_end = i
			break
		i += 1
	if name_end < 0:
		name_end = mini(bytes.size(), 32)
	var name := Cp932.decode(bytes.slice(1, name_end)).rstrip(" ")
	# 数値トークンの開始バイト (名前+詰め物の幅として保持する)
	var token_start := name_end
	while token_start < bytes.size() and bytes[token_start] == 0x20:
		token_start += 1
	# 数値トークンの開始 (文字位置)
	var rest := line.substr(name.length() + 1).lstrip(" ")
	var tokens := rest.split(" ", false)
	var f := {"name": name, "name_width": token_start - 1}
	for k in HEADER_KEYS.size():
		f[HEADER_KEYS[k]] = String(tokens[k]) if k < tokens.size() else ""
	return {"kind": "header", "fields": f, "modified": false}


static func _parse_sub(line: String) -> Dictionary:
	if line.begins_with("<"):
		return {"kind": "select", "fields": {"text": line},
				"modified": false}
	if line.length() < 2 or line[0] != ":":
		return {"kind": "raw", "fields": {}, "modified": false}
	var letter := line[1]
	var rest := line.substr(2)
	var f := {"letter": letter, "rest": rest}
	match letter:
		"T", "S":
			var p := _take(rest, 1)
			f["prob"] = p[0]
			var p2 := _take(p[1], 1)
			f["type"] = p2[0]
			f["text"] = p2[1].lstrip(" ")
		"M", "I":
			var p := _take(rest, 1)
			f["prob"] = p[0]
			f["data"] = p[1].lstrip(" ")
		"Z", "C":
			var p := _take(rest, 1)
			f["prob"] = p[0]
		"R":
			var p := _take(rest, 1)
			f["apc"] = p[0]
			var p2 := _take(p[1], 1)
			f["apt"] = p2[0]
			f["tail"] = p2[1].lstrip(" ")
		"O":
			f["options"] = rest.lstrip(" ")
		"G":
			f["graphic"] = rest.lstrip(" ")
		"A":
			f["hex"] = rest.lstrip(" ")
	return {"kind": "sub", "fields": f, "modified": false}


## 先頭トークンを n 個取り、[連結した分, 残り] を返す
static func _take(s: String, n: int) -> Array:
	var out := ""
	var rest := s
	for k in n:
		rest = rest.lstrip(" ")
		var sp := rest.find(" ")
		if sp < 0:
			out = rest if out == "" else out + " " + rest
			rest = ""
			break
		out = rest.substr(0, sp) if out == "" else out + " " + rest.substr(0, sp)
		rest = rest.substr(sp + 1)
	return [out, rest]


static func build_line(rec: Dictionary, _idx: int = -1) -> String:
	var f: Dictionary = rec.get("fields", {})
	match String(rec["kind"]):
		"header":
			var name := String(f["name"])
			var width := int(f.get("name_width", 31))
			var padded := name
			var nb := Cp932.encode(padded).size()
			while nb < width:
				padded += " "
				nb += 1
			var nums: Array = []
			for k in HEADER_KEYS.size():
				var w := HEADER_WIDTHS[k]
				var v := String(f[HEADER_KEYS[k]])
				nums.append(v.lpad(w, "0") if v.is_valid_int() else v)
			return ":" + padded + " ".join(nums)
		"term":
			return "."
		"select":
			return String(f["text"])
		"sub":
			return ":" + String(f["letter"]) + String(f["rest"])
	return ""

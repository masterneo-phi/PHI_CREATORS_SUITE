class_name PhiFd
extends RefCounted
## phi.fd (エリア) のモデル。FORMAT_SPEC §3。
## 格子は2桁16進の生エリアコード。未編集マスは原文2文字を保持。
## 格子の後ろのディレクティブ (:E/:S/:M/:F/:T/.) は行ミラーで保持し、
## :E はエリア定義として分解する (名前欄の幅も保持)。

var size_x := 0
var size_y := 0
var _raw: PackedByteArray = PackedByteArray() ## 2バイト/マス
var _codes: PackedByteArray = PackedByteArray()
var _edited := {}
var force_dirty := false ## 新規作成直後は保存対象にする
var records: Array[Dictionary] = []
var raw_lines: PhiRawLines

const FLAG_NAMES := {
	"R": "Resource禁止", "M": "魔法禁止", "N": "魔法効果禁止",
	"E": "Eagle Eye禁止", "Q": "Return禁止", "T": "ゲート接続禁止",
	"W": "看板書込禁止", "L": "Wizard Lock禁止", "G": "気化禁止",
	"A": "攻撃禁止", "D": "エリア魔法禁止", "X": "ddx許可",
	"C": "チャージ禁止", "O": "Remote Get禁止", "P": "Remote Put禁止",
	"7": "7x7表示禁止",
}


static func create_new(sx: int, sy: int) -> PhiFd:
	var fd := PhiFd.new()
	fd.size_x = sx
	fd.size_y = sy
	fd._raw.resize(sx * sy * 2)
	fd._codes.resize(sx * sy)
	for i in sx * sy:
		fd._raw[i * 2] = 0x30
		fd._raw[i * 2 + 1] = 0x30
	fd.raw_lines = PhiRawLines.from_bytes(
			":E 00 00 New Area\n.\n".to_utf8_buffer())
	fd.records = [_parse_directive(":E 00 00 New Area"),
			{"kind": "term", "fields": {}, "modified": false}]
	return fd


static func parse(data: PackedByteArray, sx: int, sy: int) -> PhiFd:
	var fd := PhiFd.new()
	fd.size_x = sx
	fd.size_y = sy
	fd._raw.resize(sx * sy * 2)
	fd._codes.resize(sx * sy)
	var all := PhiRawLines.from_bytes(data)
	for y in sy:
		var row := PackedByteArray()
		if y < all.line_count():
			row = all.lines[y]
		for x in sx:
			var i := y * sx + x
			var c1 := 0x30
			var c2 := 0x30
			if x * 2 + 1 < row.size():
				c1 = row[x * 2]
				c2 = row[x * 2 + 1]
			fd._raw[i * 2] = c1
			fd._raw[i * 2 + 1] = c2
			fd._codes[i] = _hex2(c1, c2)
	fd.raw_lines = PhiRawLines.new()
	for li in range(sy, all.line_count()):
		fd.raw_lines.lines.append(all.lines[li])
		fd.raw_lines.eols.append(all.eols[li])
		fd.raw_lines.dirty.append(false)
	for i in fd.raw_lines.line_count():
		fd.records.append(_parse_directive(fd.raw_lines.line_text(i)))
	return fd


static func load_file(path: String, sx: int, sy: int) -> PhiFd:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse(data, sx, sy)


static func _hex2(c1: int, c2: int) -> int:
	return _hex1(c1) * 16 + _hex1(c2)


static func _hex1(c: int) -> int:
	if c >= 0x30 and c <= 0x39:
		return c - 0x30
	if c >= 0x61 and c <= 0x66:
		return c - 0x61 + 10
	if c >= 0x41 and c <= 0x46:
		return c - 0x41 + 10
	return 0


static func _parse_directive(line: String) -> Dictionary:
	if line == ".":
		return {"kind": "term", "fields": {}, "modified": false}
	if line.length() >= 2 and line[0] == ":" and line[1] in "ESMFT":
		var letter := line[1]
		if letter == "E":
			var rest := line.substr(2).lstrip(" ")
			var code := rest.substr(0, 2)
			var after_code := rest.substr(2).lstrip(" ")
			var floor_s := after_code.substr(0, 2)
			var tail := after_code.substr(2)
			var name := ""
			var flags := ""
			var width := 0
			var idx := tail.find("  ")
			if idx >= 0:
				name = tail.substr(0, idx).lstrip(" ")
				var j := idx
				while j < tail.length() and tail[j] == " ":
					j += 1
				flags = tail.substr(j)
				width = Cp932.encode(name).size() + (j - idx)
			else:
				name = tail.lstrip(" ")
			return {"kind": "E", "fields": {"code": code,
					"floor": floor_s, "name": name, "flags": flags,
					"name_width": width}, "modified": false}
		return {"kind": letter, "fields": {"rest": line.substr(2)},
				"modified": false}
	return {"kind": "raw", "fields": {}, "modified": false}


static func build_directive(rec: Dictionary) -> String:
	var f: Dictionary = rec.get("fields", {})
	match String(rec["kind"]):
		"term":
			return "."
		"E":
			var name := String(f["name"])
			var width := int(f.get("name_width", 0))
			var nb := Cp932.encode(name).size()
			var padded := name
			while nb < width:
				padded += " "
				nb += 1
			if width == 0:
				padded += "  "
			return ":E %s %s %s%s" % [String(f["code"]), String(f["floor"]),
					padded, String(f["flags"])]
		"S", "M", "F", "T":
			return ":" + String(rec["kind"]) + String(f["rest"])
	return ""


func touch(rec: Dictionary) -> void:
	rec["modified"] = true


func code_at(x: int, y: int) -> int:
	return _codes[y * size_x + x]


func set_cell(x: int, y: int, code: int) -> void:
	var i := y * size_x + x
	_codes[i] = code
	_edited[i] = true


## 使われている生コードの一覧 (昇順)
func used_codes() -> Array[int]:
	var seen := {}
	for c in _codes:
		seen[c] = true
	var out: Array[int] = []
	for k in seen.keys():
		out.append(int(k))
	out.sort()
	return out


## :E レコードをコードで探す (無ければ -1)
func find_e(code: int) -> int:
	var hex := "%02x" % code
	for i in records.size():
		if String(records[i]["kind"]) == "E" \
				and String(records[i]["fields"]["code"]).to_lower() == hex:
			return i
	return -1


func is_dirty() -> bool:
	if force_dirty:
		return true
	if not _edited.is_empty():
		return true
	for rec in records:
		if bool(rec.get("modified", false)):
			return true
	return false


func serialize() -> PackedByteArray:
	var out := PackedByteArray()
	for y in size_y:
		for x in size_x:
			var i := y * size_x + x
			if _edited.has(i):
				var s := "%02x" % _codes[i]
				var b := s.to_ascii_buffer()
				out.append(b[0])
				out.append(b[1])
			else:
				out.append(_raw[i * 2])
				out.append(_raw[i * 2 + 1])
		out.append(0x0A)
	for i in records.size():
		if bool(records[i].get("modified", false)):
			raw_lines.set_line_text(i, build_directive(records[i]))
	out.append_array(raw_lines.to_bytes())
	return out

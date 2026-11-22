class_name PhiDd
extends RefCounted
## phi.dd (マップ地形) のモデル。FORMAT_SPEC §2。
## 1マス = 2文字 (地形文字 + 見た目文字)。未編集マスは原文ペアを
## そのまま保持し、編集したマスだけサーバのライタ正規形で出す。
## 見た目文字は通常は正規ペアの2文字目で、'~' は屋根、
## '1'/'2'/'3' は高さ +1/+2/+3 段、'9' は −1 段 (窪地) の印
## (PHIDM_NEO 拡張)。屋根と高さは1文字を取り合うため排他。
## 格子の後ろの :T 行 (surface) は PhiRawLines で原文保持する。

var size_x := 0
var size_y := 0
var _raw: PackedByteArray = PackedByteArray() ## 2バイト/マス
var _codes: PackedByteArray = PackedByteArray()
var _roof: PackedByteArray = PackedByteArray()
var _height: PackedInt32Array = PackedInt32Array() ## −1〜+3 (段)
var _edited := {}
var force_dirty := false ## 新規作成直後は保存対象にする
var tail: PhiRawLines

## 地形文字 (バイト) → 内部コード
const CHAR_TO_CODE := {
	0x2A: 0x08, 0x6F: 0x01, 0x3A: 0x10, 0x2B: 0x11, 0x5F: 0x12,
	0x78: 0x13, 0x2F: 0x20, 0x2E: 0x40, 0x73: 0x42, 0x5B: 0x7C,
	0x5A: 0x6C, 0x24: 0x79, 0x21: 0x80, 0x61: 0xC2, 0x49: 0xC0,
	0x25: 0xC1, 0x7C: 0xD0, 0x5E: 0xD1, 0x54: 0xDC, 0x3D: 0xDD,
	0x48: 0xEC, 0x7B: 0xED, 0x23: 0xFC, 0x40: 0xFD,
}
## 内部コード → ライタ正規ペア (save_dd の格子用表)
const CODE_TO_PAIR := {
	0x00: "  ", 0x08: "**", 0x01: "o ", 0x10: "::", 0x11: "+:",
	0x12: "__", 0xD1: "^^", 0x13: "xx", 0xC1: "xx", 0x20: "//",
	0x40: "..", 0x41: "..", 0x7C: "[]", 0xED: "[]", 0x79: "$$",
	0xEE: "$$", 0x6C: "ZZ", 0xEF: "ZZ", 0x80: "!!", 0xC2: "a ",
	0xC0: "II", 0xD0: "||", 0xDC: "TT", 0xDD: "==", 0xEC: "HH",
	0xFC: "##", 0xFD: "@@", 0x42: "ss", 0xFF: "??",
}
## コード → 日本語名 (パレット表示用)
const CODE_TO_NAME := {
	0x00: "道", 0x08: "対魔法バリアー", 0x01: "プレート", 0x10: "草",
	0x11: "花", 0x12: "水", 0xD1: "通れない水", 0x13: "サークル",
	0x20: "霧", 0x40: "バリアー(対モンスター)", 0x42: "倉庫",
	0x7C: "ドア", 0x6C: "隠しドア(金属)", 0x79: "隠しドア(煉瓦)",
	0x80: "バリアー(対知的生物)", 0xC2: "バリアー(アストラル以外)",
	0xC0: "鉄格子", 0xD0: "窓", 0xDC: "木", 0xDD: "ガラス",
	0xEC: "金属壁", 0xFC: "煉瓦壁", 0xFD: "岩壁",
}
## パレットに出すコード (ロック形は保存で畳まれるため出さない)
const PALETTE: Array[int] = [
	0x00, 0x10, 0x11, 0x12, 0xD1, 0xDC, 0x01, 0x13, 0x20, 0x42,
	0x7C, 0x6C, 0x79, 0xD0, 0xDD, 0xC0, 0xEC, 0xFC, 0xFD, 0x08,
	0x40, 0x80, 0xC2,
]
## 見た目文字 (バイト) → 高さ (段)。'~' (屋根) とは排他。
const BYTE_TO_HEIGHT := {0x31: 1, 0x32: 2, 0x33: 3, 0x39: -1}
## 高さ (段) → 見た目文字 (バイト)
const HEIGHT_TO_BYTE := {1: 0x31, 2: 0x32, 3: 0x33, -1: 0x39}
## コード → クライアント表示文字 (dd_m57 の潰し)
const CODE_TO_DISP := {
	0x01: "o", 0x10: ":", 0x11: "+", 0x12: "_", 0xD1: "_",
	0x13: "x", 0x20: "/", 0x41: ">", 0x7C: "[", 0xC0: "I",
	0xD0: "|", 0xDD: "=", 0xC1: "%", 0xED: "{", 0xEC: "H",
	0x6C: "H", 0xEF: "H", 0x79: "#", 0xEE: "#", 0xFC: "#",
	0xFD: "@", 0xDC: "T", 0xFF: "?",
}


static func create_new(sx: int, sy: int) -> PhiDd:
	var dd := PhiDd.new()
	dd.size_x = sx
	dd.size_y = sy
	dd._raw.resize(sx * sy * 2)
	dd._codes.resize(sx * sy)
	dd._roof.resize(sx * sy)
	dd._height.resize(sx * sy)
	for y in sy:
		for x in sx:
			var border := x == 0 or y == 0 or x == sx - 1 or y == sy - 1
			var i := y * sx + x
			if border:
				dd._codes[i] = 0xEC
				dd._roof[i] = 1
				dd._raw[i * 2] = 0x48
				dd._raw[i * 2 + 1] = 0x7E
			else:
				dd._raw[i * 2] = 0x20
				dd._raw[i * 2 + 1] = 0x20
	dd.tail = PhiRawLines.from_bytes(PackedByteArray())
	return dd


static func parse(data: PackedByteArray, sx: int, sy: int) -> PhiDd:
	var dd := PhiDd.new()
	dd.size_x = sx
	dd.size_y = sy
	dd._raw.resize(sx * sy * 2)
	dd._codes.resize(sx * sy)
	dd._roof.resize(sx * sy)
	dd._height.resize(sx * sy)
	var all := PhiRawLines.from_bytes(data)
	for y in sy:
		var row := PackedByteArray()
		if y < all.line_count():
			row = all.lines[y]
		for x in sx:
			var i := y * sx + x
			var c1 := 0x48
			var c2 := 0x7E
			if x * 2 + 1 < row.size():
				c1 = row[x * 2]
				c2 = row[x * 2 + 1]
			elif x * 2 < row.size():
				c1 = row[x * 2]
				c2 = 0x20
			dd._raw[i * 2] = c1
			dd._raw[i * 2 + 1] = c2
			dd._codes[i] = int(CHAR_TO_CODE.get(c1, 0))
			dd._roof[i] = 1 if c2 == 0x7E else 0
			dd._height[i] = int(BYTE_TO_HEIGHT.get(c2, 0))
	dd.tail = PhiRawLines.new()
	for li in range(sy, all.line_count()):
		dd.tail.lines.append(all.lines[li])
		dd.tail.eols.append(all.eols[li])
		dd.tail.dirty.append(false)
	return dd


static func load_file(path: String, sx: int, sy: int) -> PhiDd:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse(data, sx, sy)


func code_at(x: int, y: int) -> int:
	return _codes[y * size_x + x]


func roof_at(x: int, y: int) -> bool:
	return _roof[y * size_x + x] == 1


## 高さ (段、−1〜+3)。0 = 印なし。
func height_at(x: int, y: int) -> int:
	return _height[y * size_x + x]


## 地形の変更。高さは保持するが、屋根を付ける場合は
## 1文字を取り合うため高さが落ちる。
func set_cell(x: int, y: int, code: int, roof: bool) -> void:
	var h := height_at(x, y)
	if roof:
		h = 0
	set_cell_full(x, y, code, roof, h)


func set_cell_full(x: int, y: int, code: int, roof: bool, height: int) -> void:
	var i := y * size_x + x
	_codes[i] = code
	_height[i] = clampi(height, -1, 3)
	# 高さと屋根は排他 (高さがある側が印を取る)
	_roof[i] = 1 if roof and height == 0 else 0
	_edited[i] = true


## 高さだけの変更。1バイト目 (地形) は保たれる。
## 高さを付けると屋根は外れる (印が優先)。0 で消去。
func set_height(x: int, y: int, height: int) -> void:
	var i := y * size_x + x
	_height[i] = clampi(height, -1, 3)
	if height != 0:
		_roof[i] = 0
	_edited[i] = true


func is_dirty() -> bool:
	if force_dirty:
		return true
	if not _edited.is_empty():
		return true
	if tail != null:
		for d in tail.dirty:
			if d:
				return true
	return false


func serialize() -> PackedByteArray:
	var out := PackedByteArray()
	for y in size_y:
		for x in size_x:
			var i := y * size_x + x
			if _edited.has(i):
				var pair := String(CODE_TO_PAIR.get(_codes[i], "  "))
				var b := pair.to_ascii_buffer()
				out.append(b[0])
				if _height[i] != 0:
					out.append(int(HEIGHT_TO_BYTE.get(_height[i], b[1])))
				else:
					out.append(0x7E if _roof[i] == 1 else b[1])
			else:
				out.append(_raw[i * 2])
				out.append(_raw[i * 2 + 1])
		out.append(0x0A)
	if tail != null:
		out.append_array(tail.to_bytes())
	return out


## :T 行の一覧 [{line: tail行番号, x, y, pair}]
func t_records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tail == null:
		return out
	for i in tail.line_count():
		var line := tail.line_text(i)
		if line.begins_with(":T ") and line.length() >= 13:
			out.append({"line": i, "x": line.substr(3, 3).to_int(),
					"y": line.substr(7, 3).to_int(),
					"pair": line.substr(11, 2)})
	return out


func set_t_record(line_idx: int, x: int, y: int, pair: String) -> void:
	tail.set_line_text(line_idx, ":T %03d %03d %s" % [x, y, pair])


func add_t_record(x: int, y: int, pair: String) -> void:
	tail.lines.append(Cp932.encode(":T %03d %03d %s" % [x, y, pair]))
	tail.eols.append("\n".to_utf8_buffer())
	tail.dirty.append(true)


func remove_t_record(line_idx: int) -> void:
	tail.lines.remove_at(line_idx)
	tail.eols.remove_at(line_idx)
	tail.dirty.remove_at(line_idx)

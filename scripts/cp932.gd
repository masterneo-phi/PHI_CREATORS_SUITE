class_name Cp932
extends RefCounted
## cp932 と String の変換。仕様書 §1。
##
## 変換表は Python の cp932 コーデックから生成した cp932_table.json を使う
## (tools/gen_cp932_table.py)。Python の errors="replace" と同じ振る舞い:
## 受信で読めないバイトは U+FFFD にし、送信で変換できない文字は "?" 1つにする。
##
## 復号の規則(Python のマルチバイトコーデックと同じ):
## ・1バイトで読めるバイト(ASCII・半角カナ・0x80/0xA0/0xFD〜0xFF)はその文字。
## ・先行バイト(0x81〜0x9F・0xE0〜0xFC)は次バイトと組にして表を引く。
##   組が表に無ければ、先行バイトだけを U+FFFD にし、次バイトは改めて読む。
## ・行末に残った先行バイトは U+FFFD。

const REPLACEMENT := 0xFFFD
const TABLE_PATH := "res://cp932_table.json"

static var _single: Dictionary = {}
static var _double: Dictionary = {}
static var _encode: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	var text := FileAccess.get_file_as_string(TABLE_PATH)
	if text.is_empty():
		push_error("Cp932: 変換表が読めません: " + TABLE_PATH)
		_loaded = true
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Cp932: 変換表の JSON が壊れています")
		_loaded = true
		return
	for key in (parsed as Dictionary).get("single", {}):
		_single[int(key)] = int(parsed["single"][key])
	for key in (parsed as Dictionary).get("double", {}):
		_double[int(key)] = int(parsed["double"][key])
	for key in (parsed as Dictionary).get("encode", {}):
		_encode[int(key)] = int(parsed["encode"][key])
	_loaded = true


static func is_lead_byte(b: int) -> bool:
	return (0x81 <= b and b <= 0x9F) or (0xE0 <= b and b <= 0xFC)


## cp932 のバイト列 → String。読めないバイトは U+FFFD。
static func decode(raw: PackedByteArray) -> String:
	ensure_loaded()
	var utf8 := PackedByteArray()
	var i := 0
	var size := raw.size()
	while i < size:
		var b := raw[i]
		if _single.has(b):
			_append_utf8(utf8, _single[b])
			i += 1
		elif is_lead_byte(b) and i + 1 < size:
			var key := (b << 8) | raw[i + 1]
			if _double.has(key):
				_append_utf8(utf8, _double[key])
				i += 2
			else:
				_append_utf8(utf8, REPLACEMENT)
				i += 1
		else:
			_append_utf8(utf8, REPLACEMENT)
			i += 1
	return utf8.get_string_from_utf8()


## String → cp932 のバイト列。変換できない文字は "?" (0x3F)。
static func encode(text: String) -> PackedByteArray:
	ensure_loaded()
	var out := PackedByteArray()
	for i in text.length():
		var cp := text.unicode_at(i)
		if _encode.has(cp):
			var seq: int = _encode[cp]
			if seq > 0xFF:
				out.append(seq >> 8)
				out.append(seq & 0xFF)
			else:
				out.append(seq)
		else:
			out.append(0x3F)
	return out


static func _append_utf8(out: PackedByteArray, cp: int) -> void:
	if cp < 0x80:
		out.append(cp)
	elif cp < 0x800:
		out.append(0xC0 | (cp >> 6))
		out.append(0x80 | (cp & 0x3F))
	elif cp < 0x10000:
		out.append(0xE0 | (cp >> 12))
		out.append(0x80 | ((cp >> 6) & 0x3F))
		out.append(0x80 | (cp & 0x3F))
	else:
		out.append(0xF0 | (cp >> 18))
		out.append(0x80 | ((cp >> 12) & 0x3F))
		out.append(0x80 | ((cp >> 6) & 0x3F))
		out.append(0x80 | (cp & 0x3F))

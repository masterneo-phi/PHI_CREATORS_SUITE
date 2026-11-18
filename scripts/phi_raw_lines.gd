class_name PhiRawLines
extends RefCounted
## ファイルを「行のバイト列 + 行末バイト」の列として保持する土台。
##
## 実世界の phi.swt には CP932 未割り当ての単独バイト 0x80 を含む
## :A 行がある (FORMAT_SPEC §15)。文字列化して保存し直すと壊れる
## ため、未編集の行は元のバイト列のまま保持し、編集した行だけ
## Cp932.encode で作り直す。これで load→save のバイト一致を守る。

var lines: Array[PackedByteArray] = [] ## 改行を含まない行バイト列
var eols: Array[PackedByteArray] = [] ## 行ごとの行末バイト (通常 "\n")
var dirty: Array[bool] = [] ## 編集済み行 (保存時に encode し直す対象)


static func from_bytes(data: PackedByteArray) -> PhiRawLines:
	var out := PhiRawLines.new()
	var start := 0
	var i := 0
	while i < data.size():
		if data[i] == 0x0A:
			var eol_len := 1
			var content_end := i
			if i > start and data[i - 1] == 0x0D:
				content_end = i - 1
				eol_len = 2
			out.lines.append(data.slice(start, content_end))
			out.eols.append(data.slice(i - eol_len + 1 if eol_len == 1 else content_end, i + 1))
			out.dirty.append(false)
			start = i + 1
		i += 1
	if start < data.size():
		out.lines.append(data.slice(start))
		out.eols.append(PackedByteArray())
		out.dirty.append(false)
	elif start == data.size() and data.size() > 0:
		# 末尾が改行で終わる場合、空の最終行は作らない
		pass
	return out


static func load_file(path: String) -> PhiRawLines:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return from_bytes(f.get_buffer(f.get_length()))


func to_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	for i in lines.size():
		out.append_array(lines[i])
		out.append_array(eols[i])
	return out


func line_count() -> int:
	return lines.size()


## 表示・編集用の復号 (壊れたバイトは U+FFFD になる。保存には使わない)
func line_text(idx: int) -> String:
	return Cp932.decode(lines[idx])


## 行を文字列で置き換える (編集として記録する)
func set_line_text(idx: int, text: String) -> void:
	lines[idx] = Cp932.encode(text)
	dirty[idx] = true


## その行が Cp932 の往復 (decode→encode) でバイト一致するか
func line_is_cp932_clean(idx: int) -> bool:
	return Cp932.encode(Cp932.decode(lines[idx])) == lines[idx]

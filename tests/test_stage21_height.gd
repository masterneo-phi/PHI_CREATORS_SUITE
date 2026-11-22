extends SceneTree
## 第21段: マップの高さ (起伏)。phi.dd の見た目文字 (2バイト目) の
## 印 ('1'=+1段 / '2'=+2段 / '3'=+3段 / '9'=−1段の窪地) について、
## モデルの解釈・原文保持・塗り・消去と、キャンバスの高さペン
## (Undo/Redo・右クリック吸い取り) を検証する。

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


## 8x8 の dd バイト列。1行目 (y=1) に印の見本を並べる:
## ::(無印) :1 :2 :3 :9 +:(花) H~(屋根) ::
func _fixture() -> PackedByteArray:
	var rows: Array[String] = []
	var top := ""
	for i in 8:
		top += "HH"
	rows.append(top)
	rows.append("::" + ":1" + ":2" + ":3" + ":9" + "+:" + "H~" + "::")
	for r in 6:
		var row := ""
		for i in 8:
			row += "::"
		rows.append(row)
	var data := PackedByteArray()
	for row in rows:
		data.append_array(row.to_ascii_buffer())
		data.append(0x0A)
	return data


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var data := _fixture()
	var dd := PhiDd.parse(data, 8, 8)
	_check(dd != null, "parse")
	# --- 解釈 (y=1 の並び: :: :1 :2 :3 :9 +: H~ ::) ---
	_check(dd.height_at(0, 1) == 0, "plain :: height 0")
	_check(dd.height_at(1, 1) == 1, ":1 -> +1")
	_check(dd.height_at(2, 1) == 2, ":2 -> +2")
	_check(dd.height_at(3, 1) == 3, ":3 -> +3")
	_check(dd.height_at(4, 1) == -1, ":9 -> -1 (hollow)")
	_check(dd.height_at(5, 1) == 0, "+: height 0")
	_check(dd.code_at(5, 1) == 0x11, "+: is flower")
	_check(dd.code_at(1, 1) == 0x10, ":1 keeps grass code")
	_check(dd.roof_at(6, 1), "H~ is roofed")
	_check(dd.height_at(6, 1) == 0, "H~ height 0")
	# --- 無編集往復はバイト同一 (印も原文保持) ---
	_check(dd.serialize() == data, "untouched round trip with markers")
	_check(not dd.is_dirty(), "not dirty after parse")
	# --- 高さを塗る: 1バイト目を保って印だけ変わる ---
	dd.set_height(0, 1, 2)
	var lines := PhiRawLines.from_bytes(dd.serialize())
	_check(lines.line_text(1).substr(0, 2) == ":2", "paint +2 writes :2")
	_check(dd.code_at(0, 1) == 0x10, "paint height keeps terrain")
	# --- 消去: 正規ペアに戻る ---
	dd.set_height(1, 1, 0)
	lines = PhiRawLines.from_bytes(dd.serialize())
	_check(lines.line_text(1).substr(2, 2) == "::", "erase restores ::")
	# --- 屋根のあるマスに高さ: 印が優先され屋根が外れる ---
	dd.set_height(6, 1, 1)
	_check(not dd.roof_at(6, 1), "height on roofed cell drops roof")
	lines = PhiRawLines.from_bytes(dd.serialize())
	_check(lines.line_text(1).substr(12, 2) == "H1", "roofed cell becomes H1")
	# --- 地形ペンは高さを保持する ---
	dd.set_cell(2, 1, 0x12, false) # ":2" (高さ+2) を水にする
	_check(dd.height_at(2, 1) == 2, "terrain paint keeps height")
	lines = PhiRawLines.from_bytes(dd.serialize())
	_check(lines.line_text(1).substr(4, 2) == "_2", "water with height is _2")
	# --- 屋根を付ける地形変更では高さが落ちる ---
	dd.set_cell(3, 1, 0x10, true) # ":3" (高さ+3) に屋根付きで草を塗る
	_check(dd.height_at(3, 1) == 0, "roofed terrain paint drops height")
	lines = PhiRawLines.from_bytes(dd.serialize())
	_check(lines.line_text(1).substr(6, 2) == ":~", "roofed grass is :~")

	# --- キャンバス: 高さペンと Undo/Redo ---
	var dd2 := PhiDd.parse(data, 8, 8)
	var canvas := MapCanvas.new()
	canvas.dd = dd2
	root.add_child(canvas)
	canvas.mode = "height"
	canvas.pen_height = 3
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(0, 1))
	canvas.call("_end_stroke")
	_check(dd2.height_at(0, 1) == 3, "height pen paints +3")
	canvas.undo()
	_check(dd2.height_at(0, 1) == 0, "height paint undone")
	canvas.redo()
	_check(dd2.height_at(0, 1) == 3, "height paint redone")
	canvas.undo()
	canvas.pen_height = -1
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(6, 6))
	canvas.call("_end_stroke")
	_check(dd2.height_at(6, 6) == -1, "height pen paints -1")
	var l2 := PhiRawLines.from_bytes(dd2.serialize())
	_check(l2.line_text(6).substr(12, 2) == ":9", "hollow written as :9")
	canvas.pen_height = 0
	canvas.call("_begin_stroke")
	canvas.call("_apply", Vector2i(3, 1))
	canvas.call("_end_stroke")
	_check(dd2.height_at(3, 1) == 0, "height pen erases")
	var l3 := PhiRawLines.from_bytes(dd2.serialize())
	_check(l3.line_text(1).substr(6, 2) == "::", "erased cell back to ::")
	# 右クリック吸い取り (高さモードでは段数を拾う)
	canvas.call("_pick", Vector2i(2, 1))
	_check(canvas.pen_height == 2, "pick reads height")

	print("stage21 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)

class_name MapCanvas
extends Control
## マップ描画キャンバス (phi.dd 地形 + phi.fd エリア + phi.od 配置)。
## チップシートがあれば実グラフィック、無ければ色+ペア文字で描く。

signal hover_changed(x: int, y: int)
signal object_picked(rec_idx: int)
signal painted
signal coord_picked(x: int, y: int)
signal pick_cancelled
signal offset_changed

var dd: PhiDd
var fd: PhiFd
var od: PhiOd
var chip_tex: Texture2D
var show_area := false
var show_objects := true
## 座標指定モード (他エディタからマップで座標を選ばせる)
var pick_mode := false
## 出現位置 (phi.ed) とスイッチ位置 (phi.swt) のマーカー。
## 各要素は {x, y, label}。switch_targets は動作位置 (ax, ay)。
var show_spawns := true
var show_switches := true
var spawn_points: Array = []
var switch_points: Array = []
var switch_targets: Array = []
## 選択中エリアの強調表示 (-1 = なし)
var highlight_area := -1
var mode := "terrain" ## terrain / fill / surface / area / object
var pen_code := 0xFC
var pen_roof := false
var pen_area := 0
var cell_px := 16
var offset := Vector2.ZERO ## 左上に表示するマス (小数可)
var selected_object := -1

var _hover := Vector2i(-1, -1)
var _painting := false
var _panning := false
var _pan_start := Vector2.ZERO
var _offset_start := Vector2.ZERO
var _drag_obj := -1

const CHIP_BYTE_TO_INDEX := {
	0x20: [0], 0x3A: [1], 0x2B: [2], 0x54: [1, 3], 0x5F: [4],
	0x6F: [5], 0x40: [6], 0x23: [7], 0x48: [8], 0x49: [9],
	0x3D: [10], 0x5B: [11], 0x7B: [12], 0x7C: [13], 0x78: [14],
	0x25: [15], 0x2F: [16], 0x3E: [17], 0x3F: [31], 0x73: [0],
}
const FALLBACK_COLORS := {
	0x00: Color(0.24, 0.22, 0.19), 0x10: Color(0.30, 0.45, 0.20),
	0x11: Color(0.38, 0.52, 0.24), 0x12: Color(0.16, 0.35, 0.62),
	0xD1: Color(0.10, 0.22, 0.45), 0xDC: Color(0.16, 0.32, 0.14),
	0xEC: Color(0.45, 0.45, 0.50), 0xFC: Color(0.52, 0.30, 0.22),
	0xFD: Color(0.35, 0.30, 0.28), 0x7C: Color(0.55, 0.40, 0.25),
	0xD0: Color(0.65, 0.70, 0.75), 0xDD: Color(0.60, 0.68, 0.72),
	0xC0: Color(0.40, 0.40, 0.44), 0x20: Color(0.55, 0.55, 0.55),
	0x40: Color(0.24, 0.22, 0.19), 0x80: Color(0.24, 0.22, 0.19),
	0xC2: Color(0.24, 0.22, 0.19), 0x08: Color(0.35, 0.20, 0.45),
	0x42: Color(0.45, 0.35, 0.20), 0x13: Color(0.50, 0.45, 0.30),
	0x01: Color(0.45, 0.40, 0.30), 0x6C: Color(0.45, 0.45, 0.50),
	0x79: Color(0.52, 0.30, 0.22),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # 拡大時もドットを保つ


func cell_at_pos(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell_px + offset.x),
			floori(p.y / cell_px + offset.y))


func _cell_rect(cx: int, cy: int) -> Rect2:
	return Rect2((cx - offset.x) * cell_px, (cy - offset.y) * cell_px,
			cell_px, cell_px)


## 表示範囲がマップの端を越えないよう offset を締める (第6段)。
func clamp_offset() -> void:
	if dd == null:
		return
	var vis_x := size.x / float(cell_px)
	var vis_y := size.y / float(cell_px)
	offset.x = clampf(offset.x, 0.0, maxf(0.0, dd.size_x - vis_x))
	offset.y = clampf(offset.y, 0.0, maxf(0.0, dd.size_y - vis_y))


func _draw() -> void:
	if dd == null:
		return
	clamp_offset()
	var font := get_theme_default_font()
	# マップ全体の輪郭 (余白枠の中で範囲が分かるように)
	var extent := Rect2(Vector2(-offset.x, -offset.y) * cell_px,
			Vector2(dd.size_x, dd.size_y) * cell_px)
	draw_rect(extent, Color(0.9, 0.9, 0.95, 0.85), false, 2.5)
	var x0 := maxi(0, floori(offset.x))
	var y0 := maxi(0, floori(offset.y))
	var x1 := mini(dd.size_x - 1, x0 + ceili(size.x / cell_px) + 1)
	var y1 := mini(dd.size_y - 1, y0 + ceili(size.y / cell_px) + 1)
	var surfaces := {}
	if dd.tail != null:
		for t in dd.t_records():
			surfaces[Vector2i(int(t["x"]), int(t["y"]))] = String(t["pair"])
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var rect := _cell_rect(cx, cy)
			var code := dd.code_at(cx, cy)
			_draw_terrain(rect, code, dd.roof_at(cx, cy), font)
			if surfaces.has(Vector2i(cx, cy)):
				draw_rect(Rect2(rect.position + Vector2(1, 1),
						rect.size - Vector2(2, 2)), Color(0.2, 0.9, 0.9),
						false, 1.5)
			if show_area and fd != null:
				var ac := fd.code_at(cx, cy)
				var col := Color.from_hsv(fmod(ac * 0.618, 1.0), 0.55, 0.9, 0.35)
				draw_rect(rect, col)
				if cell_px >= 16:
					draw_string(font, rect.position + Vector2(2, 13),
							"%02x" % ac, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
							Color(1, 1, 1, 0.9))
			if highlight_area >= 0 and fd != null \
					and fd.code_at(cx, cy) == highlight_area:
				draw_rect(rect, Color(1.0, 0.95, 0.35, 0.38))
				draw_rect(rect, Color(1.0, 0.9, 0.2, 0.9), false, 1.5)
			draw_rect(rect, Color(0, 0, 0, 0.18), false, 1.0)
	if show_objects and od != null:
		for i in od.records.size():
			var rec := od.records[i]
			if String(rec["kind"]) != "O":
				continue
			var f: Dictionary = rec["fields"]
			var ox := int(f["x"])
			var oy := int(f["y"])
			if ox < x0 or ox > x1 or oy < y0 or oy > y1 or ox < 0:
				continue
			var rect := _cell_rect(ox, oy)
			var center := rect.get_center()
			var r := cell_px * 0.36
			var pts := PackedVector2Array([
					center + Vector2(0, -r), center + Vector2(r, 0),
					center + Vector2(0, r), center + Vector2(-r, 0)])
			draw_colored_polygon(pts, Color(1.0, 0.62, 0.15, 0.92))
			if i == selected_object:
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2],
						pts[3], pts[0]]), Color.WHITE, 2.0)
			if cell_px >= 24:
				draw_string(font, rect.position + Vector2(1, cell_px - 3),
						String(f["gname"]).substr(0, 4),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	if show_spawns:
		for p in spawn_points:
			_draw_point_mark(int(p["x"]), int(p["y"]), x0, x1, y0, y1,
					Color(1.0, 0.25, 0.3, 0.95), String(p.get("label", "")),
					font, true)
	if show_switches:
		for p in switch_points:
			_draw_point_mark(int(p["x"]), int(p["y"]), x0, x1, y0, y1,
					Color(0.25, 0.85, 1.0, 0.95), String(p.get("label", "")),
					font, false)
		for p in switch_targets:
			var tx := int(p["x"])
			var ty := int(p["y"])
			if tx < x0 or tx > x1 or ty < y0 or ty > y1:
				continue
			var rect := _cell_rect(tx, ty)
			draw_circle(rect.get_center(), maxf(2.0, cell_px * 0.14),
					Color(0.25, 0.85, 1.0, 0.8))
	if _hover.x >= 0:
		if pick_mode:
			draw_rect(_cell_rect(_hover.x, _hover.y), Color(1, 0.3, 1, 0.95),
					false, 2.5)
		else:
			draw_rect(_cell_rect(_hover.x, _hover.y), Color(1, 1, 1, 0.85),
					false, 1.5)


## 座標マーカー (出現位置=赤い菱形、スイッチ=水色の四角)。
func _draw_point_mark(px: int, py: int, x0: int, x1: int, y0: int, y1: int,
		col: Color, label: String, font: Font, diamond: bool) -> void:
	if px < x0 or px > x1 or py < y0 or py > y1:
		return
	var rect := _cell_rect(px, py)
	var center := rect.get_center()
	var r := cell_px * 0.38
	var pts: PackedVector2Array
	if diamond:
		pts = PackedVector2Array([center + Vector2(0, -r),
				center + Vector2(r, 0), center + Vector2(0, r),
				center + Vector2(-r, 0), center + Vector2(0, -r)])
	else:
		pts = PackedVector2Array([
				center + Vector2(-r, -r), center + Vector2(r, -r),
				center + Vector2(r, r), center + Vector2(-r, r),
				center + Vector2(-r, -r)])
	draw_polyline(pts, col, 2.0)
	if cell_px >= 24 and label != "":
		draw_string(font, rect.position + Vector2(1, 11), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


func _draw_terrain(rect: Rect2, code: int, roof: bool, font: Font) -> void:
	var disp := String(PhiDd.CODE_TO_DISP.get(code, " "))
	var byte := disp.unicode_at(0) if disp != "" else 0x20
	var indices: Array = CHIP_BYTE_TO_INDEX.get(byte, [0])
	if chip_tex != null:
		for k in indices.size():
			var idx := int(indices[k])
			var src := Rect2((idx % 16) * 32, (idx / 16) * 48, 32, 48)
			var dst := Rect2(rect.position + Vector2(0, -cell_px * 0.5),
					Vector2(cell_px, cell_px * 1.5))
			if k == 0:
				dst = Rect2(rect.position, rect.size)
				src = Rect2(src.position + Vector2(0, 16), Vector2(32, 32))
			draw_texture_rect_region(chip_tex, dst, src)
	else:
		draw_rect(rect, FALLBACK_COLORS.get(code, Color(0.3, 0.3, 0.3)))
		if cell_px >= 16:
			var pair := String(PhiDd.CODE_TO_PAIR.get(code, "  "))
			draw_string(font, rect.position + Vector2(3, cell_px - 4), pair,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	if roof:
		draw_circle(rect.position + Vector2(cell_px - 4, 4), 3.0,
				Color(1, 0.9, 0.3, 0.95))


func _gui_input(event: InputEvent) -> void:
	if dd == null:
		return
	if pick_mode and event is InputEventMouseButton:
		var mb2 := event as InputEventMouseButton
		if mb2.button_index == MOUSE_BUTTON_LEFT and mb2.pressed:
			var c := cell_at_pos(mb2.position)
			if c.x >= 0 and c.y >= 0 and c.x < dd.size_x and c.y < dd.size_y:
				coord_picked.emit(c.x, c.y)
			return
		if mb2.button_index == MOUSE_BUTTON_RIGHT and mb2.pressed:
			pick_cancelled.emit()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			offset.y -= 3
			clamp_offset()
			offset_changed.emit()
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			offset.y += 3
			clamp_offset()
			offset_changed.emit()
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_pan_start = mb.position
			_offset_start = offset
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_pick(cell_at_pos(mb.position))
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				_apply(cell_at_pos(mb.position))
				_painting = mode in ["terrain", "area", "surface"]
			else:
				_painting = false
				_drag_obj = -1
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			offset = _offset_start - (mm.position - _pan_start) / cell_px
			clamp_offset()
			offset_changed.emit()
			queue_redraw()
			return
		var c := cell_at_pos(mm.position)
		if c != _hover and c.x >= 0 and c.y >= 0 \
				and c.x < dd.size_x and c.y < dd.size_y:
			_hover = c
			hover_changed.emit(c.x, c.y)
			queue_redraw()
		if _painting:
			_apply(c)
		elif _drag_obj >= 0:
			_move_drag_obj(c)


func _pick(c: Vector2i) -> void:
	if c.x < 0 or c.y < 0 or c.x >= dd.size_x or c.y >= dd.size_y:
		return
	if mode == "area" and fd != null:
		pen_area = fd.code_at(c.x, c.y)
	else:
		pen_code = dd.code_at(c.x, c.y)
		pen_roof = dd.roof_at(c.x, c.y)
	painted.emit()
	queue_redraw()


func _apply(c: Vector2i) -> void:
	if c.x < 0 or c.y < 0 or c.x >= dd.size_x or c.y >= dd.size_y:
		return
	match mode:
		"terrain":
			dd.set_cell(c.x, c.y, pen_code, pen_roof)
		"fill":
			_fill(c, dd.code_at(c.x, c.y))
		"area":
			if fd != null:
				fd.set_cell(c.x, c.y, pen_area)
		"surface":
			_paint_surface(c)
		"object":
			var idx := _object_at(c)
			selected_object = idx
			_drag_obj = idx
			object_picked.emit(idx)
	painted.emit()
	queue_redraw()


func _fill(c: Vector2i, from_code: int) -> void:
	if from_code == pen_code:
		return
	var stack: Array[Vector2i] = [c]
	var seen := {}
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p) or p.x < 0 or p.y < 0 or p.x >= dd.size_x \
				or p.y >= dd.size_y:
			continue
		seen[p] = true
		if dd.code_at(p.x, p.y) != from_code:
			continue
		dd.set_cell(p.x, p.y, pen_code, pen_roof)
		stack.append_array([p + Vector2i(1, 0), p + Vector2i(-1, 0),
				p + Vector2i(0, 1), p + Vector2i(0, -1)])


func _paint_surface(c: Vector2i) -> void:
	var pair := String(PhiDd.CODE_TO_PAIR.get(pen_code, "  "))
	for t in dd.t_records():
		if int(t["x"]) == c.x and int(t["y"]) == c.y:
			dd.set_t_record(int(t["line"]), c.x, c.y, pair)
			return
	dd.add_t_record(c.x, c.y, pair)


func _object_at(c: Vector2i) -> int:
	if od == null:
		return -1
	for i in od.records.size():
		var rec := od.records[i]
		if String(rec["kind"]) != "O":
			continue
		if int(rec["fields"]["x"]) == c.x and int(rec["fields"]["y"]) == c.y:
			return i
	return -1


func _move_drag_obj(c: Vector2i) -> void:
	if od == null or _drag_obj < 0:
		return
	if c.x < 0 or c.y < 0 or c.x >= dd.size_x or c.y >= dd.size_y:
		return
	var rec := od.records[_drag_obj]
	rec["fields"]["x"] = c.x
	rec["fields"]["y"] = c.y
	od.touch(rec)
	object_picked.emit(_drag_obj)
	queue_redraw()

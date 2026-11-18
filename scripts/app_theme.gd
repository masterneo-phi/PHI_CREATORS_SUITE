class_name AppTheme
extends RefCounted
## アプリ全体のテーマ (第5段)。NeoPHI 並みの文字サイズにし、
## 上部バーを青、ボタンをシルバーにして色を付ける。

const FONT_SIZE := 18
const BAR_BLUE := Color(0.13, 0.30, 0.62)
const SILVER := Color(0.78, 0.79, 0.83)
const SILVER_HOVER := Color(0.88, 0.89, 0.92)
const SILVER_PRESSED := Color(0.62, 0.63, 0.68)
const INK := Color(0.10, 0.10, 0.12)
const GOLD := Color(0.98, 0.80, 0.35)


static func _flat(bg: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


static func bar_style() -> StyleBoxFlat:
	return _flat(BAR_BLUE)


static func build() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans JP", "Noto Sans CJK JP", "Segoe UI", "BIZ UDPGothic",
		"Hiragino Sans", "Yu Gothic", "Meiryo", "sans-serif"])
	t.default_font = font
	t.default_font_size = FONT_SIZE
	# ボタンはシルバー地に黒文字
	t.set_stylebox("normal", "Button", _flat(SILVER))
	t.set_stylebox("hover", "Button", _flat(SILVER_HOVER))
	t.set_stylebox("pressed", "Button", _flat(SILVER_PRESSED))
	t.set_stylebox("disabled", "Button", _flat(Color(0.45, 0.45, 0.48)))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), GOLD))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.25, 0.25, 0.27))
	t.set_font_size("font_size", "Button", FONT_SIZE)
	# 入力部品の文字も大きく
	for cls in ["LineEdit", "TextEdit", "SpinBox", "OptionButton",
			"CheckBox", "ItemList", "Tree", "Label", "TabBar"]:
		t.set_font_size("font_size", cls, FONT_SIZE)
	t.set_constant("item_height", "ItemList", 30)
	t.set_constant("v_separation", "ItemList", 4)
	# 選択中をはっきりさせる
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_stylebox("selected", "ItemList", _flat(BAR_BLUE))
	t.set_stylebox("selected_focus", "ItemList", _flat(BAR_BLUE))
	# チェックボックスは Button のシルバー地を継ぐので文字は濃色
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	return t

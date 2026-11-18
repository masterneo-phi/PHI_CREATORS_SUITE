class_name AppTheme
extends RefCounted
## アプリ全体のテーマ (第5段、第6段で 1.5 倍に拡大)。
## 上部バーを青、ボタンをシルバーにして色を付ける。

const FONT_SIZE := 27
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
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.set_corner_radius_all(5)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func style(bg: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	return _flat(bg, border)


static func bar_style() -> StyleBoxFlat:
	return _flat(BAR_BLUE)


static func _svg_icon(svg: String) -> ImageTexture:
	var img := Image.new()
	img.load_svg_from_string(svg)
	return ImageTexture.create_from_image(img)


static func _check_icons() -> Dictionary:
	var unchecked := _svg_icon(
		'<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36">'
		+ '<rect x="3" y="3" width="30" height="30" rx="6" fill="#d8d9de" stroke="#5a5b63" stroke-width="3"/></svg>')
	var checked := _svg_icon(
		'<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36">'
		+ '<rect x="3" y="3" width="30" height="30" rx="6" fill="#21509e" stroke="#122c57" stroke-width="3"/>'
		+ '<path d="M10 19 L16 25 L27 11" fill="none" stroke="#ffffff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></svg>')
	return {"checked": checked, "unchecked": unchecked}


## 基準サイズ (27) 前提で書かれた相対フォントサイズを、
## そのコントロールの現在のテーマ既定サイズに合わせて換算する
static func rel(control: Control, orig: int) -> int:
	var base := control.get_theme_default_font_size()
	if base <= 0:
		base = FONT_SIZE
	return maxi(10, int(round(orig * float(base) / 27.0)))


static func build(font_size: int = FONT_SIZE) -> Theme:
	font_size = clampi(font_size, 10, 60)
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans JP", "Noto Sans CJK JP", "Segoe UI", "BIZ UDPGothic",
		"Hiragino Sans", "Yu Gothic", "Meiryo", "sans-serif"])
	t.default_font = font
	t.default_font_size = font_size
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
	t.set_font_size("font_size", "Button", font_size)
	# 入力部品の文字も大きく
	for cls in ["LineEdit", "TextEdit", "SpinBox", "OptionButton",
			"CheckBox", "ItemList", "Tree", "Label", "TabBar"]:
		t.set_font_size("font_size", cls, font_size)
	t.set_constant("item_height", "ItemList",
			maxi(28, int(round(46.0 * font_size / 27.0))))
	t.set_constant("v_separation", "ItemList", 6)
	# 選択中をはっきりさせる
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_stylebox("selected", "ItemList", _flat(BAR_BLUE))
	t.set_stylebox("selected_focus", "ItemList", _flat(BAR_BLUE))
	# チェックボックスは大きな専用アイコン + 濃色文字 (シルバー地のため)
	var icons := _check_icons()
	t.set_icon("checked", "CheckBox", icons["checked"])
	t.set_icon("unchecked", "CheckBox", icons["unchecked"])
	t.set_icon("checked_disabled", "CheckBox", icons["checked"])
	t.set_icon("unchecked_disabled", "CheckBox", icons["unchecked"])
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	# プルダウンの矢印とスピンボタンの三角も大きく
	t.set_icon("arrow", "OptionButton", _svg_icon(
		'<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30">'
		+ '<path d="M6 11 L15 21 L24 11 Z" fill="#1a1a1e"/></svg>'))
	t.set_icon("up", "SpinBox", _svg_icon(
		'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
		+ '<path d="M5 15 L12 7 L19 15 Z" fill="#1a1a1e"/></svg>'))
	t.set_icon("down", "SpinBox", _svg_icon(
		'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
		+ '<path d="M5 9 L12 17 L19 9 Z" fill="#1a1a1e"/></svg>'))
	return t

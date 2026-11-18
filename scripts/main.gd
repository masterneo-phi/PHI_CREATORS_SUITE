extends Control
## PHI CREATORS SUITE のシェル: world を開き、エディタを切り替え、
## まとめて保存する。

const TdEditor := preload("res://scripts/td_editor.gd")
const AnnounceEditor := preload("res://scripts/announce_editor.gd")
const SwtEditor := preload("res://scripts/swt_editor.gd")
const EdEditor := preload("res://scripts/ed_editor.gd")
const OdEditor := preload("res://scripts/od_editor.gd")
const ExEditor := preload("res://scripts/ex_editor.gd")
const CrtEditor := preload("res://scripts/crt_editor.gd")
const AdEditor := preload("res://scripts/ad_editor.gd")
const MapEditor := preload("res://scripts/map_editor.gd")

const EDITORS: Array[Dictionary] = [
	{"name": "世界設定 (phi.td)", "scene": "td"},
	{"name": "アナウンス (phi.bb/inf)", "scene": "announce"},
	{"name": "マップ (phi.dd / phi.fd)", "scene": "map"},
	{"name": "スイッチ (phi.swt)", "scene": "swt"},
	{"name": "オブジェクト (phi.od)", "scene": "od"},
	{"name": "エネミー (phi.ed)", "scene": "ed"},
	{"name": "クリエイト (phi.crt)", "scene": "crt"},
	{"name": "ゲート制限 (phi.ex)", "scene": "ex"},
	{"name": "マスター権限 (phi.ad)", "scene": "ad"},
]

var _project: WorldProject
var _path_label: Label
var _status_label: Label
var _editor_list: ItemList
var _host: MarginContainer
var _editors := {}
var _save_btn: Button
var _pick_handler: Callable
var _pick_return_idx := -1
var _pick_switching := false
var _current_idx := 0
var _autosave_check: CheckBox
var _autosave_timer: Timer
var _about_overlay: Control = null
var _update_http: HTTPRequest = null
var _update_busy := false
var _update_manual := false
var _update_retried := false
var _update_info: Dictionary = {}
var _update_overlay: Control = null
var _update_label: Label = null


func _ready() -> void:
	add_to_group("creators_main")
	theme = AppTheme.build()
	_setup_global_menu()
	_setup_global_menu.call_deferred()
	_start_auto_update_check()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", AppTheme.bar_style())
	root.add_child(bar_panel)
	var bar := HBoxContainer.new()
	bar_panel.add_child(bar)
	var open_btn := Button.new()
	open_btn.text = "既存の world を開く"
	open_btn.pressed.connect(_on_open_pressed)
	bar.add_child(open_btn)
	var new_btn := Button.new()
	new_btn.text = "新しい world を作る"
	new_btn.pressed.connect(_on_new_pressed)
	bar.add_child(new_btn)
	_save_btn = Button.new()
	_save_btn.text = "保存"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	bar.add_child(_save_btn)
	_autosave_check = CheckBox.new()
	_autosave_check.text = "自動保存 (60秒ごと)"
	_autosave_check.toggled.connect(_on_autosave_toggled)
	bar.add_child(_autosave_check)
	var about_btn := Button.new()
	about_btn.text = "バージョン情報"
	about_btn.pressed.connect(_show_about)
	bar.add_child(about_btn)
	var update_btn := Button.new()
	update_btn.text = "更新を確認"
	update_btn.pressed.connect(func() -> void: _check_update(true))
	bar.add_child(update_btn)
	_path_label = Label.new()
	_path_label.text = "(未選択)"
	_path_label.clip_text = true
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_path_label)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color",
			Color(1.0, 0.95, 0.75))
	bar.add_child(_status_label)
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 60.0
	_autosave_timer.timeout.connect(_on_autosave_tick)
	add_child(_autosave_timer)
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	_autosave_check.button_pressed = bool(cfg.get_value("save", "auto", false))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	_editor_list = ItemList.new()
	_editor_list.custom_minimum_size = Vector2(315, 0)
	for e in EDITORS:
		_editor_list.add_item(String(e["name"]))
	_editor_list.item_selected.connect(_on_editor_selected)
	split.add_child(_editor_list)
	_host = MarginContainer.new()
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_host)
	var hint := Label.new()
	hint.text = "「既存の world を開く」で、サーバの world フォルダ (phi.td のある場所) を\n選んでください。そのまま読み込んで編集を始められます。\n無いファイル (phi.crt 等) は各エディタで新規作成できます。"
	_host.add_child(hint)
	# 前回の world が残っていれば、読み込んで開始する
	var last := _last_world_dir()
	if not last.is_empty() and FileAccess.file_exists(last.path_join("phi.td")):
		open_world(last)


func _last_world_dir() -> String:
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	return String(cfg.get_value("world", "dir", ""))


func _remember_world(dir: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("world", "dir", dir)
	cfg.save("user://creators.cfg")


func _on_open_pressed() -> void:
	var dlg := FileDialog.new()
	dlg.transparent = true # Mac で黒く潰れないように (NeoPHI の教訓)
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = "既存の world フォルダを選択 (phi.td のある場所)"
	var last := _last_world_dir()
	if not last.is_empty() and DirAccess.open(last) != null:
		dlg.current_dir = last
	dlg.dir_selected.connect(open_world)
	add_child(dlg)
	dlg.popup_centered(Vector2i(900, 600))


func _on_new_pressed() -> void:
	var dlg := FileDialog.new()
	dlg.transparent = true # Mac で黒く潰れないように (NeoPHI の教訓)
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = "新しい world を作る空のフォルダを選択"
	dlg.dir_selected.connect(_create_world)
	add_child(dlg)
	dlg.popup_centered(Vector2i(900, 600))


## 最小の phi.td を置いて新しい world にする。名前・ポートは
## 世界設定エディタで後から変えられる。
func _create_world(dir: String) -> void:
	Cp932.ensure_loaded()
	var td_path := dir.path_join("phi.td")
	if FileAccess.file_exists(td_path):
		_status_label.text = "phi.td が既にあります。「既存の world を開く」を使ってください"
		return
	var f := FileAccess.open(td_path, FileAccess.WRITE)
	if f == null:
		_status_label.text = "phi.td が作れませんでした"
		return
	f.store_buffer(Cp932.encode(":N New World\n:T 0\n:O O 20099 A 001 001 MSGT\n.\n"))
	f.close()
	open_world(dir)


func open_world(dir: String) -> void:
	var p := WorldProject.new()
	Cp932.ensure_loaded()
	if not p.open(dir):
		_status_label.text = "phi.td が開けませんでした"
		return
	_project = p
	_path_label.text = dir
	_save_btn.disabled = false
	_status_label.text = "開きました"
	_remember_world(dir)
	for child in _host.get_children():
		child.queue_free()
	_editors.clear()
	_editor_list.select(0)
	_on_editor_selected(0)


func _on_editor_selected(idx: int) -> void:
	if _project == null:
		return
	_current_idx = idx
	var key := String(EDITORS[idx]["scene"])
	for child in _host.get_children():
		_host.remove_child(child)
	if key == "":
		var l := Label.new()
		l.text = "このエディタはまだありません"
		_host.add_child(l)
		return
	if not _editors.has(key):
		var ed: Control
		match key:
			"td":
				ed = TdEditor.new()
			"announce":
				ed = AnnounceEditor.new()
			"swt":
				ed = SwtEditor.new()
			"ed":
				ed = EdEditor.new()
			"od":
				ed = OdEditor.new()
			"ex":
				ed = ExEditor.new()
			"crt":
				ed = CrtEditor.new()
			"ad":
				ed = AdEditor.new()
			"map":
				ed = MapEditor.new()
				ed.connect("coord_picked", _on_coord_picked)
				ed.connect("pick_cancelled", _on_pick_cancelled)
		ed.call("setup", _project)
		_editors[key] = ed
	_host.add_child(_editors[key])
	if key == "map" and _editors[key].has_method("refresh_marks"):
		_editors[key].call("refresh_marks")
	# 座標指定中に手で別のエディタへ移ったら、指定は取り消す
	if key != "map" and _pick_return_idx >= 0 and not _pick_switching:
		_pick_handler = Callable()
		_pick_return_idx = -1
		if _editors.has("map"):
			_editors["map"].call("end_coord_pick")


## 座標指定の依頼 (エネミー・スイッチ等のエディタから)。
## マップエディタに切り替え、クリックされた座標を handler に渡して
## 元のエディタへ戻る。マップの無い world では受け付けない。
func request_coord_pick(handler: Callable) -> void:
	if _project == null or _project.dd == null:
		_status_label.text = "マップが無い world では座標を指定できません"
		return
	_pick_handler = handler
	_pick_return_idx = _current_idx
	var map_idx := _editor_index("map")
	_pick_switching = true
	_editor_list.select(map_idx)
	_on_editor_selected(map_idx)
	_pick_switching = false
	(_editors["map"] as Control).call("begin_coord_pick")


func _on_coord_picked(x: int, y: int) -> void:
	var handler := _pick_handler
	_pick_handler = Callable()
	_return_from_pick()
	if handler.is_valid():
		handler.call(x, y)


func _on_pick_cancelled() -> void:
	_pick_handler = Callable()
	_return_from_pick()
	_status_label.text = "座標指定を中止しました"


func _return_from_pick() -> void:
	if _pick_return_idx >= 0:
		_pick_switching = true
		_editor_list.select(_pick_return_idx)
		_on_editor_selected(_pick_return_idx)
		_pick_switching = false
		_pick_return_idx = -1


func _on_save_pressed() -> void:
	if _project == null:
		return
	var saved := _project.save_all()
	if saved.is_empty():
		_status_label.text = "変更はありません"
	else:
		_status_label.text = "保存しました: " + ", ".join(saved)


func _editor_index(scene_key: String) -> int:
	for i in EDITORS.size():
		if String(EDITORS[i]["scene"]) == scene_key:
			return i
	return 0


func _on_autosave_toggled(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("save", "auto", on)
	cfg.save("user://creators.cfg")
	if on:
		_autosave_timer.start()
	else:
		_autosave_timer.stop()


func _on_autosave_tick() -> void:
	if _project == null:
		return
	var saved := _project.save_all()
	if not saved.is_empty():
		var t := Time.get_time_dict_from_system()
		_status_label.text = "自動保存しました (%02d:%02d): %s" % [
			int(t["hour"]), int(t["minute"]), ", ".join(saved)]


func _show_about() -> void:
	# Mac 実機では別 OS 窓 (AcceptDialog / Window) が出ない事象が続いた
	# ため、メイン画面内のオーバーレイ (通常の Control) で出す。
	# Control はメイン画面の一部として描かれるので必ず表示できる。
	if _about_overlay == null:
		_about_overlay = _make_overlay("バージョン情報")
		var label := Label.new()
		label.text = CreatorsVersion.about_text()
		(_about_overlay.get_meta("box") as VBoxContainer).add_child(label)
		add_child(_about_overlay)
	_center_overlay(_about_overlay)
	_about_overlay.show()


## 画面内オーバーレイの土台 (暗い全面 + 中央のパネル + 題名行)。
## 戻り値の Control に meta "panel" / "box" を付けて返す。
func _make_overlay(title_text: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", AppTheme.style(
			Color(0.16, 0.17, 0.20), Color(0.55, 0.58, 0.65)))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var tl := Label.new()
	tl.text = title_text
	tl.add_theme_color_override("font_color", AppTheme.GOLD)
	head.add_child(tl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: root.hide())
	head.add_child(close_btn)
	box.add_child(head)
	_attach_panel_drag(head, panel)
	root.set_meta("panel", panel)
	root.set_meta("box", box)
	root.hide()
	return root


## オーバーレイのパネルを中身の大きさで画面中央に置く
func _center_overlay(root: Control) -> void:
	var panel := root.get_meta("panel") as PanelContainer
	var need := panel.get_combined_minimum_size() + Vector2(36, 28)
	if need.x < 200 or need.y < 120:
		need = Vector2(440, 260)
	need.x = minf(need.x, maxf(size.x - 16.0, 320.0))
	need.y = minf(need.y, maxf(size.y - 16.0, 240.0))
	panel.size = need
	panel.position = Vector2(maxf(0.0, (size.x - need.x) / 2.0),
			maxf(0.0, (size.y - need.y) / 2.0))


## 題名行を掴んでパネルを動かせるようにする
func _attach_panel_drag(band: Control, panel: Control) -> void:
	var state := {"drag": false, "off": Vector2.ZERO}
	band.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				state["drag"] = mb.pressed
				if mb.pressed:
					state["off"] = band.get_global_mouse_position() \
							- panel.position
		elif event is InputEventMouseMotion and bool(state["drag"]):
			panel.position = band.get_global_mouse_position() \
					- Vector2(state["off"]))


## macOS のアプリケーションメニューの「About」は Godot 既定では
## 何も起きないため、バージョン情報へつなぐ。項目は位置ではなく
## 項目名 (About… / …について) で探す (NeoPHI の実績方式)
func _setup_global_menu() -> void:
	if not OS.has_feature("macos"):
		return
	if not NativeMenu.has_feature(NativeMenu.FEATURE_GLOBAL_MENU):
		return
	if not NativeMenu.has_system_menu(NativeMenu.APPLICATION_MENU_ID):
		return
	var menu := NativeMenu.get_system_menu(NativeMenu.APPLICATION_MENU_ID)
	for i in NativeMenu.get_item_count(menu):
		var item_text := NativeMenu.get_item_text(menu, i)
		if item_text.begins_with("About") or item_text.contains("について"):
			NativeMenu.set_item_callback(menu, i,
					Callable(self, "_on_macos_about_item"))
			return


func _on_macos_about_item(_tag: Variant) -> void:
	_show_about()


# --- 更新チェック (NeoPHI 第40/102段の移植) --------------------------

func _start_auto_update_check() -> void:
	## 起動時の自動チェック。配布版 (エディタでない実行) でのみ行う。
	if OS.has_feature("editor"):
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.timeout.connect(func() -> void: _check_update(false))
	add_child(timer)
	timer.start()


func _check_update(manual: bool) -> void:
	## GitHub の最新リリースを確認する。新しいものがあれば窓を出す。
	## 手動の時は最新だった/失敗したこともステータスで知らせる。
	if _update_busy:
		return
	if _update_http == null:
		_update_http = HTTPRequest.new()
		_update_http.timeout = 15.0
		_update_http.request_completed.connect(_on_update_response)
		add_child(_update_http)
	_update_busy = true
	_update_manual = manual
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: PHICreatorsSuite/" + CreatorsVersion.VERSION,
	])
	var err := _update_http.request(CreatorsUpdate.API_URL, headers)
	if err != OK:
		_update_busy = false
		if manual:
			_status_label.text = "更新を確認できませんでした"
		else:
			_schedule_update_retry()


func _schedule_update_retry() -> void:
	## 自動チェック失敗時に 30 秒後にもう一度だけ確認する。
	if _update_retried:
		return
	_update_retried = true
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 30.0
	timer.timeout.connect(func() -> void: _check_update(false))
	add_child(timer)
	timer.start()


func _on_update_response(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_update_busy = false
	var manual := _update_manual
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if manual:
			_status_label.text = "更新を確認できませんでした"
		else:
			_schedule_update_retry()
		return
	var info := CreatorsUpdate.parse_latest(body.get_string_from_utf8())
	if info.is_empty():
		if manual:
			_status_label.text = "更新を確認できませんでした"
		else:
			_schedule_update_retry()
		return
	_update_retried = false
	if CreatorsUpdate.is_newer(str(info["tag"]), CreatorsVersion.VERSION):
		_update_info = info
		_show_update_dialog()
	elif manual:
		_status_label.text = "PHI CREATORS SUITE " \
				+ CreatorsVersion.VERSION + " は最新です"


func _show_update_dialog() -> void:
	## 更新のお知らせ。About と同じ画面内オーバーレイ方式。
	if _update_overlay == null:
		_update_overlay = _make_overlay("更新のお知らせ")
		var box := _update_overlay.get_meta("box") as VBoxContainer
		_update_label = Label.new()
		_update_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_update_label.custom_minimum_size = Vector2(400, 0)
		box.add_child(_update_label)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		buttons.alignment = BoxContainer.ALIGNMENT_END
		box.add_child(buttons)
		var open_btn := Button.new()
		open_btn.text = "GitHub のリリースページを開く"
		open_btn.focus_mode = Control.FOCUS_NONE
		open_btn.pressed.connect(_on_update_open_page)
		buttons.add_child(open_btn)
		var close2 := Button.new()
		close2.text = "閉じる"
		close2.focus_mode = Control.FOCUS_NONE
		close2.pressed.connect(func() -> void: _update_overlay.hide())
		buttons.add_child(close2)
		add_child(_update_overlay)
	var tag := str(_update_info.get("tag", ""))
	var rel_name := str(_update_info.get("name", ""))
	var shown := tag
	if not rel_name.is_empty() and rel_name != tag:
		shown = tag + " (" + rel_name + ")"
	_update_label.text = "新しいバージョン " + shown \
			+ " が公開されています。\n現在のバージョンは " \
			+ CreatorsVersion.VERSION \
			+ " です。\nGitHub のリリースページから新しい " \
			+ "PHI CREATORS SUITE を入手してください。"
	_center_overlay(_update_overlay)
	_update_overlay.show()


func _on_update_open_page() -> void:
	OS.shell_open(CreatorsUpdate.page_url(_update_info))
	_update_overlay.hide()

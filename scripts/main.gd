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
	{"name": "アナウンス (phi.bb / phi.inf)", "scene": "announce"},
	{"name": "エネミー (phi.ed)", "scene": "ed"},
	{"name": "オブジェクト (phi.od)", "scene": "od"},
	{"name": "クリエイト (phi.crt)", "scene": "crt"},
	{"name": "マップ (phi.dd / phi.fd)", "scene": "map"},
	{"name": "スイッチ (phi.swt)", "scene": "swt"},
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


func _ready() -> void:
	add_to_group("creators_main")
	theme = AppTheme.build()
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
	_path_label = Label.new()
	_path_label.text = "(未選択)"
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
	_editor_list.custom_minimum_size = Vector2(260, 0)
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
	var dlg := AcceptDialog.new()
	dlg.title = "バージョン情報"
	dlg.dialog_text = CreatorsVersion.about_text()
	add_child(dlg)
	dlg.popup_centered(Vector2i(360, 200))

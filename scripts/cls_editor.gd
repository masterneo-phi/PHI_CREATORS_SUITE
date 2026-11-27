extends VBoxContainer
## プログラムエディタ: phi.cls (Lua スイッチプログラム、PHIDM_NEO
## 拡張) をプレーンテキストとして編集する。動作62 の引数 (関数名) や
## on_second などのフックが対象。保存は WorldProject が CP932 で
## バイト保持 (.bak 付き) する。

var _project: WorldProject
var _edit: TextEdit


func setup(project: WorldProject) -> void:
	_project = project
	var label := Label.new()
	label.text = "phi.cls — Lua プログラム (動作62・毎秒フック等)"
	add_child(label)
	var note := Label.new()
	note.text = "サーバ側の Lua で実行されます。構文の検証は PCS では行いません。" \
			+ "文中の %job / %sex は職業名・性別名に置き換わる場合があります。"
	note.modulate = Color(0.75, 0.75, 0.75)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	_edit = TextEdit.new()
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.text = project.cls_text
	_edit.text_changed.connect(func() -> void:
		_project.cls_text = _edit.text)
	add_child(_edit)
	if not project.has_cls:
		var n2 := Label.new()
		n2.text = "(phi.cls は無い world です。書くと保存時に新規作成されます)"
		add_child(n2)

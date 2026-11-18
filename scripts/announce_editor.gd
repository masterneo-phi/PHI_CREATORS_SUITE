extends VBoxContainer
## アナウンスエディタ: phi.bb (ログイン時の挨拶) と
## phi.inf (世界の案内) をそのまま編集する。どちらもサーバ側に
## パーサはなく、プレーンテキストとして表示される (FORMAT_SPEC §12)。

var _project: WorldProject
var _bb_edit: TextEdit
var _inf_edit: TextEdit


func setup(project: WorldProject) -> void:
	_project = project
	var bb_label := Label.new()
	bb_label.text = "phi.bb — ログイン時に表示されるアナウンス"
	add_child(bb_label)
	_bb_edit = TextEdit.new()
	_bb_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bb_edit.text = project.bb_text
	_bb_edit.text_changed.connect(func() -> void:
		_project.bb_text = _bb_edit.text)
	add_child(_bb_edit)
	if not project.has_bb:
		var note := Label.new()
		note.text = "(phi.bb は無い world です。書くと保存時に新規作成されます)"
		add_child(note)
	var inf_label := Label.new()
	inf_label.text = "phi.inf — 世界の案内文"
	add_child(inf_label)
	_inf_edit = TextEdit.new()
	_inf_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inf_edit.text = project.inf_text
	_inf_edit.text_changed.connect(func() -> void:
		_project.inf_text = _inf_edit.text)
	add_child(_inf_edit)
	if not project.has_inf:
		var note2 := Label.new()
		note2.text = "(phi.inf は無い world です。書くと保存時に新規作成されます)"
		add_child(note2)

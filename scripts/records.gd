class_name TryRecords
extends RefCounted

const MAX_SAFE_COUNTER := 9_007_199_254_740_991

var path := "user://records.json"
var data := {"version": 1, "deaths": 0, "attempts": 0, "clears": 0, "best_time": 0.0, "no_death": false, "secret": false, "music": true, "sfx": true, "muted": false}
var last_error := ""

func _init(test_mode: bool = false) -> void:
	if test_mode:
		path = "user://test_records.json"
		return
	load_records()

func load_records() -> void:
	if not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	var loaded = parser.data if error == OK else null
	if not loaded is Dictionary or loaded.get("version", 0) != 1:
		last_error = "기록 파일을 읽지 못했습니다. 이번 기록은 새로 저장합니다."
		return
	for key in ["deaths", "attempts", "clears"]:
		var value = loaded.get(key)
		if value is float or value is int:
			# JSON numbers are doubles: reject overflow before converting to int.
			data[key] = int(value) if is_finite(float(value)) and value >= 0 and value <= MAX_SAFE_COUNTER else 0
	if loaded.get("best_time") is float or loaded.get("best_time") is int:
		var best := float(loaded.best_time)
		data.best_time = best if is_finite(best) and best > 0 and best < float(MAX_SAFE_COUNTER) / 100.0 else 0.0
	for key in ["no_death", "secret", "music", "sfx", "muted"]:
		if loaded.get(key) is bool:
			data[key] = loaded[key]

func save() -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "기록 저장 실패: 저장 폴더를 확인해 주세요."
		return false
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if result != OK:
		last_error = "기록 저장 실패: 임시 파일을 바꾸지 못했습니다."
		return false
	last_error = ""
	return true

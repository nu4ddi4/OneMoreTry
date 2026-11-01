class_name TryUpdater
extends Node

signal changed

const REPOSITORY := "nu4ddi4/side-scroller-game"
const LATEST_URL := "https://api.github.com/repos/" + REPOSITORY + "/releases/latest"
const BETA_URL := "https://api.github.com/repos/" + REPOSITORY + "/releases?per_page=100"
const DOWNLOAD_BASE := "https://github.com/" + REPOSITORY + "/releases/download/"
const MAX_INSTALLER_SIZE := 256 * 1024 * 1024
const CACHE_DIR := "user://updates"
enum State { IDLE, CHECKING, CURRENT, AVAILABLE, DOWNLOADING, READY, FAILED }

var state := State.IDLE
var message := "업데이트"
var current_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
var release: Dictionary = {}
var installer_path := ""
var request: HTTPRequest
var progress_clock := 0.0
var channel: String = ProjectSettings.get_setting("application/config/release_channel", "stable")
var automatic_download := false
var settings_path: String

func _init(test_mode: bool = false) -> void:
	settings_path = "user://test_update_settings.cfg" if test_mode else "user://update_settings.cfg"

func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(settings_path) == OK:
		var saved = settings.get_value("updates", "channel", channel)
		if saved in ["stable", "beta"]:
			channel = saved
	request = HTTPRequest.new()
	request.use_threads = true
	request.max_redirects = 5
	add_child(request)
	request.request_completed.connect(_completed)

static func version_parts(value: String) -> PackedInt64Array:
	var pattern := RegEx.new()
	pattern.compile("^(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})(-beta)?$")
	var found := pattern.search(value)
	if found == null:
		return PackedInt64Array()
	return PackedInt64Array([int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3)), 0 if value.ends_with("-beta") else 1])

static func is_newer(candidate: String, installed: String) -> bool:
	var next := version_parts(candidate)
	var previous := version_parts(installed)
	if next.is_empty() or previous.is_empty():
		return false
	for i in 4:
		if next[i] != previous[i]:
			return next[i] > previous[i]
	return false

static func release_version(data: Variant, selected_channel: String) -> String:
	if selected_channel not in ["stable", "beta"] or not data is Dictionary or data.get("draft") != false or data.get("prerelease") != (selected_channel == "beta"):
		return ""
	var tag = data.get("tag_name")
	if not tag is String or not tag.begins_with("v") or version_parts(tag.substr(1)).is_empty() or tag.ends_with("-beta") != (selected_channel == "beta"):
		return ""
	return tag.substr(1)

static func newest_version(data: Variant, selected_channel: String) -> String:
	var best := ""
	var entries: Array = data if data is Array else [data]
	for entry in entries:
		var candidate := release_version(entry, selected_channel)
		if not candidate.is_empty() and (best.is_empty() or is_newer(candidate, best)):
			best = candidate
	return best

static func select_release(data: Variant, installed: String, selected_channel: String = "stable") -> Dictionary:
	if data is Array:
		var best: Dictionary = {}
		for entry in data:
			var candidate := select_release(entry, installed, selected_channel)
			if not candidate.is_empty() and (best.is_empty() or is_newer(candidate.version, best.version)):
				best = candidate
		return best
	var version := release_version(data, selected_channel)
	if not is_newer(version, installed):
		return {}
	var tag := "v" + version
	var filename: String = "OneMoreTry-%s-Windows-x64-Setup.exe" % tag
	var assets = data.get("assets")
	if not assets is Array:
		return {}
	for asset in assets:
		if not asset is Dictionary or asset.get("name") != filename:
			continue
		var digest = asset.get("digest")
		var byte_count = asset.get("size")
		if not digest is String or not digest.begins_with("sha256:"):
			continue
		var checksum: String = digest.substr(7).to_lower()
		if checksum.length() != 64 or not checksum.is_valid_hex_number():
			continue
		if not (byte_count is int or byte_count is float) or byte_count < 1 or byte_count > MAX_INSTALLER_SIZE or byte_count != int(byte_count):
			continue
		# Construct the URL ourselves. Release metadata cannot redirect us to another repository.
		return {"version": tag.substr(1), "filename": filename, "sha256": checksum, "size": int(byte_count), "url": DOWNLOAD_BASE + tag + "/" + filename}
	return {}

func feed_url() -> String:
	return BETA_URL if channel == "beta" else LATEST_URL

func set_channel(value: String) -> bool:
	if value not in ["stable", "beta"]:
		return false
	var settings := ConfigFile.new()
	settings.set_value("updates", "channel", value)
	if settings.save(settings_path) != OK:
		request.cancel_request()
		fail("설정을 저장하지 못했습니다.")
		return false
	request.cancel_request()
	remove_partial()
	release.clear()
	installer_path = ""
	request.download_file = ""
	channel = value
	set_status(State.IDLE, "업데이트")
	return true

func set_status(next: State, value: String) -> void:
	state = next
	message = value
	changed.emit()

func check_for_updates() -> void:
	if state in [State.CHECKING, State.DOWNLOADING, State.READY]:
		return
	release.clear()
	request.download_file = ""
	request.body_size_limit = 16 * 1024 * 1024
	request.timeout = 15
	set_status(State.CHECKING, "업데이트 확인 중")
	var error := request.request(feed_url(), ["Accept: application/vnd.github+json", "User-Agent: OneMoreTry/" + current_version, "X-GitHub-Api-Version: 2022-11-28"])
	if error != OK:
		fail("연결하지 못했습니다. 다시 시도해 주세요.")

func download_update() -> void:
	if state != State.AVAILABLE:
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR)) != OK:
		fail("파일을 저장하지 못했습니다. 저장 공간을 확인해 주세요.")
		return
	installer_path = CACHE_DIR.path_join(release.filename)
	remove_partial()
	if verify_installer(installer_path):
		mark_ready()
		return
	request.download_file = installer_path + ".part"
	request.body_size_limit = release.size
	request.timeout = 300
	set_status(State.DOWNLOADING, "다운로드 중")
	if request.request(release.url, ["User-Agent: OneMoreTry/" + current_version]) != OK:
		fail("다운로드하지 못했습니다. 다시 시도해 주세요.")

func _process(delta: float) -> void:
	if state != State.DOWNLOADING:
		return
	progress_clock += delta
	if progress_clock >= 0.2:
		progress_clock = 0
		message = "다운로드 %d%%" % clampi(int(100.0 * request.get_downloaded_bytes() / release.size), 0, 100)
		changed.emit()

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state not in [State.CHECKING, State.DOWNLOADING]:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if state == State.CHECKING and response_code == 404:
			set_status(State.CURRENT, "업데이트가 없습니다.")
		else:
			fail("다운로드하지 못했습니다. 연결을 확인해 주세요.")
		return
	if state == State.CHECKING:
		var parser := JSON.new()
		var parse_error := parser.parse(body.get_string_from_utf8())
		var data = parser.data if parse_error == OK else null
		if (channel == "stable" and (not data is Dictionary or not data.get("tag_name") is String or version_parts(str(data.get("tag_name")).trim_prefix("v")).is_empty())) or (channel == "beta" and not data is Array):
			fail("업데이트를 확인하지 못했습니다.")
			return
		release = select_release(data, current_version, channel)
		if not release.is_empty():
			set_status(State.AVAILABLE, "v%s 업데이트" % release.version)
			if automatic_download:
				download_update()
		elif is_newer(newest_version(data, channel), current_version):
			fail("나중에 다시 확인해 주세요.")
		else:
			set_status(State.CURRENT, "업데이트가 없습니다. (v%s)" % current_version)
		return
	if not verify_installer(installer_path + ".part"):
		fail("파일이 손상되었습니다. 다시 다운로드해 주세요.")
		return
	if FileAccess.file_exists(installer_path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(installer_path)) != OK:
		fail("파일을 저장하지 못했습니다.")
		return
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(installer_path + ".part"), ProjectSettings.globalize_path(installer_path))
	if error != OK:
		fail("파일을 저장하지 못했습니다.")
		return
	mark_ready()

func mark_ready() -> void:
	set_status(State.READY, "v%s 설치 준비 완료\n설치하면 게임이 종료됩니다." % release.version)

func verify_installer(path: String) -> bool:
	if release.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var size := file.get_length()
	file.close()
	return size == release.size and FileAccess.get_sha256(path) == release.sha256

func launch_installer() -> bool:
	if state != State.READY or OS.get_name() != "Windows":
		return false
	# Check again in case the downloaded file changed while the dialog was open.
	if not verify_installer(installer_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(installer_path))
		fail("파일이 변경되었습니다. 다시 다운로드해 주세요.")
		return false
	if OS.create_process(ProjectSettings.globalize_path(installer_path), []) <= 0:
		fail("설치 파일을 실행하지 못했습니다.")
		return false
	return true

func cancel() -> void:
	if state not in [State.CHECKING, State.DOWNLOADING]:
		return
	request.cancel_request()
	remove_partial()
	set_status(State.IDLE, "취소했습니다.")

func remove_partial() -> void:
	if not installer_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(installer_path + ".part"))

func fail(value: String) -> void:
	remove_partial()
	set_status(State.FAILED, value)

func _exit_tree() -> void:
	if request:
		request.cancel_request()
	remove_partial()

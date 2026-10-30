class_name TryUpdater
extends Node

signal changed

const REPOSITORY := "nu4ddi4/side-scroller-game"
const LATEST_URL := "https://api.github.com/repos/" + REPOSITORY + "/releases/latest"
const DOWNLOAD_BASE := "https://github.com/" + REPOSITORY + "/releases/download/"
const MAX_INSTALLER_SIZE := 256 * 1024 * 1024
const CACHE_DIR := "user://updates"
enum State { IDLE, CHECKING, CURRENT, AVAILABLE, DOWNLOADING, READY, FAILED }

var state := State.IDLE
var message := "새 버전을 확인할 수 있습니다."
var current_version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
var release: Dictionary = {}
var installer_path := ""
var request: HTTPRequest
var progress_clock := 0.0

func _ready() -> void:
	request = HTTPRequest.new()
	request.use_threads = true
	request.max_redirects = 5
	add_child(request)
	request.request_completed.connect(_completed)

static func version_parts(value: String) -> PackedInt64Array:
	var pattern := RegEx.new()
	pattern.compile("^(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})$")
	var found := pattern.search(value)
	if found == null:
		return PackedInt64Array()
	return PackedInt64Array([int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))])

static func is_newer(candidate: String, installed: String) -> bool:
	var next := version_parts(candidate)
	var previous := version_parts(installed)
	if next.is_empty() or previous.is_empty():
		return false
	for i in 3:
		if next[i] != previous[i]:
			return next[i] > previous[i]
	return false

static func select_release(data: Variant, installed: String) -> Dictionary:
	if not data is Dictionary or data.get("draft") != false or data.get("prerelease") != false:
		return {}
	var tag = data.get("tag_name")
	if not tag is String or not tag.begins_with("v") or not is_newer(tag.substr(1), installed):
		return {}
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

func set_status(next: State, value: String) -> void:
	state = next
	message = value
	changed.emit()

func check_for_updates() -> void:
	if state in [State.CHECKING, State.DOWNLOADING, State.READY]:
		return
	release.clear()
	request.download_file = ""
	request.body_size_limit = 2 * 1024 * 1024
	request.timeout = 15
	set_status(State.CHECKING, "GitHub에서 새 버전을 확인하고 있습니다.")
	var error := request.request(LATEST_URL, ["Accept: application/vnd.github+json", "User-Agent: OneMoreTry/" + current_version, "X-GitHub-Api-Version: 2022-11-28"])
	if error != OK:
		fail("업데이트 서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.")

func download_update() -> void:
	if state != State.AVAILABLE:
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR)) != OK:
		fail("업데이트를 저장하지 못했습니다. 저장 공간을 확인해 주세요.")
		return
	installer_path = CACHE_DIR.path_join(release.filename)
	remove_partial()
	request.download_file = installer_path + ".part"
	request.body_size_limit = release.size
	request.timeout = 300
	set_status(State.DOWNLOADING, "설치 파일을 다운로드하고 있습니다.")
	if request.request(release.url, ["User-Agent: OneMoreTry/" + current_version]) != OK:
		fail("다운로드를 시작하지 못했습니다. 다시 시도해 주세요.")

func _process(delta: float) -> void:
	if state != State.DOWNLOADING:
		return
	progress_clock += delta
	if progress_clock >= 0.2:
		progress_clock = 0
		message = "설치 파일 다운로드 중  %d%%" % clampi(int(100.0 * request.get_downloaded_bytes() / release.size), 0, 100)
		changed.emit()

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state not in [State.CHECKING, State.DOWNLOADING]:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if state == State.CHECKING and response_code == 404:
			set_status(State.CURRENT, "현재 받을 수 있는 새 정식 버전이 없습니다.")
		else:
			fail("업데이트를 받지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.")
		return
	if state == State.CHECKING:
		var parser := JSON.new()
		var parse_error := parser.parse(body.get_string_from_utf8())
		var data = parser.data if parse_error == OK else null
		if not data is Dictionary or not data.get("tag_name") is String or version_parts(str(data.get("tag_name")).trim_prefix("v")).is_empty():
			fail("업데이트 정보를 읽지 못했습니다. 잠시 후 다시 시도해 주세요.")
			return
		release = select_release(data, current_version)
		if not release.is_empty():
			set_status(State.AVAILABLE, "새 버전 %s을 받을 수 있습니다.\n다운로드 후 설치하면 게임이 종료됩니다. 저장 기록은 유지됩니다." % release.version)
		elif is_newer(str(data.tag_name).trim_prefix("v"), current_version):
			fail("새 버전의 설치 파일이 아직 준비되지 않았습니다. 잠시 후 다시 확인해 주세요.")
		else:
			set_status(State.CURRENT, "최신 버전을 사용하고 있습니다. (v%s)" % current_version)
		return
	if not verify_installer(installer_path + ".part"):
		fail("설치 파일 검증에 실패했습니다. 파일을 삭제했습니다. 다시 다운로드해 주세요.")
		return
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(installer_path + ".part"), ProjectSettings.globalize_path(installer_path))
	if error != OK:
		fail("설치 파일을 저장하지 못했습니다. 다시 시도해 주세요.")
		return
	set_status(State.READY, "v%s 다운로드와 검증을 마쳤습니다.\n설치 프로그램을 실행하고 게임을 종료합니다. 저장 기록은 유지됩니다." % release.version)

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
		fail("설치 파일이 변경되었습니다. 다시 다운로드해 주세요.")
		return false
	if OS.create_process(ProjectSettings.globalize_path(installer_path), []) <= 0:
		fail("설치 프로그램을 실행하지 못했습니다. 다시 시도해 주세요.")
		return false
	return true

func cancel() -> void:
	if state not in [State.CHECKING, State.DOWNLOADING]:
		return
	request.cancel_request()
	remove_partial()
	set_status(State.IDLE, "업데이트를 취소했습니다. 나중에 다시 확인할 수 있습니다.")

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

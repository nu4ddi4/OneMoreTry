extends SceneTree

const Updater = preload("res://scripts/updater.gd")
var failures := 0
var checks := 0
var updater: TryUpdater
var fixture_url := ""
const PAYLOAD := "test installer payload\n"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-url="):
			fixture_url = argument.trim_prefix("--fixture-url=")
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func metadata(version: String = "0.3.0") -> Dictionary:
	return {"tag_name": "v" + version, "draft": false, "prerelease": false, "assets": [{"name": "OneMoreTry-v%s-Windows-x64-Setup.exe" % version, "digest": "sha256:" + PAYLOAD.sha256_text(), "size": PAYLOAD.to_utf8_buffer().size(), "browser_download_url": "https://untrusted.invalid/payload.exe"}]}

func wait_for_request() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while updater.state in [Updater.State.CHECKING, Updater.State.DOWNLOADING] and Time.get_ticks_msec() < deadline:
		await process_frame
	check(updater.state not in [Updater.State.CHECKING, Updater.State.DOWNLOADING], "HTTP request finishes within the test deadline")

func fetch_metadata(endpoint: String) -> void:
	updater.request.download_file = ""
	updater.request.timeout = 2
	updater.request.body_size_limit = 1024 * 1024
	updater.set_status(Updater.State.CHECKING, "test")
	check(updater.request.request(fixture_url + endpoint) == OK, "Real HTTP metadata request starts")
	await wait_for_request()

func run() -> void:
	check(Updater.is_newer("0.10.0", "0.9.9"), "Versions compare numerically, including double digits")
	check(not Updater.is_newer("0.2.0", "0.2.0"), "Same version is not an update")
	check(not Updater.is_newer("0.1.9", "0.2.0"), "Downgrades are not offered")
	for value in ["../1.2.3", "1.2", "1.2.3-beta", "01.2.3", "999999999999.0.0"]:
		check(Updater.version_parts(value).is_empty(), "Reject malformed version: " + value)
	var data := metadata()
	var selected := Updater.select_release(data, "0.2.0")
	check(selected.get("url") == Updater.DOWNLOAD_BASE + "v0.3.0/OneMoreTry-v0.3.0-Windows-x64-Setup.exe", "Asset URL is constructed from the fixed repository")
	for key in ["draft", "prerelease"]:
		data = metadata()
		data[key] = true
		check(Updater.select_release(data, "0.2.0").is_empty(), "Do not install " + key + " releases")
	for digest in [null, "", "md5:bad", "sha256:" + "z".repeat(64)]:
		data = metadata()
		data.assets[0].digest = digest
		check(Updater.select_release(data, "0.2.0").is_empty(), "Missing or invalid SHA-256 is rejected")
	for size in [-1, 0, 1.5, Updater.MAX_INSTALLER_SIZE + 1]:
		data = metadata()
		data.assets[0].size = size
		check(Updater.select_release(data, "0.2.0").is_empty(), "Invalid installer size is rejected")
	data = metadata()
	data.assets[0].name = "another-installer.exe"
	check(Updater.select_release(data, "0.2.0").is_empty(), "Unrelated release assets cannot be installed")
	check(Updater.select_release(metadata("0.1.0"), "0.2.0").is_empty(), "Older release cannot be selected")
	updater = Updater.new()
	root.add_child(updater)
	updater.current_version = "0.2.0"
	# Isolated cache paths; never touch the player's update downloads or records.
	updater.installer_path = "user://test-updater.exe"
	updater.release = selected
	var file := FileAccess.open(updater.installer_path, FileAccess.WRITE)
	file.store_string(PAYLOAD)
	file.close()
	check(updater.verify_installer(updater.installer_path), "Matching downloaded bytes pass size and SHA-256 verification")
	file = FileAccess.open(updater.installer_path, FileAccess.WRITE)
	file.store_string("x".repeat(PAYLOAD.length()))
	file.close()
	check(not updater.verify_installer(updater.installer_path), "Same-sized tampered download fails verification")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(updater.installer_path))
	check(not updater.verify_installer(updater.installer_path), "Missing download cannot be installed")
	check(not fixture_url.is_empty(), "Local HTTP fixture is configured")
	if not fixture_url.is_empty():
		await fetch_metadata("/metadata")
		check(updater.state == Updater.State.AVAILABLE, "Valid metadata offers the update without downloading it")
		updater.current_version = "0.3.0"
		await fetch_metadata("/metadata")
		check(updater.state == Updater.State.CURRENT, "Current version shows no update")
		updater.current_version = "0.2.0"
		await fetch_metadata("/malformed")
		check(updater.state == Updater.State.FAILED, "Invalid JSON shows a recoverable failure")
		await fetch_metadata("/unavailable")
		check(updater.state == Updater.State.FAILED, "Rate limiting shows a recoverable failure")
		await fetch_metadata("/missing")
		check(updater.state == Updater.State.CURRENT, "No published stable release leaves the game usable")
		for endpoint in ["/installer", "/tampered", "/truncated", "/oversized"]:
			updater.release = selected.duplicate()
			updater.release.filename = "test-updater.exe"
			updater.release.url = fixture_url + endpoint
			updater.set_status(Updater.State.AVAILABLE, "test")
			updater.download_update()
			await wait_for_request()
			if endpoint == "/installer":
				check(updater.state == Updater.State.READY and updater.verify_installer(updater.installer_path), "Real download is verified and staged for explicit install")
				check(not updater.launch_installer(), "Linux tests never execute a Windows installer")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(updater.installer_path))
			else:
				check(updater.state == Updater.State.FAILED, "Reject bad downloaded bytes: " + endpoint)
			check(not FileAccess.file_exists(updater.installer_path + ".part"), "Partial download is cleaned up")
		updater.release.url = fixture_url + "/slow"
		updater.set_status(Updater.State.AVAILABLE, "test")
		updater.download_update()
		updater.cancel()
		await create_timer(0.1).timeout
		check(updater.state == Updater.State.IDLE and not FileAccess.file_exists(updater.installer_path + ".part"), "Cancelling aborts HTTP and removes partial files")
	updater.free()
	print("Updater: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

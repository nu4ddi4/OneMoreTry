extends SceneTree

const Updater = preload("res://scripts/updater.gd")
var failures := 0
var checks := 0
var updater: TryUpdater
var fixture_url := ""
const PAYLOAD := "test update payload\n"

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
	return {"tag_name": "v" + version, "draft": false, "prerelease": version.ends_with("-beta"), "assets": [{"name": "OneMoreTry-v%s-Windows-x64.zip" % version, "digest": "sha256:" + PAYLOAD.sha256_text(), "size": PAYLOAD.to_utf8_buffer().size(), "browser_download_url": "https://untrusted.invalid/payload.exe"}]}

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
	check(Updater.is_newer("0.5.0", "0.5.0-beta"), "Stable follows the beta of the same core version")
	check(not Updater.is_newer("0.5.0-beta", "0.5.0"), "Same-core beta cannot downgrade stable")
	check(not Updater.is_newer("0.4.9", "0.5.0-beta"), "Switching to stable never downgrades a newer beta")
	check(Updater.is_newer("0.5.1-beta", "0.5.0"), "A higher-core beta can update stable")
	for value in ["../1.2.3", "1.2", "1.2.3-beta.1", "1.2.3-alpha", "01.2.3", "999999999999.0.0"]:
		check(Updater.version_parts(value).is_empty(), "Reject malformed version: " + value)
	var data := metadata()
	var selected := Updater.select_release(data, "0.2.0")
	check(selected.get("url") == Updater.DOWNLOAD_BASE + "v0.3.0/OneMoreTry-v0.3.0-Windows-x64.zip", "Asset URL is constructed from the fixed repository")
	var legacy := metadata()
	legacy.assets[0].name = "OneMoreTry-v0.3.0-Windows-x64-Setup.exe"
	check(Updater.select_release(legacy,"0.2.0").is_empty(),"Installer-only releases cannot enter the automatic file-replacement path")
	legacy.assets.append(metadata().assets[0])
	check(Updater.select_release(legacy,"0.2.0").get("filename").ends_with(".zip"),"A release with installer and ZIP selects only the update archive")
	for key in ["draft", "prerelease"]:
		data = metadata()
		data[key] = true
		check(Updater.select_release(data, "0.2.0").is_empty(), "Do not install " + key + " releases")
	for digest in [null, "", "md5:bad", "sha256:" + "z".repeat(64)]:
		data = metadata()
		data.assets[0].digest = digest
		check(Updater.select_release(data, "0.2.0").is_empty(), "Missing or invalid SHA-256 is rejected")
	for size in [-1, 0, 1.5, Updater.MAX_PACKAGE_SIZE + 1]:
		data = metadata()
		data.assets[0].size = size
		check(Updater.select_release(data, "0.2.0").is_empty(), "Invalid package size is rejected")
	data = metadata()
	data.assets[0].name = "another-package.exe"
	check(Updater.select_release(data, "0.2.0").is_empty(), "Unrelated release assets cannot be installed")
	check(Updater.select_release(metadata("0.1.0"), "0.2.0").is_empty(), "Older release cannot be selected")
	var releases := [metadata("0.4.0-beta"), metadata("0.5.0"), metadata("0.6.0-beta"), metadata("0.5.0-beta")]
	check(Updater.select_release(releases, "0.4.0", "beta").get("version") == "0.6.0-beta", "Beta feed selects highest beta, independent of API ordering")
	check(Updater.select_release(releases, "0.4.0", "stable").get("version") == "0.5.0", "Stable selection excludes betas")
	check(Updater.select_release(metadata("0.4.9"), "0.5.0-beta", "stable").is_empty(), "Channel switch cannot select lower-core stable")
	check(Updater.select_release(metadata("0.5.0-beta"), "0.5.0", "beta").is_empty(), "Channel switch cannot select same-core beta over stable")
	check(not Updater.select_release(metadata("0.5.0"), "0.5.0-beta", "stable").is_empty(), "Channel switch may promote same-core beta to stable")
	check(Updater.select_release(metadata("0.5.0"), "0.4.0", "beta").is_empty(), "Beta channel does not receive stable releases")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_update_settings.cfg"))
	updater = Updater.new(true)
	root.add_child(updater)
	updater.current_version = "0.2.0"
	check(updater.set_channel("beta") and updater.feed_url() == Updater.BETA_URL, "Channel selection uses the beta releases feed")
	var restored := Updater.new(true)
	root.add_child(restored)
	check(restored.channel == "beta", "Selected channel persists across updater instances")
	restored.free()
	check(not updater.set_channel("invalid") and updater.channel == "beta", "Invalid channel cannot replace saved selection")
	check(updater.set_channel("stable") and updater.feed_url() == Updater.LATEST_URL, "Stable channel uses GitHub latest stable")
	# Isolated cache paths; never touch the player's update downloads or records.
	updater.package_path = "user://test-updater.zip"
	updater.release = selected
	var file := FileAccess.open(updater.package_path, FileAccess.WRITE)
	file.store_string(PAYLOAD)
	file.close()
	check(updater.verify_package(updater.package_path), "Matching downloaded bytes pass size and SHA-256 verification")
	file = FileAccess.open(updater.package_path, FileAccess.WRITE)
	file.store_string("x".repeat(PAYLOAD.length()))
	file.close()
	check(not updater.verify_package(updater.package_path), "Same-sized tampered download fails verification")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(updater.package_path))
	check(not updater.verify_package(updater.package_path), "Missing download cannot be installed")
	check(not fixture_url.is_empty(), "Local HTTP fixture is configured")
	if not fixture_url.is_empty():
		await fetch_metadata("/metadata")
		check(updater.state == Updater.State.AVAILABLE, "Valid metadata offers the update without downloading it")
		updater.automatic_download = true
		var local_download := func():
			if updater.state == Updater.State.AVAILABLE:
				updater.release.url = fixture_url + "/package"
				updater.release.filename = "test-updater.zip"
		updater.changed.connect(local_download)
		await fetch_metadata("/metadata")
		updater.changed.disconnect(local_download)
		check(updater.state == Updater.State.READY, "Automatic update verifies and stages the selected channel download")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(updater.package_path))
		updater.automatic_download = false
		check(updater.set_channel("beta"), "Switch from staged package clears the previous channel")
		check(updater.release.is_empty() and updater.package_path.is_empty() and not updater.launch_apply(), "Old-channel staged package cannot launch after switching")
		await fetch_metadata("/betas")
		check(updater.release.get("version") == "0.5.0-beta", "Real HTTP beta list skips drafts and stable entries")
		await fetch_metadata("/beta-incomplete")
		check(updater.state == Updater.State.FAILED, "Missing beta package is a retryable failure rather than no update")
		updater.current_version = "0.5.0-beta"
		updater.set_channel("stable")
		await fetch_metadata("/metadata")
		check(updater.state == Updater.State.CURRENT and updater.release.is_empty(), "Real HTTP stable channel switch refuses downgrade")
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
		for endpoint in ["/package", "/tampered", "/truncated", "/oversized"]:
			updater.release = selected.duplicate()
			updater.release.filename = "test-updater.zip"
			updater.release.url = fixture_url + endpoint
			if endpoint == "/package":
				var stale := FileAccess.open("user://updates/test-updater.zip", FileAccess.WRITE)
				stale.store_string("x".repeat(PAYLOAD.length()))
				stale.close()
			updater.set_status(Updater.State.AVAILABLE, "test")
			updater.download_update()
			await wait_for_request()
			if endpoint == "/package":
				check(updater.state == Updater.State.READY and updater.verify_package(updater.package_path), "Real download is verified and staged for application")
				check(not updater.launch_apply(), "Linux tests never execute a Windows package")
				updater.release.url = fixture_url + "/missing"
				updater.set_status(Updater.State.AVAILABLE, "test")
				updater.download_update()
				check(updater.state == Updater.State.READY, "A verified cached package is reused without another network request")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(updater.package_path))
			else:
				check(updater.state == Updater.State.FAILED, "Reject bad downloaded bytes: " + endpoint)
			check(not FileAccess.file_exists(updater.package_path + ".part"), "Partial download is cleaned up")
		updater.release.url = fixture_url + "/slow"
		updater.set_status(Updater.State.AVAILABLE, "test")
		updater.download_update()
		updater.set_channel("beta")
		await create_timer(0.1).timeout
		check(updater.state == Updater.State.IDLE and updater.release.is_empty() and not FileAccess.file_exists("user://updates/test-updater.zip.part"), "Switching channel aborts HTTP and removes partial files")
	updater.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_update_settings.cfg"))
	print("Updater: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

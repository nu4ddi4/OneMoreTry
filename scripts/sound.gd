class_name TrySound
extends Node

var music_on := true
var sfx_on := true
var bgm: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}

func _ready() -> void:
	bgm = AudioStreamPlayer.new()
	bgm.stream = load("res://assets/audio/meadow.wav")
	bgm.volume_db = -18
	add_child(bgm)
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -13
		add_child(voice)
		voices.append(voice)
	for key in ["jump", "death", "checkpoint", "crumble", "warning", "trap", "clear", "secret", "click"]:
		streams[key] = load("res://assets/audio/" + key + ".wav")
	bgm.finished.connect(func():
		if music_on:
			bgm.play())

func set_music(on: bool) -> void:
	music_on = on
	if on and not bgm.playing:
		bgm.play()
	elif not on:
		bgm.stop()

func set_effects(on: bool) -> void:
	sfx_on = on
	if not on:
		for voice in voices:
			voice.stop()

func effect(key: String) -> void:
	if not sfx_on:
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = streams[key]
			voice.play()
			return

func quiet(quietly: bool) -> void:
	bgm.volume_db = -27 if quietly else -18

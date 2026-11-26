extends Node
## Autoload "Game": the session's profile (meta) and current run.
## RunState and Profile are plain RefCounted so headless tests drive them without a scene tree.

const RunState := preload("res://core/run_state.gd")
const Profile := preload("res://core/profile.gd")

var run = RunState.new()
var profile = Profile.new()
var fast_ui := false   ## smoke runs: skip the title card and loading cards


func _ready() -> void:
	# `-- profile=user://other.json` keeps test or tool runs away from the real save.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("profile="):
			profile.save_path = a.substr(8)
		elif a == "splash":
			fast_ui = true
			add_child(load("res://tools/make_splash.gd").new())
		elif a.begins_with("smoke="):
			fast_ui = true
			var driver: Node = load("res://tools/ui_smoke.gd").new()
			driver.set("out_dir", a.substr(6))
			add_child(driver)
	profile.load_from()


func save_profile() -> void:
	profile.save()

extends Node
## Autoload "Game": owns the single RunState for the session.
## RunState itself is a plain RefCounted so headless tests can drive it without a scene tree.

const RunState := preload("res://core/run_state.gd")

var run = RunState.new()

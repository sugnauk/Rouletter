extends RefCounted
## Build identity shown on the title screen.
## VERSION is bumped by hand with every update (0.0.1 -> 0.0.2 ...; see CHANGELOG.md).
## The deploy workflow overwrites BUILD with the commit hash and build time, so "dev" means a
## local/editor run.

const VERSION := "0.0.28"
const BUILD := "dev"


static func label() -> String:
	return "v%s  (%s)" % [VERSION, BUILD]

extends RefCounted
## Build identity shown on the title screen. The deploy workflow overwrites BUILD with the
## commit hash and build time, so "dev" means a local/editor run.

const VERSION := "0.1"
const BUILD := "dev"


static func label() -> String:
	return "v%s  %s" % [VERSION, BUILD]

---@diagnostic disable: lowercase-global
stds.nvim = {
	globals = {
		"vim",
		"describe",
		"it",
		"before_each",
		"after_each",
		"teardown",
		"pending",
		"clear",
	},
	read_globals = {
		"jit",
	},
}
std = "lua51+nvim"

exclude_files = {
	"lua/blink-git-commit/health.lua",
}

ignore = {
	"631", -- max_line_length
	"212/_.*", -- unused argument, for vars with "_" prefix
}

max_line_length = 120
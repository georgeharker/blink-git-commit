local M = {}

local health = vim.health or require("health")

function M.check()
	health.start("blink-git-commit.nvim")

	-- Check if blink.cmp is available
	local has_blink_cmp, _blink_cmp = pcall(require, "blink.cmp")
	if has_blink_cmp then
		health.ok("blink.cmp is installed")
	else
		health.error("blink.cmp is not installed", {
			"Install blink.cmp: https://github.com/Saghen/blink.cmp"
		})
		return
	end

	-- Check if we can create the source
	local has_source, source = pcall(require, "blink-git-commit")
	if has_source then
		health.ok("blink-git-commit source can be loaded")

		-- Try to create an instance
		local ok, instance = pcall(source.new, {})
		if ok then
			health.ok("blink-git-commit source can be instantiated")
		else
			health.error("Failed to create blink-git-commit instance", {
				"Error: " .. tostring(instance)
			})
		end
	else
		health.error("Failed to load blink-git-commit source", {
			"Error: " .. tostring(source)
		})
	end

	-- Check if we're in a git repository
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")
	if vim.v.shell_error == 0 and #git_root > 0 then
		health.ok("Currently in a git repository: " .. git_root[1])
	else
		health.warn("Not currently in a git repository", {
			"Scope auto-detection will not work outside of git repositories"
		})
	end

	-- Check filetype detection
	if vim.bo.filetype == "gitcommit" then
		health.ok("Currently editing a git commit message")
	else
		health.info("Not currently editing a git commit message (filetype: " .. vim.bo.filetype .. ")")
	end

	-- Check trigger characters
	if has_source then
		local instance = source.new({})
		local triggers = instance:get_trigger_characters()
		health.info("Trigger characters: " .. table.concat(triggers, ", "))
	end
end

return M

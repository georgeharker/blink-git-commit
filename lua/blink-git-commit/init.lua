
--- @class blink-git-commit.Options
--- @field prefixes? table[]
--- @field scopes? string[]
--- @field auto_detect_scopes? boolean
--- @field breaking_changes? boolean
--- @field min_chars? number
--- @field item_kind? number
--- @field show_documentation? boolean

--- @class GitCommitSource
--- @field opts blink-git-commit.Options
--- @field cached_results boolean
--- @field completion_items table[]

local async = require("blink.cmp.lib.async")

--- @param description string
--- @return { kind: string, value: string }
local function setup_item_docs(prefix, description)
	return {
		kind = "markdown",
		value = string.format("# `%s`\n\n%s", prefix, description),
	}
end

--- Detect scopes from current git repository structure
--- @return string[]
local function detect_git_scopes()
	local scopes = {}

	-- Get git root directory
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 then
		return {}
	end

	-- Common directories that often represent scopes
	local common_scope_dirs = {
		"src", "lib", "api", "ui", "components", "utils", "auth", "db",
		"config", "docs", "tests", "scripts", "assets", "styles"
	}

	for _, dir in ipairs(common_scope_dirs) do
		local full_path = git_root .. "/" .. dir
		if vim.fn.isdirectory(full_path) == 1 then
			table.insert(scopes, dir)
		end
	end

	-- Also check for package.json to get project-specific scopes
	local package_json = git_root .. "/package.json"
	if vim.fn.filereadable(package_json) == 1 then
		local ok, content = pcall(vim.fn.readfile, package_json)
		if ok then
			local json_str = table.concat(content, "\n")
			-- Simple pattern matching for common scope indicators
			for scope in json_str:gmatch('"([^"]+)":') do
				if scope:match("^[a-z][a-z0-9-]*$") and #scope <= 15 then
					if not vim.tbl_contains(scopes, scope) then
						table.insert(scopes, scope)
					end
				end
			end
		end
	end

	return scopes
end

local M = {}

--- @param opts? blink-git-commit.Options
--- @return GitCommitSource
function M.new(opts)
	vim.validate { opts = { opts, "table", true } }
	opts = opts or {}

	local default_opts = {
		prefixes = {
			{ prefix = "feat:", description = "A new feature for the user" },
			{ prefix = "fix:", description = "A bug fix for the user" },
			{ prefix = "docs:", description = "Documentation changes" },
			{ prefix = "style:", description = "Code style changes (formatting, missing semi colons, etc)" },
			{ prefix = "refactor:", description = "Code refactoring without changing functionality" },
			{ prefix = "perf:", description = "Performance improvements" },
			{ prefix = "test:", description = "Adding missing tests or correcting existing tests" },
			{ prefix = "build:", description = "Changes that affect the build system or external dependencies" },
			{ prefix = "ci:", description = "Changes to CI configuration files and scripts" },
			{ prefix = "chore:", description = "Other changes that don't modify src or test files" },
			{ prefix = "revert:", description = "Reverts a previous commit" }
		},
		scopes = {
			"api", "ui", "auth", "db", "config", "deps", "docs", "core", "utils"
		},
		auto_detect_scopes = true,
		breaking_changes = true,
		min_chars = 0,
		item_kind = require("blink.cmp.types").CompletionItemKind.Keyword,
		show_documentation = true,
	}

	--- @type GitCommitSource
	local self = setmetatable({}, { __index = M })

	self.opts = vim.tbl_deep_extend("force", default_opts, opts)
	self.cached_results = false
	self.completion_items = {}

	return self
end

--- Check if we're in a git commit file
--- @return boolean
function M:is_available()
	return vim.bo.filetype == "gitcommit"
end

--- @return string[]
function M:get_trigger_characters()
	return { ":", "(", "!" }
end

--- @param ctx table
--- @param callback fun(...: any)
--- @return fun()
function M:get_completions(ctx, callback)
	local task = async.task.empty():map(function()
		-- Only provide completions for gitcommit filetype
		if not self:is_available() then
			callback()
			return function() end
		end

		-- Check if we meet minimum character requirement
		local current_line = ctx.line
		local cursor_col = ctx.cursor[2]
		local before_cursor = current_line:sub(1, cursor_col)

		if #before_cursor < self.opts.min_chars then
			callback()
			return function() end
		end

		if not self.cached_results then
			self:setup_completion_items()
			self.cached_results = true
		end

		-- Filter items based on what user has typed
		local filtered_items = {}
		local input = before_cursor:lower()

		for _, item in ipairs(self.completion_items) do
			local label_lower = item.label:lower()
			if label_lower:find(input, 1, true) == 1 or input == "" then
				table.insert(filtered_items, item)
			end
		end

		callback({
			is_incomplete_forward = false,
			is_incomplete_backward = false,
			items = filtered_items,
		})

		return function() end
	end)

	return function()
		task:cancel()
	end
end

function M:setup_completion_items()
	local items = {}

	-- Get scopes (auto-detect if enabled)
	local scopes = {}
	if self.opts.auto_detect_scopes then
		local detected_scopes = detect_git_scopes()
		scopes = vim.tbl_extend("force", self.opts.scopes or {}, detected_scopes)
	else
		scopes = self.opts.scopes or {}
	end

	-- Remove duplicates and sort
	local unique_scopes = {}
	for _, scope in ipairs(scopes) do
		if not vim.tbl_contains(unique_scopes, scope) then
			table.insert(unique_scopes, scope)
		end
	end
	table.sort(unique_scopes)

	-- Add basic prefixes
	for _, prefix_config in ipairs(self.opts.prefixes) do
		local prefix = prefix_config.prefix
		local description = prefix_config.description
		local documentation = self.opts.show_documentation
			and setup_item_docs(prefix, description)
			or nil

		table.insert(items, {
			label = prefix,
			insertText = prefix .. " ",
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			kind = self.opts.item_kind,
			documentation = documentation,
			sortText = "1" .. prefix, -- Higher priority
		})

		-- Add breaking change variants if enabled
		if self.opts.breaking_changes then
			local breaking_prefix = prefix:gsub(":", "!:")
			table.insert(items, {
				label = breaking_prefix,
				insertText = breaking_prefix .. " ",
				insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
				kind = self.opts.item_kind,
				documentation = self.opts.show_documentation
					and setup_item_docs(breaking_prefix, "⚠️  BREAKING CHANGE: " .. description)
					or nil,
				sortText = "2" .. breaking_prefix, -- Lower priority than basic prefixes
			})
		end
	end

	-- Add scoped versions
	for _, prefix_config in ipairs(self.opts.prefixes) do
		local prefix = prefix_config.prefix
		local description = prefix_config.description
		for _, scope in ipairs(unique_scopes) do
			local base_prefix = prefix:gsub(":", "")
			local scoped_label = string.format("%s(%s):", base_prefix, scope)
			local scoped_insert = string.format("%s(%s): ", base_prefix, scope)

			table.insert(items, {
				label = scoped_label,
				insertText = scoped_insert,
				insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
				kind = self.opts.item_kind,
				documentation = self.opts.show_documentation
					and setup_item_docs(scoped_label, string.format("Scoped %s (%s)", description, scope))
					or nil,
				sortText = "3" .. scoped_label, -- Lowest priority
			})

			-- Add breaking change scoped versions if enabled
			if self.opts.breaking_changes then
				local breaking_scoped_label = string.format("%s(%s)!:", base_prefix, scope)
				local breaking_scoped_insert = string.format("%s(%s)!: ", base_prefix, scope)

				table.insert(items, {
					label = breaking_scoped_label,
					insertText = breaking_scoped_insert,
					insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
					kind = self.opts.item_kind,
					documentation = self.opts.show_documentation
						and setup_item_docs(breaking_scoped_label, string.format("⚠️  BREAKING CHANGE: Scoped %s (%s)", description, scope))
						or nil,
					sortText = "4" .. breaking_scoped_label,
				})
			end
		end
	end

	self.completion_items = items
end

return M

--- vim:ts=4:sts=4:sw=0:noet:

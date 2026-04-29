--- @class blink-cmp-git-commit.Options
--- @field prefixes? table[]
--- @field scopes? string[]
--- @field auto_detect_scopes? boolean
--- @field breaking_changes? boolean
--- @field min_chars? number
--- @field show_documentation? boolean
--- @field type_kind_name? string Kind name registered for type items (default "GitCommit")
--- @field scope_kind_name? string Kind name registered for scope items (default "GitCommitScope")
--- @field kind_icons? table<string, string> Default icons per kind name; injected into appearance.kind_icons only for keys not already set

--- @class GitCommitSource
--- @field opts blink-cmp-git-commit.Options
--- @field type_items table[]
--- @field scope_items table[]
--- @field close_items table[]

local async = require("blink.cmp.lib.async")
local types = require("blink.cmp.types")

--- @param prefix string
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

	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 then
		return {}
	end

	local common_scope_dirs = {
		"src", "lib", "api", "ui", "components", "utils", "auth", "db",
		"config", "docs", "tests", "scripts", "assets", "styles",
	}

	for _, dir in ipairs(common_scope_dirs) do
		local full_path = git_root .. "/" .. dir
		if vim.fn.isdirectory(full_path) == 1 then
			table.insert(scopes, dir)
		end
	end

	local package_json = git_root .. "/package.json"
	if vim.fn.filereadable(package_json) == 1 then
		local ok, content = pcall(vim.fn.readfile, package_json)
		if ok then
			local json_str = table.concat(content, "\n")
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

local default_kind_icons = {
	GitCommit      = "󰊢",
	GitCommitScope = "󰉋",
}

--- Register a custom kind name on blink.cmp.types.CompletionItemKind, returning
--- its integer id. Idempotent: re-registering an existing name returns the
--- existing id without appending a duplicate.
--- @param kind_name string
--- @return integer
local function register_kind(kind_name)
	if types.CompletionItemKind[kind_name] then
		return types.CompletionItemKind[kind_name]
	end
	local id = #types.CompletionItemKind + 1
	types.CompletionItemKind[id] = kind_name
	types.CompletionItemKind[kind_name] = id
	return id
end

--- Inject default kind icons into blink.cmp's appearance config — only for
--- keys not already present, so user config wins. Safe no-op if blink config
--- isn't accessible.
--- @param icons table<string, string>
local function inject_default_kind_icons(icons)
	local ok, conf = pcall(require, "blink.cmp.config")
	if not ok then
		return
	end
	local kind_icons = conf.appearance and conf.appearance.kind_icons
	if type(kind_icons) ~= "table" then
		return
	end
	for name, icon in pairs(icons) do
		if kind_icons[name] == nil then
			kind_icons[name] = icon
		end
	end
end

--- Register a default-linked highlight group for the kind so users get a
--- sensible group name without us overriding their colorscheme.
--- @param kind_name string
local function register_kind_highlight(kind_name)
	vim.api.nvim_set_hl(0, "BlinkCmpKind" .. kind_name, { link = "BlinkCmpKind", default = true })
end

local M = {}

--- @param opts? blink-cmp-git-commit.Options
--- @return GitCommitSource
function M.new(opts)
	vim.validate { opts = { opts, "table", true } }
	opts = opts or {}

	local default_opts = {
		prefixes = {
			{ prefix = "feat", description = "A new feature for the user" },
			{ prefix = "fix", description = "A bug fix for the user" },
			{ prefix = "docs", description = "Documentation changes" },
			{ prefix = "style", description = "Code style changes (formatting, missing semi colons, etc)" },
			{ prefix = "refactor", description = "Code refactoring without changing functionality" },
			{ prefix = "perf", description = "Performance improvements" },
			{ prefix = "test", description = "Adding missing tests or correcting existing tests" },
			{ prefix = "build", description = "Changes that affect the build system or external dependencies" },
			{ prefix = "ci", description = "Changes to CI configuration files and scripts" },
			{ prefix = "chore", description = "Other changes that don't modify src or test files" },
			{ prefix = "revert", description = "Reverts a previous commit" },
		},
		scopes = {
			"api", "ui", "auth", "db", "config", "deps", "docs", "core", "utils",
		},
		auto_detect_scopes = true,
		breaking_changes = true,
		min_chars = 0,
		show_documentation = true,
		type_kind_name = "GitCommit",
		scope_kind_name = "GitCommitScope",
		kind_icons = default_kind_icons,
	}

	--- @type GitCommitSource
	local self = setmetatable({}, { __index = M })
	self.opts = vim.tbl_deep_extend("force", default_opts, opts)
	self.type_items = {}
	self.scope_items = {}

	self.type_kind = register_kind(self.opts.type_kind_name)
	self.scope_kind = register_kind(self.opts.scope_kind_name)
	register_kind_highlight(self.opts.type_kind_name)
	register_kind_highlight(self.opts.scope_kind_name)
	inject_default_kind_icons(self.opts.kind_icons or {})

	self:setup_completion_items()

	return self
end

--- @return boolean
function M:is_available()
	return vim.bo.filetype == "gitcommit"
end

--- @return string[]
function M:get_trigger_characters()
	return { ":", "(", ")", "!" }
end

--- Build the BREAKING CHANGE footer item, optionally adding `!` to the
--- subject line via additionalTextEdits when missing.
--- @return table
function M:make_breaking_footer_item()
	local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
	local item = {
		label = "BREAKING CHANGE",
		insertText = "BREAKING CHANGE: ",
		insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
		kind = self.type_kind,
		documentation = self.opts.show_documentation
			and setup_item_docs("BREAKING CHANGE", "Mark this commit as introducing a breaking change.")
			or nil,
	}

	if not first_line:match("!:") then
		local colon_pos = first_line:find(":")
		if colon_pos ~= nil then
			item.additionalTextEdits = {
				{
					range = {
						start = { line = 0, character = colon_pos - 1 },
						["end"] = { line = 0, character = colon_pos - 1 },
					},
					newText = "!",
				},
			}
		end
	end

	return item
end

--- @param ctx table
--- @param callback fun(...: any)
--- @return fun()
function M:get_completions(ctx, callback)
	local task = async.task.empty():map(function()
		if not self:is_available() then
			callback()
			return function() end
		end

		local row = ctx.cursor[1]
		local col = ctx.cursor[2]
		local before_cursor = ctx.line:sub(1, col)

		if #before_cursor < self.opts.min_chars then
			callback()
			return function() end
		end

		-- Once a space has been typed on the current line, the user is into
		-- subject text or a footer value — stop offering completions.
		if before_cursor:find("%s") then
			callback({ items = {} })
			return function() end
		end

		local items = {}
		if row == 1 and before_cursor:match("^%w+%([^)]*$") then
			-- Inside `type(...)` — offer scope names.
			items = self.scope_items
		elseif row == 1 and before_cursor:match("^%w+%([^)]*%)$") then
			-- After closing paren `type(scope)` — offer terminator.
			items = self.close_items
		elseif row == 1 and not before_cursor:find("[():]") then
			-- Start of subject — offer commit types.
			items = self.type_items
		elseif row > 1 and self.opts.breaking_changes then
			-- Footer area — offer BREAKING CHANGE.
			items = { self:make_breaking_footer_item() }
		end

		callback({
			is_incomplete_forward = false,
			is_incomplete_backward = false,
			items = vim.deepcopy(items),
		})

		return function() end
	end)

	return function()
		task:cancel()
	end
end

function M:setup_completion_items()
	-- Build type items. Each conventional-commit type yields up to three completions:
	--   feat:      — type, no scope, ready for subject
	--   feat(      — type, opens scope (cursor inside parens triggers scope_items)
	--   feat!:     — type with breaking-change marker (only if breaking_changes)
	-- Prefix is normalized to strip a trailing `:` so callers may supply either
	-- "feat" or "feat:" in opts.prefixes.
	local type_items = {}
	for _, prefix_config in ipairs(self.opts.prefixes) do
		local prefix = (prefix_config.prefix or ""):gsub(":$", "")
		local description = prefix_config.description

		table.insert(type_items, {
			label = prefix .. ":",
			insertText = prefix .. ": ",
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			kind = self.type_kind,
			documentation = self.opts.show_documentation
				and setup_item_docs(prefix .. ":", description)
				or nil,
			sortText = "1" .. prefix,
		})

		table.insert(type_items, {
			label = prefix .. "(",
			insertText = prefix .. "(",
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			kind = self.type_kind,
			documentation = self.opts.show_documentation
				and setup_item_docs(prefix .. "(scope):", "Scoped " .. description)
				or nil,
			sortText = "2" .. prefix,
		})

		if self.opts.breaking_changes then
			table.insert(type_items, {
				label = prefix .. "!:",
				insertText = prefix .. "!: ",
				insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
				kind = self.type_kind,
				documentation = self.opts.show_documentation
					and setup_item_docs(prefix .. "!:", "BREAKING CHANGE: " .. description)
					or nil,
				sortText = "3" .. prefix,
			})
		end
	end
	self.type_items = type_items

	-- Build close items, offered after `type(scope)` to terminate the prefix.
	local close_items = {
		{
			label = ":",
			insertText = ": ",
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			kind = self.type_kind,
			documentation = self.opts.show_documentation
				and setup_item_docs(":", "End scoped prefix")
				or nil,
			sortText = "1",
		},
	}
	if self.opts.breaking_changes then
		table.insert(close_items, {
			label = "!:",
			insertText = "!: ",
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			kind = self.type_kind,
			documentation = self.opts.show_documentation
				and setup_item_docs("!:", "End scoped prefix as a BREAKING CHANGE")
				or nil,
			sortText = "2",
		})
	end
	self.close_items = close_items

	-- Build scope items (bare scope names; closing `)` is left to the user)
	local scopes
	if self.opts.auto_detect_scopes then
		scopes = vim.tbl_extend("force", self.opts.scopes or {}, detect_git_scopes())
	else
		scopes = self.opts.scopes or {}
	end

	local seen = {}
	local unique_scopes = {}
	for _, scope in ipairs(scopes) do
		if not seen[scope] then
			seen[scope] = true
			table.insert(unique_scopes, scope)
		end
	end
	table.sort(unique_scopes)

	local scope_items = {}
	for _, scope in ipairs(unique_scopes) do
		table.insert(scope_items, {
			label = scope,
			insertText = scope,
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			kind = self.scope_kind,
		})
	end
	self.scope_items = scope_items
end

return M

--- vim:ts=4:sts=4:sw=0:noet:

-- Example blink.cmp configuration with git-commit source

require('blink.cmp').setup({
	-- Appearance
	appearance = {
		use_nvim_cmp_as_default = true,
		nerd_font_variant = 'mono'
	},

	-- Sources configuration
	sources = {
		-- Default sources for most filetypes
		default = { 'lsp', 'path', 'snippets', 'buffer' },

		-- Per-filetype sources
		per_filetype = {
			gitcommit = { 'git-commit', 'buffer' }
		},

		-- Provider configurations
		providers = {
			-- Git commit completion source
			['git-commit'] = {
				name = 'git-commit',
				module = 'blink-cmp-git-commit',
				opts = {
					-- Customize commit prefixes
					prefixes = {
						'feat:', 'fix:', 'docs:', 'style:', 'refactor:',
						'perf:', 'test:', 'build:', 'ci:', 'chore:', 'revert:'
					},

					-- Manual scopes (combined with auto-detected ones)
					scopes = {
						'api', 'ui', 'auth', 'db', 'config', 'deps', 'docs'
					},

					-- Auto-detect scopes from project structure
					auto_detect_scopes = true,

					-- Include breaking change variants (feat!:, fix!:, etc.)
					breaking_changes = true,

					-- Show helpful documentation
					show_documentation = true,

					-- Start suggesting immediately
					min_chars = 0
				}
			},

			-- Other providers...
			lsp = { name = 'LSP' },
			path = { name = 'Path', score_offset = 3 },
			snippets = { name = 'Snippets' },
			buffer = { name = 'Buffer', fallback_for = { 'lsp' } }
		}
	},

	-- Completion menu configuration
	completion = {
		accept = {
			auto_brackets = {
				enabled = true,
			},
		},
		menu = {
			draw = {
				treesitter = { 'lsp' }
			}
		},
		documentation = {
			auto_show = true,
			auto_show_delay = 500
		},
		ghost_text = {
			enabled = vim.g.ai_cmp == nil
		}
	},

	-- Signature help
	signature = {
		enabled = true
	}
})

-- Optional: Set up an autocmd to ensure the source is only used for git commits
vim.api.nvim_create_autocmd('FileType', {
	pattern = 'gitcommit',
	callback = function()
		-- You can add any additional git commit specific configuration here
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 72
	end
})

-- Example configuration showing how to customize prefixes with descriptions
-- and add custom commit types for your specific workflow

require('blink.cmp').setup({
  sources = {
    default = { 'lsp', 'path', 'snippets', 'buffer', 'git-commit' },
    providers = {
      ['git-commit'] = {
        name = 'git-commit',
        module = 'blink-git-commit',
        opts = {
          -- Custom prefixes with your own descriptions
          prefixes = {
            -- Standard conventional commits
            { prefix = 'feat:', description = 'A new feature for the user' },
            { prefix = 'fix:', description = 'A bug fix for the user' },
            { prefix = 'docs:', description = 'Documentation changes' },
            { prefix = 'style:', description = 'Code style changes (formatting, missing semi colons, etc)' },
            { prefix = 'refactor:', description = 'Code refactoring without changing functionality' },
            { prefix = 'perf:', description = 'Performance improvements' },
            { prefix = 'test:', description = 'Adding missing tests or correcting existing tests' },
            { prefix = 'build:', description = 'Changes that affect the build system or external dependencies' },
            { prefix = 'ci:', description = 'Changes to CI configuration files and scripts' },
            { prefix = 'chore:', description = 'Other changes that don\'t modify src or test files' },
            { prefix = 'revert:', description = 'Reverts a previous commit' },

            -- Custom commit types for your team/project
            { prefix = 'hotfix:', description = 'Critical production fixes that need immediate deployment' },
            { prefix = 'wip:', description = 'Work in progress - incomplete changes that will be amended' },
            { prefix = 'security:', description = 'Security-related changes and vulnerability fixes' },
            { prefix = 'deps:', description = 'Dependency updates and package management' },
            { prefix = 'config:', description = 'Configuration file changes' },
            { prefix = 'deploy:', description = 'Deployment and infrastructure related changes' },
          },

          -- Custom scopes for your project structure
          scopes = {
            'frontend', 'backend', 'database', 'auth', 'api', 'ui', 'admin',
            'mobile', 'web', 'shared', 'common', 'utils', 'tools', 'scripts'
          },

          -- Enable auto-detection to combine with manual scopes
          auto_detect_scopes = true,

          -- Enable breaking changes support
          breaking_changes = true,

          -- Show completions immediately
          min_chars = 0,

          -- Show helpful documentation
          show_documentation = true,
        }
      }
    }
  }
})

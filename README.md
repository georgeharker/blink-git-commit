# blink-git-commit.nvim

A comprehensive [blink.cmp](https://github.com/Saghen/blink.cmp) completion source for git commit messages, providing intelligent suggestions for conventional commit formats.

## Features

- 🎯 **Conventional Commit Prefixes**: Complete common prefixes like `feat:`, `fix:`, `chore:`, etc.
- 🎯 **Scoped Commits**: Intelligent scope suggestions based on project structure
- 🎯 **Breaking Changes**: Support for `!` breaking change indicators  
- 🎯 **Context Aware**: Only activates in git commit messages (`gitcommit` filetype)
- 🎯 **Auto-detection**: Automatically detects project scopes from directory structure
- 🎯 **Customizable**: Configure prefixes, scopes, and behavior to match your workflow

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-username/blink-git-commit.nvim',
  dependencies = { 'saghen/blink.cmp' },
  opts = {}
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/blink-git-commit.nvim',
  requires = { 'saghen/blink.cmp' },
}
```

## Configuration

Add the source to your blink.cmp configuration:

```lua
require('blink.cmp').setup({
  sources = {
    default = { 'lsp', 'path', 'snippets', 'buffer', 'git-commit' },
    providers = {
      ['git-commit'] = {
        name = 'git-commit',
        module = 'blink-git-commit',
        opts = {
          -- Configuration options (see below)
        }
      }
    }
  }
})
```

### Options

```lua
require('blink.cmp').setup({
  sources = {
    providers = {
      ['git-commit'] = {
        name = 'git-commit',
        module = 'blink-git-commit',
        opts = {
          -- Commit type prefixes with configurable descriptions
          -- Each prefix is defined with both the prefix text and its description
          -- Commit type prefixes
          prefixes = {
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
            { prefix = 'revert:', description = 'Reverts a previous commit' }
          },
          
          -- Manual scopes (used when auto_detect_scopes is false or as fallback)
          scopes = {
            'api', 'ui', 'auth', 'db', 'config', 'deps', 'docs', 'core', 'utils'
          },
          
          -- Auto-detect scopes from project directory structure
          auto_detect_scopes = true,
          
          -- Include breaking change indicator (!)
          breaking_changes = true,
          
          -- Minimum characters before showing completions
          min_chars = 0,
          
          -- Show documentation for each completion item
          show_documentation = true,
          
          -- Completion item kind (see blink.cmp types)
          item_kind = require('blink.cmp.types').CompletionItemKind.Keyword
        }
      }
    }
  }
})
```

## Usage

When editing a git commit message, the plugin will automatically provide completions:

- Type `f` → suggests `feat:`, `fix:`
- Type `feat` → suggests `feat:`, `feat!:`, `feat(scope):`
- Type `feat(` → suggests scoped versions like `feat(api):`, `feat(ui):`
- Type `feat!` → suggests `feat!:` for breaking changes

## Examples

The plugin helps you write conventional commits like:

```
feat: add user authentication system
fix(api): resolve login endpoint timeout issue  
docs: update installation guide
feat!: change API response format
chore(deps): update dependencies to latest versions
perf(db): optimize database queries
test(auth): add unit tests for login flow
```

## Scope Auto-detection

When `auto_detect_scopes` is enabled (default), the plugin will automatically detect potential scopes from your project structure by looking for:

- Common directories: `src`, `lib`, `api`, `ui`, `components`, `utils`, `auth`, `db`, `config`, `docs`, `tests`, `scripts`, `assets`, `styles`
- Package.json entries (for JavaScript/Node.js projects)

These auto-detected scopes are combined with your manually configured scopes.

## Conventional Commits

This plugin follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Where `type` is one of:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **build**: Changes that affect the build system or external dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

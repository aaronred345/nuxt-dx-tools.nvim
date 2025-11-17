# Nuxt DX Tools Language Server

A Language Server Protocol (LSP) implementation for Nuxt projects that provides intelligent code navigation, auto-completion, and hover information for Nuxt-specific features.

**Works with any LSP-compatible editor**: Neovim, VSCode, Sublime Text, Emacs, Vim, and more!

## Features

- 🎯 **Goto Definition** for auto-imported components, composables, and utilities
- 📝 **Hover Information** with documentation and usage examples
- ✨ **Auto-completion** for imports, path aliases, layouts, and middleware
- 🔍 **Virtual Module Resolution** (`#imports`, `#app`, `#build`, `#components`)
- 🛣️ **API Route Navigation** - Jump from `$fetch('/api/users')` to handler file
- 📄 **Page Route Navigation** - Jump from `navigateTo('/about')` to page file
- ⚙️ **definePageMeta Support** - Navigate to layouts and middleware
- 🗂️ **Path Alias Resolution** - Full `tsconfig.json` parsing with references
- 🧩 **Nuxt 3 & 4 Support** - Automatic structure detection

## Installation

**Works with all major Node.js package managers!**

### Global Installation (Recommended)

Choose your preferred package manager:

```bash
# npm
npm install -g nuxt-dx-tools-lsp

# pnpm (faster, more efficient)
pnpm add -g nuxt-dx-tools-lsp

# yarn
yarn global add nuxt-dx-tools-lsp

# bun (fastest)
bun add -g nuxt-dx-tools-lsp
```

Then the `nuxt-dx-tools-lsp` command will be available globally.

### Local Installation

```bash
# npm
npm install nuxt-dx-tools-lsp

# pnpm
pnpm add nuxt-dx-tools-lsp

# yarn
yarn add nuxt-dx-tools-lsp

# bun
bun add nuxt-dx-tools-lsp
```

Then use the appropriate runner:
- **npm**: `npx nuxt-dx-tools-lsp`
- **pnpm**: `pnpm exec nuxt-dx-tools-lsp`
- **yarn**: `yarn nuxt-dx-tools-lsp`
- **bun**: `bunx nuxt-dx-tools-lsp`

### From Source

```bash
git clone https://github.com/aaronred345/nuxt-dx-tools.nvim.git
cd nuxt-dx-tools.nvim/lsp-server

# The install script auto-detects your package manager
npm install    # or: pnpm install, yarn install, bun install
```

The build process automatically detects and works with whichever package manager you're using!

## Usage

The LSP server communicates via stdio and follows the Language Server Protocol specification.

### Command

```bash
nuxt-dx-tools-lsp --stdio
```

## Editor Setup

### Neovim

#### With nvim-lspconfig

```lua
require('lspconfig').nuxt_dx_tools.setup{}
```

#### With the Neovim plugin (includes additional features)

```lua
-- Install: aaronred345/nuxt-dx-tools.nvim
require('nuxt-dx-tools').setup()
```

See [Neovim Installation Guide](../INSTALLATION.md) for details.

### VSCode

Install the companion VSCode extension (coming soon) or configure manually:

```json
{
  "languageServerExample.server": {
    "command": "nuxt-dx-tools-lsp",
    "args": ["--stdio"],
    "filetypes": ["vue", "typescript", "javascript"]
  }
}
```

### Sublime Text

Add to LSP settings:

```json
{
  "clients": {
    "nuxt-dx-tools": {
      "enabled": true,
      "command": ["nuxt-dx-tools-lsp", "--stdio"],
      "selector": "source.vue | source.ts | source.js"
    }
  }
}
```

### Emacs (lsp-mode)

```elisp
(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection '("nuxt-dx-tools-lsp" "--stdio"))
  :major-modes '(vue-mode typescript-mode javascript-mode)
  :server-id 'nuxt-dx-tools))
```

### Vim (vim-lsp)

```vim
if executable('nuxt-dx-tools-lsp')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'nuxt-dx-tools',
    \ 'cmd': {server_info->['nuxt-dx-tools-lsp', '--stdio']},
    \ 'whitelist': ['vue', 'typescript', 'javascript'],
    \ })
endif
```

### Helix

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "vue"
language-servers = ["volar", "nuxt-dx-tools"]

[[language]]
name = "typescript"
language-servers = ["typescript-language-server", "nuxt-dx-tools"]

[language-server.nuxt-dx-tools]
command = "nuxt-dx-tools-lsp"
args = ["--stdio"]
```

## LSP Capabilities

The server implements the following LSP methods:

- `textDocument/definition` - Goto definition
- `textDocument/hover` - Hover information
- `textDocument/completion` - Auto-completion
- `textDocument/codeAction` - Code actions (planned)
- `textDocument/publishDiagnostics` - Diagnostics (planned)

## How It Works

The LSP server:

1. **Parses `tsconfig.json`** to understand path aliases and project structure
2. **Reads `.nuxt/*.d.ts`** files to discover auto-imported components and composables
3. **Detects Nuxt 3 vs Nuxt 4** structure automatically
4. **Caches** parsed data with TTL for performance
5. **Provides intelligent navigation** for Nuxt-specific patterns

## Requirements

- Node.js >= 18.0.0
- A Nuxt 3 or Nuxt 4 project with `.nuxt/` directory (run `nuxt dev` or `nuxt build` to generate)

## Multiple LSP Servers

This LSP server is designed to work **alongside** other language servers like:

- **volar** / **vue-language-server** - For Vue.js and TypeScript support
- **tsserver** / **vtsls** - For TypeScript support

The servers complement each other:
- Nuxt DX Tools handles Nuxt-specific features
- Volar/tsserver handle general TypeScript/Vue features

All results are merged by your editor.

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run watch

# Test
npm test
```

## Troubleshooting

### Server not starting

Check if Node.js is installed:
```bash
node --version  # Should be >= 18.0.0
```

### No completions/definitions

Make sure you're in a Nuxt project with a `.nuxt/` directory:
```bash
ls .nuxt/  # Should contain imports.d.ts, components.d.ts, etc.
```

If missing, build your Nuxt project:
```bash
nuxt dev  # or nuxt build
```

### Server crashes

Enable LSP logging in your editor to see error messages.

## License

MIT

## Links

- [GitHub Repository](https://github.com/aaronred345/nuxt-dx-tools.nvim)
- [Issue Tracker](https://github.com/aaronred345/nuxt-dx-tools.nvim/issues)
- [Neovim Plugin](https://github.com/aaronred345/nuxt-dx-tools.nvim)

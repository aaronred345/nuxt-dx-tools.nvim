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

### From Source

```bash
git clone https://github.com/aaronred345/nuxt-dx-tools.nvim.git
cd nuxt-dx-tools.nvim/lsp-server

# Install dependencies (works with npm, pnpm, yarn, or bun)
npm install

# Build the LSP server
npm run build
```

After building, the server executable will be at `dist/server.js`.

### Verify Installation

```bash
# Test the server starts
node dist/server.js --stdio

# You should see: "Nuxt DX Tools Language Server started"
# Press Ctrl+C to exit
```

## Editor Setup

The LSP server works with any editor that supports the Language Server Protocol. Below are detailed setup instructions for popular editors.

### Neovim

#### Option 1: With the Neovim Plugin (Recommended)

The easiest way is to use the full Neovim plugin, which includes the LSP server plus additional Lua-based features:

```lua
-- Using lazy.nvim
{
  'aaronred345/nuxt-dx-tools.nvim',
  ft = { 'vue', 'typescript', 'javascript' },
  config = function()
    require('nuxt-dx-tools').setup({
      -- The plugin handles LSP server setup automatically
      lsp = {
        enabled = true,  -- Enable LSP integration
      }
    })
  end
}
```

See the [main README](../README.md) for full plugin installation details.

#### Option 2: Manual LSP Setup with nvim-lspconfig

If you only want the LSP server without the Neovim plugin:

```lua
-- In your Neovim config (e.g., ~/.config/nvim/lua/lsp.lua)
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

-- Register the server if not already registered
if not configs.nuxt_dx_tools then
  configs.nuxt_dx_tools = {
    default_config = {
      cmd = { 'node', '/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js', '--stdio' },
      filetypes = { 'vue', 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
      root_dir = lspconfig.util.root_pattern('nuxt.config.ts', 'nuxt.config.js', '.nuxt'),
      settings = {},
    },
  }
end

-- Start the server
lspconfig.nuxt_dx_tools.setup({
  on_attach = function(client, bufnr)
    -- Your keybindings here
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = bufnr })
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr })
  end,
})
```

**Note:** Replace `/path/to/nuxt-dx-tools.nvim` with the actual path where you cloned the repository.

#### Option 3: Create a Symlink (Advanced)

Make the server globally accessible:

```bash
# From the lsp-server directory
sudo ln -s $(pwd)/dist/server.js /usr/local/bin/nuxt-dx-tools-lsp
sudo chmod +x /usr/local/bin/nuxt-dx-tools-lsp

# Then use simplified config:
cmd = { 'nuxt-dx-tools-lsp', '--stdio' }
```

### VSCode

#### Manual Configuration

1. Install the [Custom Local Language Server](https://marketplace.visualstudio.com/items?itemName=nnixaa.custom-local-language-server) extension

2. Add to your VSCode settings (`.vscode/settings.json` or user settings):

```json
{
  "customLocalLanguageServer.servers": [
    {
      "name": "Nuxt DX Tools",
      "command": "node",
      "args": [
        "/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js",
        "--stdio"
      ],
      "filetypes": ["vue", "typescript", "javascript", "typescriptreact", "javascriptreact"]
    }
  ]
}
```

**Note:** Replace `/path/to/nuxt-dx-tools.nvim` with the actual path.

#### Verify in VSCode

1. Open a `.vue` file in your Nuxt project
2. Open Command Palette (Cmd/Ctrl+Shift+P)
3. Search for "Developer: Show Running Extensions"
4. Look for "Nuxt DX Tools" in the language servers list

### Sublime Text

Requires [LSP package](https://packagecontrol.io/packages/LSP) installed.

1. Install LSP via Package Control: `Cmd/Ctrl+Shift+P` → "Install Package" → "LSP"

2. Go to Preferences → Package Settings → LSP → Settings

3. Add to your LSP settings:

```json
{
  "clients": {
    "nuxt-dx-tools": {
      "enabled": true,
      "command": [
        "node",
        "/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js",
        "--stdio"
      ],
      "selector": "source.vue | source.ts | source.js | source.tsx | source.jsx",
      "settings": {}
    }
  }
}
```

4. Restart Sublime Text

5. Open a Nuxt project and verify in the status bar: "LSP: nuxt-dx-tools"

### Emacs (lsp-mode)

Add to your Emacs configuration:

```elisp
;; In your init.el or lsp configuration
(require 'lsp-mode)

(add-to-list 'lsp-language-id-configuration '(vue-mode . "vue"))
(add-to-list 'lsp-language-id-configuration '(typescript-mode . "typescript"))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection
                   '("node"
                     "/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js"
                     "--stdio"))
  :activation-fn (lsp-activate-on "vue" "typescript" "javascript")
  :major-modes '(vue-mode typescript-mode javascript-mode)
  :priority 0
  :server-id 'nuxt-dx-tools))

;; Enable in Vue files
(add-hook 'vue-mode-hook #'lsp)
(add-hook 'typescript-mode-hook #'lsp)
```

**Verify:** Open a `.vue` file and check the modeline shows "LSP[nuxt-dx-tools]"

### Vim (vim-lsp)

Requires [vim-lsp](https://github.com/prabirshrestha/vim-lsp) plugin.

Add to your `.vimrc` or `init.vim`:

```vim
" Register the LSP server
if executable('node')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'nuxt-dx-tools',
    \ 'cmd': {server_info->['node', '/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js', '--stdio']},
    \ 'allowlist': ['vue', 'typescript', 'javascript', 'typescriptreact', 'javascriptreact'],
    \ 'workspace_config': {},
    \ })
endif

" Enable LSP for Vue files
augroup lsp_nuxt
  autocmd!
  autocmd BufNewFile,BufRead *.vue setlocal filetype=vue
  autocmd FileType vue,typescript,javascript call s:on_lsp_buffer_enabled()
augroup END

function! s:on_lsp_buffer_enabled() abort
  setlocal omnifunc=lsp#complete
  nmap <buffer> gd <plug>(lsp-definition)
  nmap <buffer> K <plug>(lsp-hover)
endfunction
```

### Helix

Add to `~/.config/helix/languages.toml`:

```toml
# Configure the server
[language-server.nuxt-dx-tools]
command = "node"
args = ["/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js", "--stdio"]

# Attach to Vue files (alongside Volar)
[[language]]
name = "vue"
language-servers = ["volar", "nuxt-dx-tools"]

# Attach to TypeScript files (alongside tsserver)
[[language]]
name = "typescript"
language-servers = ["typescript-language-server", "nuxt-dx-tools"]

# Attach to JavaScript files
[[language]]
name = "javascript"
language-servers = ["typescript-language-server", "nuxt-dx-tools"]
```

**Verify:** Run `:log-open` in Helix and look for "nuxt-dx-tools initialized"

### Zed

Add to `~/.config/zed/settings.json`:

```json
{
  "lsp": {
    "nuxt-dx-tools": {
      "binary": {
        "path": "node",
        "arguments": [
          "/path/to/nuxt-dx-tools.nvim/lsp-server/dist/server.js",
          "--stdio"
        ]
      },
      "settings": {}
    }
  },
  "languages": {
    "Vue": {
      "language_servers": ["volar", "nuxt-dx-tools"]
    },
    "TypeScript": {
      "language_servers": ["typescript-language-server", "nuxt-dx-tools"]
    }
  }
}
```

## Testing Your Setup

After configuring your editor:

1. **Open a Nuxt project** with a `.nuxt/` directory (run `nuxt dev` first if needed)

2. **Open a Vue component** that uses auto-imported composables:
   ```vue
   <script setup>
   // Hover over 'useState' - you should see documentation
   const count = useState('counter', () => 0)
   </script>
   ```

3. **Test Goto Definition:**
   - Put cursor on an auto-imported component like `<MyButton>`
   - Press `gd` (Neovim/Vim) or F12 (VSCode)
   - Should jump to the component file

4. **Test Auto-completion:**
   - Type `use` and trigger completion (Ctrl+Space)
   - Should see Nuxt composables like `useState`, `useFetch`, etc.

5. **Check LSP is running:**
   - **Neovim:** `:LspInfo`
   - **VSCode:** Output panel → "Nuxt DX Tools"
   - **Sublime:** LSP status in bottom bar
   - **Emacs:** `M-x lsp-describe-session`

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

# nuxt-dx-tools.nvim

A Neovim plugin that enhances the developer experience for Nuxt projects by providing tools for auto-locating and navigating to auto-imported components, functions, routes, and more.

Port of the [vscode-nuxt-dx-tools](https://github.com/alimozdemir/vscode-nuxt-dx-tools) extension.

### Disclaimer

In full disclosure, this plugin port was written entirely by the Sonnet 4.5 model. I am currently still testing it's functionality. I will do my best to maintain this as long as there's interest

## ✨ Features

- 🎯 **Auto-locate Components** - Navigate to actual component files instead of `.nuxt/components.d.ts`
- 🔧 **Auto-locate Composables** - Jump to composable and function definitions
- 🔌 **Custom Plugin Support** - Find custom plugin definitions (like `$dialog` from `useNuxtApp()`)
- 🌐 **Server API Navigation** - Jump to Nitro API routes from `$fetch` and `useFetch` calls
- 📄 **definePageMeta Support** - Navigate to layouts and middleware from page meta
- 💡 **Hover Information** - Preview API route files on hover
- 🔗 **Path Alias Autocompletion** - Intelligent path completion for Nuxt aliases (`~`, `@`, `#app`, etc.) in import statements (blink.cmp)
- ⚡ **Fast & Cached** - Intelligent caching for better performance

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "aaronred345/nuxt-dx-tools.nvim",
  ft = { "vue", "typescript", "javascript" },
  config = function()
    require("nuxt-dx-tools").setup()
  end,
}
```

## ⚙️ Configuration

```lua
require("nuxt-dx-tools").setup({
  api_functions = { "$fetch", "useFetch", "$fetch.raw" },
  hover_enabled = true,
  goto_definition_enabled = true,
  nuxt_root = nil,
})
```

### blink.cmp Integration

To enable Nuxt path alias autocompletion in import statements, add the nuxt-dx-tools source to your blink.cmp configuration:

```lua
{
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "nuxt" },
      providers = {
        nuxt = {
          name = "nuxt-dx-tools",
          module = "nuxt-dx-tools.blink-source",
          score_offset = 10, -- Boost nuxt completions
        },
      },
    },
  },
}
```

This enables intelligent autocompletion for:
- Nuxt aliases: `~`, `~~`, `@`, `@@`
- Built-in aliases: `#app`, `#build`, `#imports`, etc.
- Custom aliases from your `tsconfig.json`
- Relative paths: `./`, `../`

## 🚀 Usage

- `gd` - Go to definition (enhanced for Nuxt)
- `K` - Show hover information (enhanced for API routes)
- `<leader>ni` - Show component info
- `<leader>nr` - Refresh cache

## 📝 Requirements

- Neovim >= 0.8.0
- A Nuxt 3 or Nuxt 4 project

### Nuxt 4 Compatibility

This plugin fully supports both Nuxt 3 and Nuxt 4, including:
- ✅ Nuxt 3 (classic directory structure)
- ✅ Nuxt 4 with classic structure (backwards compatibility mode)
- ✅ Nuxt 4 with new `app/` directory structure

The plugin automatically detects your project structure and adapts accordingly, supporting:
- `app/components/`, `app/composables/`, `app/layouts/`, `app/middleware/`, and `app/plugins/` (Nuxt 4)
- Root-level directories (Nuxt 3 / Nuxt 4 classic mode)
- New Nuxt 4 path aliases: `~`, `~~`, `@`, `@@`, `#app`, `#build`, `#imports`

## 📜 License

MIT License - see LICENSE file for details

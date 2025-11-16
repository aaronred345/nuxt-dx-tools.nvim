# nuxt-dx-tools.nvim

A Neovim plugin that enhances the developer experience for Nuxt projects by providing tools for auto-locating and navigating to auto-imported components, functions, routes, and more.

Port of the [vscode-nuxt-dx-tools](https://github.com/alimozdemir/vscode-nuxt-dx-tools) extension.

## ✨ Features

- 🎯 **Auto-locate Components** - Navigate to actual component files instead of `.nuxt/components.d.ts`
- 🔧 **Auto-locate Composables** - Jump to composable and function definitions
- 🔌 **Custom Plugin Support** - Find custom plugin definitions (like `$dialog` from `useNuxtApp()`)
- 🌐 **Server API Navigation** - Jump to Nitro API routes from `$fetch` and `useFetch` calls
- 📄 **definePageMeta Support** - Navigate to layouts and middleware from page meta
- 💡 **Hover Information** - Preview API route files on hover
- ⚡ **Fast & Cached** - Intelligent caching for better performance

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/nuxt-dx-tools.nvim",
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

## 🚀 Usage

- `gd` - Go to definition (enhanced for Nuxt)
- `K` - Show hover information (enhanced for API routes)
- `<leader>ni` - Show component info
- `<leader>nr` - Refresh cache

## 📝 Requirements

- Neovim >= 0.8.0
- A Nuxt 3 project

## 📜 License

MIT License - see LICENSE file for details

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
- 🔗 **Path Alias Completion** - Intelligent auto-completion for TypeScript path aliases (`~`, `@`, `#app`, etc.)
- 💡 **Hover Information** - Preview API route files on hover
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

## 🚀 Usage

### Keybindings

- `gd` - Go to definition (enhanced for Nuxt)
- `K` - Show hover information (enhanced for API routes)
- `<leader>ni` - Show component info
- `<leader>nr` - Refresh cache

### Commands

- `:NuxtDXRefresh` - Refresh all caches
- `:NuxtDXComponentInfo` - Show component info under cursor
- `:NuxtDXShowAliases` - Show all configured path aliases
- `:NuxtDXRefreshAliases` - Refresh path alias cache
- `:NuxtDXDebugAliases` - Show detailed debug info about path aliases (helpful for troubleshooting)

### Path Alias Auto-Completion

The plugin provides intelligent auto-completion for TypeScript path aliases in import statements. It automatically:

- Parses your `tsconfig.json` and all referenced tsconfig files (e.g., `.nuxt/tsconfig.*.json`)
- Extracts path aliases like `~`, `@`, `@@`, `#app`, `#build`, etc.
- Provides file and directory completions when typing aliased paths
- Supports both relative paths (`./`, `../`) and aliased paths (`@/`, `~/`, `#app/`)
- Works with both **nvim-cmp** and **blink.cmp** completion engines

**Example:**
```typescript
import MyComponent from "@/components/  // Auto-completes files in your components directory
import { useAuth } from "~/composables/  // Auto-completes files in your composables directory
import type { Ref } from "#app"  // Auto-completes Nuxt internal modules
```

The plugin intelligently handles Nuxt's auto-generated tsconfig structure where the main `tsconfig.json` contains references to multiple configuration files.

**For more detailed examples and troubleshooting, see [EXAMPLES.md](EXAMPLES.md).**

## 📝 Requirements

- Neovim >= 0.8.0
- A Nuxt 3 project

## 📜 License

MIT License - see LICENSE file for details

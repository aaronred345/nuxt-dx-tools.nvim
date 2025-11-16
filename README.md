# nuxt-dx-tools.nvim

A comprehensive Neovim plugin that dramatically enhances the developer experience for Nuxt projects with advanced navigation, diagnostics, scaffolding, testing, and more.

Port of the [vscode-nuxt-dx-tools](https://github.com/alimozdemir/vscode-nuxt-dx-tools) extension, with extensive Nuxt 4 enhancements.

### Disclaimer

In full disclosure, this plugin was written entirely by the Sonnet 4.5 model. I am currently still testing its functionality. I will do my best to maintain this as long as there's interest.

## ✨ Features

### 🎯 Navigation & Discovery

- **Auto-locate Components** - Navigate to actual component files instead of `.nuxt/components.d.ts`
- **Auto-locate Composables** - Jump to composable and function definitions
- **Custom Plugin Support** - Find custom plugin definitions (like `$dialog` from `useNuxtApp()`)
- **Server API Navigation** - Jump to Nitro API routes from `$fetch` and `useFetch` calls
- **definePageMeta Support** - Navigate to layouts and middleware from page meta
- **Virtual Module Resolution** - Go-to-definition for `#imports`, `#app`, `#build`, `#components`, etc.
- **Fuzzy Pickers** - Telescope/vim.ui.select pickers for pages, components, and routes with metadata

### 🔧 Smart Data Fetching Support

- **useAsyncData/useFetch Recognition** - Detect data fetching patterns and show cache key info
- **Find Shared Data** - Locate all files using the same cache key (deduplication tracking)
- **Conversion Suggestions** - Smart suggestions to convert between `useFetch` ↔ `useAsyncData`
- **Data Fetch Diagnostics** - Warn about missing cache keys, SSR issues, and best practices

### 🚀 Full Nitro Handler Support

- **Handler Signature Preview** - Hover shows function signatures, parameters, and return types
- **Terminal Testing** - Quick commands to test API endpoints with curl
- **Route Parameter Detection** - Matches dynamic routes `[id]`, `[...slug]`, etc.
- **HTTP Method Support** - Handles `.get.ts`, `.post.ts`, etc.

### 🔍 Find Usages for Auto-Imports

- **Symbol Usage Search** - Find all usages of auto-imported composables and components
- **Usage Statistics** - Show usage counts and identify unused auto-imports
- **Project-wide Search** - Search across all pages, components, and composables

### 📝 Nuxt 4 Migration Helpers

- **Structure Detection** - Detect old Nuxt 3 patterns (pages/layouts in root vs app/)
- **Migration Hints** - Show actionable migration suggestions in floating window
- **Auto-fix** - Apply fixes to move files from root to `app/` directory
- **Deprecated API Detection** - Warn about deprecated Nuxt 3 APIs with replacement suggestions

### 🧪 Test Integration

- **Toggle Test File** - Jump between source and test files
- **Generate Test Stubs** - Create test files with Vitest templates for components, composables, and API routes
- **Run Tests** - Execute tests in terminal split
- **Convention-based Discovery** - Finds `.spec.ts`, `.test.ts`, and `__tests__/` files

### ⚡ Scaffolding & Code Generation

- **Interactive Scaffold Generator** (`:NuxtNew`) - Create pages, components, composables, API routes, middleware, plugins, layouts
- **TypeScript Templates** - Modern Nuxt 4 templates with TypeScript
- **Smart Options** - Contextual options (e.g., add props to components, HTTP method for API routes)
- **Code Snippets** - 15+ Nuxt 4 code snippets for common patterns

### 🩺 Diagnostics & Linting

- **SSR Safety Checks** - Detect server-only APIs used without guards
- **definePageMeta Validation** - Ensure proper usage in `<script setup>`
- **Route Param Validation** - Match `route.params` usage with file path params
- **Nitro Handler Checks** - Validate event handler signatures
- **Async Composable Warnings** - Suggest `await` for async data fetching

### 📊 Project Health & Insights

- **Health Report** - Comprehensive project analysis showing structure, dependencies, configuration, file organization
- **Virtual Modules Browser** - View all Nuxt virtual modules and their exports
- **Component Info** - Detailed info about components under cursor

### 💡 Path Alias Autocompletion

- **blink.cmp Integration** - Intelligent path completion in import statements
- **Nuxt Aliases** - `~`, `~~`, `@`, `@@`, `#app`, `#build`, `#imports`, etc.
- **Custom Aliases** - Reads `tsconfig.json` for project-specific aliases
- **Directory Navigation** - Browse directories as you type

### ⚙️ Developer Experience

- **Smart Caching** - Intelligent cache with TTL and auto-refresh
- **Fast Performance** - Lazy-loaded modules for minimal startup impact
- **Nuxt 4 First** - Built for Nuxt 4 with full Nuxt 3 backwards compatibility
- **Rich Hover Info** - Context-aware hover with examples and documentation

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "aaronred345/nuxt-dx-tools.nvim",
  ft = { "vue", "typescript", "javascript" },
  dependencies = {
    "nvim-telescope/telescope.nvim", -- Optional, for better pickers
  },
  config = function()
    require("nuxt-dx-tools").setup()
  end,
}
```

## ⚙️ Configuration

```lua
require("nuxt-dx-tools").setup({
  -- API function patterns to recognize
  api_functions = { "$fetch", "useFetch", "$fetch.raw" },

  -- Enable enhanced hover
  hover_enabled = true,

  -- Enable enhanced goto definition
  goto_definition_enabled = true,

  -- Enable diagnostics
  diagnostics_enabled = true,

  -- Manually set Nuxt root (auto-detected if nil)
  nuxt_root = nil,
})
```

### blink.cmp Integration

To enable Nuxt path alias autocompletion:

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
          score_offset = 10,
        },
      },
    },
  },
}
```

## 🚀 Usage

### Default Keymaps

All keymaps are prefixed with `<leader>n`:

#### Core Navigation
- `gd` - Enhanced go to definition
- `K` - Enhanced hover (shows API signatures, data fetch info, virtual modules)

#### Fuzzy Navigation
- `<leader>np` - Jump to page (fuzzy picker)
- `<leader>nc` - Jump to component (fuzzy picker)
- `<leader>nj` - Jump to page/component (combined picker)

#### Find & Usages
- `<leader>nf` - Find usages of auto-imported symbol
- `<leader>nu` - Show usage statistics

#### API & Testing
- `<leader>nt` - Test API endpoint under cursor
- `<leader>ntt` - Toggle test file
- `<leader>ntr` - Run test
- `<leader>ntc` - Create test file

#### Data Fetching
- `<leader>ndf` - Find data fetch usages
- `<leader>ndc` - Convert data fetch type
- `<leader>ndi` - Check data fetch issues

#### Scaffolding
- `<leader>nn` - New file (scaffold generator)
- `<leader>ns` - Show snippets picker

#### Migration
- `<leader>nm` - Show migration hints
- `<leader>nM` - Apply migration fixes

#### Info & Diagnostics
- `<leader>ni` - Component info
- `<leader>nr` - Refresh cache
- `<leader>nv` - Show virtual modules
- `<leader>nh` - Project health report

### Commands

All commands are prefixed with `:Nuxt`:

#### Navigation
- `:NuxtJumpToPage` - Fuzzy page picker
- `:NuxtJumpToComponent` - Fuzzy component picker
- `:NuxtJump` - Combined picker

#### Migration
- `:NuxtMigrationHints` - Show Nuxt 4 migration hints
- `:NuxtMigrationFix` - Apply migration fixes

#### Data Fetching
- `:NuxtFindDataUsages` - Find data fetch key usages
- `:NuxtConvertFetch` - Convert between useFetch/useAsyncData
- `:NuxtCheckDataFetch` - Check data fetching issues

#### API & Testing
- `:NuxtTestEndpoint` - Test API endpoint
- `:NuxtToggleTest` - Toggle test file
- `:NuxtCreateTest` - Create test file
- `:NuxtRunTest` - Run test

#### Scaffolding
- `:NuxtNew` - Interactive scaffold generator
- `:NuxtSnippets` - Show snippet picker

#### Find Usages
- `:NuxtFindUsages` - Find usages of symbol
- `:NuxtUsageStats` - Usage statistics

#### Info & Diagnostics
- `:NuxtHealth` - Project health report
- `:NuxtComponentInfo` - Component info
- `:NuxtVirtualModules` - Show virtual modules
- `:NuxtRefresh` / `:NuxtDXRefresh` - Refresh cache

## 📝 Requirements

- Neovim >= 0.8.0
- A Nuxt 3 or Nuxt 4 project
- Optional: [Telescope](https://github.com/nvim-telescope/telescope.nvim) for better pickers
- Optional: [blink.cmp](https://github.com/saghen/blink.cmp) for path alias completion

### Nuxt 4 Compatibility

This plugin fully supports both Nuxt 3 and Nuxt 4:

- ✅ Nuxt 3 (classic directory structure)
- ✅ Nuxt 4 with classic structure
- ✅ Nuxt 4 with new `app/` directory
- ✅ Automatic structure detection
- ✅ Migration helpers for Nuxt 3 → 4

Supported directories:
- `app/components/`, `app/composables/`, `app/layouts/`, `app/middleware/`, `app/plugins/` (Nuxt 4)
- Root-level directories (Nuxt 3)
- `server/api/`, `server/routes/`, `server/middleware/` (Nitro)

## 🎯 Feature Details

### Scaffolding Templates

The `:NuxtNew` command provides templates for:

1. **Page** - With `definePageMeta`, layout, middleware, `useAsyncData` options
2. **Component** - With TypeScript props, emits, scoped styles
3. **Composable** - With `useState`, proper return types
4. **API Route** - GET/POST/PUT/DELETE handlers with `defineEventHandler`
5. **Middleware** - Route middleware with auth checks
6. **Plugin** - Nuxt plugins with provide/hooks
7. **Layout** - Layout templates with header/footer options

### Code Snippets

Available snippets (trigger with `:NuxtSnippets`):

- `npage` - Nuxt 4 page template
- `ncomp` - Component with TypeScript
- `nuad` - useAsyncData
- `nufetch` - useFetch
- `nulazy` - useLazyFetch
- `nustate` - useState
- `npmeta` - definePageMeta
- `nmiddleware` - Route middleware
- `nplugin` - Plugin
- `napi-get/post` - API handlers
- `ncomposable` - Composable
- `nuhead` - useHead
- `nuseo` - useSeoMeta

### Diagnostics

Real-time diagnostics for:

- ❌ Server-only APIs used on client
- ❌ `definePageMeta` outside `<script setup>`
- ❌ Route param mismatches
- ❌ Missing await on async composables
- ⚠️ Missing cache keys on data fetching
- ⚠️ Improper Nitro handler signatures

### Project Health Report

Shows:

- 📁 Project structure (Nuxt 3 vs 4)
- 📦 Dependencies (Nuxt version, TypeScript, testing)
- ⚙️ Configuration (config files, tsconfig, .nuxt)
- 📊 File organization (counts of pages, components, composables, API routes)
- ⚠️ Detected issues

## 🤝 Contributing

Contributions are welcome! This plugin was AI-generated but can be improved by the community.

## 📜 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Original [vscode-nuxt-dx-tools](https://github.com/alimozdemir/vscode-nuxt-dx-tools) extension
- Claude Sonnet 4.5 for the implementation
- Nuxt team for the amazing framework

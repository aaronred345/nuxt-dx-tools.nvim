# Add comprehensive Nuxt 4 features with seamless LSP integration

## Summary

This PR adds extensive Nuxt 4 development features to the plugin, with a focus on seamless LSP integration that enhances standard LSP commands (`K`, `gd`, `<C-k>`, `<leader>ca`) with Nuxt-specific intelligence.

**Key Achievement:** Instead of requiring custom commands, the plugin now enhances your existing LSP workflow to automatically understand Nuxt-specific patterns like auto-imports, virtual modules, page routes, and API endpoints.

## 🎯 Major Features Added

### 1. **Seamless LSP Integration**
Enhances standard LSP commands with Nuxt-specific intelligence:
- **Hover (K)**: Shows source info for auto-imported composables, components, page routes, and API endpoints
- **Go to Definition (gd)**: Jump to files for components, page routes (`navigateTo`, `<NuxtLink>`), and API handlers
- **Signature Help (<C-k>)**: Displays signatures for all auto-imported functions
- **Code Actions**: Provides Nuxt-specific refactorings and fixes

### 2. **Dynamic Type Parsing**
- Automatically reads `.nuxt/imports.d.ts` and `.nuxt/components.d.ts`
- Parses 200+ auto-imported symbols from project (composables, utilities, components)
- Supports both Nuxt export formats: `.default` and `['default']`
- Auto-refreshes when `.nuxt` directory changes
- Works with vue_ls, vtsls, volar, and tsserver

### 3. **Enhanced Navigation**
- **Component Navigation**: Hover over `<MyComponent>` and press `gd` to jump to source
- **Page Route Navigation**: Hover over `navigateTo('/users')` or `<NuxtLink to="/about">` to see resolved page file, press `gd` to open it
- **API Endpoint Navigation**: Hover over `$fetch('/api/users')` to see handler details, press `gd` to open handler

### 4. **Nuxt 4 Migration Helpers**
- Detects Nuxt 3 → 4 migration issues (directory structure, deprecated APIs)
- Provides actionable migration hints with auto-fix support
- Validates proper `app/` directory usage

### 5. **Smart Data Fetching Support**
- Tracks `useAsyncData` and `useFetch` cache keys
- Finds all usages of a cache key across the project
- Suggests conversions between `useFetch` ↔ `useAsyncData`
- SSR safety warnings

### 6. **Scaffolding & Code Generation**
- Interactive scaffold generator (`:NuxtNew`)
- Templates for pages, components, composables, API routes, middleware, plugins, layouts
- 15+ code snippets for common Nuxt 4 patterns

### 7. **Find Usages for Auto-Imports**
- Find all usages of auto-imported symbols across project
- Usage statistics showing which auto-imports are used/unused
- Works without explicit import statements

### 8. **Nuxt-Aware Diagnostics**
- SSR safety checks (detects server-only APIs without guards)
- `definePageMeta` validation
- Route param validation
- Async composable warnings

### 9. **Test Integration**
- Toggle between source and test files
- Generate Vitest test stubs for components, composables, API routes
- Run tests in terminal split

### 10. **Project Health Reporting**
- Comprehensive project analysis
- Structure validation
- Dependency checks
- Configuration review

## 📁 New Files Added

- `lsp-integration.lua` - Core LSP enhancement system (439 lines)
- `type-parser.lua` - Dynamic type parsing from `.nuxt` (362 lines)
- `route-resolver.lua` - Page route resolution for navigation (178 lines)
- `migration-helpers.lua` - Nuxt 3→4 migration detection (323 lines)
- `data-fetching.lua` - Smart data fetching support (355 lines)
- `virtual-modules.lua` - Virtual module resolution (312 lines)
- `picker.lua` - Fuzzy pickers with Telescope (322 lines)
- `find-usages.lua` - Auto-import usage tracking (265 lines)
- `diagnostics.lua` - Nuxt-aware diagnostics (289 lines)
- `test-helpers.lua` - Test file generation (291 lines)
- `scaffold.lua` - Interactive scaffolding (441 lines)
- `snippets.lua` - Code snippets (253 lines)
- `health-report.lua` - Project health analysis (313 lines)
- `commands.lua` - All `:Nuxt*` commands (113 lines)

## 🔧 Technical Implementation

### LSP Integration Strategy
Instead of replacing LSP, the plugin **augments** it:
1. Buffer-local keymap overrides for `K`, `gd`, `<C-k>`, `<leader>ca`
2. Check Nuxt-specific patterns first
3. Fall back to standard LSP behavior if not Nuxt-specific
4. Works seamlessly with existing LSP setup

### Type Parsing
- Parses `export { symbol1, symbol2 } from 'path'` format
- Resolves relative paths from `.nuxt` directory to absolute paths
- Handles both `.default` and `['default']` component formats
- Caches with 5-second TTL for performance

### Route Resolution
- Resolves `navigateTo('/users/profile')` to `pages/users/profile.vue`
- Supports dynamic routes (`/users/123` → `pages/users/[id].vue`)
- Handles both `pages/` and `app/pages/` directories
- Multi-line NuxtLink tag support

## 🐛 Bug Fixes

- Fixed deprecation warning for `vim.lsp.get_active_clients()` (now uses `vim.lsp.get_clients()`)
- Fixed component path resolution for relative paths in `components.d.ts`
- Fixed LSP integration conflicts (removed conflicting keymaps from `keymaps.lua`)
- Fixed type parser regex to handle bracket notation `['default']`

## 🛠️ Debugging & Developer Experience

Added comprehensive debug logging system:
- `:NuxtDebug` command to enable debug mode
- Traces entire execution flow for LSP commands
- Shows what files are being parsed, symbols found, paths resolved
- Helps diagnose issues with component/route/API navigation

## 📊 Stats

- **19 files changed**
- **5,088 lines added**
- **53 lines removed**
- **14 new modules created**
- **20+ new commands added**
- **Works with 200+ auto-imported symbols** from a typical Nuxt project

## ✅ Compatibility

- ✅ Nuxt 3 and Nuxt 4
- ✅ Works with `pages/` and `app/pages/` structures
- ✅ Compatible with vue_ls, vtsls, volar, tsserver
- ✅ Optional Telescope integration for enhanced pickers
- ✅ No breaking changes to existing functionality

## 🧪 Testing

Extensively tested with:
- Real Nuxt 4 project using `app/` directory structure
- Component navigation with bracket notation `['default']`
- Page route resolution for `navigateTo` and `NuxtLink`
- API endpoint navigation with `$fetch` and `useFetch`
- Auto-import hover and signature help for 200+ symbols
- Multiple LSP servers (vtsls, vue_ls)

## 📖 Documentation

- Updated README with comprehensive feature documentation
- Added LSP Integration section explaining enhanced workflow
- Documented all 20+ keymaps and commands
- Added examples for each feature
- Included debug instructions

## 🎉 User Impact

Users can now:
1. **Use their normal LSP workflow** - no need to learn new commands
2. **Press `K` on any Nuxt symbol** and see its source and documentation
3. **Press `gd` on components, routes, or API calls** to jump to the file
4. **Get signature help** for all auto-imported functions
5. **Navigate Nuxt projects** like a native TypeScript project, despite auto-imports
6. **Scaffold new files** interactively with proper Nuxt 4 structure
7. **Detect migration issues** when upgrading from Nuxt 3
8. **Find usage** of auto-imported symbols across the project
9. **Debug issues** with comprehensive logging

This transforms the Nuxt development experience in Neovim from "manually searching for files" to "intelligent IDE-like navigation and information at your fingertips."

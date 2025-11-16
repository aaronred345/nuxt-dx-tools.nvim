# nuxt-dx-tools.nvim - Usage Examples

This document provides comprehensive examples of how to use the path alias auto-completion feature.

## Path Alias Auto-Completion

### How It Works

The plugin automatically parses your Nuxt project's TypeScript configuration to provide intelligent auto-completion for path aliases.

#### Your tsconfig.json Structure

A typical Nuxt 3 project has a `tsconfig.json` that references multiple configuration files:

```json
{
  "files": [],
  "references": [
    {
      "path": "./.nuxt/tsconfig.app.json"
    },
    {
      "path": "./.nuxt/tsconfig.server.json"
    },
    {
      "path": "./.nuxt/tsconfig.shared.json"
    },
    {
      "path": "./.nuxt/tsconfig.node.json"
    }
  ]
}
```

The plugin will:
1. Parse the main `tsconfig.json`
2. Follow all `references` to find other tsconfig files
3. Extract `compilerOptions.paths` from each file
4. Merge all path aliases into a single set
5. Provide completions based on these aliases

#### Example .nuxt/tsconfig.app.json

```json
{
  "compilerOptions": {
    "paths": {
      "~/*": ["./*"],
      "@/*": ["./*"],
      "~~/*": ["./*"],
      "@@/*": ["./*"],
      "#app": ["./node_modules/nuxt/dist/app"],
      "#app/*": ["./node_modules/nuxt/dist/app/*"],
      "#build": ["./.nuxt"],
      "#build/*": ["./.nuxt/*"]
    }
  }
}
```

### Using Auto-Completion

#### 1. Standard Nuxt Aliases

When you start typing an import statement, the plugin will suggest completions:

```typescript
import MyComponent from "@/
//                       ^ Triggers completion - shows files/folders in your project root

import { useAuth } from "~/composables/
//                                    ^ Shows files in the composables directory

import Button from "@/components/ui/
//                                 ^ Shows files in components/ui directory
```

#### 2. Nuxt Internal Aliases

Access Nuxt's internal modules easily:

```typescript
import { defineNuxtPlugin } from "#app"
//                               ^ Shows Nuxt app modules

import type { NuxtConfig } from "#build"
//                              ^ Shows build-time types
```

#### 3. Relative Paths

The plugin also enhances relative path completions:

```typescript
import Sidebar from "./components/
//                               ^ Shows files in ./components

import utils from "../utils/
//                         ^ Shows files in parent's utils directory
```

#### 4. Navigate to Definitions

Press `gd` on any aliased import to jump to the actual file:

```typescript
import MyComponent from "@/components/MyComponent.vue"
//                      ^ Place cursor here and press 'gd'
```

### Supported File Extensions

The plugin recognizes and completes these file types:
- `.vue` - Vue components
- `.ts` - TypeScript files
- `.js` - JavaScript files
- `.mjs` - ES modules
- `.tsx` - TypeScript JSX
- `.jsx` - JavaScript JSX

### Troubleshooting

#### Check Loaded Aliases

Run `:NuxtDXShowAliases` to see all configured path aliases:

```
Path Aliases:

  ~ → .
  @ → .
  ~~ → .
  @@ → .
  #app → node_modules/nuxt/dist/app
  #build → .nuxt
```

#### Debug Path Alias Loading

Run `:NuxtDXDebugAliases` to see detailed information:

```
=== Nuxt Path Aliases Debug Info ===

Nuxt Root: /home/user/my-nuxt-project

Main tsconfig: /home/user/my-nuxt-project/tsconfig.json
  ✓ Main tsconfig.json found

Referenced tsconfig files:
  1. ✓ ./.nuxt/tsconfig.app.json
     Found 8 alias(es)
  2. ✓ ./.nuxt/tsconfig.server.json
     Found 4 alias(es)
  3. ✓ ./.nuxt/tsconfig.shared.json
     Found 2 alias(es)
  4. ✓ ./.nuxt/tsconfig.node.json
     Found 0 alias(es)

All loaded aliases:
  ~ → .
  @ → .
  #app → node_modules/nuxt/dist/app
  ...
```

#### Refresh Aliases

If you modify your tsconfig files, run `:NuxtDXRefreshAliases` to reload the aliases.

The plugin also automatically refreshes when you save any `tsconfig.json` or `tsconfig.*.json` file.

## Completion Engines

### nvim-cmp

The plugin automatically registers as a completion source for nvim-cmp. No additional configuration needed!

```lua
-- Your nvim-cmp setup
require('cmp').setup({
  sources = {
    { name = 'nvim_lsp' },
    { name = 'nuxt-aliases' }, -- Automatically registered by the plugin
    -- ... other sources
  }
})
```

### blink.cmp

The plugin is automatically detected by blink.cmp. Just install the plugin and it works!

```lua
-- blink.cmp will automatically find and use the completion source
require('blink-cmp').setup({
  -- ... your config
})
```

## Advanced Features

### Multi-Target Aliases

If your tsconfig has multiple targets for an alias, the plugin uses the first one:

```json
{
  "compilerOptions": {
    "paths": {
      "#components": [
        "./components",
        "./node_modules/@nuxt/ui/components"
      ]
    }
  }
}
```

In this case, completions will use `./components`.

### Trailing Commas & Comments

The plugin handles JSON with comments and trailing commas (common in tsconfig files):

```json
{
  "compilerOptions": {
    "paths": {
      "~/*": ["./*"], // Your project root
      "@/*": ["./*"], // Alternative alias
    }
  }
}
```

### Index Files

The plugin intelligently resolves index files:

```typescript
import utils from "@/utils"
// Resolves to @/utils/index.ts (or .js, .vue, etc.)
```

## Performance

The plugin uses intelligent caching:
- Aliases are cached for 10 seconds to avoid constant file re-parsing
- Cache is automatically invalidated when tsconfig files are modified
- Manual refresh available via `:NuxtDXRefreshAliases`

## Comparison with VSCode

This plugin provides the same path alias completion experience as VSCode's TypeScript IntelliSense, specifically adapted for Nuxt 3 projects with their unique tsconfig structure.

Key similarities:
- ✓ Parses tsconfig.json references
- ✓ Extracts path aliases from compilerOptions
- ✓ Provides file/folder completions for aliased paths
- ✓ Supports goto definition for aliased imports
- ✓ Handles multiple target paths
- ✓ Works with Nuxt's auto-generated tsconfig files

## Tips & Best Practices

1. **Use `:NuxtDXDebugAliases`** when setting up the plugin to verify all aliases are loaded correctly

2. **Organize imports** - Use aliases consistently:
   - `@/` or `~/` for project root imports
   - `./` for same-directory imports
   - `../` for parent directory imports

3. **Check your .nuxt directory** - Make sure Nuxt has generated the tsconfig files by running `nuxt prepare` or starting the dev server

4. **Configure your tsconfig** - You can add custom aliases in `nuxt.config.ts`:
   ```typescript
   export default defineNuxtConfig({
     alias: {
       '@services': './app/services',
       '@models': './app/models'
     }
   })
   ```
   These will be picked up automatically after Nuxt regenerates the tsconfig files.

# How to Rebuild the LSP Server After Pulling Changes

## The Problem
The TypeScript source code has the fix, but the compiled JavaScript in `dist/` is outdated.
You're running on Windows, so you need to rebuild there.

## Solution: Rebuild on Windows

### Option 1: Let Plugin Manager Rebuild (Recommended)
If you use lazy.nvim, packer, etc., this will rebuild automatically:

```lua
-- In your Neovim config, update the plugin:
-- For lazy.nvim:
:Lazy update nuxt-dx-tools.nvim

-- For packer:
:PackerSync
```

The postinstall hook will automatically run `npm run build`.

### Option 2: Manual Rebuild
If the plugin manager doesn't rebuild, do it manually:

```powershell
# On Windows, in PowerShell:
cd $HOME\.local\share\nvim\site\pack\packer\start\nuxt-dx-tools.nvim\lsp-server
# Or wherever your plugin is installed

# Install dependencies and build:
npm install

# This runs postinstall which builds the TypeScript automatically
# You should see: "🔨 Building TypeScript LSP server..."
```

### Option 3: Force Rebuild
```powershell
cd path\to\nuxt-dx-tools.nvim\lsp-server
npm run build
```

## Verify the Fix is Active

After rebuilding, restart Neovim and check the logs for these NEW messages:

```
[TsConfig] Added fallback: "~~" -> "c:\Users\aaron\...\web"
[TsConfig] Loaded 18 path aliases (with fallbacks):
```

NOT the old message:
```
[TsConfig] Loaded 17 path aliases from tsconfig:  ❌ OLD
```

## Test Steps

1. Rebuild the LSP server (see above)
2. Completely restart Neovim (`:qa!`)
3. Open a .vue file with `import { X } from "~~/shared/..."`
4. Press `gd` on the import path
5. Should jump to `web/shared/...`

## Check Logs

Logs on Windows are in:
```
%USERPROFILE%\path\to\nuxt-dx-tools.nvim\server-debug.log
```

After pressing `gd`, you should see:
```
[Definition] REQUEST RECEIVED ...
[TsConfig:Resolve] Resolving "~~/shared/utils/response"...
[TsConfig:Resolve] Matched alias "~~" -> "c:\...\web\shared\utils\response"
```

NOT this broken behavior:
```
TsConfig resolved "~~" -> "c:\...\web\app~/shared\..."  ❌ BROKEN
```

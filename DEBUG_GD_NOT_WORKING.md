# Debugging: Why gd Isn't Working

## The Problem

The LSP server logs show **ZERO Definition requests** are reaching the server:
- ✅ Server starts successfully
- ✅ Server initializes and loads aliases
- ✅ Hover requests work (seen in logs)
- ❌ **NO Definition requests** when pressing `gd`

This means `gd` isn't triggering `textDocument/definition` requests to our LSP server.

## Root Cause Analysis

The `~~` alias resolution fix is **correct and working** in the code, but it's never being executed because Definition requests aren't reaching the server.

## Debug Steps

### 1. Check if LSP Client is Attached

In Neovim, open a Nuxt file and run:
```vim
:lua print(vim.inspect(vim.lsp.get_clients()))
```

Look for `nuxt-dx-tools-lsp` in the output. Check:
- Is it in the list?
- What does `server_capabilities.definitionProvider` show? (should be `true`)

### 2. Verify gd Keybinding

```vim
:verbose nmap gd
```

Should show something like:
```
n  gd       * vim.lsp.buf.definition()
```

If it shows something else, your keybinding isn't set correctly.

### 3. Test Definition Manually

With cursor on a Nuxt import, run:
```vim
:lua vim.lsp.buf.definition()
```

Then check `server-debug.log` for:
```
[Definition] REQUEST RECEIVED for ...
```

If this log appears, the problem is your `gd` keybinding.
If it doesn't appear, the problem is LSP client configuration.

### 4. Enable LSP Debug Logging

```vim
:lua vim.lsp.set_log_level('debug')
```

Then press `gd` and check:
```
~/.local/state/nvim/lsp.log
```

Look for lines about `textDocument/definition` requests.

### 5. Check Init Options

The server checks for `enableDefinition` in init options (defaults to `true`).
Check your plugin configuration in your Neovim config:

```lua
vim.lsp.start({
  name = 'nuxt-dx-tools-lsp',
  -- ...
  init_options = {
    enableDefinition = true,  -- Make sure this is true or omitted
  },
})
```

## Expected Behavior

When `gd` works correctly, you should see in `server-debug.log`:
```
[Definition] REQUEST RECEIVED for file:///.../file.vue at 10:25
[TsConfig:Resolve] Resolving "~~/shared/utils/response"...
[TsConfig:Resolve] Matched Nuxt ~~ (derived from ~) -> "c:\...\web\shared\utils\response"
```

## Common Issues

### Issue: gd calls vtsls/tsserver only, not nuxt-dx-tools-lsp

**Cause:** Multiple LSP servers attached, Neovim only queries one.

**Solution:** Neovim 0.11+ queries all servers automatically. Check your Neovim version:
```vim
:version
```

If < 0.11, you need to update Neovim or manually configure multi-server handling.

### Issue: definitionProvider capability is undefined

**Cause:** Server initialization didn't complete or init_options disabled it.

**Solution:** Check plugin config, ensure init_options doesn't have `enableDefinition = false`.

### Issue: Server crashes on Windows

**Symptoms:** `server-error.log` shows exit code like 1073807364 (0xC0000004)

**Solution:** This is a Windows access violation. Make sure you rebuilt the server after pulling latest changes:
```powershell
cd nuxt-dx-tools.nvim\lsp-server
npm run build
```

## If All Else Fails

Share the output of these commands:
1. `:lua print(vim.inspect(vim.lsp.get_clients()))`
2. `:verbose nmap gd`
3. Contents of `~/.local/state/nvim/lsp.log` after pressing `gd`
4. Contents of `server-debug.log` after pressing `gd`

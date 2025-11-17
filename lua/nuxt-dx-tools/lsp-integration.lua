-- LSP integration for Nuxt DX tools
local M = {}

local utils = require("nuxt-dx-tools.utils")
local type_parser = require("nuxt-dx-tools.type-parser")

-- Debug flag
local DEBUG = false

local function log(msg)
  if DEBUG then
    vim.notify("[Nuxt DX] " .. msg, vim.log.levels.INFO)
  end
end

-- Check if we're in a Nuxt project
local function is_nuxt_project()
  return utils.find_nuxt_root() ~= nil
end

-- Get word under cursor
local function get_current_word()
  local word = vim.fn.expand("<cword>")
  return word
end

-- Show hover for Nuxt symbol
local function show_nuxt_hover()
  log("show_nuxt_hover called")

  if not is_nuxt_project() then
    log("Not a Nuxt project")
    return false
  end

  local word = get_current_word()
  log("Current word: " .. (word or "nil"))

  if not word or word == "" then
    log("No word under cursor")
    return false
  end

  -- Try virtual modules first (for #imports, #app, etc.)
  local virtual_modules = require("nuxt-dx-tools.virtual-modules")
  if virtual_modules.show_hover() then
    log("Virtual modules showed hover")
    return true
  end

  -- Try data fetching patterns (useAsyncData, useFetch)
  local data_fetching = require("nuxt-dx-tools.data-fetching")
  if data_fetching.show_hover() then
    log("Data fetching showed hover")
    return true
  end

  -- Try API routes ($fetch calls)
  local api_routes = require("nuxt-dx-tools.api-routes")
  if api_routes.show_hover() then
    log("API routes showed hover")
    return true
  end

  -- Check if it's an auto-imported symbol (composables, components, utilities)
  local hover_text = type_parser.get_hover_text(word)
  if hover_text and #hover_text > 0 then
    log("Found type info for: " .. word)
    vim.lsp.util.open_floating_preview(hover_text, "markdown", {
      border = "rounded",
      focusable = false,
      focus = false,
    })
    return true
  end

  log("No Nuxt hover found for: " .. word)
  return false
end

-- Show signature help for Nuxt symbol
local function show_nuxt_signature()
  log("show_nuxt_signature called")

  if not is_nuxt_project() then
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]
  if not line then
    return false
  end

  -- Find the function being called
  local func_name = line:sub(1, pos[2]):match("([%w_]+)%s*%($")
  if not func_name then
    return false
  end

  log("Function name: " .. func_name)

  -- Get symbol info
  local symbol_info = type_parser.get_symbol_info(func_name)
  if symbol_info and symbol_info.import_path then
    log("Found symbol info for: " .. func_name)

    local lines = {
      "```typescript",
      "// Nuxt Auto-import",
      "import { " .. func_name .. " } from '" .. symbol_info.import_path .. "'",
      "```",
      "",
      "**Source:** `" .. symbol_info.import_path .. "`",
    }

    -- Add context about the source
    if symbol_info.import_path:match("^#app") then
      table.insert(lines, "")
      table.insert(lines, "*Built-in Nuxt composable - check docs for signature*")
    elseif symbol_info.import_path:match("node_modules") then
      local module_name = symbol_info.import_path:match("node_modules/([^/]+)")
      if module_name then
        table.insert(lines, "")
        table.insert(lines, "*From module: " .. module_name .. "*")
      end
    end

    vim.lsp.util.open_floating_preview(lines, "markdown", {
      border = "rounded",
      focusable = false,
      focus = false,
    })
    return true
  end

  log("No symbol info found for: " .. func_name)
  return false
end

-- Get Nuxt code actions
local function get_nuxt_code_actions()
  log("get_nuxt_code_actions called")

  if not is_nuxt_project() then
    return {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]
  if not line then
    return {}
  end

  local nuxt_actions = {}

  -- Migration fixes
  if line:match("useAsync%s*%(") then
    table.insert(nuxt_actions, {
      title = "⚡ Replace 'useAsync' with 'useAsyncData'",
      kind = "quickfix",
      isPreferred = true,
      edit = {
        changes = {
          [vim.uri_from_bufnr(bufnr)] = {
            {
              range = {
                start = { line = pos[1] - 1, character = 0 },
                ["end"] = { line = pos[1] - 1, character = #line },
              },
              newText = line:gsub("useAsync%s*%(", "useAsyncData('data', "),
            },
          },
        },
      },
    })
  end

  -- Add cache key suggestions
  if line:match("useAsyncData%s*%(%s*%(%)%s*=>") or line:match("useAsyncData%s*%(%s*async%s*%(%)") then
    table.insert(nuxt_actions, {
      title = "💡 Add cache key to useAsyncData",
      kind = "quickfix",
      edit = {
        changes = {
          [vim.uri_from_bufnr(bufnr)] = {
            {
              range = {
                start = { line = pos[1] - 1, character = 0 },
                ["end"] = { line = pos[1] - 1, character = #line },
              },
              newText = line:gsub("useAsyncData%s*%(", "useAsyncData('data-" .. os.time() .. "', "),
            },
          },
        },
      },
    })
  end

  if line:match("useFetch") and not line:match("key%s*:") then
    local new_line = line
    if line:match("useFetch%s*%(['\"][^'\"]+['\"]%s*%)") then
      new_line = line:gsub("(useFetch%s*%(['\"][^'\"]+['\"]%s*)%)", "%1, { key: 'fetch-" .. os.time() .. "' }")
    end

    table.insert(nuxt_actions, {
      title = "💡 Add cache key to useFetch",
      kind = "quickfix",
      edit = {
        changes = {
          [vim.uri_from_bufnr(bufnr)] = {
            {
              range = {
                start = { line = pos[1] - 1, character = 0 },
                ["end"] = { line = pos[1] - 1, character = #line },
              },
              newText = new_line,
            },
          },
        },
      },
    })
  end

  -- Test file actions
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not (filepath:match("%.spec%.") or filepath:match("%.test%.")) then
    table.insert(nuxt_actions, {
      title = "🧪 Create test file",
      kind = "refactor.extract",
      command = {
        title = "Create test",
        command = "lua require('nuxt-dx-tools.test-helpers').create_test_file()",
      },
    })
  end

  -- Find usages action
  local word = get_current_word()
  if word and word:match("^[A-Z]") then
    table.insert(nuxt_actions, {
      title = "🔍 Find usages of '" .. word .. "'",
      kind = "refactor",
      command = {
        title = "Find usages",
        command = "lua require('nuxt-dx-tools.find-usages').find_current_symbol_usages()",
      },
    })
  end

  log("Found " .. #nuxt_actions .. " Nuxt code actions")
  return nuxt_actions
end

-- Setup buffer-local LSP overrides
function M.setup_buffer(bufnr)
  if not is_nuxt_project() then
    return
  end

  log("Setting up buffer " .. bufnr)

  -- NOTE: Keybindings are NOT set automatically to avoid conflicts with user configurations.
  -- Users should manually set up keybindings in their config if desired.
  --
  -- Example keybindings:
  -- vim.keymap.set("n", "gd", function() require("nuxt-dx-tools").goto_definition() end, { buffer = bufnr })
  -- vim.keymap.set("n", "K", function() require("nuxt-dx-tools.lsp-integration").show_hover() end, { buffer = bufnr })
  -- vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, { buffer = bufnr })
end

-- Ensure tsconfig.json extends .nuxt/tsconfig.json
local function ensure_tsconfig_extends_nuxt()
  local nuxt_root = utils.find_nuxt_root()
  if not nuxt_root then
    return false
  end

  local tsconfig_path = nuxt_root .. "/tsconfig.json"
  local nuxt_tsconfig = nuxt_root .. "/.nuxt/tsconfig.json"

  -- Check if .nuxt/tsconfig.json exists
  if vim.fn.filereadable(nuxt_tsconfig) == 0 then
    log(".nuxt/tsconfig.json not found - Nuxt may not be running")
    return false
  end

  -- Read existing tsconfig.json
  local tsconfig_content = ""
  if vim.fn.filereadable(tsconfig_path) == 1 then
    local file = io.open(tsconfig_path, "r")
    if file then
      tsconfig_content = file:read("*a")
      file:close()
    end
  end

  -- Check if it already extends .nuxt/tsconfig.json
  if tsconfig_content:match('"extends".*%.nuxt/tsconfig%.json') then
    log("tsconfig.json already extends .nuxt/tsconfig.json")
    return true
  end

  -- Ask user if they want to update tsconfig.json
  vim.schedule(function()
    local choice = vim.fn.confirm(
      "Your tsconfig.json doesn't extend .nuxt/tsconfig.json.\n" ..
      "This causes path alias errors in diagnostics.\n\n" ..
      "Would you like to update it?",
      "&Yes\n&No",
      1
    )

    if choice == 1 then
      -- Create or update tsconfig.json
      local new_config = {
        ["extends"] = "./.nuxt/tsconfig.json"
      }

      -- If there's existing content, try to merge
      if tsconfig_content ~= "" then
        -- Parse existing config (simple approach)
        local has_extends = tsconfig_content:match('"extends"')
        if has_extends then
          vim.notify(
            "Your tsconfig.json already has an 'extends' field.\n" ..
            "Please manually update it to extend './.nuxt/tsconfig.json'",
            vim.log.levels.WARN
          )
          return
        end
      end

      -- Write new tsconfig.json
      local file = io.open(tsconfig_path, "w")
      if file then
        file:write(vim.fn.json_encode(new_config))
        file:close()
        vim.notify(
          "Updated tsconfig.json to extend .nuxt/tsconfig.json.\n" ..
          "Please restart your LSP server (LspRestart).",
          vim.log.levels.INFO
        )
      else
        vim.notify("Failed to write tsconfig.json", vim.log.levels.ERROR)
      end
    end
  end)

  return false
end

-- Setup LSP enhancements on attach
function M.on_attach(client, bufnr)
  log("LSP attached: " .. client.name .. " in buffer " .. bufnr)

  if not is_nuxt_project() then
    log("Not a Nuxt project, skipping setup")
    return
  end

  -- Only enhance Vue/TypeScript LSP clients
  local relevant_clients = {
    ["volar"] = true,
    ["vue-language-server"] = true,
    ["vuels"] = true,
    ["vtsls"] = true,
    ["tsserver"] = true,
    ["typescript-language-server"] = true,
  }

  if not relevant_clients[client.name] then
    log("Client " .. client.name .. " not relevant, skipping")
    return
  end

  log("Setting up Nuxt DX for " .. client.name)

  -- Check and fix tsconfig.json if needed (only for TypeScript LSP servers)
  if client.name == "vtsls" or client.name == "tsserver" or client.name == "typescript-language-server" then
    ensure_tsconfig_extends_nuxt()
  end

  M.setup_buffer(bufnr)
end

-- Setup function
function M.setup()
  log("Setting up Nuxt DX LSP integration")

  -- Set up autocmd to enhance LSP on attach
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("NuxtDXLSP", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        M.on_attach(client, args.buf)
      end
    end,
  })

  -- Also set up for already-attached LSP clients
  vim.schedule(function()
    -- Use vim.lsp.get_clients() for Neovim 0.10+, fallback to get_active_clients() for older versions
    local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
    for _, client in ipairs(get_clients()) do
      for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
        M.on_attach(client, bufnr)
      end
    end
  end)

  -- Refresh type cache when .nuxt files change
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("NuxtDXTypeCache", { clear = true }),
    pattern = { "*/.nuxt/imports.d.ts", "*/.nuxt/components.d.ts" },
    callback = function()
      log("Clearing type cache")
      type_parser.clear_cache()
    end,
  })
end

-- Enable debug mode
function M.enable_debug()
  DEBUG = true
  vim.notify("Nuxt DX debug mode enabled", vim.log.levels.INFO)
end

-- Export helper functions for manual keybinding setup
M.show_nuxt_hover = show_nuxt_hover
M.show_nuxt_signature = show_nuxt_signature
M.get_nuxt_code_actions = get_nuxt_code_actions

return M

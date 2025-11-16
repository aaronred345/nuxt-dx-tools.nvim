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

  -- Override go to definition with our custom implementation
  vim.keymap.set("n", "gd", function()
    log("gd pressed in buffer " .. bufnr)

    -- Use our enhanced goto_definition that handles components, routes, API endpoints
    require("nuxt-dx-tools").goto_definition()
  end, {
    buffer = bufnr,
    desc = "Nuxt DX: Enhanced go to definition",
  })

  -- Override hover with our custom implementation
  vim.keymap.set("n", "K", function()
    log("K pressed in buffer " .. bufnr)

    -- Try Nuxt hover first
    if show_nuxt_hover() then
      return
    end

    -- Fall back to LSP hover
    log("Falling back to LSP hover")
    vim.lsp.buf.hover()
  end, {
    buffer = bufnr,
    desc = "Nuxt DX: Enhanced hover",
  })

  -- Override signature help
  vim.keymap.set("i", "<C-k>", function()
    log("<C-k> pressed in buffer " .. bufnr)

    -- Try Nuxt signature first
    if show_nuxt_signature() then
      return
    end

    -- Fall back to LSP signature help
    log("Falling back to LSP signature help")
    vim.lsp.buf.signature_help()
  end, {
    buffer = bufnr,
    desc = "Nuxt DX: Enhanced signature help",
  })

  -- Augment code actions
  local original_code_action = vim.lsp.buf.code_action
  vim.keymap.set("n", "<leader>ca", function()
    log("Code action triggered in buffer " .. bufnr)

    -- Get Nuxt actions
    local nuxt_actions = get_nuxt_code_actions()

    -- If we have Nuxt actions, show them with vim.ui.select
    -- and let the user also trigger LSP actions
    if #nuxt_actions > 0 then
      -- Get LSP actions too
      local params = vim.lsp.util.make_range_params()
      params.context = {
        diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
      }

      vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, function(results)
        local all_actions = vim.deepcopy(nuxt_actions)

        -- Merge LSP actions
        for client_id, result in pairs(results or {}) do
          if result.result then
            vim.list_extend(all_actions, result.result)
          end
        end

        -- Show all actions
        vim.ui.select(all_actions, {
          prompt = "Code actions:",
          format_item = function(item)
            return item.title
          end,
        }, function(choice)
          if choice and choice.edit then
            vim.lsp.util.apply_workspace_edit(choice.edit, "utf-8")
          elseif choice and choice.command then
            if choice.command.command:match("^lua ") then
              vim.cmd(choice.command.command)
            else
              vim.lsp.buf.execute_command(choice.command)
            end
          end
        end)
      end)
    else
      -- No Nuxt actions, just use LSP
      original_code_action()
    end
  end, {
    buffer = bufnr,
    desc = "Nuxt DX: Enhanced code actions",
  })
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

return M

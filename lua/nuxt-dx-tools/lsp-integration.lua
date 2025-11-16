-- LSP integration for Nuxt DX tools
local M = {}

local utils = require("nuxt-dx-tools.utils")
local type_parser = require("nuxt-dx-tools.type-parser")

-- Check if we're in a Nuxt project
local function is_nuxt_project()
  return utils.find_nuxt_root() ~= nil
end

-- Get word under cursor
local function get_current_word()
  local word = vim.fn.expand("<cword>")
  return word
end

-- Augment hover with Nuxt type information
local function augment_hover(original_handler)
  return function(err, result, ctx, config)
    if not is_nuxt_project() then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end

    local word = get_current_word()
    if not word or word == "" then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end

    -- Try Nuxt-specific hover first
    local virtual_modules = require("nuxt-dx-tools.virtual-modules")
    if virtual_modules.show_hover() then
      return
    end

    local data_fetching = require("nuxt-dx-tools.data-fetching")
    if data_fetching.show_hover() then
      return
    end

    local api_routes = require("nuxt-dx-tools.api-routes")
    if api_routes.show_hover() then
      return
    end

    -- Check if it's an auto-imported symbol
    local hover_text = type_parser.get_hover_text(word)
    if hover_text then
      -- If LSP also has info, combine them
      if result and result.contents then
        -- Prepend Nuxt info to LSP info
        local lsp_lines = {}
        if type(result.contents) == "string" then
          table.insert(lsp_lines, result.contents)
        elseif result.contents.value then
          table.insert(lsp_lines, result.contents.value)
        elseif result.contents.kind == "markdown" then
          table.insert(lsp_lines, result.contents.value)
        end

        -- Combine
        local combined = {}
        vim.list_extend(combined, hover_text)
        if #lsp_lines > 0 then
          table.insert(combined, "")
          table.insert(combined, "---")
          table.insert(combined, "")
          vim.list_extend(combined, lsp_lines)
        end

        vim.lsp.util.open_floating_preview(combined, "markdown", {
          border = "rounded",
          focusable = false,
          focus = false,
        })
        return
      else
        -- Just show Nuxt info
        vim.lsp.util.open_floating_preview(hover_text, "markdown", {
          border = "rounded",
          focusable = false,
          focus = false,
        })
        return
      end
    end

    -- Fall back to LSP
    if original_handler then
      return original_handler(err, result, ctx, config)
    end
  end
end

-- Augment signature help with Nuxt information
local function augment_signature_help(original_handler)
  return function(err, result, ctx, config)
    if not is_nuxt_project() then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end

    local bufnr = ctx.bufnr
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]
    if not line then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end

    -- Find the function being called
    local func_name = line:sub(1, pos[2]):match("([%w_]+)%s*%($")
    if not func_name then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end

    -- Get symbol info
    local symbol_info = type_parser.get_symbol_info(func_name)
    if symbol_info and symbol_info.raw_line then
      -- Extract signature from raw line
      local signature = symbol_info.raw_line:match(":%s*(.+)")
      if signature then
        local lines = {
          "```typescript",
          "// Nuxt Auto-import",
          func_name .. ": " .. signature,
          "```",
        }

        if symbol_info.import_path then
          table.insert(lines, "")
          table.insert(lines, "**Source:** `" .. symbol_info.import_path .. "`")
        end

        vim.lsp.util.open_floating_preview(lines, "markdown", {
          border = "rounded",
          focusable = false,
          focus = false,
        })
        return
      end
    end

    -- Fall back to LSP
    if original_handler then
      return original_handler(err, result, ctx, config)
    end
  end
end

-- Augment code actions with Nuxt-specific actions
local function augment_code_action(original_handler)
  return function(err, result, ctx, config)
    if not is_nuxt_project() then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end

    local bufnr = ctx.bufnr
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]
    if not line then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
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

    -- Merge with LSP actions
    local all_actions = vim.deepcopy(nuxt_actions)
    if result and type(result) == "table" then
      vim.list_extend(all_actions, result)
    end

    -- Pass merged actions to original handler
    if original_handler then
      return original_handler(err, all_actions, ctx, config)
    end

    -- Fallback: show actions with vim.ui.select
    if #all_actions > 0 then
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
    end
  end
end

-- Setup LSP enhancements on attach
function M.on_attach(client, bufnr)
  if not is_nuxt_project() then
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
    return
  end

  -- Store original handlers
  local original_hover = client.handlers["textDocument/hover"] or vim.lsp.handlers["textDocument/hover"]
  local original_signature = client.handlers["textDocument/signatureHelp"] or vim.lsp.handlers["textDocument/signatureHelp"]
  local original_code_action = client.handlers["textDocument/codeAction"] or vim.lsp.handlers["textDocument/codeAction"]

  -- Set augmented handlers
  client.handlers["textDocument/hover"] = augment_hover(original_hover)
  client.handlers["textDocument/signatureHelp"] = augment_signature_help(original_signature)
  client.handlers["textDocument/codeAction"] = augment_code_action(original_code_action)
end

-- Setup function
function M.setup()
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

  -- Refresh type cache when .nuxt files change
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("NuxtDXTypeCache", { clear = true }),
    pattern = { "*/.nuxt/imports.d.ts", "*/.nuxt/components.d.ts" },
    callback = function()
      type_parser.clear_cache()
    end,
  })
end

return M

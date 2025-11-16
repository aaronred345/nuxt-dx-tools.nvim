-- LSP integration for Nuxt DX tools
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Enhance hover with Nuxt-specific information
function M.setup_hover_handler()
  local original_handler = vim.lsp.handlers["textDocument/hover"]

  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    -- Try our custom hover first
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

    -- Fall back to original handler
    if original_handler then
      return original_handler(err, result, ctx, config)
    end
  end
end

-- Provide signature help for Nuxt composables
function M.setup_signature_help()
  local signatures = {
    useAsyncData = {
      label = "useAsyncData(key?: string, handler: () => Promise<T>, options?: AsyncDataOptions<T>)",
      parameters = {
        { label = "key", documentation = "Unique key for caching (optional but recommended)" },
        { label = "handler", documentation = "Async function that returns data" },
        { label = "options", documentation = "Options: server, lazy, immediate, watch, transform, pick, default" },
      },
      documentation = "Composable for async data fetching with caching and SSR support",
    },
    useFetch = {
      label = "useFetch(url: string | Request | Ref<string>, options?: UseFetchOptions)",
      parameters = {
        { label = "url", documentation = "URL to fetch from" },
        { label = "options", documentation = "Options: method, query, body, headers, key, server, lazy, etc." },
      },
      documentation = "Wrapper around useAsyncData and $fetch for convenient data fetching",
    },
    useLazyFetch = {
      label = "useLazyFetch(url: string, options?: UseFetchOptions)",
      parameters = {
        { label = "url", documentation = "URL to fetch from" },
        { label = "options", documentation = "Same as useFetch but with lazy: true by default" },
      },
      documentation = "Non-blocking version of useFetch",
    },
    useState = {
      label = "useState<T>(key?: string, init?: () => T)",
      parameters = {
        { label = "key", documentation = "Unique key for the state" },
        { label = "init", documentation = "Initialization function" },
      },
      documentation = "SSR-friendly shared state management",
    },
    definePageMeta = {
      label = "definePageMeta(meta: PageMeta)",
      parameters = {
        { label = "meta", documentation = "Page metadata: layout, middleware, name, path, alias, etc." },
      },
      documentation = "Define page-level metadata (must be used in <script setup>)",
    },
    defineEventHandler = {
      label = "defineEventHandler(handler: (event: H3Event) => any)",
      parameters = {
        { label = "handler", documentation = "Event handler function that receives H3Event" },
      },
      documentation = "Define a Nitro server event handler",
    },
    useRouter = {
      label = "useRouter()",
      parameters = {},
      documentation = "Access the Vue Router instance",
    },
    useRoute = {
      label = "useRoute()",
      parameters = {},
      documentation = "Access the current route",
    },
    navigateTo = {
      label = "navigateTo(to: RouteLocationRaw, options?: NavigateToOptions)",
      parameters = {
        { label = "to", documentation = "Route location to navigate to" },
        { label = "options", documentation = "Navigation options: replace, redirectCode, external" },
      },
      documentation = "Programmatic navigation helper",
    },
  }

  local original_handler = vim.lsp.handlers["textDocument/signatureHelp"]

  vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
    local bufnr = ctx.bufnr
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]

    -- Check if we're in a Nuxt composable call
    for name, sig in pairs(signatures) do
      if line:match(name .. "%s*%(") then
        -- Create signature help response
        local sig_help = {
          signatures = {
            {
              label = sig.label,
              documentation = {
                kind = "markdown",
                value = sig.documentation,
              },
              parameters = sig.parameters,
            },
          },
          activeSignature = 0,
          activeParameter = 0,
        }

        vim.lsp.util.stylize_markdown(bufnr, sig_help.signatures[1].documentation.value, {})
        return vim.lsp.util.open_floating_preview(
          { sig.label, "", sig.documentation },
          "markdown",
          { border = "rounded", focusable = false }
        )
      end
    end

    -- Fall back to original handler
    if original_handler then
      return original_handler(err, result, ctx, config)
    end
  end
end

-- Provide code actions
function M.setup_code_actions()
  local code_actions_ns = vim.api.nvim_create_namespace("nuxt-dx-code-actions")

  local function get_code_actions(bufnr, range)
    local actions = {}
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line + 1, false)
    local line = lines[1] or ""

    -- Migration fixes
    if line:match("useAsync%s*%(") then
      table.insert(actions, {
        title = "⚡ Replace 'useAsync' with 'useAsyncData'",
        kind = "quickfix",
        command = {
          title = "Replace useAsync",
          command = "nuxt-dx.replace-use-async",
          arguments = { bufnr, range },
        },
      })
    end

    if line:match("asyncData%s*%(") then
      table.insert(actions, {
        title = "⚡ Convert to useAsyncData composable",
        kind = "refactor.rewrite",
        command = {
          title = "Convert asyncData",
          command = "nuxt-dx.convert-async-data",
          arguments = { bufnr, range },
        },
      })
    end

    -- Data fetching improvements
    if line:match("useAsyncData%s*%(%s*%(%)%s*=>") then
      table.insert(actions, {
        title = "💡 Add cache key to useAsyncData",
        kind = "quickfix",
        command = {
          title = "Add cache key",
          command = "nuxt-dx.add-cache-key",
          arguments = { bufnr, range },
        },
      })
    end

    if line:match("useFetch") and not line:match("key%s*:") then
      table.insert(actions, {
        title = "💡 Add cache key to useFetch",
        kind = "quickfix",
        command = {
          title = "Add cache key",
          command = "nuxt-dx.add-fetch-key",
          arguments = { bufnr, range },
        },
      })
    end

    -- Test file actions
    if not (filepath:match("%.spec%.") or filepath:match("%.test%.")) then
      table.insert(actions, {
        title = "🧪 Create test file",
        kind = "refactor.extract",
        command = {
          title = "Create test",
          command = "nuxt-dx.create-test-file",
          arguments = { bufnr },
        },
      })
    end

    -- Component actions
    local word = vim.fn.expand("<cword>")
    if word and word:match("^[A-Z]") then
      table.insert(actions, {
        title = "🔍 Find usages of '" .. word .. "'",
        kind = "refactor",
        command = {
          title = "Find usages",
          command = "nuxt-dx.find-usages",
          arguments = { word },
        },
      })
    end

    -- definePageMeta validation
    if line:match("definePageMeta") then
      local in_script_setup = false
      for i = range.start.line - 1, 0, -1 do
        local prev_line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
        if prev_line:match("<script%s+setup") then
          in_script_setup = true
          break
        end
      end

      if not in_script_setup then
        table.insert(actions, {
          title = "❌ Move definePageMeta to <script setup>",
          kind = "quickfix",
          command = {
            title = "Move to script setup",
            command = "nuxt-dx.move-to-script-setup",
            arguments = { bufnr, range },
          },
        })
      end
    end

    return actions
  end

  -- Register code action provider
  local original_handler = vim.lsp.handlers["textDocument/codeAction"]

  vim.lsp.handlers["textDocument/codeAction"] = function(err, result, ctx, config)
    local bufnr = ctx.bufnr
    local pos = vim.api.nvim_win_get_cursor(0)

    local range = {
      start = { line = pos[1] - 1, character = 0 },
      ["end"] = { line = pos[1] - 1, character = 999 },
    }

    local nuxt_actions = get_code_actions(bufnr, range)

    -- Merge with LSP actions
    local all_actions = nuxt_actions
    if result then
      vim.list_extend(all_actions, result)
    end

    if #all_actions == 0 then
      vim.notify("No code actions available", vim.log.levels.INFO)
      return
    end

    -- Show actions
    vim.ui.select(all_actions, {
      prompt = "Code actions:",
      format_item = function(item)
        return item.title
      end,
    }, function(choice)
      if choice and choice.command then
        M.execute_command(choice.command)
      elseif choice and choice.edit then
        vim.lsp.util.apply_workspace_edit(choice.edit, "utf-8")
      end
    end)
  end
end

-- Execute code action commands
function M.execute_command(command)
  local cmd = command.command
  local args = command.arguments or {}

  if cmd == "nuxt-dx.replace-use-async" then
    local bufnr, range = args[1], args[2]
    local line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)[1]
    local new_line = line:gsub("useAsync%s*%(", "useAsyncData('data', ")
    vim.api.nvim_buf_set_lines(bufnr, range.start.line, range.start.line + 1, false, { new_line })
    vim.notify("Replaced useAsync with useAsyncData", vim.log.levels.INFO)

  elseif cmd == "nuxt-dx.add-cache-key" then
    local bufnr, range = args[1], args[2]
    local line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)[1]
    local key = "data-" .. math.random(1000, 9999)
    local new_line = line:gsub("useAsyncData%s*%(", "useAsyncData('" .. key .. "', ")
    vim.api.nvim_buf_set_lines(bufnr, range.start.line, range.start.line + 1, false, { new_line })
    vim.notify("Added cache key to useAsyncData", vim.log.levels.INFO)

  elseif cmd == "nuxt-dx.add-fetch-key" then
    local bufnr, range = args[1], args[2]
    local line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)[1]
    local key = "fetch-" .. math.random(1000, 9999)

    if line:match("useFetch%s*%(['\"][^'\"]+['\"]%s*%)") then
      local new_line = line:gsub("(%useFetch%s*%(['\"][^'\"]+['\"]%))", "%1, { key: '" .. key .. "' }")
      vim.api.nvim_buf_set_lines(bufnr, range.start.line, range.start.line + 1, false, { new_line })
    else
      local new_line = line:gsub("({)", "%1 key: '" .. key .. "', ")
      vim.api.nvim_buf_set_lines(bufnr, range.start.line, range.start.line + 1, false, { new_line })
    end
    vim.notify("Added cache key to useFetch", vim.log.levels.INFO)

  elseif cmd == "nuxt-dx.create-test-file" then
    local test_helpers = require("nuxt-dx-tools.test-helpers")
    test_helpers.create_test_file()

  elseif cmd == "nuxt-dx.find-usages" then
    local word = args[1]
    local find_usages = require("nuxt-dx-tools.find-usages")
    find_usages.find_symbol_usages(word)
  end
end

-- Setup document symbols for virtual imports
function M.setup_document_symbols()
  local original_handler = vim.lsp.handlers["textDocument/documentSymbol"]

  vim.lsp.handlers["textDocument/documentSymbol"] = function(err, result, ctx, config)
    local bufnr = ctx.bufnr
    local virtual_symbols = {}

    -- Parse buffer for virtual imports
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
      -- Find #imports, #app, etc.
      for module in line:gmatch("from%s+['\"]([#@][^'\"]+)['\"]") do
        table.insert(virtual_symbols, {
          name = module,
          kind = vim.lsp.protocol.SymbolKind.Module,
          range = {
            start = { line = i - 1, character = 0 },
            ["end"] = { line = i - 1, character = #line },
          },
          selectionRange = {
            start = { line = i - 1, character = 0 },
            ["end"] = { line = i - 1, character = #line },
          },
        })
      end
    end

    -- Merge with LSP symbols
    local all_symbols = virtual_symbols
    if result then
      vim.list_extend(all_symbols, result)
    end

    if original_handler then
      return original_handler(err, all_symbols, ctx, config)
    end
  end
end

-- Setup workspace symbols for Nuxt auto-imports
function M.setup_workspace_symbols()
  local original_handler = vim.lsp.handlers["workspace/symbol"]

  vim.lsp.handlers["workspace/symbol"] = function(err, result, ctx, config)
    local query = ctx.params.query or ""
    local nuxt_symbols = {}

    -- Add auto-imported composables
    local find_usages = require("nuxt-dx-tools.find-usages")
    local auto_imports = find_usages.get_auto_imports()

    for _, import in ipairs(auto_imports) do
      if import.name:lower():match(query:lower()) then
        table.insert(nuxt_symbols, {
          name = import.name,
          kind = vim.lsp.protocol.SymbolKind.Function,
          location = {
            uri = vim.uri_from_fname(utils.find_nuxt_root() .. "/.nuxt/imports.d.ts"),
            range = {
              start = { line = 0, character = 0 },
              ["end"] = { line = 0, character = 0 },
            },
          },
        })
      end
    end

    -- Add components
    local components = find_usages.get_auto_components()
    for _, comp in ipairs(components) do
      if comp.name:lower():match(query:lower()) then
        table.insert(nuxt_symbols, {
          name = comp.name,
          kind = vim.lsp.protocol.SymbolKind.Class,
          location = {
            uri = vim.uri_from_fname(utils.find_nuxt_root() .. "/.nuxt/components.d.ts"),
            range = {
              start = { line = 0, character = 0 },
              ["end"] = { line = 0, character = 0 },
            },
          },
        })
      end
    end

    -- Merge with LSP symbols
    local all_symbols = nuxt_symbols
    if result then
      vim.list_extend(all_symbols, result)
    end

    if original_handler then
      return original_handler(err, all_symbols, ctx, config)
    end
  end
end

-- Setup all LSP enhancements
function M.setup()
  M.setup_hover_handler()
  M.setup_signature_help()
  M.setup_code_actions()
  M.setup_document_symbols()
  M.setup_workspace_symbols()
end

return M

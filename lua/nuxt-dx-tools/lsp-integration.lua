-- LSP integration for Nuxt DX tools
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Store original handlers per client
M.original_handlers = {}

-- Check if we're in a Nuxt project
local function is_nuxt_project()
  return utils.find_nuxt_root() ~= nil
end

-- Nuxt composable signatures
local NUXT_SIGNATURES = {
  useAsyncData = {
    label = "useAsyncData(key?: string, handler: () => Promise<T>, options?: AsyncDataOptions<T>)",
    documentation = "Composable for async data fetching with caching and SSR support.\n\nOptions:\n- `server`: Run on server-side only (default: true)\n- `lazy`: Non-blocking (default: false)\n- `immediate`: Fetch immediately (default: true)\n- `watch`: Reactive dependencies to watch\n- `transform`: Transform result data\n- `pick`: Pick specific keys from data\n- `default`: Default value factory",
  },
  useFetch = {
    label = "useFetch(url: string | Ref<string>, options?: UseFetchOptions)",
    documentation = "Wrapper around useAsyncData and $fetch for convenient data fetching.\n\nOptions:\n- `method`: HTTP method\n- `query`: Query parameters\n- `body`: Request body\n- `headers`: Request headers\n- `key`: Cache key (auto-generated if not provided)\n- Plus all useAsyncData options",
  },
  useLazyFetch = {
    label = "useLazyFetch(url: string, options?: UseFetchOptions)",
    documentation = "Non-blocking version of useFetch. Same as useFetch with `lazy: true`",
  },
  useLazyAsyncData = {
    label = "useLazyAsyncData(key?: string, handler: () => Promise<T>, options?: AsyncDataOptions<T>)",
    documentation = "Non-blocking version of useAsyncData. Same as useAsyncData with `lazy: true`",
  },
  useState = {
    label = "useState<T>(key?: string, init?: () => T)",
    documentation = "SSR-friendly shared state management. State is shared between server and client.\n\nParameters:\n- `key`: Unique identifier for the state\n- `init`: Initialization function (runs only once)",
  },
  definePageMeta = {
    label = "definePageMeta(meta: PageMeta)",
    documentation = "Define page-level metadata. Must be used in <script setup>.\n\nAvailable options:\n- `layout`: Layout name\n- `middleware`: Middleware to run\n- `name`: Route name\n- `path`: Custom route path\n- `alias`: Route aliases\n- `keepalive`: Keep component alive\n- `key`: Custom route key function\n- `pageTransition`: Page transition config\n- `layoutTransition`: Layout transition config",
  },
  defineEventHandler = {
    label = "defineEventHandler(handler: (event: H3Event) => any)",
    documentation = "Define a Nitro server event handler.\n\nThe event object provides:\n- `node.req`, `node.res`: Node.js request/response\n- `context`: Request context\n- Helper functions: getQuery(), readBody(), etc.",
  },
  defineNuxtRouteMiddleware = {
    label = "defineNuxtRouteMiddleware(middleware: (to, from) => any)",
    documentation = "Define route middleware.\n\nReturn values:\n- Nothing: Allow navigation\n- navigateTo(route): Redirect\n- abortNavigation(): Cancel navigation\n- abortNavigation(error): Cancel with error",
  },
  defineNuxtPlugin = {
    label = "defineNuxtPlugin(plugin: (nuxtApp) => { provide?: {} })",
    documentation = "Define a Nuxt plugin.\n\nReturn object:\n- `provide`: Object of values to inject (accessible via useNuxtApp().$name)\n\nPlugin hooks:\n- app:created, app:beforeMount, app:mounted, app:error, etc.",
  },
  navigateTo = {
    label = "navigateTo(to: RouteLocationRaw, options?: NavigateToOptions)",
    documentation = "Programmatic navigation helper.\n\nOptions:\n- `replace`: Replace current history entry\n- `redirectCode`: HTTP redirect code (server-side)\n- `external`: Navigate to external URL",
  },
  useRouter = {
    label = "useRouter(): Router",
    documentation = "Access the Vue Router instance. Available methods:\n- push(), replace(), go(), back(), forward()\n- getRoutes(), hasRoute(), resolve()\n- addRoute(), removeRoute()",
  },
  useRoute = {
    label = "useRoute(): RouteLocationNormalized",
    documentation = "Access the current route. Properties:\n- `path`: Current path\n- `params`: Route parameters\n- `query`: Query parameters\n- `hash`: URL hash\n- `name`: Route name\n- `meta`: Route metadata",
  },
  useCookie = {
    label = "useCookie<T>(name: string, options?: CookieOptions)",
    documentation = "SSR-friendly reactive cookie. Options:\n- `maxAge`: Cookie max age\n- `expires`: Expiration date\n- `httpOnly`: HTTP-only flag\n- `secure`: Secure flag\n- `domain`: Cookie domain\n- `path`: Cookie path\n- `sameSite`: SameSite attribute",
  },
  useHead = {
    label = "useHead(meta: MaybeComputedRef<MetaObject>)",
    documentation = "Manage document head. Properties:\n- `title`: Page title\n- `titleTemplate`: Title template\n- `meta`: Meta tags\n- `link`: Link tags\n- `script`: Script tags\n- `style`: Style tags\n- `htmlAttrs`, `bodyAttrs`: HTML/body attributes",
  },
  useSeoMeta = {
    label = "useSeoMeta(meta: SeoMetaInput)",
    documentation = "Type-safe SEO meta tags. Properties:\n- `title`, `description`\n- `ogTitle`, `ogDescription`, `ogImage`\n- `twitterCard`, `twitterTitle`, `twitterDescription`\n- And many more SEO-related meta tags",
  },
}

-- Enhanced hover handler
local function enhance_hover(err, result, ctx, config)
  if not is_nuxt_project() then
    -- Not a Nuxt project, use original handler
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client and M.original_handlers[client.id] and M.original_handlers[client.id].hover then
      return M.original_handlers[client.id].hover(err, result, ctx, config)
    end
    return
  end

  -- Try Nuxt-specific hover
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

  -- Fall back to LSP hover
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client and M.original_handlers[client.id] and M.original_handlers[client.id].hover then
    return M.original_handlers[client.id].hover(err, result, ctx, config)
  end

  -- Default hover display if no original handler
  if result and result.contents then
    vim.lsp.util.stylize_markdown(ctx.bufnr, result.contents, {})
  end
end

-- Enhanced signature help handler
local function enhance_signature_help(err, result, ctx, config)
  if not is_nuxt_project() then
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client and M.original_handlers[client.id] and M.original_handlers[client.id].signatureHelp then
      return M.original_handlers[client.id].signatureHelp(err, result, ctx, config)
    end
    return
  end

  local bufnr = ctx.bufnr
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]

  -- Check if we're in a Nuxt composable call
  for name, sig in pairs(NUXT_SIGNATURES) do
    if line:match(name .. "%s*%(") then
      local lines = {
        "```typescript",
        sig.label,
        "```",
        "",
        sig.documentation,
      }

      vim.lsp.util.open_floating_preview(lines, "markdown", {
        border = "rounded",
        focusable = false,
        focus = false,
      })
      return
    end
  end

  -- Fall back to LSP signature help
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client and M.original_handlers[client.id] and M.original_handlers[client.id].signatureHelp then
    return M.original_handlers[client.id].signatureHelp(err, result, ctx, config)
  end
end

-- Enhanced code action handler
local function enhance_code_action(err, result, ctx, config)
  if not is_nuxt_project() then
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client and M.original_handlers[client.id] and M.original_handlers[client.id].codeAction then
      return M.original_handlers[client.id].codeAction(err, result, ctx, config)
    end
    return
  end

  local bufnr = ctx.bufnr
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]

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
              newText = line:gsub("(%useFetch%s*%(['\"][^'\"]+['\"]%s*%))$", "%1, { key: 'fetch-" .. os.time() .. "' }"),
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
  local word = vim.fn.expand("<cword>")
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
  local all_actions = nuxt_actions
  if result then
    vim.list_extend(all_actions, result)
  end

  -- Get original handler to display actions
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client and M.original_handlers[client.id] and M.original_handlers[client.id].codeAction then
    return M.original_handlers[client.id].codeAction(err, all_actions, ctx, config)
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

-- Setup LSP handlers when client attaches
function M.on_attach(client, bufnr)
  if not is_nuxt_project() then
    return
  end

  -- Only set up for relevant LSP clients
  local relevant_clients = {
    ["volar"] = true,
    ["vue-language-server"] = true,
    ["vuels"] = true,
    ["tsserver"] = true,
    ["typescript-language-server"] = true,
  }

  if not relevant_clients[client.name] then
    return
  end

  -- Store original handlers for this client
  if not M.original_handlers[client.id] then
    M.original_handlers[client.id] = {
      hover = client.handlers["textDocument/hover"] or vim.lsp.handlers["textDocument/hover"],
      signatureHelp = client.handlers["textDocument/signatureHelp"] or vim.lsp.handlers["textDocument/signatureHelp"],
      codeAction = client.handlers["textDocument/codeAction"] or vim.lsp.handlers["textDocument/codeAction"],
    }
  end

  -- Override handlers for this client
  client.handlers["textDocument/hover"] = enhance_hover
  client.handlers["textDocument/signatureHelp"] = enhance_signature_help
  client.handlers["textDocument/codeAction"] = enhance_code_action
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
end

return M

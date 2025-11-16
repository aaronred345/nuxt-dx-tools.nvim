-- Nuxt-aware diagnostics and linting
local M = {}

local utils = require("nuxt-dx-tools.utils")

M.namespace = vim.api.nvim_create_namespace("nuxt-dx-diagnostics")

-- Check for SSR-only APIs used on client
function M.check_ssr_issues(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diagnostics = {}

  local ssr_only_apis = {
    "readBody",
    "readFormData",
    "readRawBody",
    "readMultipartFormData",
    "getQuery",
    "getRouterParam",
    "getCookie",
    "setCookie",
    "deleteCookie",
    "getRequestHeaders",
    "getRequestHeader",
    "setResponseHeader",
    "setResponseHeaders",
    "getRequestURL",
    "getRequestProtocol",
    "getRequestHost",
  }

  for lnum, line in ipairs(lines) do
    -- Check if line uses SSR-only API without proper guard
    for _, api in ipairs(ssr_only_apis) do
      if line:match("%f[%w]" .. api .. "%f[%W]") then
        -- Check if there's a server-side guard
        local has_guard = false

        -- Look for guards in surrounding lines
        for i = math.max(1, lnum - 5), math.min(#lines, lnum + 5) do
          local nearby_line = lines[i]
          if nearby_line:match("process%.server") or
             nearby_line:match("import%.meta%.server") or
             nearby_line:match("server%s*:%s*true") then
            has_guard = true
            break
          end
        end

        if not has_guard then
          table.insert(diagnostics, {
            lnum = lnum - 1,
            col = line:find(api) - 1,
            end_col = (line:find(api) or 0) + #api - 1,
            severity = vim.diagnostic.severity.ERROR,
            message = string.format("'%s' is server-only. Use in server route or with process.server guard", api),
            source = "nuxt-dx",
          })
        end
      end
    end
  end

  return diagnostics
end

-- Check for improper definePageMeta usage
function M.check_page_meta(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diagnostics = {}

  for lnum, line in ipairs(lines) do
    -- Check for definePageMeta outside <script setup>
    if line:match("definePageMeta") then
      local in_script_setup = false

      -- Look backwards for <script setup>
      for i = lnum - 1, 1, -1 do
        if lines[i]:match("<script%s+setup") or lines[i]:match("<script%s+.*setup") then
          in_script_setup = true
          break
        elseif lines[i]:match("</script>") then
          break
        end
      end

      if not in_script_setup then
        table.insert(diagnostics, {
          lnum = lnum - 1,
          col = line:find("definePageMeta") - 1,
          severity = vim.diagnostic.severity.ERROR,
          message = "definePageMeta must be used inside <script setup>",
          source = "nuxt-dx",
        })
      end
    end

    -- Check for definePageMeta with reactive data
    if line:match("definePageMeta") and (line:match("ref%(") or line:match("computed%(") or line:match("reactive%(")) then
      table.insert(diagnostics, {
        lnum = lnum - 1,
        col = 0,
        severity = vim.diagnostic.severity.ERROR,
        message = "definePageMeta cannot use reactive data (refs, computed, reactive)",
        source = "nuxt-dx",
      })
    end
  end

  return diagnostics
end

-- Check for missing await on async composables
function M.check_async_composables(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diagnostics = {}

  local async_composables = {
    "useAsyncData",
    "useFetch",
    "useLazyFetch",
    "useLazyAsyncData",
  }

  for lnum, line in ipairs(lines) do
    for _, composable in ipairs(async_composables) do
      if line:match("%f[%w]" .. composable .. "%f[%W]") then
        -- Check if await is present
        if not line:match("await%s+" .. composable) and not line:match("const%s+{.-}%s*=%s*" .. composable) then
          -- Check if it's inside an async function
          local in_async_function = false
          for i = lnum - 1, math.max(1, lnum - 20), -1 do
            if lines[i]:match("async%s+function") or lines[i]:match("async%s*%(") then
              in_async_function = true
              break
            end
          end

          if in_async_function and not line:match("await") then
            table.insert(diagnostics, {
              lnum = lnum - 1,
              col = line:find(composable) - 1,
              severity = vim.diagnostic.severity.WARN,
              message = string.format("Consider using 'await' with %s for proper data loading", composable),
              source = "nuxt-dx",
            })
          end
        end
      end
    end
  end

  return diagnostics
end

-- Check for route param mismatches
function M.check_route_params(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local root = utils.find_nuxt_root()

  if not root or not filepath:match("/pages/") then
    return {}
  end

  local diagnostics = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Extract route params from file path
  local route_params = {}
  for param in filepath:gmatch("%[([^%]]+)%]") do
    -- Handle [...slug] syntax
    if param:match("^%.%.%.") then
      param = param:gsub("^%.%.%.", "")
    end
    route_params[param] = true
  end

  -- Check for param usage in code
  for lnum, line in ipairs(lines) do
    -- Look for route.params.xxx usage
    for param_name in line:gmatch("route%.params%.(%w+)") do
      if not route_params[param_name] then
        table.insert(diagnostics, {
          lnum = lnum - 1,
          col = line:find("route%.params%." .. param_name) - 1,
          severity = vim.diagnostic.severity.WARN,
          message = string.format("Route param '%s' not defined in file path. Available params: %s",
            param_name,
            next(route_params) and table.concat(vim.tbl_keys(route_params), ", ") or "none"
          ),
          source = "nuxt-dx",
        })
      end
    end
  end

  return diagnostics
end

-- Check for improper Nitro handler signatures
function M.check_nitro_handlers(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if not filepath:match("/server/") then
    return {}
  end

  local diagnostics = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for lnum, line in ipairs(lines) do
    -- Check for defineEventHandler without event parameter
    if line:match("defineEventHandler%s*%(%s*%(%)") then
      table.insert(diagnostics, {
        lnum = lnum - 1,
        col = line:find("defineEventHandler") - 1,
        severity = vim.diagnostic.severity.INFO,
        message = "Consider adding 'event' parameter to access request data",
        source = "nuxt-dx",
      })
    end

    -- Check for missing return in event handler
    local has_handler_def = line:match("defineEventHandler")
    if has_handler_def then
      local has_return = false
      for i = lnum, math.min(#lines, lnum + 20) do
        if lines[i]:match("return%s+") then
          has_return = true
          break
        end
      end

      if not has_return then
        table.insert(diagnostics, {
          lnum = lnum - 1,
          col = 0,
          severity = vim.diagnostic.severity.WARN,
          message = "Event handler should return a value",
          source = "nuxt-dx",
        })
      end
    end
  end

  return diagnostics
end

-- Main diagnostic function
function M.update_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local all_diagnostics = {}

  -- Run all checks
  vim.list_extend(all_diagnostics, M.check_ssr_issues(bufnr))
  vim.list_extend(all_diagnostics, M.check_page_meta(bufnr))
  vim.list_extend(all_diagnostics, M.check_async_composables(bufnr))
  vim.list_extend(all_diagnostics, M.check_route_params(bufnr))
  vim.list_extend(all_diagnostics, M.check_nitro_handlers(bufnr))

  -- Set diagnostics
  vim.diagnostic.set(M.namespace, bufnr, all_diagnostics, {})
end

-- Setup diagnostics autocmd
function M.setup()
  local group = vim.api.nvim_create_augroup("NuxtDXDiagnostics", { clear = true })

  vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "TextChanged", "InsertLeave" }, {
    group = group,
    pattern = { "*.vue", "*.ts", "*.js" },
    callback = function(args)
      -- Debounce the diagnostics update
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          M.update_diagnostics(args.buf)
        end
      end, 500)
    end,
  })
end

-- Clear diagnostics
function M.clear()
  vim.diagnostic.reset(M.namespace)
end

return M

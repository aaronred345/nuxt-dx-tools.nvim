-- API route detection and navigation
local M = {}

local utils = require("nuxt-dx-tools.utils")
local config = {}

function M.set_config(cfg)
  config = cfg
end

-- Extract API call information from current line
function M.extract_api_info()
  local line = vim.api.nvim_get_current_line()

  -- Patterns to match various API call syntaxes
  local patterns = {
    { pattern = "%$fetch%.?%w*%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*{[^}]*method%s*:%s*['\"]([^'\"]+)['\"]", path_idx = 1, method_idx = 2 },
    { pattern = "%$fetch%.?%w*%s*%(%s*['\"]([^'\"]+)['\"]", path_idx = 1, method_idx = nil },
    { pattern = "useFetch%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*{[^}]*method%s*:%s*['\"]([^'\"]+)['\"]", path_idx = 1, method_idx = 2 },
    { pattern = "useFetch%s*%(%s*['\"]([^'\"]+)['\"]", path_idx = 1, method_idx = nil },
    { pattern = "%$fetch%.?%w*%s*%(%s*`([^`]+)`", path_idx = 1, method_idx = nil, is_template = true },
    { pattern = "%$fetch%.?%w*%s*%(%s*['\"]([^'\"]+)['\"]%s*%+", path_idx = 1, method_idx = nil, is_concat = true },
  }

  for _, p in ipairs(patterns) do
    local matches = { line:match(p.pattern) }
    if #matches > 0 then
      local path = matches[p.path_idx]
      local method = p.method_idx and matches[p.method_idx] or "GET"
      
      if p.is_template then
        path = path:gsub("%$%{[^}]+%}", "[id]")
      elseif p.is_concat then
        path = path
      end
      
      return { path = path, method = method }
    end
  end

  return nil
end

-- Find server API routes with support for dynamic parameters and methods
function M.find_server_route(api_path, http_method)
  local root = utils.find_nuxt_root()
  if not root then return nil end

  local route = api_path:gsub("^/api", "")
  if route == "" then route = "/" end

  local server_dir = root .. "/server/api"
  
  local result = utils.try_file_extensions(server_dir .. route, { ".ts", ".js", ".mjs" })
  if result then return result end

  result = utils.try_file_extensions(server_dir .. route .. "/index", { ".ts", ".js", ".mjs" })
  if result then return result end

  if http_method then
    result = utils.try_file_extensions(server_dir .. route .. "." .. http_method:lower(), { ".ts", ".js", ".mjs" })
    if result then return result end

    result = utils.try_file_extensions(server_dir .. route .. "/index." .. http_method:lower(), { ".ts", ".js", ".mjs" })
    if result then return result end
  end

  local parts = vim.split(route, "/", { plain = true })
  for i, part in ipairs(parts) do
    if part:match("^%d+$") or part:match("^[a-zA-Z0-9_-]+$") then
      for _, param_name in ipairs({ "id", "slug", "key", "name" }) do
        local param_parts = vim.deepcopy(parts)
        param_parts[i] = "[" .. param_name .. "]"
        local param_route = table.concat(param_parts, "/")
        
        result = utils.try_file_extensions(server_dir .. param_route, { ".ts", ".js", ".mjs" })
        if result then return result end
        
        if http_method then
          result = utils.try_file_extensions(server_dir .. param_route .. "." .. http_method:lower(), { ".ts", ".js", ".mjs" })
          if result then return result end
        end
      end
    end
  end

  for i = #parts, 1, -1 do
    local wildcard_parts = vim.list_slice(parts, 1, i - 1)
    for _, wildcard in ipairs({ "[...slug]", "[...]" }) do
      table.insert(wildcard_parts, wildcard)
      local wildcard_route = table.concat(wildcard_parts, "/")
      
      result = utils.try_file_extensions(server_dir .. wildcard_route, { ".ts", ".js", ".mjs" })
      if result then return result end
      
      if http_method then
        result = utils.try_file_extensions(server_dir .. wildcard_route .. "." .. http_method:lower(), { ".ts", ".js", ".mjs" })
        if result then return result end
      end
    end
  end

  return nil
end

function M.goto_definition()
  local api_info = M.extract_api_info()
  if not api_info then return false end

  local route_file = M.find_server_route(api_info.path, api_info.method)
  if route_file then
    vim.cmd("edit " .. route_file)
    return true
  else
    vim.notify("API route not found: " .. api_info.path, vim.log.levels.WARN)
    return true
  end
end

function M.show_hover()
  local api_info = M.extract_api_info()
  if not api_info then return false end

  local route_file = M.find_server_route(api_info.path, api_info.method)
  if not route_file then
    vim.notify("API route not found: " .. api_info.path, vim.log.levels.WARN)
    return true
  end

  local file = io.open(route_file, "r")
  if not file then return false end

  local preview_lines = {}
  for i = 1, 3 do
    local line = file:read("*line")
    if not line then break end
    table.insert(preview_lines, line)
  end
  file:close()

  local preview = table.concat(preview_lines, "\n")
  local relative_path = route_file:gsub(utils.find_nuxt_root() .. "/", "")

  local hover_content = {
    "**Server Route:** " .. api_info.path,
    "**Method:** " .. api_info.method,
    "**File:** " .. relative_path,
    "",
    "```typescript",
    preview,
    "```",
  }

  vim.lsp.util.open_floating_preview(hover_content, "markdown", {
    border = "rounded",
    focusable = false,
    max_width = 80,
  })

  return true
end

return M

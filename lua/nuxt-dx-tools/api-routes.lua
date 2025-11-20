-- API route detection and navigation
local M = {}

local utils = require("nuxt-dx-tools.utils")
local config = {}

function M.set_config(cfg)
  config = cfg
end

-- Extract API call information from current line
-- @return table|nil: { path = string, method = string } or nil if no API call found
-- @return string|nil: Error message if extraction failed
function M.extract_api_info()
  -- Safely get current line
  local ok, line = pcall(vim.api.nvim_get_current_line)
  if not ok or not line or line == "" then
    return nil, "Cannot get current line"
  end

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
    -- Safely match pattern
    local ok_match, matches = pcall(function() return { line:match(p.pattern) } end)
    if ok_match and matches and #matches > 0 then
      -- Validate path_idx is within bounds
      if not p.path_idx or p.path_idx > #matches then
        return nil, string.format("Internal error: path_idx %d out of bounds (matches: %d)", p.path_idx or 0, #matches)
      end

      local path = matches[p.path_idx]
      if not path or path == "" then
        return nil, "Extracted path is empty"
      end

      -- Validate method_idx if present
      local method = "GET"  -- Default method
      if p.method_idx then
        if p.method_idx > #matches then
          return nil, string.format("Internal error: method_idx %d out of bounds", p.method_idx)
        end
        method = matches[p.method_idx] or "GET"
      end

      -- Process template strings
      if p.is_template then
        path = path:gsub("%$%{[^}]+%}", "[id]")
      end

      -- Validate method is a valid HTTP method
      local valid_methods = { GET = true, POST = true, PUT = true, DELETE = true, PATCH = true, HEAD = true, OPTIONS = true }
      if not valid_methods[method:upper()] then
        return nil, string.format("Invalid HTTP method: %s", method)
      end

      return { path = path, method = method:upper() }, nil
    end
  end

  return nil, "No API call pattern found in current line"
end

-- Find server API routes with support for dynamic parameters and methods
-- @param api_path string: API path (e.g., "/api/users", "/api/users/123")
-- @param http_method string|nil: HTTP method (GET, POST, etc.)
-- @return string|nil: File path to the route handler, or nil if not found
-- @return string|nil: Error message if search failed
function M.find_server_route(api_path, http_method)
  -- Validate inputs
  if not api_path or api_path == "" then
    return nil, "Invalid API path: empty or nil"
  end

  if http_method and type(http_method) ~= "string" then
    return nil, "Invalid HTTP method: must be a string"
  end

  local root, err = utils.find_nuxt_root()
  if not root then
    return nil, err or "No Nuxt project root found"
  end

  -- Normalize API path
  local route = api_path:gsub("^/api", "")
  if route == "" then
    route = "/"
  end

  local sep = package.config:sub(1,1)
  local server_dir = root .. sep .. "server" .. sep .. "api"

  -- Check if server/api directory exists
  if vim.fn.isdirectory(server_dir) ~= 1 then
    return nil, string.format("Server API directory not found: %s", server_dir)
  end
  
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

-- Extract handler signature from file
function M.extract_handler_signature(file_path)
  local content = utils.read_file(file_path)
  if not content then return nil end

  -- Try to extract defineEventHandler signature
  local handler_pattern = "defineEventHandler%s*%(%s*%(([^)]*)%)"
  local async_pattern = "defineEventHandler%s*%(%s*async%s*%(%s*([^)]*)%)"

  local params = content:match(async_pattern) or content:match(handler_pattern)
  if params then
    return {
      parameters = params,
      is_async = content:match("async") ~= nil,
    }
  end

  -- Try to extract export default signature
  local export_pattern = "export%s+default%s+defineEventHandler%s*%(%s*%(([^)]*)%)"
  params = content:match(export_pattern)
  if params then
    return {
      parameters = params,
      is_async = content:match("async") ~= nil,
    }
  end

  return nil
end

-- Extract return type from handler
function M.extract_return_type(file_path)
  local content = utils.read_file(file_path)
  if not content then return nil end

  -- Look for explicit return type
  local return_type_pattern = ":%s*Promise<([^>]+)>"
  local return_type = content:match(return_type_pattern)
  if return_type then return return_type end

  -- Look for return statements to infer type
  local return_patterns = {
    "return%s+%{",  -- object
    "return%s+%[",  -- array
    "return%s+['\"]", -- string
    "return%s+%d", -- number
    "return%s+true", -- boolean
    "return%s+false", -- boolean
  }

  local type_map = {
    [1] = "object",
    [2] = "array",
    [3] = "string",
    [4] = "number",
    [5] = "boolean",
    [6] = "boolean",
  }

  for i, pattern in ipairs(return_patterns) do
    if content:match(pattern) then
      return type_map[i]
    end
  end

  return nil
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
  for i = 1, 10 do
    local line = file:read("*line")
    if not line then break end
    table.insert(preview_lines, line)
  end
  file:close()

  local preview = table.concat(preview_lines, "\n")
  local relative_path = route_file:gsub(vim.pesc(utils.find_nuxt_root() .. path.separator()), "")

  -- Extract signature information
  local signature = M.extract_handler_signature(route_file)
  local return_type = M.extract_return_type(route_file)

  local hover_content = {
    "**Server Route:** " .. api_info.path,
    "**Method:** " .. api_info.method,
    "**File:** " .. relative_path,
  }

  if signature then
    table.insert(hover_content, "**Parameters:** " .. (signature.parameters ~= "" and signature.parameters or "none"))
    if signature.is_async then
      table.insert(hover_content, "**Type:** async handler")
    end
  end

  if return_type then
    table.insert(hover_content, "**Returns:** " .. return_type)
  end

  table.insert(hover_content, "")
  table.insert(hover_content, "```typescript")
  table.insert(hover_content, preview)
  table.insert(hover_content, "```")
  table.insert(hover_content, "")
  table.insert(hover_content, "*Press `gd` to open the handler file*")
  table.insert(hover_content, "")
  table.insert(hover_content, "*Press `<leader>nt` to test this endpoint*")

  vim.lsp.util.open_floating_preview(hover_content, "markdown", {
    border = "rounded",
    focusable = false,
    max_width = 80,
  })

  return true
end

-- Open terminal to test API endpoint
function M.test_endpoint_in_terminal()
  local api_info = M.extract_api_info()
  if not api_info then
    vim.notify("No API endpoint found under cursor", vim.log.levels.WARN)
    return
  end

  local route_file = M.find_server_route(api_info.path, api_info.method)
  if not route_file then
    vim.notify("API route not found: " .. api_info.path, vim.log.levels.WARN)
    return
  end

  -- Create curl command based on method
  local method = api_info.method:upper()
  local url = "http://localhost:3000" .. api_info.path

  local curl_cmd
  if method == "GET" then
    curl_cmd = string.format("curl -X GET '%s' | jq", url)
  elseif method == "POST" then
    curl_cmd = string.format("curl -X POST '%s' -H 'Content-Type: application/json' -d '{}' | jq", url)
  elseif method == "PUT" then
    curl_cmd = string.format("curl -X PUT '%s' -H 'Content-Type: application/json' -d '{}' | jq", url)
  elseif method == "DELETE" then
    curl_cmd = string.format("curl -X DELETE '%s' | jq", url)
  else
    curl_cmd = string.format("curl -X %s '%s' | jq", method, url)
  end

  -- Open terminal in a split
  vim.cmd("botright split")
  vim.cmd("terminal " .. curl_cmd)
  vim.cmd("startinsert")
end

-- Open handler file in terminal for quick testing
function M.open_handler_in_terminal()
  local api_info = M.extract_api_info()
  if not api_info then
    vim.notify("No API endpoint found under cursor", vim.log.levels.WARN)
    return
  end

  local route_file = M.find_server_route(api_info.path, api_info.method)
  if not route_file then
    vim.notify("API route not found: " .. api_info.path, vim.log.levels.WARN)
    return
  end

  local root = utils.find_nuxt_root()
  local relative_path = route_file:gsub(vim.pesc(root .. path.separator()), "")

  -- Open terminal with helpful commands
  vim.cmd("botright split")
  vim.cmd("terminal")

  -- Wait for terminal to be ready and send commands
  vim.defer_fn(function()
    local chan_id = vim.b.terminal_job_id
    if chan_id then
      vim.fn.chansend(chan_id, "# Testing Nitro handler: " .. relative_path .. "\r")
      vim.fn.chansend(chan_id, "# Run: npm run dev\r")
      vim.fn.chansend(chan_id, "# Test: curl http://localhost:3000" .. api_info.path .. "\r")
      vim.fn.chansend(chan_id, "\r")
    end
  end, 100)
end

return M

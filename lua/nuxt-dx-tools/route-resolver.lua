-- Route resolution for navigateTo and NuxtLink
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Extract route path from navigateTo call
local function extract_navigate_to_path()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  -- Match: navigateTo('/path') or navigateTo("/path")
  local path = line:match("navigateTo%s*%(%s*['\"]([^'\"]+)['\"]")
  if path then
    return path
  end

  -- Match: navigateTo({ path: '/path' })
  path = line:match("navigateTo%s*%(%s*{%s*path%s*:%s*['\"]([^'\"]+)['\"]")
  if path then
    return path
  end

  return nil
end

-- Extract route path from NuxtLink to attribute
local function extract_nuxt_link_path()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line_num = pos[1]

  -- Get surrounding lines to handle multi-line tags
  local start_line = math.max(1, line_num - 5)
  local end_line = math.min(vim.api.nvim_buf_line_count(bufnr), line_num + 5)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local text = table.concat(lines, "\n")

  -- Match: <NuxtLink to="/path"> or <NuxtLink to='/path'>
  local path = text:match('<NuxtLink[^>]*to%s*=%s*["\']([^"\']+)["\']')
  if path then
    return path
  end

  return nil
end

-- Resolve route path to page file
function M.resolve_route_to_file(route_path)
  if not route_path then return nil end

  local root = utils.find_nuxt_root()
  if not root then return nil end

  -- Remove leading slash
  route_path = route_path:gsub("^/", "")

  -- Handle index routes
  if route_path == "" or route_path == "/" then
    route_path = "index"
  end

  local structure = utils.detect_structure()
  local base_dirs = {}

  if structure.has_app_dir then
    table.insert(base_dirs, root .. "/app/pages")
  end
  table.insert(base_dirs, root .. "/pages")

  -- Try different file extensions and patterns
  local patterns = {
    route_path .. ".vue",
    route_path .. "/index.vue",
    route_path .. ".ts",
    route_path .. ".js",
  }

  -- Also try with brackets for dynamic routes
  -- /users/123 -> /users/[id].vue
  local parts = vim.split(route_path, "/")
  if #parts > 1 then
    local dynamic_patterns = {}
    for i = #parts, 1, -1 do
      local dynamic_parts = vim.deepcopy(parts)
      dynamic_parts[i] = "[id]"
      local dynamic_path = table.concat(dynamic_parts, "/")
      table.insert(dynamic_patterns, dynamic_path .. ".vue")
      table.insert(dynamic_patterns, dynamic_path .. "/index.vue")
    end
    vim.list_extend(patterns, dynamic_patterns)
  end

  -- Search for the file
  for _, base_dir in ipairs(base_dirs) do
    for _, pattern in ipairs(patterns) do
      local file_path = base_dir .. "/" .. pattern
      if vim.fn.filereadable(file_path) == 1 then
        return file_path
      end
    end
  end

  return nil
end

-- Check if cursor is on a route reference and return info
function M.get_route_info()
  local path = extract_navigate_to_path()
  if not path then
    path = extract_nuxt_link_path()
  end

  if not path then
    return nil
  end

  local file_path = M.resolve_route_to_file(path)

  return {
    route = path,
    file_path = file_path,
    type = extract_navigate_to_path() and "navigateTo" or "NuxtLink",
  }
end

-- Go to page file for route under cursor
function M.goto_route_file()
  local info = M.get_route_info()

  if not info then
    return false
  end

  if not info.file_path then
    vim.notify("Could not find page file for route: " .. info.route, vim.log.levels.WARN)
    return true -- We handled it, just couldn't find the file
  end

  vim.cmd("edit " .. info.file_path)
  return true
end

-- Show hover info for route
function M.show_hover()
  local info = M.get_route_info()

  if not info then
    return false
  end

  local lines = {}

  table.insert(lines, "```typescript")
  table.insert(lines, "// Nuxt Route")
  table.insert(lines, info.type .. "('" .. info.route .. "')")
  table.insert(lines, "```")
  table.insert(lines, "")

  if info.file_path then
    table.insert(lines, "**Page File:** `" .. info.file_path .. "`")
    table.insert(lines, "")
    table.insert(lines, "*Press `gd` to open the page file*")
  else
    table.insert(lines, "⚠️ **Page file not found for route:** `" .. info.route .. "`")
    table.insert(lines, "")
    table.insert(lines, "Expected in `pages/` or `app/pages/`")
  end

  vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    focusable = false,
    focus = false,
  })

  return true
end

return M

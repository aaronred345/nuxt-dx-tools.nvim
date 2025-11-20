-- definePageMeta support for layouts and middleware
local M = {}

local utils = require("nuxt-dx-tools.utils")
local path = require("nuxt-dx-tools.path")

local function find_layout(layout_name)
  local root = utils.find_nuxt_root()
  if not root then return nil end

  -- Try app/layouts first (Nuxt 4), then layouts (Nuxt 3)
  local possible_dirs = utils.get_directory_paths("layouts")

  for _, layouts_dir in ipairs(possible_dirs) do
    local result = utils.try_file_extensions(path.join(layouts_dir, layout_name), { ".vue", ".ts", ".js" })
    if result then
      return result
    end
  end

  return nil
end

local function find_middleware(middleware_name)
  local root = utils.find_nuxt_root()
  if not root then return nil end

  -- Try app/middleware first (Nuxt 4), then middleware (Nuxt 3)
  local possible_dirs = utils.get_directory_paths("middleware")

  for _, middleware_dir in ipairs(possible_dirs) do
    local patterns = {
      path.join(middleware_dir, middleware_name),
      path.join(middleware_dir, middleware_name) .. ".global",
    }

    for _, pattern in ipairs(patterns) do
      local result = utils.try_file_extensions(pattern, { ".ts", ".js" })
      if result then return result end
    end
  end

  return nil
end

local function parse_page_meta()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local results = {}

  local meta_block = content:match("definePageMeta%s*%(%s*({.-%})%s*%)")
  if not meta_block then return results end

  local layout = meta_block:match("layout%s*:%s*['\"]([^'\"]+)['\"]")
  if layout then
    table.insert(results, { type = "layout", name = layout })
  end

  local middleware_str = meta_block:match("middleware%s*:%s*['\"]([^'\"]+)['\"]")
  if middleware_str then
    table.insert(results, { type = "middleware", name = middleware_str })
  end

  local middleware_array = meta_block:match("middleware%s*:%s*%[([^%]]+)%]")
  if middleware_array then
    for mw in middleware_array:gmatch("['\"]([^'\"]+)['\"]") do
      table.insert(results, { type = "middleware", name = mw })
    end
  end

  return results
end

function M.goto_definition(word, line)
  if not line:match("definePageMeta") and not line:match("layout%s*:") and not line:match("middleware%s*:") then
    return false
  end

  local meta_items = parse_page_meta()
  if #meta_items == 0 then return false end

  local items = {}
  for _, item in ipairs(meta_items) do
    local filepath
    if item.type == "layout" then
      filepath = find_layout(item.name)
    elseif item.type == "middleware" then
      filepath = find_middleware(item.name)
    end
    if filepath then
      table.insert(items, { filename = filepath, text = item.type .. ": " .. item.name })
    end
  end

  if #items == 0 then return false end

  if #items == 1 then
    vim.cmd("edit " .. items[1].filename)
    return true
  else
    vim.ui.select(items, {
      prompt = "Select definition:",
      format_item = function(item) return item.text end,
    }, function(choice)
      if choice then
        vim.cmd("edit " .. choice.filename)
      end
    end)
    return true
  end
end

return M

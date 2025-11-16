-- Utility functions
local M = {}

local config = {}
local structure_cache = nil

function M.set_config(cfg)
  config = cfg
end

-- Detect if project uses Nuxt 4 app/ directory structure
function M.detect_structure()
  if structure_cache then
    return structure_cache
  end

  local root = M.find_nuxt_root()
  if not root then
    return { has_app_dir = false }
  end

  -- Check if app/ directory exists and contains typical Nuxt directories
  local app_dir = root .. "/app"
  local has_app_dir = vim.fn.isdirectory(app_dir) == 1

  structure_cache = {
    has_app_dir = has_app_dir,
    root = root
  }

  return structure_cache
end

-- Get possible directory paths in priority order (Nuxt 4 app/ first, then root)
function M.get_directory_paths(subdir)
  local root = M.find_nuxt_root()
  if not root then return {} end

  local structure = M.detect_structure()
  local paths = {}

  -- If app/ directory exists, check there first
  if structure.has_app_dir then
    table.insert(paths, root .. "/app/" .. subdir)
  end

  -- Always check root directory as fallback
  table.insert(paths, root .. "/" .. subdir)

  return paths
end

-- Find Nuxt project root
function M.find_nuxt_root(force)
  local cache = require("nuxt-dx-tools.cache")
  
  if config.nuxt_root then
    return config.nuxt_root
  end

  local markers = { ".nuxt", "nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs" }
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fn.fnamemodify(current_file, ":h")

  -- Search upward from current file
  local path = current_dir
  while path ~= "/" do
    for _, marker in ipairs(markers) do
      local marker_path = path .. "/" .. marker
      if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
        config.nuxt_root = path
        return path
      end
    end
    path = vim.fn.fnamemodify(path, ":h")
  end

  return nil
end

-- Read file content
function M.read_file(filepath)
  local file = io.open(filepath, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

-- Check if file exists
function M.file_exists(filepath)
  return vim.fn.filereadable(filepath) == 1
end

-- Try file with various extensions
function M.try_file_extensions(base_path, extensions)
  extensions = extensions or { ".ts", ".js", ".mjs", ".vue" }
  for _, ext in ipairs(extensions) do
    local file_path = base_path .. ext
    if M.file_exists(file_path) then
      return file_path
    end
  end
  return nil
end

-- Find custom plugin definitions
function M.find_custom_plugin_definition(symbol)
  local root = M.find_nuxt_root()
  if not root then return nil end

  -- Build search directories list, checking app/ subdirectories first
  local search_dirs = {}

  -- Add app/types and app/plugins if app/ directory exists
  local structure = M.detect_structure()
  if structure.has_app_dir then
    table.insert(search_dirs, root .. "/app/types")
    table.insert(search_dirs, root .. "/app/plugins")
  end

  -- Add root-level directories
  table.insert(search_dirs, root .. "/types")
  table.insert(search_dirs, root .. "/plugins")
  table.insert(search_dirs, root .. "/.nuxt")

  for _, dir in ipairs(search_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.d.ts", false, true)
      for _, file in ipairs(files) do
        local content = M.read_file(file)
        if content and content:match("%$" .. symbol) then
          return file
        end
      end
    end
  end

  return nil
end

return M

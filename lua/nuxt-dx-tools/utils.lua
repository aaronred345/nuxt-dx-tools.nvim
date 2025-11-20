-- Utility functions
local M = {}

local config = {}
local structure_cache = nil

function M.set_config(cfg)
  config = cfg
end

-- Clear all caches (call when .nuxt directory changes)
function M.clear_cache()
  structure_cache = nil
  config.nuxt_root = nil
  local cache = require("nuxt-dx-tools.cache")
  cache.clear_all()
end

-- Detect if project uses Nuxt 4 app/ directory structure
-- @return table: Structure info with has_app_dir and root fields
function M.detect_structure()
  if structure_cache then
    return structure_cache
  end

  local root, err = M.find_nuxt_root()
  if not root then
    -- Return safe defaults when no root found
    structure_cache = { has_app_dir = false, root = nil, error = err }
    return structure_cache
  end

  -- Check if app/ directory exists and contains typical Nuxt directories
  local sep = package.config:sub(1,1)
  local app_dir = root .. sep .. "app"
  local has_app_dir = vim.fn.isdirectory(app_dir) == 1

  structure_cache = {
    has_app_dir = has_app_dir,
    root = root,
    error = nil
  }

  return structure_cache
end

-- Get possible directory paths in priority order (Nuxt 4 app/ first, then root)
-- @param subdir string: Subdirectory name (e.g., "components", "composables")
-- @return table: List of possible paths, empty if no root found
-- @return string|nil: Error message if failed
function M.get_directory_paths(subdir)
  if not subdir or subdir == "" then
    return {}, "Invalid subdir: empty or nil"
  end

  local root, err = M.find_nuxt_root()
  if not root then
    return {}, err or "No Nuxt project root found"
  end

  local structure = M.detect_structure()
  local paths = {}
  local sep = package.config:sub(1,1)  -- System path separator

  -- If app/ directory exists, check there first
  if structure.has_app_dir then
    table.insert(paths, root .. sep .. "app" .. sep .. subdir)
  end

  -- Always check root directory as fallback
  table.insert(paths, root .. sep .. subdir)

  return paths, nil
end

-- Find Nuxt project root with improved monorepo support
-- @param force boolean: Force re-detection even if cached
-- @param start_path string|nil: Starting directory (defaults to current buffer directory)
-- @return string|nil: Project root path or nil if not found
-- @return string|nil: Error message if not found
function M.find_nuxt_root(force, start_path)
  local cache = require("nuxt-dx-tools.cache")

  if config.nuxt_root and not force then
    return config.nuxt_root, nil
  end

  local markers = { ".nuxt", "nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs" }
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = start_path or vim.fn.fnamemodify(current_file, ":h")

  -- Handle empty buffer or invalid path
  if not current_dir or current_dir == "" then
    return nil, "Cannot determine current directory (empty buffer?)"
  end

  -- Search upward from current file (with depth limit for performance)
  local path = current_dir
  local depth = 0
  local max_depth = 50  -- Prevent infinite loops in edge cases

  -- Support both Unix and Windows root detection
  local is_root = function(p)
    return p == "/" or p == "" or p:match("^%a:[\\/]$")  -- Unix / or Windows C:\ or C:/
  end

  while not is_root(path) and depth < max_depth do
    for _, marker in ipairs(markers) do
      -- Use proper path separator for platform
      local sep = package.config:sub(1,1)  -- Gets system path separator
      local marker_path = path .. sep .. marker

      if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
        -- Prefer directories with .nuxt/ generated (active project)
        -- This helps in monorepos to find the nearest active Nuxt project
        local nuxt_dir = path .. sep .. ".nuxt"
        if vim.fn.isdirectory(nuxt_dir) == 1 then
          config.nuxt_root = path
          return path, nil
        end

        -- If we find nuxt.config.* but no .nuxt, store as candidate
        if marker ~= ".nuxt" then
          config.nuxt_root = path
          return path, nil
        end
      end
    end

    path = vim.fn.fnamemodify(path, ":h")
    depth = depth + 1
  end

  return nil, "No Nuxt project found. Make sure .nuxt directory exists (run 'nuxt dev' or 'nuxt build' first) or nuxt.config.* is present."
end

-- Read file content with proper error handling
-- @param filepath string: Path to file
-- @return string|nil: File content or nil on error
-- @return string|nil: Error message if failed
function M.read_file(filepath)
  if not filepath or filepath == "" then
    return nil, "Invalid filepath: empty or nil"
  end

  local file, err = io.open(filepath, "r")
  if not file then
    return nil, string.format("Cannot open file '%s': %s", filepath, err or "unknown error")
  end

  local ok, content = pcall(function() return file:read("*all") end)
  file:close()

  if not ok then
    return nil, string.format("Error reading file '%s': %s", filepath, content)
  end

  return content, nil
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
-- @param symbol string: Symbol name to search for (e.g., "fetch", "dialog")
-- @return string|nil: File path containing the definition, or nil if not found
-- @return string|nil: Error message if search failed
function M.find_custom_plugin_definition(symbol)
  if not symbol or symbol == "" then
    return nil, "Invalid symbol: empty or nil"
  end

  local root, err = M.find_nuxt_root()
  if not root then
    return nil, err or "No Nuxt project root found"
  end

  -- Build search directories list, checking app/ subdirectories first
  local search_dirs = {}
  local sep = package.config:sub(1,1)

  -- Add app/types and app/plugins if app/ directory exists
  local structure = M.detect_structure()
  if structure.has_app_dir then
    table.insert(search_dirs, root .. sep .. "app" .. sep .. "types")
    table.insert(search_dirs, root .. sep .. "app" .. sep .. "plugins")
  end

  -- Add root-level directories
  table.insert(search_dirs, root .. sep .. "types")
  table.insert(search_dirs, root .. sep .. "plugins")
  table.insert(search_dirs, root .. sep .. ".nuxt")

  local files_searched = 0
  for _, dir in ipairs(search_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      -- Use pcall to safely handle glob operations that might fail
      local ok, files = pcall(vim.fn.glob, dir .. "/**/*.d.ts", false, true)
      if ok and files then
        for _, file in ipairs(files) do
          files_searched = files_searched + 1
          local content, read_err = M.read_file(file)
          if content and content:match("%$" .. vim.pesc(symbol)) then  -- Escape special chars
            return file, nil
          end
          -- Continue searching even if one file fails to read
        end
      end
    end
  end

  return nil, string.format("Symbol '$%s' not found (searched %d files)", symbol, files_searched)
end

return M

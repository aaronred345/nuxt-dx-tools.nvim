-- Utility functions
local M = {}

local config = {}

function M.set_config(cfg)
  config = cfg
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

  local search_dirs = {
    root .. "/types",
    root .. "/plugins",
    root .. "/.nuxt",
  }

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

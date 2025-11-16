-- Component and composable mapping management
local M = {}

local utils = require("nuxt-dx-tools.utils")
local cache = require("nuxt-dx-tools.cache")

-- Parse .nuxt/components.d.ts for component mappings
function M.load_mappings()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local components_file = root .. "/.nuxt/components.d.ts"
  if not utils.file_exists(components_file) then
    return {}
  end

  local mappings = {}
  local content = utils.read_file(components_file)
  if not content then return {} end

  -- Match patterns like: 'MyComponent': typeof import('../components/MyComponent.vue')['default']
  -- In Nuxt 4 with app/, this becomes: typeof import('../../app/components/MyComponent.vue')
  for name, path in content:gmatch("'([^']+)':%s*typeof%s+import%('([^']+)'%)") do
    -- Resolve the path properly - the import path is relative to .nuxt/
    -- In Nuxt 3: ../components/Foo.vue → resolve from .nuxt/
    -- In Nuxt 4: ../../app/components/Foo.vue → resolve from .nuxt/
    local nuxt_dir = root .. "/.nuxt"
    local full_path = vim.fn.resolve(nuxt_dir .. "/" .. path)
    -- Normalize the path to remove any .. or . segments
    full_path = vim.fn.fnamemodify(full_path, ":p")
    mappings[name] = full_path
  end

  -- Also handle LazyComponent patterns
  for name, path in content:gmatch("'Lazy([^']+)':%s*typeof%s+import%('([^']+)'%)") do
    local nuxt_dir = root .. "/.nuxt"
    local full_path = vim.fn.resolve(nuxt_dir .. "/" .. path)
    full_path = vim.fn.fnamemodify(full_path, ":p")
    mappings["Lazy" .. name] = full_path
  end

  cache.set_components(mappings)
  return mappings
end

-- Parse .nuxt/imports.d.ts for composable/function mappings
function M.load_composable_mappings()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local imports_file = root .. "/.nuxt/imports.d.ts"
  if not utils.file_exists(imports_file) then
    return {}
  end

  local mappings = {}
  local content = utils.read_file(imports_file)
  if not content then return {} end

  -- Match patterns like: export const useMyComposable: typeof import('../composables/useMyComposable')['default']
  -- In Nuxt 4 with app/, this becomes: typeof import('../../app/composables/useMyComposable')
  for name, path in content:gmatch("const%s+([%w_]+):%s*typeof%s+import%('([^']+)'%)") do
    local nuxt_dir = root .. "/.nuxt"
    local full_path = vim.fn.resolve(nuxt_dir .. "/" .. path)
    -- Normalize the path to remove any .. or . segments
    full_path = vim.fn.fnamemodify(full_path, ":p")
    mappings[name] = full_path
  end

  cache.set_composables(mappings)
  return mappings
end

-- Debug flag (will be set by debug command)
local DEBUG = false

local function log(msg)
  if DEBUG then
    vim.notify("[Nuxt Components] " .. msg, vim.log.levels.INFO)
  end
end

function M.enable_debug()
  DEBUG = true
end

-- Go to component definition
function M.goto_definition(word)
  log("goto_definition called for: " .. word)

  local components = cache.get_components()
  log("Cache has " .. vim.tbl_count(components) .. " components")

  if components[word] then
    log("Found component in cache: " .. components[word])
    vim.cmd("edit " .. components[word])
    return true
  end

  -- Try composables
  local composables = cache.get_composables()
  log("Cache has " .. vim.tbl_count(composables) .. " composables")

  if composables[word] then
    log("Found composable in cache: " .. composables[word])
    vim.cmd("edit " .. composables[word])
    return true
  end

  -- Fallback: try type parser for component info
  log("Trying type parser as fallback")
  local type_parser = require("nuxt-dx-tools.type-parser")
  local symbol_info = type_parser.get_symbol_info(word)

  if symbol_info then
    log("Type parser found symbol, type: " .. (symbol_info.type or "nil"))
  end

  if symbol_info and symbol_info.type == "component" and symbol_info.path then
    log("Type parser has component path: " .. symbol_info.path)
    -- Make sure the file exists
    if vim.fn.filereadable(symbol_info.path) == 1 then
      log("File is readable, opening: " .. symbol_info.path)
      vim.cmd("edit " .. symbol_info.path)
      return true
    else
      log("File is not readable: " .. symbol_info.path)
    end
  end

  log("Component not found for: " .. word)
  return false
end

-- Show component info
function M.show_info(word)
  local components = cache.get_components()
  
  if components[word] then
    vim.notify("Component: " .. word .. "\nPath: " .. components[word], vim.log.levels.INFO)
  else
    vim.notify("Not a recognized component: " .. word, vim.log.levels.WARN)
  end
end

return M

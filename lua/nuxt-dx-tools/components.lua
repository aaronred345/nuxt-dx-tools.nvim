-- Component and composable mapping management
local M = {}

local utils = require("nuxt-dx-tools.utils")
local cache = require("nuxt-dx-tools.cache")

-- Parse .nuxt/components.d.ts for component mappings
-- @return table: Component name to path mappings
-- @return string|nil: Error message if failed
function M.load_mappings()
  local root, err = utils.find_nuxt_root()
  if not root then
    local msg = err or "No Nuxt project found"
    vim.notify("[Nuxt Components] " .. msg, vim.log.levels.WARN)
    return {}, msg
  end

  local sep = package.config:sub(1,1)
  local components_file = root .. sep .. ".nuxt" .. sep .. "components.d.ts"

  if not utils.file_exists(components_file) then
    local msg = string.format(
      ".nuxt/components.d.ts not found. Run 'nuxt dev' or 'nuxt build' to generate it.\nSearched: %s",
      components_file
    )
    vim.notify("[Nuxt Components] " .. msg, vim.log.levels.WARN)
    return {}, msg
  end

  local content, read_err = utils.read_file(components_file)
  if not content then
    local msg = read_err or "Failed to read components.d.ts"
    vim.notify("[Nuxt Components] " .. msg, vim.log.levels.ERROR)
    return {}, msg
  end

  local mappings = {}
  local nuxt_dir = root .. sep .. ".nuxt"

  -- Match patterns like: 'MyComponent': typeof import('../components/MyComponent.vue')['default']
  -- In Nuxt 4 with app/, this becomes: typeof import('../../app/components/MyComponent.vue')
  for name, path in content:gmatch("'([^']+)':%s*typeof%s+import%('([^']+)'%)") do
    -- Resolve the path properly - the import path is relative to .nuxt/
    local full_path = vim.fn.resolve(nuxt_dir .. sep .. path)
    -- Normalize the path to remove any .. or . segments
    full_path = vim.fn.fnamemodify(full_path, ":p")
    mappings[name] = full_path
  end

  -- Also handle LazyComponent patterns
  for name, path in content:gmatch("'Lazy([^']+)':%s*typeof%s+import%('([^']+)'%)") do
    local full_path = vim.fn.resolve(nuxt_dir .. sep .. path)
    full_path = vim.fn.fnamemodify(full_path, ":p")
    mappings["Lazy" .. name] = full_path
  end

  local count = vim.tbl_count(mappings)
  log(string.format("Loaded %d component mappings", count))

  cache.set_components(mappings)
  return mappings, nil
end

-- Parse .nuxt/imports.d.ts for composable/function mappings
-- @return table: Composable name to path mappings
-- @return string|nil: Error message if failed
function M.load_composable_mappings()
  local root, err = utils.find_nuxt_root()
  if not root then
    local msg = err or "No Nuxt project found"
    vim.notify("[Nuxt Composables] " .. msg, vim.log.levels.WARN)
    return {}, msg
  end

  local sep = package.config:sub(1,1)
  local imports_file = root .. sep .. ".nuxt" .. sep .. "imports.d.ts"

  if not utils.file_exists(imports_file) then
    local msg = string.format(
      ".nuxt/imports.d.ts not found. Run 'nuxt dev' or 'nuxt build' to generate it.\nSearched: %s",
      imports_file
    )
    vim.notify("[Nuxt Composables] " .. msg, vim.log.levels.WARN)
    return {}, msg
  end

  local content, read_err = utils.read_file(imports_file)
  if not content then
    local msg = read_err or "Failed to read imports.d.ts"
    vim.notify("[Nuxt Composables] " .. msg, vim.log.levels.ERROR)
    return {}, msg
  end

  local mappings = {}
  local nuxt_dir = root .. sep .. ".nuxt"

  -- Match patterns like: export const useMyComposable: typeof import('../composables/useMyComposable')['default']
  -- In Nuxt 4 with app/, this becomes: typeof import('../../app/composables/useMyComposable')
  for name, path in content:gmatch("const%s+([%w_]+):%s*typeof%s+import%('([^']+)'%)") do
    local full_path = vim.fn.resolve(nuxt_dir .. sep .. path)
    -- Normalize the path to remove any .. or . segments
    full_path = vim.fn.fnamemodify(full_path, ":p")
    mappings[name] = full_path
  end

  local count = vim.tbl_count(mappings)
  log(string.format("Loaded %d composable mappings", count))

  cache.set_composables(mappings)
  return mappings, nil
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

function M.toggle_debug()
  DEBUG = not DEBUG
  if DEBUG then
    vim.notify("Nuxt Components debug mode enabled", vim.log.levels.INFO)
  else
    vim.notify("Nuxt Components debug mode disabled", vim.log.levels.INFO)
  end
end

-- Go to component definition
-- @param word string: Component or composable name
-- @return boolean: true if definition found and opened, false otherwise
function M.goto_definition(word)
  if not word or word == "" then
    vim.notify("[Nuxt] Invalid symbol name", vim.log.levels.ERROR)
    return false
  end

  log("goto_definition called for: " .. word)

  local components = cache.get_components()
  log("Cache has " .. vim.tbl_count(components) .. " components")

  if components[word] then
    log("Found component in cache: " .. components[word])
    -- Verify file exists before opening
    if vim.fn.filereadable(components[word]) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(components[word]))
      return true
    else
      vim.notify(
        string.format("[Nuxt] Component file not found: %s\nTry running :NuxtRefresh", components[word]),
        vim.log.levels.WARN
      )
      return false
    end
  end

  -- Try composables
  local composables = cache.get_composables()
  log("Cache has " .. vim.tbl_count(composables) .. " composables")

  if composables[word] then
    log("Found composable in cache: " .. composables[word])
    -- Verify file exists before opening
    if vim.fn.filereadable(composables[word]) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(composables[word]))
      return true
    else
      vim.notify(
        string.format("[Nuxt] Composable file not found: %s\nTry running :NuxtRefresh", composables[word]),
        vim.log.levels.WARN
      )
      return false
    end
  end

  -- Fallback: try type parser for component info
  log("Trying type parser as fallback")
  local ok, type_parser = pcall(require, "nuxt-dx-tools.type-parser")
  if not ok then
    vim.notify("[Nuxt] Failed to load type parser: " .. type_parser, vim.log.levels.ERROR)
    return false
  end

  local symbol_info = type_parser.get_symbol_info(word)

  if symbol_info then
    log("Type parser found symbol, type: " .. (symbol_info.type or "nil"))
  end

  if symbol_info and symbol_info.type == "component" and symbol_info.path then
    log("Type parser has component path: " .. symbol_info.path)
    -- Make sure the file exists
    if vim.fn.filereadable(symbol_info.path) == 1 then
      log("File is readable, opening: " .. symbol_info.path)
      vim.cmd("edit " .. vim.fn.fnameescape(symbol_info.path))
      return true
    else
      log("File is not readable: " .. symbol_info.path)
      vim.notify(
        string.format("[Nuxt] File not found: %s", symbol_info.path),
        vim.log.levels.WARN
      )
      return false
    end
  end

  log("Component not found for: " .. word)
  vim.notify(
    string.format(
      "[Nuxt] '%s' not found.\n\nPossible causes:\n" ..
      "• Not a Nuxt component or composable\n" ..
      "• .nuxt directory not generated (run 'nuxt dev')\n" ..
      "• Cache needs refresh (run :NuxtRefresh)",
      word
    ),
    vim.log.levels.WARN
  )
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

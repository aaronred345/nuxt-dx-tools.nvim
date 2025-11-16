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
  for name, path in content:gmatch("'([^']+)':%s*typeof%s+import%('([^']+)'%)") do
    local full_path = vim.fn.resolve(root .. "/.nuxt/" .. path)
    mappings[name] = full_path
  end

  -- Also handle LazyComponent patterns
  for name, path in content:gmatch("'Lazy([^']+)':%s*typeof%s+import%('([^']+)'%)") do
    local full_path = vim.fn.resolve(root .. "/.nuxt/" .. path)
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
  for name, path in content:gmatch("const%s+([%w_]+):%s*typeof%s+import%('([^']+)'%)") do
    local full_path = vim.fn.resolve(root .. "/.nuxt/" .. path)
    mappings[name] = full_path
  end

  cache.set_composables(mappings)
  return mappings
end

-- Go to component definition
function M.goto_definition(word)
  local components = cache.get_components()
  if components[word] then
    vim.cmd("edit " .. components[word])
    return true
  end

  -- Try composables
  local composables = cache.get_composables()
  if composables[word] then
    vim.cmd("edit " .. composables[word])
    return true
  end

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

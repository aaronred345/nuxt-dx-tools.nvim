-- Cache management for components and composables
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Cache storage
local cache_data = {
  components = nil,
  composables = nil,
  nuxt_root = nil,
  last_updated = 0,
  ttl = 5, -- seconds
}

-- Check if cache is valid
function M.is_valid()
  local now = os.time()
  return cache_data.components and (now - cache_data.last_updated) < cache_data.ttl
end

-- Clear cache
function M.clear()
  cache_data.components = nil
  cache_data.composables = nil
  cache_data.last_updated = 0
end

-- Get components from cache
function M.get_components()
  if M.is_valid() and cache_data.components then
    return cache_data.components
  end
  return require("nuxt-dx-tools.components").load_mappings()
end

-- Get composables from cache
function M.get_composables()
  if M.is_valid() and cache_data.composables then
    return cache_data.composables
  end
  return require("nuxt-dx-tools.components").load_composable_mappings()
end

-- Set components cache
function M.set_components(data)
  cache_data.components = data
  cache_data.last_updated = os.time()
end

-- Set composables cache
function M.set_composables(data)
  cache_data.composables = data
  cache_data.last_updated = os.time()
end

-- Load all caches
function M.load_all()
  M.get_components()
  M.get_composables()
end

-- Clear all caches
function M.clear_all()
  M.clear()
end

return M

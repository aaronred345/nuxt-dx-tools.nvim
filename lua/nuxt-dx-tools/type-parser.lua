-- Type information parser for Nuxt auto-imports
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Cache for parsed type information
M.cache = {
  imports = {},
  components = {},
  modules = {},
  last_update = 0,
  ttl = 5000, -- 5 seconds
}

-- Parse TypeScript type from declaration
local function parse_type_declaration(line)
  -- Extract function signature: export const useFoo: (...) => ...
  local func_sig = line:match("export%s+const%s+(%w+)%s*:%s*(.+)")
  if func_sig then
    local name, signature = func_sig:match("(%w+)%s*:%s*(.+)")
    return name, signature
  end

  -- Extract function declaration: export function useFoo(...) { }
  local func_decl = line:match("export%s+function%s+(%w+)%s*(%([^)]*%))")
  if func_decl then
    return func_decl
  end

  return nil
end

-- Parse .nuxt/imports.d.ts for all auto-imported symbols
function M.parse_imports()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local imports_file = root .. "/.nuxt/imports.d.ts"
  local content = utils.read_file(imports_file)
  if not content then return {} end

  local imports = {}

  -- Parse each line
  for line in content:gmatch("[^\r\n]+") do
    -- Match: export const useFoo: typeof import('...').useFoo
    local name, import_path = line:match("export%s+const%s+(%w+)%s*:%s*typeof%s+import%(['\"]([^'\"]+)['\"]%)%.(%w+)")
    if name then
      imports[name] = {
        name = name,
        type = "composable",
        import_path = import_path,
        raw_line = line,
      }
    end

    -- Match: export const Foo: typeof import('...').default
    name, import_path = line:match("export%s+const%s+(%w+)%s*:%s*typeof%s+import%(['\"]([^'\"]+)['\"]%)%.default")
    if name then
      imports[name] = {
        name = name,
        type = "composable",
        import_path = import_path,
        raw_line = line,
      }
    end

    -- Match simple exports
    name = line:match("export%s+const%s+(%w+)%s*:")
    if name and not imports[name] then
      imports[name] = {
        name = name,
        type = "symbol",
        raw_line = line,
      }
    end
  end

  return imports
end

-- Parse .nuxt/components.d.ts for all components
function M.parse_components()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local components_file = root .. "/.nuxt/components.d.ts"
  local content = utils.read_file(components_file)
  if not content then return {} end

  local components = {}

  -- Parse component declarations
  for line in content:gmatch("[^\r\n]+") do
    -- Match: 'ComponentName': typeof import('path').default
    local name, path = line:match("'([%w]+)'%s*:%s*typeof%s+import%(['\"]([^'\"]+)['\"]%)%.default")
    if name then
      components[name] = {
        name = name,
        type = "component",
        path = path,
        raw_line = line,
      }
    end

    -- Match: ComponentName: typeof import('path').default
    name, path = line:match("(%w+)%s*:%s*typeof%s+import%(['\"]([^'\"]+)['\"]%)%.default")
    if name and not name:match("^_") and not components[name] then
      components[name] = {
        name = name,
        type = "component",
        path = path,
        raw_line = line,
      }
    end
  end

  return components
end

-- Parse package.json for Nuxt modules
function M.parse_package_modules()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local package_file = root .. "/package.json"
  local content = utils.read_file(package_file)
  if not content then return {} end

  local modules = {}

  -- Find all @nuxt/* and nuxt-* dependencies
  for name in content:gmatch('"(@nuxt/[^"]+)"') do
    modules[name] = { name = name, type = "nuxt-module" }
  end

  for name in content:gmatch('"(nuxt%-[^"]+)"') do
    modules[name] = { name = name, type = "nuxt-module" }
  end

  for name in content:gmatch('"(@nuxtjs/[^"]+)"') do
    modules[name] = { name = name, type = "nuxt-module" }
  end

  return modules
end

-- Update cache if needed
function M.update_cache()
  local now = vim.loop.now()
  if now - M.cache.last_update < M.cache.ttl then
    return
  end

  M.cache.imports = M.parse_imports()
  M.cache.components = M.parse_components()
  M.cache.modules = M.parse_package_modules()
  M.cache.last_update = now
end

-- Get symbol information
function M.get_symbol_info(symbol)
  M.update_cache()

  -- Check imports
  if M.cache.imports[symbol] then
    return M.cache.imports[symbol]
  end

  -- Check components
  if M.cache.components[symbol] then
    return M.cache.components[symbol]
  end

  return nil
end

-- Get all symbols
function M.get_all_symbols()
  M.update_cache()

  local all = {}
  for name, info in pairs(M.cache.imports) do
    all[name] = info
  end
  for name, info in pairs(M.cache.components) do
    all[name] = info
  end

  return all
end

-- Get hover text for a symbol
function M.get_hover_text(symbol)
  local info = M.get_symbol_info(symbol)
  if not info then return nil end

  local lines = {}

  if info.type == "composable" then
    table.insert(lines, "```typescript")
    table.insert(lines, "// Nuxt Auto-import")
    table.insert(lines, info.raw_line or ("const " .. symbol))
    table.insert(lines, "```")

    if info.import_path then
      table.insert(lines, "")
      table.insert(lines, "**Source:** `" .. info.import_path .. "`")
    end
  elseif info.type == "component" then
    table.insert(lines, "```vue")
    table.insert(lines, "<!-- Nuxt Auto-imported Component -->")
    table.insert(lines, "<" .. symbol .. " />")
    table.insert(lines, "```")

    if info.path then
      table.insert(lines, "")
      table.insert(lines, "**Source:** `" .. info.path .. "`")
    end
  end

  return lines
end

-- Clear cache
function M.clear_cache()
  M.cache = {
    imports = {},
    components = {},
    modules = {},
    last_update = 0,
    ttl = 5000,
  }
end

return M

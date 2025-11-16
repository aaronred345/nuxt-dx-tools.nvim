-- Type information parser for Nuxt auto-imports
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Debug flag
local DEBUG = false

local function log(msg)
  if DEBUG then
    vim.notify("[Nuxt Type Parser] " .. msg, vim.log.levels.INFO)
  end
end

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
  if not root then
    log("No Nuxt root found")
    return {}
  end

  local imports_file = root .. "/.nuxt/imports.d.ts"
  log("Parsing imports from: " .. imports_file)

  local content = utils.read_file(imports_file)
  if not content then
    log("Could not read imports file")
    return {}
  end

  local imports = {}
  local line_count = 0
  local sample_lines = {}

  -- Parse each line
  for line in content:gmatch("[^\r\n]+") do
    line_count = line_count + 1

    -- Collect first few export lines for debugging
    if line:match("^%s*export") and #sample_lines < 5 then
      table.insert(sample_lines, line)
    end

    -- Match: export const useFoo: typeof import('...').useFoo
    local name, import_path = line:match("export%s+const%s+(%w+)%s*:%s*typeof%s+import%(['\"]([^'\"]+)['\"]%)%.(%w+)")
    if name then
      imports[name] = {
        name = name,
        type = "composable",
        import_path = import_path,
        raw_line = line,
      }
      log("Found composable: " .. name .. " from " .. import_path)
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
      log("Found default import: " .. name .. " from " .. import_path)
    end

    -- Match simple exports
    name = line:match("export%s+const%s+(%w+)%s*:")
    if name and not imports[name] then
      imports[name] = {
        name = name,
        type = "symbol",
        raw_line = line,
      }
      log("Found symbol: " .. name)
    end
  end

  log("Parsed " .. line_count .. " lines, found " .. vim.tbl_count(imports) .. " imports")

  if #sample_lines > 0 and vim.tbl_count(imports) == 0 then
    log("Sample export lines from file:")
    for i, line in ipairs(sample_lines) do
      log("  Line " .. i .. ": " .. line)
    end
  end

  return imports
end

-- Parse .nuxt/components.d.ts for all components
function M.parse_components()
  local root = utils.find_nuxt_root()
  if not root then
    log("No Nuxt root found for components")
    return {}
  end

  local components_file = root .. "/.nuxt/components.d.ts"
  log("Parsing components from: " .. components_file)

  local content = utils.read_file(components_file)
  if not content then
    log("Could not read components file")
    return {}
  end

  local components = {}
  local line_count = 0
  local sample_lines = {}

  -- Parse component declarations
  for line in content:gmatch("[^\r\n]+") do
    line_count = line_count + 1

    -- Collect first few component lines for debugging
    if (line:match("'%w+'%s*:") or (line:match("%w+%s*:") and not line:match("^%s*export"))) and #sample_lines < 5 then
      table.insert(sample_lines, line)
    end

    -- Match: 'ComponentName': typeof import('path').default
    local name, path = line:match("'([%w]+)'%s*:%s*typeof%s+import%(['\"]([^'\"]+)['\"]%)%.default")
    if name then
      components[name] = {
        name = name,
        type = "component",
        path = path,
        raw_line = line,
      }
      log("Found component (quoted): " .. name .. " from " .. path)
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
      log("Found component (unquoted): " .. name .. " from " .. path)
    end
  end

  log("Parsed " .. line_count .. " lines, found " .. vim.tbl_count(components) .. " components")

  if #sample_lines > 0 and vim.tbl_count(components) == 0 then
    log("Sample component lines from file:")
    for i, line in ipairs(sample_lines) do
      log("  Line " .. i .. ": " .. line)
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

  log("Looking up symbol: " .. symbol)

  -- Check imports
  if M.cache.imports[symbol] then
    log("Found in imports cache")
    return M.cache.imports[symbol]
  end

  -- Check components
  if M.cache.components[symbol] then
    log("Found in components cache")
    return M.cache.components[symbol]
  end

  log("Symbol not found in cache")
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
  log("Getting hover text for: " .. symbol)

  local info = M.get_symbol_info(symbol)
  if not info then
    log("No info found for symbol")
    return nil
  end

  log("Building hover text for type: " .. info.type)

  local lines = {}

  if info.type == "composable" or info.type == "symbol" then
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

  log("Generated " .. #lines .. " lines of hover text")
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

-- Enable debug mode
function M.enable_debug()
  DEBUG = true
  vim.notify("Nuxt Type Parser debug mode enabled", vim.log.levels.INFO)
end

return M

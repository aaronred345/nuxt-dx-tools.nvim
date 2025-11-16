-- Path alias resolution for Nuxt projects (Clean Rewrite)
-- Handles TypeScript path mappings from tsconfig.json
local M = {}

-- Dependencies
local utils = require("nuxt-dx-tools.utils")

-- Cache to avoid re-parsing tsconfig files constantly
local cache = {
  aliases = {},
  timestamp = 0,
  ttl = 10, -- Cache for 10 seconds
}

-- Parse a single tsconfig.json file and extract path mappings
local function parse_tsconfig_file(filepath)
  if not utils.file_exists(filepath) then
    return {}
  end

  local content = utils.read_file(filepath)
  if not content then
    return {}
  end

  -- Remove JSON comments (not standard but commonly used)
  content = content:gsub("//[^\n]*", "")
  content = content:gsub("/%*.-/%*/", "")

  local paths = {}

  -- Find the "paths" section in compilerOptions
  local paths_section = content:match('"paths"%s*:%s*(%b{})')
  if not paths_section then
    return {}
  end

  -- Extract each path mapping: "alias/*": ["target/*"]
  for alias_pattern, target_pattern in paths_section:gmatch('"([^"]+)"%s*:%s*%[%s*"([^"]+)"') do
    -- Remove the /* suffix from both alias and target
    local alias = alias_pattern:gsub("/%*$", "")
    local target = target_pattern:gsub("^%./", ""):gsub("/%*$", "")

    paths[alias] = target
  end

  return paths
end

-- Parse all tsconfig references and merge their path mappings
local function load_all_path_mappings()
  local root = utils.find_nuxt_root()
  if not root then
    return {}
  end

  local main_tsconfig = root .. "/tsconfig.json"
  if not utils.file_exists(main_tsconfig) then
    return {}
  end

  local content = utils.read_file(main_tsconfig)
  if not content then
    return {}
  end

  -- Remove comments
  content = content:gsub("//[^\n]*", "")
  content = content:gsub("/%*.-/%*/", "")

  local all_paths = {}

  -- Extract all referenced tsconfig files from "references" array
  local references_section = content:match('"references"%s*:%s*(%b[])')
  if references_section then
    for ref_path in references_section:gmatch('"path"%s*:%s*"([^"]+)"') do
      local full_path = root .. "/" .. ref_path
      local paths = parse_tsconfig_file(full_path)

      -- Merge paths into all_paths
      for alias, target in pairs(paths) do
        all_paths[alias] = target
      end
    end
  end

  -- Also parse the main tsconfig itself
  local main_paths = parse_tsconfig_file(main_tsconfig)
  for alias, target in pairs(main_paths) do
    all_paths[alias] = target
  end

  return all_paths
end

-- Get all path aliases (with caching)
function M.get_aliases()
  local now = os.time()

  -- Return cached data if still valid
  if cache.aliases and (now - cache.timestamp) < cache.ttl then
    return cache.aliases
  end

  -- Load fresh data
  local aliases = load_all_path_mappings()

  -- Update cache
  cache.aliases = aliases
  cache.timestamp = now

  return aliases
end

-- Get the Nuxt project root directory
function M.get_nuxt_root()
  return utils.find_nuxt_root()
end

-- Resolve an aliased path to an absolute filesystem path
function M.resolve_alias_path(import_path)
  local aliases = M.get_aliases()
  local root = M.get_nuxt_root()

  if not root then
    return nil
  end

  -- Check each alias to see if it matches the import path
  for alias, target in pairs(aliases) do
    if import_path:match("^" .. vim.pesc(alias)) then
      -- Replace the alias with the target path
      local resolved = import_path:gsub("^" .. vim.pesc(alias), target)
      return root .. "/" .. resolved
    end
  end

  return nil
end

-- Find a file by resolving its aliased import path
function M.find_file_from_import(import_path)
  local resolved_path = M.resolve_alias_path(import_path)

  if not resolved_path then
    return nil
  end

  -- Try different file extensions
  local extensions = { ".vue", ".ts", ".js", ".mjs", ".tsx", ".jsx" }

  for _, ext in ipairs(extensions) do
    if utils.file_exists(resolved_path .. ext) then
      return resolved_path .. ext
    end
  end

  -- Try index files
  for _, ext in ipairs(extensions) do
    if utils.file_exists(resolved_path .. "/index" .. ext) then
      return resolved_path .. "/index" .. ext
    end
  end

  return nil
end

-- Extract import path from the current line
local function extract_import_from_line(line)
  local patterns = {
    'from%s+["\']([^"\']+)["\']',
    'import%s+["\']([^"\']+)["\']',
    'import%(["\']([^"\']+)["\']',
  }

  for _, pattern in ipairs(patterns) do
    local path = line:match(pattern)
    if path then
      return path
    end
  end

  return nil
end

-- Navigate to an aliased import (for gd command)
function M.goto_aliased_import()
  local line = vim.api.nvim_get_current_line()
  local import_path = extract_import_from_line(line)

  if not import_path then
    return false
  end

  local file = M.find_file_from_import(import_path)

  if file then
    vim.cmd("edit " .. file)
    return true
  end

  return false
end

-- Clear the cache
function M.clear_cache()
  cache.aliases = {}
  cache.timestamp = 0
end

-- Refresh aliases (clear cache and reload)
function M.refresh()
  M.clear_cache()
  M.get_aliases()
  vim.notify("Path aliases refreshed", vim.log.levels.INFO)
end

-- Show all configured aliases
function M.show_aliases()
  local aliases = M.get_aliases()

  if vim.tbl_isempty(aliases) then
    vim.notify("No path aliases found in tsconfig.json", vim.log.levels.WARN)
    return
  end

  local lines = { "Path Aliases:", "" }

  for alias, target in pairs(aliases) do
    table.insert(lines, string.format("  %s → %s", alias, target))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Setup completion (for nvim-cmp only, blink.cmp uses separate module)
function M.setup_completion()
  local cmp = package.loaded['cmp']
  if not cmp then
    return
  end

  local source = {}

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.get_trigger_characters = function()
    return { '/', '"', "'", '~', '@', '#' }
  end

  source.complete = function(self, params, callback)
    local line = params.context.cursor_before_line

    -- Only complete in import statements
    if not (line:match('from%s+["\']') or line:match('import%s+["\']') or line:match('import%(["\']')) then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local aliases = M.get_aliases()
    local items = {}

    for alias, target in pairs(aliases) do
      table.insert(items, {
        label = alias,
        kind = cmp.lsp.CompletionItemKind.Folder,
        detail = "→ " .. target,
        documentation = {
          kind = "markdown",
          value = string.format("**Path Alias**\n\nResolves to: `%s`", target),
        },
      })
    end

    callback({ items = items, isIncomplete = false })
  end

  cmp.register_source('nuxt-aliases', source.new())
end

return M

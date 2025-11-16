-- Path alias resolution and autocompletion for Nuxt projects
-- Handles ~, @, #app, #build, and other Nuxt/Vue path aliases
-- Auto-imports from tsconfig.json references
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Cache for resolved aliases
local alias_cache = {
  aliases = nil,
  last_updated = 0,
  ttl = 10, -- seconds
}

-- Parse a single tsconfig file for path mappings
local function parse_single_tsconfig(tsconfig_path)
  if not utils.file_exists(tsconfig_path) then
    return {}
  end

  local content = utils.read_file(tsconfig_path)
  if not content then return {} end

  -- Remove comments (// and /* */)
  content = content:gsub("//[^\n]*", "")
  content = content:gsub("/%*.-/%*/", "")

  local aliases = {}

  -- Extract compilerOptions.paths object
  local paths_block = content:match('"paths"%s*:%s*({.-})')
  if not paths_block then
    paths_block = content:match("'paths'%s*:%s*({.-})")
  end

  if paths_block then
    -- Match patterns like: "~/*": ["./src/*"], "@/*": ["./*"]
    for alias, path_array in paths_block:gmatch('["\']([^"\']+)["\']+%s*:%s*%[%s*["\']([^"\']+)["\']') do
      -- Remove /* from alias and path
      local clean_alias = alias:gsub("/%*$", "")
      local clean_path = path_array:gsub("^%./", ""):gsub("/%*$", "")

      -- Store the mapping
      aliases[clean_alias] = clean_path
    end
  end

  return aliases
end

-- Parse tsconfig.json and all referenced configs
local function parse_all_tsconfigs()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local main_tsconfig = root .. "/tsconfig.json"
  if not utils.file_exists(main_tsconfig) then
    return {}
  end

  local content = utils.read_file(main_tsconfig)
  if not content then return {} end

  -- Remove comments
  content = content:gsub("//[^\n]*", "")
  content = content:gsub("/%*.-/%*/", "")

  local all_aliases = {}

  -- Extract referenced tsconfig files
  local references_block = content:match('"references"%s*:%s*%[(.-)%]')
  if not references_block then
    references_block = content:match("'references'%s*:%s*%[(.-)%]")
  end

  if references_block then
    -- Extract all "path" values from references
    for path in references_block:gmatch('["\']path["\']+%s*:%s*["\']([^"\']+)["\']') do
      local tsconfig_path = root .. "/" .. path
      local aliases = parse_single_tsconfig(tsconfig_path)

      -- Merge aliases
      for alias, target in pairs(aliases) do
        all_aliases[alias] = target
      end
    end
  end

  -- Also parse the main tsconfig in case it has paths
  local main_aliases = parse_single_tsconfig(main_tsconfig)
  for alias, target in pairs(main_aliases) do
    all_aliases[alias] = target
  end

  return all_aliases
end

-- Get all aliases with caching
function M.get_aliases()
  local now = os.time()

  if alias_cache.aliases and (now - alias_cache.last_updated) < alias_cache.ttl then
    return alias_cache.aliases
  end

  local aliases = parse_all_tsconfigs()

  alias_cache.aliases = aliases
  alias_cache.last_updated = now

  return aliases
end

-- Resolve a path with alias to absolute path
function M.resolve_alias(import_path)
  local aliases = M.get_aliases()
  local root = utils.find_nuxt_root()
  if not root then return nil end

  -- Check each alias
  for alias, target in pairs(aliases) do
    if import_path:match("^" .. vim.pesc(alias)) then
      -- Replace alias with target path
      local resolved = import_path:gsub("^" .. vim.pesc(alias), target)

      -- Make it absolute
      local absolute_path = root .. "/" .. resolved

      return absolute_path
    end
  end

  return nil
end

-- Find file from import statement with alias support
function M.find_import_file(import_path)
  -- First try to resolve alias
  local resolved = M.resolve_alias(import_path)

  if resolved then
    -- Try with various extensions
    local result = utils.try_file_extensions(resolved, { ".vue", ".ts", ".js", ".mjs", ".tsx", ".jsx" })
    if result then return result end

    -- Try as directory with index file
    result = utils.try_file_extensions(resolved .. "/index", { ".vue", ".ts", ".js", ".mjs", ".tsx", ".jsx" })
    if result then return result end
  end

  return nil
end

-- Extract import path from current line
local function extract_import_path()
  local line = vim.api.nvim_get_current_line()

  -- Match various import patterns
  local patterns = {
    'from%s+["\']([^"\']+)["\']',   -- from "path"
    'import%s+["\']([^"\']+)["\']', -- import "path"
    'import%(+["\']([^"\']+)["\']', -- import("path")
  }

  for _, pattern in ipairs(patterns) do
    local path = line:match(pattern)
    if path then return path end
  end

  return nil
end

-- Go to definition for aliased imports
function M.goto_aliased_import()
  local import_path = extract_import_path()
  if not import_path then return false end

  local file = M.find_import_file(import_path)
  if file then
    vim.cmd("edit " .. file)
    return true
  end

  return false
end

-- Setup autocompletion for path aliases (supports both nvim-cmp and blink.cmp)
function M.setup_completion()
  -- Try blink.cmp first
  local blink_ok, blink = pcall(require, 'blink.cmp')
  if blink_ok then
    M.setup_blink_completion(blink)
    return
  end

  -- Fall back to nvim-cmp
  local cmp = package.loaded['cmp']
  if cmp then
    M.setup_nvim_cmp_completion(cmp)
    return
  end
end

-- Blink.cmp completion source
function M.setup_blink_completion(blink)
  -- Blink.cmp uses a different registration method
  -- We need to return a source provider that blink.cmp can use

  local source = {}

  source.name = 'nuxt-aliases'

  function source.get_completions(self, ctx)
    local line = ctx.line or ctx.cursor_before_line or ''

    -- Check if we're in an import statement
    if not (line:match('from%s+["\']') or line:match('import%s+["\']') or line:match('import%(+["\']')) then
      return { items = {} }
    end

    local aliases = M.get_aliases()
    local items = {}

    -- Add alias completions
    for alias, target in pairs(aliases) do
      table.insert(items, {
        label = alias,
        kind = 19, -- Folder kind
        detail = "→ " .. target,
        documentation = {
          kind = 'markdown',
          value = string.format("**Path Alias**\n\nResolves to: `%s`", target),
        },
        insertText = alias,
      })
    end

    return { items = items }
  end

  function source.resolve(self, item)
    return item
  end

  function source.execute(self, item, callback)
    if callback then callback() end
  end

  -- For blink.cmp, we store the source in a global table
  -- and configure it via the blink.cmp setup
  _G.nuxt_aliases_blink_source = source
end

-- nvim-cmp completion source
function M.setup_nvim_cmp_completion(cmp)
  local source = {}

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.get_trigger_characters = function()
    return { '/', '"', "'" }
  end

  source.complete = function(self, params, callback)
    local line = params.context.cursor_before_line

    -- Check if we're in an import statement
    if not (line:match('from%s+["\']') or line:match('import%s+["\']') or line:match('import%(+["\']')) then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local aliases = M.get_aliases()
    local items = {}

    -- Add alias completions
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

  -- Register the source
  cmp.register_source('nuxt-aliases', source.new())
end

-- Refresh alias cache
function M.refresh()
  alias_cache.aliases = nil
  alias_cache.last_updated = 0
  M.get_aliases()
  vim.notify("Path aliases refreshed", vim.log.levels.INFO)
end

-- Show all configured aliases
function M.show_aliases()
  local aliases = M.get_aliases()

  if vim.tbl_isempty(aliases) then
    vim.notify("No path aliases found in tsconfig", vim.log.levels.WARN)
    return
  end

  local lines = { "**Configured Path Aliases:**", "" }
  for alias, target in pairs(aliases) do
    table.insert(lines, string.format("• `%s` → `%s`", alias, target))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M

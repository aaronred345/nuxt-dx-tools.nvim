-- Blink.cmp completion source for Nuxt path aliases and relative paths (Clean Rewrite)
local M = {}

-- Create a new source instance
function M.new()
  local self = setmetatable({}, { __index = M })
  return self
end

-- Characters that should trigger completion
function M:get_trigger_characters()
  return { '/', '"', "'", '~', '@', '#', '.' }
end

-- Completion item kinds (matching LSP spec)
local CompletionItemKind = {
  File = 1,
  Module = 3,
  Class = 9,
  Folder = 19,
}

-- Extract the import path being typed from the current line
local function get_import_path(line)
  local patterns = {
    'from%s+["\']([^"\']*)',   -- import X from "..."
    'import%s+["\']([^"\']*)', -- import "..."
    'import%(["\']([^"\']*)',  -- import("...")
  }

  for _, pattern in ipairs(patterns) do
    local match = line:match(pattern)
    if match then
      return match
    end
  end

  return nil
end

-- Check if a path is relative (./ or ../)
local function is_relative_path(path)
  return path:match("^%.") ~= nil
end

-- Resolve a relative path based on the current file
local function resolve_relative_path(current_file, relative_path)
  local current_dir = vim.fn.fnamemodify(current_file, ":h")
  local working_dir = current_dir
  local remaining_path = relative_path

  -- Handle ../ (go up directories)
  while remaining_path:match("^%.%./") do
    working_dir = vim.fn.fnamemodify(working_dir, ":h")
    remaining_path = remaining_path:gsub("^%.%./", "", 1)
  end

  -- Handle ./ (current directory)
  if remaining_path:match("^%./") then
    remaining_path = remaining_path:gsub("^%./", "", 1)
  end

  -- Add any subdirectory path
  if remaining_path ~= "" and remaining_path ~= "." and remaining_path ~= ".." then
    local subdir = remaining_path:match("^(.+)/[^/]*$")
    if subdir then
      working_dir = working_dir .. "/" .. subdir
    end
  end

  return working_dir
end

-- Determine what prefix to add to completion labels
local function get_label_prefix(typed_path)
  -- For relative paths, include the ./ or ../ prefix
  if typed_path:match("^%.") then
    local prefix = typed_path:match("^(%.%.?/?)")
    if not prefix then
      return typed_path
    end

    -- If there's a subdirectory being typed
    local subdir = typed_path:match("^%.%.?/(.+)/[^/]*$")
    if subdir then
      return prefix .. subdir .. "/"
    end

    return prefix
  end

  -- For alias paths, include the alias
  for _, alias in ipairs({ "~", "~~", "@", "@@" }) do
    if typed_path:match("^" .. vim.pesc(alias)) then
      local subdir = typed_path:match("^" .. vim.pesc(alias) .. "/?(.+)/[^/]*$")
      if subdir then
        return alias .. "/" .. subdir .. "/"
      end
      return alias .. "/"
    end
  end

  -- For custom aliases like #app, #build, etc.
  local custom_alias = typed_path:match("^(#[^/]*)")
  if custom_alias then
    local subdir = typed_path:match("^#[^/]*/(.+)/[^/]*$")
    if subdir then
      return custom_alias .. "/" .. subdir .. "/"
    end
    return custom_alias .. "/"
  end

  return ""
end

-- Get all files and directories in a given directory
local function get_directory_contents(dir_path)
  if vim.fn.isdirectory(dir_path) == 0 then
    return {}
  end

  local entries = {}
  local items = vim.fn.readdir(dir_path)

  for _, name in ipairs(items) do
    local full_path = dir_path .. "/" .. name
    local is_directory = vim.fn.isdirectory(full_path) == 1

    if is_directory then
      table.insert(entries, {
        name = name,
        is_dir = true,
        path = full_path,
      })
    else
      -- Only show importable files
      local ext = name:match("%.([^%.]+)$")
      if ext and vim.tbl_contains({ "vue", "ts", "js", "mjs", "jsx", "tsx" }, ext) then
        table.insert(entries, {
          name = name,
          is_dir = false,
          path = full_path,
          extension = ext,
        })
      end
    end
  end

  return entries
end

-- Create a completion item from a directory entry
local function make_completion_item(entry, prefix)
  local label = prefix .. entry.name
  if entry.is_dir then
    label = label .. "/"
  end

  local kind
  if entry.is_dir then
    kind = CompletionItemKind.Folder
  elseif entry.extension == "vue" then
    kind = CompletionItemKind.Class
  else
    kind = CompletionItemKind.Module
  end

  return {
    label = label,
    kind = kind,
    detail = entry.is_dir and "Directory" or "File",
    insertText = label,
    documentation = {
      kind = "markdown",
      value = string.format("**%s**\n\n`%s`", entry.is_dir and "Directory" or "File", entry.path),
    },
  }
end

-- Helper to safely call completion callback
local function call_callback(callback, result)
  if type(callback) == "function" then
    callback(result)
  elseif type(callback) == "table" and callback.callback then
    callback:callback(result)
  end
end

-- Main completion function
function M:get_completions(ctx, callback)
  -- Debug logging
  vim.schedule(function()
    vim.notify("[blink-source] get_completions called", vim.log.levels.DEBUG)
  end)

  -- Load path aliases module
  local ok, path_aliases = pcall(require, "nuxt-dx-tools.path-aliases")
  if not ok then
    vim.schedule(function()
      vim.notify("[blink-source] Failed to load path-aliases: " .. tostring(path_aliases), vim.log.levels.ERROR)
    end)
    call_callback(callback, { items = {} })
    return
  end

  local line = ctx.line or ctx.cursor_before_line or vim.api.nvim_get_current_line()

  vim.schedule(function()
    vim.notify("[blink-source] Line: " .. line, vim.log.levels.DEBUG)
  end)

  -- Only provide completions in import statements
  if not (line:match('from%s+["\']') or line:match('import%s+["\']') or line:match('import%(["\']')) then
    vim.schedule(function()
      vim.notify("[blink-source] Not in import statement", vim.log.levels.DEBUG)
    end)
    call_callback(callback, { items = {} })
    return
  end

  local typed_path = get_import_path(line)
  vim.schedule(function()
    vim.notify("[blink-source] Typed path: " .. tostring(typed_path), vim.log.levels.DEBUG)
  end)

  if not typed_path then
    call_callback(callback, { items = {} })
    return
  end

  local items = {}
  local current_file = vim.api.nvim_buf_get_name(0)

  -- SCENARIO 1: User is typing a relative path (./ or ../)
  if is_relative_path(typed_path) then
    local target_dir = resolve_relative_path(current_file, typed_path)
    local prefix = get_label_prefix(typed_path)

    local entries = get_directory_contents(target_dir)
    for _, entry in ipairs(entries) do
      table.insert(items, make_completion_item(entry, prefix))
    end

    call_callback(callback, { items = items })
    return
  end

  -- SCENARIO 2: User is typing an aliased path (~/, @/, #app/, etc.)
  local aliases = path_aliases.get_aliases()
  local root = path_aliases.get_nuxt_root()

  vim.schedule(function()
    local alias_count = 0
    for _ in pairs(aliases) do alias_count = alias_count + 1 end
    vim.notify(string.format("[blink-source] Found %d aliases, root: %s", alias_count, tostring(root)), vim.log.levels.DEBUG)
  end)

  if not root then
    vim.schedule(function()
      vim.notify("[blink-source] No Nuxt root found", vim.log.levels.WARN)
    end)
    call_callback(callback, { items = {} })
    return
  end

  -- Check if typed path starts with any alias
  for alias, target in pairs(aliases) do
    if typed_path:match("^" .. vim.pesc(alias)) then
      local base_dir = root .. "/" .. target
      local path_after_alias = typed_path:gsub("^" .. vim.pesc(alias) .. "/?", "")

      -- Determine which directory to search
      local search_dir = base_dir
      if path_after_alias ~= "" then
        local subdir = path_after_alias:match("^(.+)/[^/]*$")
        if subdir then
          search_dir = base_dir .. "/" .. subdir
        end
      end

      vim.schedule(function()
        vim.notify(string.format("[blink-source] Searching directory: %s", search_dir), vim.log.levels.DEBUG)
      end)

      local prefix = get_label_prefix(typed_path)
      local entries = get_directory_contents(search_dir)

      vim.schedule(function()
        vim.notify(string.format("[blink-source] Found %d entries", #entries), vim.log.levels.DEBUG)
      end)

      for _, entry in ipairs(entries) do
        table.insert(items, make_completion_item(entry, prefix))
      end

      vim.schedule(function()
        vim.notify(string.format("[blink-source] Returning %d items", #items), vim.log.levels.DEBUG)
      end)

      call_callback(callback, { items = items })
      return
    end
  end

  -- SCENARIO 3: User hasn't typed anything yet - show all options
  -- Show all available aliases
  for alias, target in pairs(aliases) do
    table.insert(items, {
      label = alias .. "/",
      kind = CompletionItemKind.Folder,
      detail = "→ " .. target,
      insertText = alias .. "/",
      documentation = {
        kind = "markdown",
        value = string.format("**Path Alias**\n\nResolves to `%s`", target),
      },
    })
  end

  vim.schedule(function()
    vim.notify(string.format("[blink-source] Showing %d alias options", #items), vim.log.levels.DEBUG)
  end)

  -- Also suggest relative paths
  table.insert(items, {
    label = "./",
    kind = CompletionItemKind.Folder,
    detail = "Current directory",
    insertText = "./",
    documentation = {
      kind = "markdown",
      value = "**Relative Path**\n\nCurrent directory",
    },
  })

  table.insert(items, {
    label = "../",
    kind = CompletionItemKind.Folder,
    detail = "Parent directory",
    insertText = "../",
    documentation = {
      kind = "markdown",
      value = "**Relative Path**\n\nParent directory",
    },
  })

  call_callback(callback, { items = items })
end

-- Resolve additional information for a completion item
function M:resolve(item, callback)
  if type(callback) == "function" then
    callback(item)
  elseif type(callback) == "table" and callback.resolve then
    callback:resolve(item)
  end
end

-- Execute action when completion item is selected
function M:execute(item, callback)
  -- In newer blink.cmp versions, execute might not need to do anything for simple sources
  -- Just return without error
  if type(callback) == "function" then
    callback()
  end
end

return M

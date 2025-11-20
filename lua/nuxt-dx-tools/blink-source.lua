-- Blink.cmp completion source for Nuxt path aliases and relative paths (Clean Rewrite)
local M = {}
local path = require("nuxt-dx-tools.path")

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
      working_dir = path.join(working_dir, subdir)
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
        return path.join(alias, subdir) .. path.separator()
      end
      return alias .. "/"
    end
  end

  -- For custom aliases like #app, #build, etc.
  local custom_alias = typed_path:match("^(#[^/]*)")
  if custom_alias then
    local subdir = typed_path:match("^#[^/]*/(.+)/[^/]*$")
    if subdir then
      return custom_path.join(alias, subdir) .. path.separator()
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
    local full_path = path.join(dir_path, name)
    local is_directory = vim.fn.isdirectory(full_path) == 1

    if is_directory then
      table.insert(entries, {
        name = name,
        is_dir = true,
        path = full_path,
      })
    else
      -- Show all files
      local ext = name:match("%.([^%.]+)$")
      table.insert(entries, {
        name = name,
        is_dir = false,
        path = full_path,
        extension = ext,
      })
    end
  end

  return entries
end

-- Calculate the text edit range for completion replacement
local function calculate_text_edit_range(context, typed_path)
  local line = context.line

  -- Find the opening quote to determine where the path string starts
  local quote_pos = nil
  local line_before_cursor = line:sub(1, context.cursor[2])
  for i = #line_before_cursor, 1, -1 do
    local char = line_before_cursor:sub(i, i)
    if char == '"' or char == "'" then
      quote_pos = i  -- Lua 1-indexed position of the quote
      break
    end
  end

  -- Calculate the range (LSP uses 0-indexed positions)
  -- Start right after the quote, end at cursor position
  local start_char, end_char
  if quote_pos then
    start_char = quote_pos  -- Position after quote (Lua 1-indexed N -> LSP 0-indexed N)
    end_char = context.cursor[2]  -- Already 0-indexed
  else
    -- Fallback: use bounds if available
    start_char = context.bounds and (context.bounds.start_col - 1) or 0
    end_char = context.cursor[2]
  end

  local range = {
    start = { line = context.cursor[1] - 1, character = start_char },
    ['end'] = { line = context.cursor[1] - 1, character = end_char }
  }

  return range
end

-- Create a completion item from a directory entry
local function make_completion_item(entry, prefix, typed_path, context)
  -- Build the complete path for label
  local complete_path = prefix .. entry.name
  if entry.is_dir then
    complete_path = complete_path .. "/"
  end

  local kind
  if entry.is_dir then
    kind = CompletionItemKind.Folder
  elseif entry.extension == "vue" then
    kind = CompletionItemKind.Class
  else
    kind = CompletionItemKind.Module
  end

  -- Calculate what text to insert
  -- If typed_path has no slash (e.g., just "~"), include the full prefix
  -- Otherwise, just insert the name
  local insert_text
  if typed_path and not typed_path:match('/') then
    -- No slash yet, include full path with prefix (e.g., "~/components/")
    insert_text = complete_path
  else
    -- Has slash, just insert the name (e.g., "components/")
    insert_text = entry.name
    if entry.is_dir then
      insert_text = insert_text .. "/"
    end
  end

  -- Calculate the range for text replacement
  local range = calculate_text_edit_range(context, typed_path)

  -- Check if next character is "/" and we're inserting a directory
  -- If so, extend the range to replace the existing "/"
  if entry.is_dir and context.line then
    local cursor_pos = context.cursor and context.cursor[2] or #context.line
    local next_char = context.line:sub(cursor_pos + 1, cursor_pos + 1)
    if next_char == "/" then
      range['end'].character = range['end'].character + 1
    end
  end

  local item = {
    label = complete_path,
    kind = kind,
    detail = entry.is_dir and "Directory" or "File",
    insertText = complete_path,
    insertTextFormat = 1,  -- PlainText
    textEdit = {
      newText = complete_path,
      range = range
    },
    filterText = entry.name,
    sortText = (entry.is_dir and "1" or "2") .. entry.name:lower(),
    documentation = {
      kind = "markdown",
      value = string.format("**%s**\n\n`%s`", entry.is_dir and "Directory" or "File", entry.path),
    },
  }

  return item
end

-- Helper to safely call completion callback
local function call_callback(callback, context, items)
  -- Build the result with proper blink.cmp format
  local result = {
    context = context,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items,
  }

  if type(callback) == "function" then
    callback(result)
  elseif type(callback) == "table" and callback.callback then
    callback:callback(result)
  end
end

-- Main completion function
function M:get_completions(ctx, callback)
  -- Load path aliases module
  local ok, path_aliases = pcall(require, "nuxt-dx-tools.path-aliases")
  if not ok then
    call_callback(callback, ctx, {})
    return
  end

  local line = ctx.line or ctx.cursor_before_line or vim.api.nvim_get_current_line()

  -- Only provide completions in import statements
  if not (line:match('from%s+["\']') or line:match('import%s+["\']') or line:match('import%(["\']')) then
    call_callback(callback, ctx, {})
    return
  end

  local typed_path = get_import_path(line)
  if not typed_path then
    call_callback(callback, ctx, {})
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
      table.insert(items, make_completion_item(entry, prefix, typed_path, ctx))
    end

    call_callback(callback, ctx, items)
    return
  end

  -- SCENARIO 2: User is typing an aliased path (~/, @/, #app/, etc.)
  local aliases = path_aliases.get_aliases()
  local root = path_aliases.get_nuxt_root()

  if not root then
    call_callback(callback, ctx, {})
    return
  end

  -- Check if typed path starts with any alias
  for alias, target in pairs(aliases) do
    if typed_path:match("^" .. vim.pesc(alias)) then
      -- Target is now an absolute path
      local base_dir = target
      local path_after_alias = typed_path:gsub("^" .. vim.pesc(alias) .. "/?", "")

      -- Determine which directory to search
      local search_dir = base_dir
      if path_after_alias ~= "" then
        local subdir = path_after_alias:match("^(.+)/[^/]*$")
        if subdir then
          search_dir = path.join(base_dir, subdir)
          -- Normalize the path
          search_dir = vim.fn.fnamemodify(search_dir, ":p")
          search_dir = search_dir:gsub("[/\\]$", "")
        end
      end

      local prefix = get_label_prefix(typed_path)
      local entries = get_directory_contents(search_dir)

      for _, entry in ipairs(entries) do
        table.insert(items, make_completion_item(entry, prefix, typed_path, ctx))
      end

      call_callback(callback, ctx, items)
      return
    end
  end

  -- SCENARIO 3: User hasn't typed anything yet - show all options

  -- Show all available aliases
  for alias, target in pairs(aliases) do
    -- Make target relative to root for display
    local display_target = target
    if root and target:find(root, 1, true) == 1 then
      display_target = target:sub(#root + 2) -- +2 to skip the separator
    end

    table.insert(items, {
      label = alias .. "/",
      kind = CompletionItemKind.Folder,
      detail = "→ " .. display_target,
      insertText = alias .. "/",
      documentation = {
        kind = "markdown",
        value = string.format("**Path Alias**\n\nResolves to `%s`", display_target),
      },
    })
  end

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

  call_callback(callback, ctx, items)
end

return M

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

  vim.notify(string.format("DEBUG calculate_text_edit_range:\n  line: %s\n  cursor: [%d,%d]\n  typed_path: %s\n  bounds: %s",
    line,
    context.cursor and context.cursor[1] or 0,
    context.cursor and context.cursor[2] or 0,
    typed_path or "nil",
    context.bounds and string.format("start=%d, len=%d", context.bounds.start_col, context.bounds.length) or "nil"), vim.log.levels.INFO)

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

  vim.notify(string.format("  range: start.char=%d, end.char=%d", range.start.character, range['end'].character), vim.log.levels.INFO)

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

  -- Determine word to replace (from quote to cursor)
  local word = typed_path or ""

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

  vim.notify(string.format("DEBUG completion item:\n  label: %s\n  textEdit: {newText=%s, range=[%d,%d]->[%d,%d]}",
    item.label, item.textEdit.newText,
    item.textEdit.range.start.line, item.textEdit.range.start.character,
    item.textEdit.range['end'].line, item.textEdit.range['end'].character), vim.log.levels.INFO)

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

  -- Log what we're returning
  local log_msg = string.format("DEBUG call_callback returning %d items", #items)
  if #items > 0 then
    local first = items[1]
    log_msg = log_msg .. string.format("\n  First item: label='%s'", first.label or "nil")
    if first.textEdit then
      log_msg = log_msg .. string.format("\n    textEdit.newText='%s'\n    textEdit.range=[%d,%d]->[%d,%d]",
        first.textEdit.newText or "nil",
        first.textEdit.range.start.line, first.textEdit.range.start.character,
        first.textEdit.range['end'].line, first.textEdit.range['end'].character)
    end
    if first.insertText then
      log_msg = log_msg .. string.format("\n    insertText='%s'", first.insertText)
    end
  end
  vim.notify(log_msg, vim.log.levels.INFO)

  if type(callback) == "function" then
    callback(result)
  elseif type(callback) == "table" and callback.callback then
    callback:callback(result)
  end
end

-- Main completion function
function M:get_completions(ctx, callback)
  -- Debug context - show ALL context fields
  local ctx_debug = "DEBUG get_completions - FULL CONTEXT:\n"
  for k, v in pairs(ctx) do
    if type(v) == "table" then
      if k == "cursor" then
        ctx_debug = ctx_debug .. string.format("  %s: [%s, %s]\n", k, v[1] or "nil", v[2] or "nil")
      elseif k == "bounds" then
        ctx_debug = ctx_debug .. string.format("  %s: {start_col=%s, length=%s}\n", k, v.start_col or "nil", v.length or "nil")
      else
        ctx_debug = ctx_debug .. string.format("  %s: <table>\n", k)
      end
    else
      ctx_debug = ctx_debug .. string.format("  %s: %s\n", k, tostring(v))
    end
  end
  vim.notify(ctx_debug, vim.log.levels.INFO)
  -- Load path aliases module
  local ok, path_aliases = pcall(require, "nuxt-dx-tools.path-aliases")
  if not ok then
    vim.notify("DEBUG: Failed to load path-aliases module", vim.log.levels.ERROR)
    call_callback(callback, ctx, {})
    return
  end
  vim.notify("DEBUG: path-aliases module loaded successfully", vim.log.levels.INFO)

  local line = ctx.line or ctx.cursor_before_line or vim.api.nvim_get_current_line()
  vim.notify(string.format("DEBUG: line = '%s'", line), vim.log.levels.INFO)

  -- Only provide completions in import statements
  local is_import = line:match('from%s+["\']') or line:match('import%s+["\']') or line:match('import%(["\']')
  vim.notify(string.format("DEBUG: is_import = %s", is_import and "true" or "false"), vim.log.levels.INFO)
  if not is_import then
    vim.notify("DEBUG: Not an import statement, returning empty", vim.log.levels.WARN)
    call_callback(callback, ctx, {})
    return
  end

  local typed_path = get_import_path(line)
  vim.notify(string.format("DEBUG: typed_path from get_import_path: '%s'", typed_path or "nil"), vim.log.levels.INFO)
  if not typed_path then
    vim.notify("DEBUG: typed_path is nil, returning empty", vim.log.levels.WARN)
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

  vim.notify(string.format("DEBUG aliases and root:\n  root: %s\n  aliases count: %d\n  typed_path: %s",
    root or "nil",
    aliases and vim.tbl_count(aliases) or 0,
    typed_path or "nil"), vim.log.levels.INFO)

  if not root then
    vim.notify("DEBUG: No Nuxt root found, returning empty", vim.log.levels.WARN)
    call_callback(callback, ctx, {})
    return
  end

  -- Check if typed path starts with any alias
  vim.notify(string.format("DEBUG: Checking aliases for typed_path='%s'", typed_path), vim.log.levels.INFO)
  for alias, target in pairs(aliases) do
    local pattern = "^" .. vim.pesc(alias)
    local matches = typed_path:match(pattern)
    vim.notify(string.format("  Checking alias '%s' with pattern '%s': %s", alias, pattern, matches and "MATCH" or "no match"), vim.log.levels.INFO)
    if matches then
      vim.notify(string.format("DEBUG: Matched alias '%s', getting directory contents", alias), vim.log.levels.INFO)
      -- Target is now an absolute path
      local base_dir = target
      local path_after_alias = typed_path:gsub("^" .. vim.pesc(alias) .. "/?", "")

      -- Determine which directory to search
      local search_dir = base_dir
      if path_after_alias ~= "" then
        local subdir = path_after_alias:match("^(.+)/[^/]*$")
        if subdir then
          search_dir = base_dir .. "/" .. subdir
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
  vim.notify("DEBUG: SCENARIO 3 - showing all aliases", vim.log.levels.INFO)

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

-- Resolve additional information for a completion item
function M:resolve(item, callback)
  vim.notify(string.format("DEBUG resolve called for item:\n  label: %s\n  textEdit: %s",
    item.label or "nil",
    item.textEdit and string.format("{newText='%s', range=[%d,%d]->[%d,%d]}",
      item.textEdit.newText or "nil",
      item.textEdit.range.start.line, item.textEdit.range.start.character,
      item.textEdit.range['end'].line, item.textEdit.range['end'].character) or "nil"), vim.log.levels.INFO)

  if type(callback) == "function" then
    callback(item)
  elseif type(callback) == "table" and callback.resolve then
    callback:resolve(item)
  end
end

-- Execute action when completion item is selected
function M:execute(item, callback)
  local item_str = "nil"
  if item then
    item_str = string.format("label='%s', insertText='%s'", item.label or "nil", item.insertText or "nil")
    if item.textEdit then
      item_str = item_str .. string.format(", textEdit={newText='%s', range=[%d,%d]->[%d,%d]}",
        item.textEdit.newText or "nil",
        item.textEdit.range.start.line, item.textEdit.range.start.character,
        item.textEdit.range['end'].line, item.textEdit.range['end'].character)
    end
  end

  vim.notify(string.format("DEBUG execute called for item:\n  %s", item_str), vim.log.levels.INFO)

  -- If item has data we need to apply, do it here
  if item and item.data and item.data.apply_edit then
    vim.notify("DEBUG: Applying custom edit from item.data", vim.log.levels.INFO)
    -- Apply custom text edit here if needed
  end

  -- In newer blink.cmp versions, execute might not need to do anything for simple sources
  -- Just return without error
  if type(callback) == "function" then
    callback()
  end
end

return M

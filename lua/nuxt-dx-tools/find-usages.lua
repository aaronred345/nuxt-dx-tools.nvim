-- Find usages for auto-imported symbols (composables, components, utils)
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Get all auto-imported symbols from .nuxt/imports.d.ts
function M.get_auto_imports()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local imports_file = root .. "/.nuxt/imports.d.ts"
  local content = utils.read_file(imports_file)
  if not content then return {} end

  local imports = {}

  -- Extract exports
  for name in content:gmatch("export%s+const%s+(%w+)") do
    table.insert(imports, { name = name, type = "composable" })
  end

  for name in content:gmatch("export%s+function%s+(%w+)") do
    table.insert(imports, { name = name, type = "function" })
  end

  return imports
end

-- Get all auto-imported components
function M.get_auto_components()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local components_file = root .. "/.nuxt/components.d.ts"
  local content = utils.read_file(components_file)
  if not content then return {} end

  local components = {}

  -- Extract component names
  for name in content:gmatch("'([%w]+)'%s*:%s*typeof") do
    table.insert(components, { name = name, type = "component" })
  end

  return components
end

-- Find all usages of a symbol in the project
function M.find_symbol_usages(symbol)
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local usages = {}

  -- Search in app/ or root directories
  local search_dirs = {
    root .. "/app",
    root .. "/pages",
    root .. "/components",
    root .. "/composables",
    root .. "/layouts",
    root .. "/middleware",
    root .. "/plugins",
  }

  for _, dir in ipairs(search_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.{vue,ts,js,tsx,jsx}", false, true)

      for _, file in ipairs(files) do
        local content = utils.read_file(file)
        if content then
          local line_num = 1
          for line in content:gmatch("[^\r\n]+") do
            -- Check for symbol usage (not in import statements)
            if not line:match("^import") and not line:match("^export") then
              -- Match whole word
              if line:match("%f[%w]" .. symbol .. "%f[%W]") then
                table.insert(usages, {
                  file = file,
                  line = line_num,
                  text = line:match("^%s*(.-)%s*$"),
                })
              end
            end
            line_num = line_num + 1
          end
        end
      end
    end
  end

  return usages
end

-- Find usages of symbol under cursor
function M.find_current_symbol_usages()
  local word = vim.fn.expand("<cword>")
  if not word or word == "" then
    vim.notify("No symbol under cursor", vim.log.levels.WARN)
    return
  end

  -- Check if it's an auto-imported symbol
  local auto_imports = M.get_auto_imports()
  local auto_components = M.get_auto_components()

  local is_auto_import = false
  for _, import in ipairs(auto_imports) do
    if import.name == word then
      is_auto_import = true
      break
    end
  end

  if not is_auto_import then
    for _, comp in ipairs(auto_components) do
      if comp.name == word then
        is_auto_import = true
        break
      end
    end
  end

  if not is_auto_import then
    vim.notify("Symbol '" .. word .. "' is not an auto-imported symbol", vim.log.levels.INFO)
    -- Fall back to LSP references
    vim.lsp.buf.references()
    return
  end

  vim.notify("Searching for usages of '" .. word .. "'...", vim.log.levels.INFO)

  local usages = M.find_symbol_usages(word)

  if #usages == 0 then
    vim.notify("No usages found for: " .. word, vim.log.levels.INFO)
    return
  end

  -- Populate quickfix list
  local qf_items = {}
  for _, usage in ipairs(usages) do
    table.insert(qf_items, {
      filename = usage.file,
      lnum = usage.line,
      text = usage.text,
    })
  end

  vim.fn.setqflist(qf_items, "r")
  vim.cmd("copen")
  vim.notify("Found " .. #usages .. " usages of: " .. word, vim.log.levels.INFO)
end

-- Show usage statistics for all auto-imported symbols
function M.show_usage_stats()
  local auto_imports = M.get_auto_imports()
  local auto_components = M.get_auto_components()

  local stats = {}

  vim.notify("Analyzing auto-import usages...", vim.log.levels.INFO)

  -- Analyze imports
  for _, import in ipairs(auto_imports) do
    local usages = M.find_symbol_usages(import.name)
    table.insert(stats, {
      name = import.name,
      type = import.type,
      count = #usages,
    })
  end

  -- Analyze components
  for _, comp in ipairs(auto_components) do
    local usages = M.find_symbol_usages(comp.name)
    table.insert(stats, {
      name = comp.name,
      type = "component",
      count = #usages,
    })
  end

  -- Sort by usage count
  table.sort(stats, function(a, b)
    return a.count > b.count
  end)

  -- Display results
  local lines = { "=== Auto-Import Usage Statistics ===", "" }

  -- Find unused symbols
  local unused = vim.tbl_filter(function(s) return s.count == 0 end, stats)
  if #unused > 0 then
    table.insert(lines, "**Unused Symbols (" .. #unused .. "):**")
    for _, stat in ipairs(unused) do
      table.insert(lines, string.format("  • %s (%s)", stat.name, stat.type))
    end
    table.insert(lines, "")
  end

  -- Show top used
  table.insert(lines, "**Most Used Symbols:**")
  for i = 1, math.min(20, #stats) do
    local stat = stats[i]
    if stat.count > 0 then
      table.insert(lines, string.format("  %2d. %-30s %s (%d usages)", i, stat.name, stat.type, stat.count))
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  local width = 100
  local height = math.min(#lines, 40)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    border = "rounded",
    style = "minimal",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
end

-- Find where a symbol is defined
function M.find_definition_file(symbol)
  local root = utils.find_nuxt_root()
  if not root then return nil end

  local search_dirs = utils.get_directory_paths("composables")
  table.insert(search_dirs, root .. "/utils")
  table.insert(search_dirs, root .. "/app/utils")

  for _, dir in ipairs(search_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.{ts,js}", false, true)

      for _, file in ipairs(files) do
        local content = utils.read_file(file)
        if content then
          -- Look for export of this symbol
          if content:match("export%s+const%s+" .. symbol) or
             content:match("export%s+function%s+" .. symbol) or
             content:match("export%s+default%s+" .. symbol) or
             content:match("export%s*{[^}]*" .. symbol) then
            return file
          end
        end
      end
    end
  end

  return nil
end

return M

-- Smart support for data fetching composables (useAsyncData, useFetch)
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Extract data fetching call information from current line
function M.extract_data_fetch_info()
  local line = vim.api.nvim_get_current_line()

  -- Patterns for useAsyncData
  local async_data_patterns = {
    { pattern = "useAsyncData%s*%(%s*['\"]([^'\"]+)['\"]", key_idx = 1, type = "useAsyncData" },
    { pattern = "useAsyncData%s*%(%s*%(%)%s*=>", key_idx = nil, type = "useAsyncData" },
  }

  -- Patterns for useFetch
  local use_fetch_patterns = {
    { pattern = "useFetch%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*{[^}]*key%s*:%s*['\"]([^'\"]+)['\"]", url_idx = 1, key_idx = 2, type = "useFetch" },
    { pattern = "useFetch%s*%(%s*['\"]([^'\"]+)['\"]", url_idx = 1, key_idx = nil, type = "useFetch" },
    { pattern = "useFetch%s*%(%s*`([^`]+)`", url_idx = 1, key_idx = nil, type = "useFetch", is_template = true },
  }

  -- Try useAsyncData patterns
  for _, p in ipairs(async_data_patterns) do
    local matches = { line:match(p.pattern) }
    if #matches > 0 then
      return {
        type = p.type,
        key = p.key_idx and matches[p.key_idx] or nil,
        has_key = p.key_idx ~= nil,
      }
    end
  end

  -- Try useFetch patterns
  for _, p in ipairs(use_fetch_patterns) do
    local matches = { line:match(p.pattern) }
    if #matches > 0 then
      return {
        type = p.type,
        url = p.url_idx and matches[p.url_idx] or nil,
        key = p.key_idx and matches[p.key_idx] or nil,
        has_key = p.key_idx ~= nil,
        is_template = p.is_template,
      }
    end
  end

  return nil
end

-- Extract options from data fetch call
function M.extract_options(line)
  local options = {
    server = nil,
    lazy = nil,
    immediate = nil,
    watch = nil,
    transform = nil,
    pick = nil,
    default = nil,
  }

  -- Check for common options
  if line:match("server%s*:%s*false") then
    options.server = false
  elseif line:match("server%s*:%s*true") then
    options.server = true
  end

  if line:match("lazy%s*:%s*true") then
    options.lazy = true
  end

  if line:match("immediate%s*:%s*false") then
    options.immediate = false
  end

  if line:match("watch%s*:") then
    options.watch = true
  end

  if line:match("transform%s*:") then
    options.transform = true
  end

  if line:match("pick%s*:") then
    options.pick = true
  end

  if line:match("default%s*:") then
    options.default = true
  end

  return options
end

-- Find all usages of a data fetch key across the project
function M.find_key_usages(key)
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local usages = {}
  local search_dirs = utils.get_directory_paths("pages")
  table.insert(search_dirs, root .. "/components")

  for _, dir in ipairs(search_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.vue", false, true)
      for _, file in ipairs(files) do
        local content = utils.read_file(file)
        if content and content:match("['\"]" .. key .. "['\"]") then
          table.insert(usages, file)
        end
      end
    end
  end

  return usages
end

-- Show hover info for data fetch call
function M.show_hover()
  local info = M.extract_data_fetch_info()
  if not info then return false end

  local line = vim.api.nvim_get_current_line()
  local options = M.extract_options(line)

  local hover_content = {
    "**" .. info.type .. "**",
    "",
  }

  if info.key then
    table.insert(hover_content, "**Cache Key:** " .. info.key)

    -- Find other usages of this key
    local usages = M.find_key_usages(info.key)
    if #usages > 1 then
      table.insert(hover_content, "**Shared Data:** Used in " .. #usages .. " files (cached/deduplicated)")
    end
  elseif info.type == "useAsyncData" then
    table.insert(hover_content, "⚠️  **No cache key specified** - data won't be shared across components")
    table.insert(hover_content, "💡 Add a unique key as first parameter for caching")
  end

  if info.url then
    table.insert(hover_content, "**URL:** " .. info.url)
  end

  table.insert(hover_content, "")
  table.insert(hover_content, "**Options:**")

  if options.server == false then
    table.insert(hover_content, "  • `server: false` - Client-side only")
  elseif options.server == true then
    table.insert(hover_content, "  • `server: true` - Server-side only")
  else
    table.insert(hover_content, "  • Runs on both server and client")
  end

  if options.lazy then
    table.insert(hover_content, "  • `lazy: true` - Non-blocking, won't wait during SSR")
  end

  if options.immediate == false then
    table.insert(hover_content, "  • `immediate: false` - Manual execution required")
  end

  if options.watch then
    table.insert(hover_content, "  • Reactive watch enabled")
  end

  if options.transform then
    table.insert(hover_content, "  • Custom transform function applied")
  end

  if options.pick then
    table.insert(hover_content, "  • Response data is filtered with pick")
  end

  if options.default then
    table.insert(hover_content, "  • Has default value")
  end

  table.insert(hover_content, "")
  table.insert(hover_content, "**Tip:** Use `<leader>nf` to find all usages of this data fetch")

  vim.lsp.util.open_floating_preview(hover_content, "markdown", {
    border = "rounded",
    focusable = false,
    max_width = 80,
  })

  return true
end

-- Find all usages of current data fetch key
function M.find_usages()
  local info = M.extract_data_fetch_info()
  if not info or not info.key then
    vim.notify("No cache key found for this data fetch call", vim.log.levels.WARN)
    return
  end

  local usages = M.find_key_usages(info.key)

  if #usages == 0 then
    vim.notify("No usages found for key: " .. info.key, vim.log.levels.INFO)
    return
  end

  -- Populate quickfix list
  local qf_items = {}
  for _, file in ipairs(usages) do
    local content = utils.read_file(file)
    if content then
      local line_num = 1
      for line in content:gmatch("[^\r\n]+") do
        if line:match(info.key) then
          table.insert(qf_items, {
            filename = file,
            lnum = line_num,
            text = line:match("^%s*(.-)%s*$"),
          })
        end
        line_num = line_num + 1
      end
    end
  end

  vim.fn.setqflist(qf_items, "r")
  vim.cmd("copen")
  vim.notify("Found " .. #qf_items .. " usages of key: " .. info.key, vim.log.levels.INFO)
end

-- Suggest conversion between useFetch and useAsyncData
function M.suggest_conversion()
  local info = M.extract_data_fetch_info()
  if not info then
    vim.notify("No data fetch call found on current line", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()

  if info.type == "useFetch" then
    -- Suggest conversion to useAsyncData if complex logic needed
    vim.ui.select({
      "Convert to useAsyncData (for complex data fetching logic)",
      "Add cache key to useFetch",
      "Cancel",
    }, {
      prompt = "Data fetching suggestions:",
    }, function(choice)
      if choice and choice:match("Convert to useAsyncData") then
        -- Generate useAsyncData equivalent
        local key = info.key or "data"
        local new_line = line:gsub(
          "useFetch%s*%(",
          "useAsyncData('" .. key .. "', () => $fetch("
        )
        new_line = new_line .. ")"
        vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { new_line })
      elseif choice and choice:match("Add cache key") then
        if not info.has_key then
          local suggested_key = "fetch-" .. (info.url or "data"):gsub("[^%w]", "-")
          local new_line = line:gsub("useFetch%s*%(", "useFetch(")
          new_line = new_line:gsub("%)", ", { key: '" .. suggested_key .. "' })")
          vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { new_line })
        end
      end
    end)
  elseif info.type == "useAsyncData" then
    -- Suggest conversion to useFetch if simple API call
    vim.ui.select({
      "Convert to useFetch (simpler for basic API calls)",
      "Add cache key",
      "Cancel",
    }, {
      prompt = "Data fetching suggestions:",
    }, function(choice)
      if choice and choice:match("Convert to useFetch") then
        vim.notify("Manual conversion needed - ensure you're using a simple $fetch call", vim.log.levels.INFO)
      elseif choice and choice:match("Add cache key") then
        if not info.has_key then
          vim.notify("Add a unique string as the first parameter to useAsyncData", vim.log.levels.INFO)
        end
      end
    end)
  end
end

-- Check for data fetching issues in current file
function M.check_issues()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local issues = {}

  for lnum, line in ipairs(lines) do
    -- Check for useAsyncData without key
    if line:match("useAsyncData%s*%(%s*%(%)%s*=>") or line:match("useAsyncData%s*%(%s*async%s*%(%)") then
      table.insert(issues, {
        lnum = lnum,
        message = "useAsyncData without cache key - data won't be shared/cached",
        severity = "warning",
      })
    end

    -- Check for useFetch without key
    if line:match("useFetch%s*%(['\"]") and not line:match("key%s*:") then
      table.insert(issues, {
        lnum = lnum,
        message = "Consider adding a cache key for data deduplication",
        severity = "info",
      })
    end

    -- Check for potential SSR issues
    if line:match("useFetch") and not line:match("server%s*:") then
      if line:match("window%.") or line:match("document%.") then
        table.insert(issues, {
          lnum = lnum,
          message = "Possible SSR issue - accessing browser APIs in data fetch",
          severity = "error",
        })
      end
    end
  end

  if #issues == 0 then
    vim.notify("No data fetching issues found!", vim.log.levels.INFO)
    return
  end

  -- Show issues in quickfix
  local qf_items = {}
  for _, issue in ipairs(issues) do
    table.insert(qf_items, {
      bufnr = bufnr,
      lnum = issue.lnum,
      text = issue.message,
      type = issue.severity == "error" and "E" or (issue.severity == "warning" and "W" or "I"),
    })
  end

  vim.fn.setqflist(qf_items, "r")
  vim.cmd("copen")
  vim.notify("Found " .. #issues .. " data fetching issues", vim.log.levels.WARN)
end

return M

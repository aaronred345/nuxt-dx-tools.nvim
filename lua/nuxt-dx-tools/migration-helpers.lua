-- Migration helpers for Nuxt 4
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Detect old Nuxt 3 patterns that should be migrated to Nuxt 4
function M.detect_migration_issues()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local structure = utils.detect_structure()
  local issues = {}

  -- If app/ directory exists, check for old patterns in root
  if structure.has_app_dir then
    -- Check for pages in root instead of app/
    local root_pages = root .. "/pages"
    if vim.fn.isdirectory(root_pages) == 1 then
      table.insert(issues, {
        type = "directory",
        severity = "warning",
        path = "/pages",
        message = "Pages directory exists in root. Should be moved to /app/pages for Nuxt 4",
        fix = function()
          return {
            action = "move_directory",
            from = root_pages,
            to = root .. "/app/pages",
          }
        end,
      })
    end

    -- Check for layouts in root instead of app/
    local root_layouts = root .. "/layouts"
    if vim.fn.isdirectory(root_layouts) == 1 then
      table.insert(issues, {
        type = "directory",
        severity = "warning",
        path = "/layouts",
        message = "Layouts directory exists in root. Should be moved to /app/layouts for Nuxt 4",
        fix = function()
          return {
            action = "move_directory",
            from = root_layouts,
            to = root .. "/app/layouts",
          }
        end,
      })
    end

    -- Check for middleware in root instead of app/
    local root_middleware = root .. "/middleware"
    if vim.fn.isdirectory(root_middleware) == 1 then
      table.insert(issues, {
        type = "directory",
        severity = "warning",
        path = "/middleware",
        message = "Middleware directory exists in root. Should be moved to /app/middleware for Nuxt 4",
        fix = function()
          return {
            action = "move_directory",
            from = root_middleware,
            to = root .. "/app/middleware",
          }
        end,
      })
    end

    -- Check for app.vue in root instead of app/
    local root_app_vue = root .. "/app.vue"
    if vim.fn.filereadable(root_app_vue) == 1 then
      table.insert(issues, {
        type = "file",
        severity = "warning",
        path = "/app.vue",
        message = "app.vue exists in root. Should be moved to /app/app.vue for Nuxt 4",
        fix = function()
          return {
            action = "move_file",
            from = root_app_vue,
            to = root .. "/app/app.vue",
          }
        end,
      })
    end

    -- Check for error.vue in root instead of app/
    local root_error_vue = root .. "/error.vue"
    if vim.fn.filereadable(root_error_vue) == 1 then
      table.insert(issues, {
        type = "file",
        severity = "warning",
        path = "/error.vue",
        message = "error.vue exists in root. Should be moved to /app/error.vue for Nuxt 4",
        fix = function()
          return {
            action = "move_file",
            from = root_error_vue,
            to = root .. "/app/error.vue",
          }
        end,
      })
    end
  end

  return issues
end

-- Scan current file for deprecated Nuxt 3 APIs
function M.detect_deprecated_apis()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local issues = {}

  local deprecated_patterns = {
    {
      pattern = "useAsync%s*%(",
      message = "useAsync is deprecated. Use useAsyncData instead.",
      replacement = "useAsyncData",
    },
    {
      pattern = "@nuxtjs/composition%-api",
      message = "@nuxtjs/composition-api is no longer needed in Nuxt 3+",
      replacement = nil,
    },
    {
      pattern = "asyncData%s*%(",
      message = "asyncData option is deprecated. Use useAsyncData composable instead.",
      replacement = nil,
    },
    {
      pattern = "fetch%s*%(",
      message = "fetch option is deprecated. Use useFetch or useAsyncData composable instead.",
      replacement = nil,
    },
    {
      pattern = "head%s*%(",
      message = "head option is deprecated. Use useHead composable or <Head> component instead.",
      replacement = "useHead",
    },
    {
      pattern = "@nuxt/bridge",
      message = "@nuxt/bridge is not needed in Nuxt 3+",
      replacement = nil,
    },
    {
      pattern = "nuxt%.config%.js",
      message = "Use nuxt.config.ts for better type safety in Nuxt 3+",
      replacement = "nuxt.config.ts",
    },
  }

  for lnum, line in ipairs(lines) do
    for _, dep in ipairs(deprecated_patterns) do
      if line:match(dep.pattern) then
        table.insert(issues, {
          type = "api",
          severity = "warning",
          line = lnum,
          column = line:find(dep.pattern),
          message = dep.message,
          replacement = dep.replacement,
        })
      end
    end
  end

  return issues
end

-- Show migration hints in a floating window
function M.show_migration_hints()
  local issues = M.detect_migration_issues()
  if #issues == 0 then
    vim.notify("No migration issues found! Your project is Nuxt 4 ready.", vim.log.levels.INFO)
    return
  end

  local lines = { "=== Nuxt 4 Migration Hints ===", "" }
  for i, issue in ipairs(issues) do
    table.insert(lines, string.format("%d. [%s] %s", i, issue.severity:upper(), issue.message))
    table.insert(lines, "   Path: " .. issue.path)
    table.insert(lines, "")
  end

  table.insert(lines, "")
  table.insert(lines, "Use :NuxtMigrationFix to apply suggested fixes")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  local width = 80
  local height = #lines
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = math.min(height, 30),
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    border = "rounded",
    style = "minimal",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
end

-- Apply migration fixes
function M.apply_migration_fixes()
  local issues = M.detect_migration_issues()
  if #issues == 0 then
    vim.notify("No migration issues to fix.", vim.log.levels.INFO)
    return
  end

  vim.ui.select(issues, {
    prompt = "Select migration fix to apply:",
    format_item = function(item)
      return string.format("[%s] %s", item.severity:upper(), item.message)
    end,
  }, function(choice)
    if not choice then return end

    local fix = choice.fix()
    if fix.action == "move_directory" then
      -- Create target directory
      vim.fn.mkdir(vim.fn.fnamemodify(fix.to, ":h"), "p")

      -- Use shell command to move
      local cmd = string.format("mv %s %s", vim.fn.shellescape(fix.from), vim.fn.shellescape(fix.to))
      local result = vim.fn.system(cmd)

      if vim.v.shell_error == 0 then
        vim.notify("Successfully moved " .. choice.path, vim.log.levels.INFO)
      else
        vim.notify("Failed to move directory: " .. result, vim.log.levels.ERROR)
      end
    elseif fix.action == "move_file" then
      -- Create target directory
      vim.fn.mkdir(vim.fn.fnamemodify(fix.to, ":h"), "p")

      -- Use shell command to move
      local cmd = string.format("mv %s %s", vim.fn.shellescape(fix.from), vim.fn.shellescape(fix.to))
      local result = vim.fn.system(cmd)

      if vim.v.shell_error == 0 then
        vim.notify("Successfully moved " .. choice.path, vim.log.levels.INFO)
      else
        vim.notify("Failed to move file: " .. result, vim.log.levels.ERROR)
      end
    end
  end)
end

-- Set up diagnostics for deprecated APIs in current buffer
function M.setup_diagnostics()
  local ns = vim.api.nvim_create_namespace("nuxt-migration")

  local function update_diagnostics()
    local bufnr = vim.api.nvim_get_current_buf()
    local issues = M.detect_deprecated_apis()

    local diagnostics = {}
    for _, issue in ipairs(issues) do
      table.insert(diagnostics, {
        bufnr = bufnr,
        lnum = issue.line - 1,
        col = issue.column or 0,
        severity = vim.diagnostic.severity.WARN,
        source = "nuxt-migration",
        message = issue.message,
        user_data = { replacement = issue.replacement },
      })
    end

    vim.diagnostic.set(ns, bufnr, diagnostics, {})
  end

  -- Update on buffer enter and text change
  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
    pattern = { "*.vue", "*.ts", "*.js", "*.mjs" },
    callback = update_diagnostics,
  })
end

-- Code action to fix deprecated API usage
function M.code_action_fix_deprecated()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local issues = M.detect_deprecated_apis()

  local actions = {}
  for _, issue in ipairs(issues) do
    if issue.line == line and issue.replacement then
      table.insert(actions, {
        title = "Replace with " .. issue.replacement,
        action = function()
          local current_line = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
          local new_line = current_line:gsub(issue.pattern:gsub("%%s%*%%%(", ""), issue.replacement)
          vim.api.nvim_buf_set_lines(bufnr, line - 1, line, false, { new_line })
        end,
      })
    end
  end

  if #actions == 0 then
    vim.notify("No fixes available for this line", vim.log.levels.INFO)
    return
  end

  vim.ui.select(actions, {
    prompt = "Select fix:",
    format_item = function(item) return item.title end,
  }, function(choice)
    if choice then choice.action() end
  end)
end

return M

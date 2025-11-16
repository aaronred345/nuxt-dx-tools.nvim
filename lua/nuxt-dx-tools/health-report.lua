-- Project health report
local M = {}

local utils = require("nuxt-dx-tools.utils")

-- Check project structure
function M.check_structure()
  local root = utils.find_nuxt_root()
  if not root then
    return { status = "error", message = "Not in a Nuxt project" }
  end

  local structure = utils.detect_structure()
  local issues = {}
  local info = {}

  -- Check for Nuxt 4 vs Nuxt 3 structure
  if structure.has_app_dir then
    table.insert(info, "✓ Using Nuxt 4 app/ directory structure")

    -- Check if there are files in both root and app/
    local root_pages = vim.fn.isdirectory(root .. "/pages") == 1
    local root_components = vim.fn.isdirectory(root .. "/components") == 1

    if root_pages or root_components then
      table.insert(issues, "⚠ Found directories in both root and app/ - consider migration")
    end
  else
    table.insert(info, "Using Nuxt 3 root directory structure")
  end

  return {
    status = #issues == 0 and "ok" or "warning",
    info = info,
    issues = issues,
  }
end

-- Check for missing dependencies
function M.check_dependencies()
  local root = utils.find_nuxt_root()
  if not root then return { status = "error" } end

  local package_json = root .. "/package.json"
  local content = utils.read_file(package_json)

  if not content then
    return { status = "error", message = "package.json not found" }
  end

  local issues = {}
  local info = {}

  -- Check for Nuxt version
  if content:match('"nuxt":%s*"[^"]*"') then
    local version = content:match('"nuxt":%s*"([^"]*)"')
    table.insert(info, "Nuxt version: " .. version)

    if version:match("^4%.") then
      table.insert(info, "✓ Using Nuxt 4")
    elseif version:match("^3%.") then
      table.insert(info, "Using Nuxt 3 - consider upgrading to Nuxt 4")
    end
  end

  -- Check for TypeScript
  if content:match('"typescript"') or content:match('"@nuxt/typescript%-build"') then
    table.insert(info, "✓ TypeScript configured")
  else
    table.insert(issues, "TypeScript not found - consider adding for better DX")
  end

  -- Check for testing framework
  if content:match('"vitest"') or content:match('"@nuxt/test%-utils"') then
    table.insert(info, "✓ Testing framework configured")
  else
    table.insert(issues, "No testing framework found - consider adding Vitest")
  end

  return {
    status = #issues == 0 and "ok" or "info",
    info = info,
    issues = issues,
  }
end

-- Check for configuration issues
function M.check_configuration()
  local root = utils.find_nuxt_root()
  if not root then return { status = "error" } end

  local issues = {}
  local info = {}

  -- Check for nuxt.config file
  local config_files = {
    { path = root .. "/nuxt.config.ts", name = "nuxt.config.ts" },
    { path = root .. "/nuxt.config.js", name = "nuxt.config.js" },
    { path = root .. "/nuxt.config.mjs", name = "nuxt.config.mjs" },
  }

  local found_config = false
  for _, config in ipairs(config_files) do
    if utils.file_exists(config.path) then
      found_config = true
      if config.name:match("%.ts$") then
        table.insert(info, "✓ Using TypeScript config: " .. config.name)
      else
        table.insert(info, "Using " .. config.name .. " - consider migrating to .ts")
      end
      break
    end
  end

  if not found_config then
    table.insert(issues, "⚠ No nuxt.config file found")
  end

  -- Check for tsconfig.json
  local tsconfig = root .. "/tsconfig.json"
  if utils.file_exists(tsconfig) then
    table.insert(info, "✓ tsconfig.json found")
  else
    table.insert(issues, "tsconfig.json not found - may affect TypeScript support")
  end

  -- Check .nuxt directory
  local nuxt_dir = root .. "/.nuxt"
  if vim.fn.isdirectory(nuxt_dir) == 1 then
    table.insert(info, "✓ .nuxt directory exists (project has been built)")
  else
    table.insert(issues, "⚠ .nuxt directory not found - run 'npm run dev' first")
  end

  return {
    status = #issues == 0 and "ok" or "warning",
    info = info,
    issues = issues,
  }
end

-- Check file organization
function M.check_file_organization()
  local root = utils.find_nuxt_root()
  if not root then return { status = "error" } end

  local issues = {}
  local info = {}
  local stats = {
    pages = 0,
    components = 0,
    composables = 0,
    layouts = 0,
    middleware = 0,
    plugins = 0,
    api_routes = 0,
  }

  -- Count files in each directory
  local structure = utils.detect_structure()
  local base_dir = structure.has_app_dir and (root .. "/app") or root

  -- Count pages
  local pages_dirs = utils.get_directory_paths("pages")
  for _, dir in ipairs(pages_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.vue", false, true)
      stats.pages = stats.pages + #files
    end
  end

  -- Count components
  local comp_dirs = utils.get_directory_paths("components")
  for _, dir in ipairs(comp_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.vue", false, true)
      stats.components = stats.components + #files
    end
  end

  -- Count composables
  local composable_dirs = utils.get_directory_paths("composables")
  for _, dir in ipairs(composable_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.{ts,js}", false, true)
      stats.composables = stats.composables + #files
    end
  end

  -- Count API routes
  local api_dir = root .. "/server/api"
  if vim.fn.isdirectory(api_dir) == 1 then
    local files = vim.fn.glob(api_dir .. "/**/*.{ts,js}", false, true)
    stats.api_routes = #files
  end

  -- Generate report
  table.insert(info, string.format("Pages: %d", stats.pages))
  table.insert(info, string.format("Components: %d", stats.components))
  table.insert(info, string.format("Composables: %d", stats.composables))
  table.insert(info, string.format("API Routes: %d", stats.api_routes))

  if stats.pages == 0 then
    table.insert(issues, "⚠ No pages found")
  end

  if stats.components > 50 then
    table.insert(info, "Large component library - consider organizing in subdirectories")
  end

  return {
    status = "ok",
    info = info,
    issues = issues,
    stats = stats,
  }
end

-- Generate full health report
function M.generate_report()
  local root = utils.find_nuxt_root()
  if not root then
    vim.notify("Not in a Nuxt project", vim.log.levels.ERROR)
    return
  end

  local structure = M.check_structure()
  local dependencies = M.check_dependencies()
  local configuration = M.check_configuration()
  local organization = M.check_file_organization()

  -- Build report
  local lines = {
    "╔════════════════════════════════════════════════════════╗",
    "║         Nuxt Project Health Report                    ║",
    "╚════════════════════════════════════════════════════════╝",
    "",
    "📁 Project Structure:",
  }

  for _, msg in ipairs(structure.info or {}) do
    table.insert(lines, "  " .. msg)
  end
  for _, msg in ipairs(structure.issues or {}) do
    table.insert(lines, "  " .. msg)
  end

  table.insert(lines, "")
  table.insert(lines, "📦 Dependencies:")
  for _, msg in ipairs(dependencies.info or {}) do
    table.insert(lines, "  " .. msg)
  end
  for _, msg in ipairs(dependencies.issues or {}) do
    table.insert(lines, "  " .. msg)
  end

  table.insert(lines, "")
  table.insert(lines, "⚙️  Configuration:")
  for _, msg in ipairs(configuration.info or {}) do
    table.insert(lines, "  " .. msg)
  end
  for _, msg in ipairs(configuration.issues or {}) do
    table.insert(lines, "  " .. msg)
  end

  table.insert(lines, "")
  table.insert(lines, "📊 File Organization:")
  for _, msg in ipairs(organization.info or {}) do
    table.insert(lines, "  " .. msg)
  end
  for _, msg in ipairs(organization.issues or {}) do
    table.insert(lines, "  " .. msg)
  end

  -- Overall status
  table.insert(lines, "")
  table.insert(lines, "════════════════════════════════════════════════════════")

  local total_issues = #(structure.issues or {}) + #(dependencies.issues or {}) +
                       #(configuration.issues or {}) + #(organization.issues or {})

  if total_issues == 0 then
    table.insert(lines, "✅ Overall Status: Healthy - No issues found")
  else
    table.insert(lines, string.format("⚠️  Overall Status: %d issue(s) found", total_issues))
  end

  table.insert(lines, "════════════════════════════════════════════════════════")

  -- Display in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 60
  local height = math.min(#lines + 2, 40)
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

return M

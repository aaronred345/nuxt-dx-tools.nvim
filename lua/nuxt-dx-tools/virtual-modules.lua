-- Virtual module (#imports, #app, #build, #internal) resolver
local M = {}

local utils = require("nuxt-dx-tools.utils")
local path = require("nuxt-dx-tools.path")

-- Map of virtual modules to their descriptions and real file locations
M.virtual_modules = {
  ["#app"] = {
    description = "Core Nuxt composables and utilities",
    exports = {
      "defineNuxtComponent",
      "defineNuxtPlugin",
      "defineNuxtRouteMiddleware",
      "useAsyncData",
      "useFetch",
      "useNuxtApp",
      "useRuntimeConfig",
      "useState",
      "useCookie",
      "useRequestHeaders",
      "useRequestEvent",
      "useRequestURL",
      "useRoute",
      "useRouter",
      "navigateTo",
      "abortNavigation",
      "createError",
      "showError",
      "clearError",
    },
    file = ".nuxt/imports.d.ts",
  },
  ["#imports"] = {
    description = "Auto-imported composables, components, and utilities",
    exports = {}, -- Will be populated from imports.d.ts
    file = ".nuxt/imports.d.ts",
  },
  ["#build"] = {
    description = "Build-time configuration and metadata",
    exports = {},
    file = ".nuxt/nuxt.d.ts",
  },
  ["#components"] = {
    description = "Auto-imported components",
    exports = {}, -- Will be populated from components.d.ts
    file = ".nuxt/components.d.ts",
  },
  ["#internal/nitro"] = {
    description = "Nitro internal utilities",
    exports = {},
    file = ".nuxt/types/nitro.d.ts",
  },
}

-- Extract virtual module import from current line
function M.extract_virtual_import()
  local line = vim.api.nvim_get_current_line()

  -- Patterns for virtual module imports
  local patterns = {
    "from%s+['\"]([#@][^'\"]+)['\"]",
    "import%s+['\"]([#@][^'\"]+)['\"]",
    "import%((['\"][#@][^'\"]+['\"])",
  }

  for _, pattern in ipairs(patterns) do
    local module = line:match(pattern)
    if module then
      module = module:gsub("['\"]", "")
      return module
    end
  end

  -- Check if cursor is on a virtual module specifier
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before_cursor = line:sub(1, col)
  local after_cursor = line:sub(col + 1)

  -- Try to find module around cursor
  local module_before = before_cursor:match("['\"]([#@][^'\"]*)")
  local module_after = after_cursor:match("([^'\"]*)['\"]")

  if module_before and module_after then
    return module_before .. module_after
  elseif module_before then
    -- Check if we're at the end of the module
    for _, mod in pairs(M.virtual_modules) do
      if module_before:find("^" .. vim.pesc(mod), 1, false) then
        return module_before
      end
    end
  end

  return nil
end

-- Get file path for virtual module
function M.get_virtual_module_file(module)
  local root = utils.find_nuxt_root()
  if not root then return nil end

  local module_info = M.virtual_modules[module]
  if module_info and module_info.file then
    return path.join(root, module_info.file)
  end

  return nil
end

-- Show hover info for virtual module
function M.show_hover()
  local module = M.extract_virtual_import()
  if not module then return false end

  -- Find exact match or best match
  local module_info = M.virtual_modules[module]

  if not module_info then
    -- Try to find partial match
    for mod, info in pairs(M.virtual_modules) do
      if module:find("^" .. vim.pesc(mod)) then
        module_info = info
        module = mod
        break
      end
    end
  end

  if not module_info then
    return false
  end

  local hover_content = {
    "**Virtual Module:** `" .. module .. "`",
    "",
    module_info.description,
    "",
  }

  if #module_info.exports > 0 then
    table.insert(hover_content, "**Common Exports:**")
    for i, export in ipairs(module_info.exports) do
      if i <= 10 then -- Limit to first 10
        table.insert(hover_content, "  • " .. export)
      end
    end
    if #module_info.exports > 10 then
      table.insert(hover_content, "  • ... and " .. (#module_info.exports - 10) .. " more")
    end
    table.insert(hover_content, "")
  end

  local file = M.get_virtual_module_file(module)
  if file and utils.file_exists(file) then
    table.insert(hover_content, "**Generated File:** " .. module_info.file)
    table.insert(hover_content, "")
    table.insert(hover_content, "Press `gd` to view type definitions")
  end

  vim.lsp.util.open_floating_preview(hover_content, "markdown", {
    border = "rounded",
    focusable = false,
    max_width = 80,
  })

  return true
end

-- Go to virtual module definition
function M.goto_definition()
  local module = M.extract_virtual_import()
  if not module then return false end

  -- Find exact or partial match
  local matched_module = nil
  if M.virtual_modules[module] then
    matched_module = module
  else
    for mod, _ in pairs(M.virtual_modules) do
      if module:find("^" .. vim.pesc(mod)) then
        matched_module = mod
        break
      end
    end
  end

  if not matched_module then
    return false
  end

  local file = M.get_virtual_module_file(matched_module)
  if file and utils.file_exists(file) then
    vim.cmd("edit " .. file)
    return true
  else
    vim.notify("Virtual module definition file not found: " .. (file or "unknown"), vim.log.levels.WARN)
    return true
  end
end

-- Parse exports from .nuxt/imports.d.ts
function M.parse_auto_imports()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local imports_file = root .. "/.nuxt/imports.d.ts"
  local content = utils.read_file(imports_file)
  if not content then return {} end

  local exports = {}

  -- Extract export declarations
  for export in content:gmatch("export%s+%{[^}]*%}") do
    for name in export:gmatch("(%w+)") do
      if name ~= "export" then
        table.insert(exports, name)
      end
    end
  end

  -- Extract const/function exports
  for name in content:gmatch("export%s+const%s+(%w+)") do
    table.insert(exports, name)
  end

  for name in content:gmatch("export%s+function%s+(%w+)") do
    table.insert(exports, name)
  end

  return exports
end

-- Parse exports from .nuxt/components.d.ts
function M.parse_component_exports()
  local root = utils.find_nuxt_root()
  if not root then return {} end

  local components_file = root .. "/.nuxt/components.d.ts"
  local content = utils.read_file(components_file)
  if not content then return {} end

  local exports = {}

  -- Extract component names
  for name in content:gmatch("'([%w]+)'%s*:%s*typeof") do
    table.insert(exports, name)
  end

  for name in content:gmatch("([%w]+):%s*typeof") do
    if not name:match("^_") then
      table.insert(exports, name)
    end
  end

  return exports
end

-- Update virtual module exports from generated files
function M.update_exports()
  -- Update #imports exports
  local auto_imports = M.parse_auto_imports()
  if #auto_imports > 0 then
    M.virtual_modules["#imports"].exports = auto_imports
  end

  -- Update #components exports
  local components = M.parse_component_exports()
  if #components > 0 then
    M.virtual_modules["#components"].exports = components
  end
end

-- Show all virtual modules
function M.show_all_modules()
  -- Update exports first
  M.update_exports()

  local lines = { "=== Nuxt Virtual Modules ===", "" }

  for module, info in pairs(M.virtual_modules) do
    table.insert(lines, "**" .. module .. "**")
    table.insert(lines, "  " .. info.description)
    if #info.exports > 0 then
      table.insert(lines, "  Exports: " .. #info.exports .. " items")
    end
    table.insert(lines, "  File: " .. info.file)
    table.insert(lines, "")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  local width = 80
  local height = math.min(#lines, 30)
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

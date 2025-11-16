-- Main entry point for nuxt-dx-tools.nvim
local M = {}

-- Default configuration
M.config = {
  api_functions = { "$fetch", "useFetch", "$fetch.raw" },
  hover_enabled = true,
  goto_definition_enabled = true,
  diagnostics_enabled = true,
  nuxt_root = nil,
}

-- Load core modules
local cache = require("nuxt-dx-tools.cache")
local utils = require("nuxt-dx-tools.utils")
local components = require("nuxt-dx-tools.components")
local api_routes = require("nuxt-dx-tools.api-routes")
local page_meta = require("nuxt-dx-tools.page-meta")

-- Lazy-loaded feature modules
local migration_helpers, data_fetching, virtual_modules, picker
local find_usages, diagnostics, test_helpers, scaffold
local snippets, health_report

-- Main go-to-definition handler
function M.goto_definition()
  local word = vim.fn.expand("<cword>")
  local line = vim.api.nvim_get_current_line()

  -- 1. Check for virtual module imports
  if not virtual_modules then
    virtual_modules = require("nuxt-dx-tools.virtual-modules")
  end
  local virtual_result = virtual_modules.goto_definition()
  if virtual_result then return end

  -- 2. Check for definePageMeta context
  local meta_result = page_meta.goto_definition(word, line)
  if meta_result then return end

  -- 3. Check for API routes
  local api_result = api_routes.goto_definition()
  if api_result then return end

  -- 4. Check for components
  local comp_result = components.goto_definition(word)
  if comp_result then return end

  -- 5. Check for custom plugin definitions (e.g., $dialog)
  if word:match("^%$") then
    local plugin_name = word:gsub("^%$", "")
    local def_file = utils.find_custom_plugin_definition(plugin_name)
    if def_file then
      vim.cmd("edit " .. def_file)
      vim.defer_fn(function()
        vim.fn.search("%$" .. plugin_name)
      end, 100)
      return
    end
  end

  -- 6. Fall back to LSP definition
  vim.lsp.buf.definition()
end

-- Enhanced hover handler
function M.show_hover()
  if not M.config.hover_enabled then
    vim.lsp.buf.hover()
    return
  end

  -- Try virtual modules first
  if not virtual_modules then
    virtual_modules = require("nuxt-dx-tools.virtual-modules")
  end
  if virtual_modules.show_hover() then return end

  -- Try data fetching info
  if not data_fetching then
    data_fetching = require("nuxt-dx-tools.data-fetching")
  end
  if data_fetching.show_hover() then return end

  -- Try API routes
  local result = api_routes.show_hover()
  if not result then
    vim.lsp.buf.hover()
  end
end

-- Refresh cache command
function M.refresh_cache()
  cache.clear()
  cache.load_all()
  vim.notify("Nuxt DX cache refreshed", vim.log.levels.INFO)
end

-- Show component info
function M.show_component_info()
  local word = vim.fn.expand("<cword>")
  components.show_info(word)
end

-- === New Feature Functions ===

-- Migration helpers
function M.show_migration_hints()
  if not migration_helpers then migration_helpers = require("nuxt-dx-tools.migration-helpers") end
  migration_helpers.show_migration_hints()
end

function M.apply_migration_fixes()
  if not migration_helpers then migration_helpers = require("nuxt-dx-tools.migration-helpers") end
  migration_helpers.apply_migration_fixes()
end

-- API testing
function M.test_endpoint()
  api_routes.test_endpoint_in_terminal()
end

-- Data fetching
function M.find_data_fetch_usages()
  if not data_fetching then data_fetching = require("nuxt-dx-tools.data-fetching") end
  data_fetching.find_usages()
end

function M.suggest_data_fetch_conversion()
  if not data_fetching then data_fetching = require("nuxt-dx-tools.data-fetching") end
  data_fetching.suggest_conversion()
end

function M.check_data_fetch_issues()
  if not data_fetching then data_fetching = require("nuxt-dx-tools.data-fetching") end
  data_fetching.check_issues()
end

-- Virtual modules
function M.show_virtual_modules()
  if not virtual_modules then virtual_modules = require("nuxt-dx-tools.virtual-modules") end
  virtual_modules.show_all_modules()
end

-- Picker/Navigation
function M.show_page_picker()
  if not picker then picker = require("nuxt-dx-tools.picker") end
  picker.show_page_picker()
end

function M.show_component_picker()
  if not picker then picker = require("nuxt-dx-tools.picker") end
  picker.show_component_picker()
end

function M.show_combined_picker()
  if not picker then picker = require("nuxt-dx-tools.picker") end
  picker.show_combined_picker()
end

-- Find usages
function M.find_usages()
  if not find_usages then find_usages = require("nuxt-dx-tools.find-usages") end
  find_usages.find_current_symbol_usages()
end

function M.show_usage_stats()
  if not find_usages then find_usages = require("nuxt-dx-tools.find-usages") end
  find_usages.show_usage_stats()
end

-- Test helpers
function M.toggle_test_file()
  if not test_helpers then test_helpers = require("nuxt-dx-tools.test-helpers") end
  test_helpers.toggle_test_file()
end

function M.create_test_file()
  if not test_helpers then test_helpers = require("nuxt-dx-tools.test-helpers") end
  test_helpers.create_test_file()
end

function M.run_test()
  if not test_helpers then test_helpers = require("nuxt-dx-tools.test-helpers") end
  test_helpers.run_current_test()
end

-- Scaffolding
function M.new_file()
  if not scaffold then scaffold = require("nuxt-dx-tools.scaffold") end
  scaffold.new()
end

-- Snippets
function M.show_snippets()
  if not snippets then snippets = require("nuxt-dx-tools.snippets") end
  snippets.show_picker()
end

-- Health report
function M.show_health_report()
  if not health_report then health_report = require("nuxt-dx-tools.health-report") end
  health_report.generate_report()
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Pass config to modules
  utils.set_config(M.config)
  api_routes.set_config(M.config)

  -- Setup LSP integration (enhances standard LSP commands)
  local lsp_integration = require("nuxt-dx-tools.lsp-integration")
  lsp_integration.setup()

  -- Setup diagnostics if enabled
  if M.config.diagnostics_enabled then
    if not diagnostics then diagnostics = require("nuxt-dx-tools.diagnostics") end
    diagnostics.setup()

    if not migration_helpers then migration_helpers = require("nuxt-dx-tools.migration-helpers") end
    migration_helpers.setup_diagnostics()
  end

  -- Setup autocommands
  require("nuxt-dx-tools.autocmds").setup(M)

  -- Setup keymaps
  require("nuxt-dx-tools.keymaps").setup(M)

  -- Setup commands
  require("nuxt-dx-tools.commands").setup(M)

  -- Initial cache load
  vim.defer_fn(function()
    if utils.find_nuxt_root() then
      cache.load_all()
    end
  end, 1000)
end

return M

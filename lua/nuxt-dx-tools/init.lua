-- Main entry point for nuxt-dx-tools.nvim
local M = {}

-- Default configuration
M.config = {
  api_functions = { "$fetch", "useFetch", "$fetch.raw" },
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
local snippets, health_report, route_resolver

-- Debug flag
local DEBUG = false

local function log(msg)
  if DEBUG then
    vim.notify("[Nuxt Init] " .. msg, vim.log.levels.INFO)
  end
end

-- NOTE: LSP features (goto definition, hover, completions) are now handled
-- exclusively by the Nuxt DX LSP server. This plugin only provides custom
-- commands and UI features.

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

  -- Setup diagnostics if enabled
  if M.config.diagnostics_enabled then
    if not diagnostics then diagnostics = require("nuxt-dx-tools.diagnostics") end
    diagnostics.setup()

    if not migration_helpers then migration_helpers = require("nuxt-dx-tools.migration-helpers") end
    migration_helpers.setup_diagnostics()
  end

  -- Setup autocommands
  require("nuxt-dx-tools.autocmds").setup(M)

  -- Setup keymaps for custom commands
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

-- Enable debug mode
function M.enable_debug()
  DEBUG = true
  vim.notify("Nuxt Init debug mode enabled", vim.log.levels.INFO)
end

-- Toggle debug mode
function M.toggle_debug()
  DEBUG = not DEBUG
  if DEBUG then
    vim.notify("Nuxt Init debug mode enabled", vim.log.levels.INFO)
  else
    vim.notify("Nuxt Init debug mode disabled", vim.log.levels.INFO)
  end
end

return M

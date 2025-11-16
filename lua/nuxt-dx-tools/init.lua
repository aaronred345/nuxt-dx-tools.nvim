-- Main entry point for nuxt-dx-tools.nvim
local M = {}

-- Default configuration
M.config = {
  api_functions = { "$fetch", "useFetch", "$fetch.raw" },
  hover_enabled = true,
  goto_definition_enabled = true,
  nuxt_root = nil,
}

-- Load modules
local cache = require("nuxt-dx-tools.cache")
local utils = require("nuxt-dx-tools.utils")
local components = require("nuxt-dx-tools.components")
local api_routes = require("nuxt-dx-tools.api-routes")
local page_meta = require("nuxt-dx-tools.page-meta")

-- Main go-to-definition handler
function M.goto_definition()
  local word = vim.fn.expand("<cword>")
  local line = vim.api.nvim_get_current_line()

  -- 1. Check for definePageMeta context
  local meta_result = page_meta.goto_definition(word, line)
  if meta_result then return end

  -- 2. Check for API routes
  local api_result = api_routes.goto_definition()
  if api_result then return end

  -- 3. Check for components
  local comp_result = components.goto_definition(word)
  if comp_result then return end

  -- 4. Check for custom plugin definitions (e.g., $dialog)
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

  -- 5. Fall back to LSP definition
  vim.lsp.buf.definition()
end

-- Hover handler for API routes
function M.show_hover()
  if not M.config.hover_enabled then
    vim.lsp.buf.hover()
    return
  end

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

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Pass config to modules
  utils.set_config(M.config)
  api_routes.set_config(M.config)

  -- Setup autocommands
  require("nuxt-dx-tools.autocmds").setup(M)

  -- Setup keymaps
  require("nuxt-dx-tools.keymaps").setup(M)

  -- Initial cache load
  vim.defer_fn(function()
    if utils.find_nuxt_root() then
      cache.load_all()
    end
  end, 1000)
end

return M

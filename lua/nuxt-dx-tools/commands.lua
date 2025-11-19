-- Command setup for nuxt-dx-tools
local M = {}

function M.setup(plugin)
  -- === Navigation & Discovery Commands ===
  vim.api.nvim_create_user_command("NuxtJumpToPage", function()
    plugin.show_page_picker()
  end, { desc = "Nuxt: Jump to page with fuzzy finder" })

  vim.api.nvim_create_user_command("NuxtJumpToComponent", function()
    plugin.show_component_picker()
  end, { desc = "Nuxt: Jump to component with fuzzy finder" })

  vim.api.nvim_create_user_command("NuxtJump", function()
    plugin.show_combined_picker()
  end, { desc = "Nuxt: Jump to page or component" })

  -- === Migration Commands ===
  vim.api.nvim_create_user_command("NuxtMigrationHints", function()
    plugin.show_migration_hints()
  end, { desc = "Nuxt: Show migration hints for Nuxt 4" })

  vim.api.nvim_create_user_command("NuxtMigrationFix", function()
    plugin.apply_migration_fixes()
  end, { desc = "Nuxt: Apply migration fixes for Nuxt 4" })

  -- === Data Fetching Commands ===
  vim.api.nvim_create_user_command("NuxtFindDataUsages", function()
    plugin.find_data_fetch_usages()
  end, { desc = "Nuxt: Find usages of data fetch key" })

  vim.api.nvim_create_user_command("NuxtConvertFetch", function()
    plugin.suggest_data_fetch_conversion()
  end, { desc = "Nuxt: Convert between useFetch and useAsyncData" })

  vim.api.nvim_create_user_command("NuxtCheckDataFetch", function()
    plugin.check_data_fetch_issues()
  end, { desc = "Nuxt: Check data fetching issues" })

  -- === API & Testing Commands ===
  vim.api.nvim_create_user_command("NuxtTestEndpoint", function()
    plugin.test_endpoint()
  end, { desc = "Nuxt: Test API endpoint under cursor" })

  vim.api.nvim_create_user_command("NuxtToggleTest", function()
    plugin.toggle_test_file()
  end, { desc = "Nuxt: Toggle between source and test file" })

  vim.api.nvim_create_user_command("NuxtCreateTest", function()
    plugin.create_test_file()
  end, { desc = "Nuxt: Create test file for current file" })

  vim.api.nvim_create_user_command("NuxtRunTest", function()
    plugin.run_test()
  end, { desc = "Nuxt: Run test for current file" })

  -- === Scaffolding Commands ===
  vim.api.nvim_create_user_command("NuxtNew", function()
    plugin.new_file()
  end, { desc = "Nuxt: Scaffold new file (page, component, etc.)" })

  vim.api.nvim_create_user_command("NuxtSnippets", function()
    plugin.show_snippets()
  end, { desc = "Nuxt: Show and insert Nuxt 4 snippets" })

  -- === Find Usages Commands ===
  vim.api.nvim_create_user_command("NuxtFindUsages", function()
    plugin.find_usages()
  end, { desc = "Nuxt: Find usages of auto-imported symbol" })

  vim.api.nvim_create_user_command("NuxtUsageStats", function()
    plugin.show_usage_stats()
  end, { desc = "Nuxt: Show usage statistics for auto-imports" })

  -- === Virtual Modules Commands ===
  vim.api.nvim_create_user_command("NuxtVirtualModules", function()
    plugin.show_virtual_modules()
  end, { desc = "Nuxt: Show all virtual modules (#imports, #app, etc.)" })

  -- === Info & Diagnostic Commands ===
  vim.api.nvim_create_user_command("NuxtHealth", function()
    plugin.show_health_report()
  end, { desc = "Nuxt: Show project health report" })

  vim.api.nvim_create_user_command("NuxtComponentInfo", function()
    plugin.show_component_info()
  end, { desc = "Nuxt: Show component info for word under cursor" })

  -- === Cache Commands ===
  vim.api.nvim_create_user_command("NuxtRefresh", function()
    plugin.refresh_cache()
  end, { desc = "Nuxt: Refresh component/composable cache" })

  -- Alias for existing command
  vim.api.nvim_create_user_command("NuxtDXRefresh", function()
    plugin.refresh_cache()
  end, { desc = "Nuxt: Refresh component/composable cache (alias)" })

  vim.api.nvim_create_user_command("NuxtDXComponentInfo", function()
    plugin.show_component_info()
  end, { desc = "Nuxt: Show component info (alias)" })

  -- === Debug Commands ===
  vim.api.nvim_create_user_command("NuxtDebug", function()
    -- Toggle Lua module debug modes
    require("nuxt-dx-tools").toggle_debug()
    require("nuxt-dx-tools.type-parser").toggle_debug()
    require("nuxt-dx-tools.components").toggle_debug()

    -- Toggle LSP server debug mode
    local clients = vim.lsp.get_clients({ name = 'nuxt-dx-tools-lsp' })
    if #clients > 0 then
      local client = clients[1]
      -- Execute the LSP command to toggle debug mode
      client.request('workspace/executeCommand', {
        command = 'nuxt-dx-tools.toggleDebug',
        arguments = {},
      }, function(err, result)
        if err then
          vim.notify("Failed to toggle LSP debug mode: " .. vim.inspect(err), vim.log.levels.ERROR)
        end
      end)
    else
      vim.notify("Nuxt DX Tools LSP not attached - only toggling Lua debug mode", vim.log.levels.WARN)
    end
  end, { desc = "Nuxt: Toggle debug logging (Lua modules + LSP server)" })

  vim.api.nvim_create_user_command("NuxtDXLspInfo", function()
    local buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = buf, name = 'nuxt-dx-tools-lsp' })

    if #clients == 0 then
      vim.notify('[Nuxt DX Tools] LSP server NOT attached to this buffer', vim.log.levels.WARN)
    else
      local client = clients[1]
      local cap = client.server_capabilities
      vim.notify(string.format(
        '[Nuxt DX Tools] LSP attached!\n' ..
        'Definition: %s\n' ..
        'Hover: %s\n' ..
        'Completion: %s\n' ..
        'Root: %s',
        cap.definitionProvider and 'enabled' or 'disabled',
        cap.hoverProvider and 'enabled' or 'disabled',
        cap.completionProvider and 'enabled' or 'disabled',
        client.config.root_dir or 'unknown'
      ), vim.log.levels.INFO)
    end
  end, { desc = 'Show Nuxt DX LSP info' })
end

return M

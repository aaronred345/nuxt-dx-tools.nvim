-- Keymap setup
local M = {}

function M.setup(plugin)
  local api = vim.api
  local group = api.nvim_create_augroup("NuxtDXToolsKeymaps", { clear = true })

  api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "vue", "typescript", "javascript" },
    callback = function(ev)
      local bufnr = ev.buf

      -- === Custom Commands ===
      -- Note: LSP features (gd, K, hover, completions) are now handled exclusively
      -- by the Nuxt DX LSP server. This plugin only provides custom commands.

      -- === Component & Info ===
      vim.keymap.set("n", "<leader>ni", plugin.show_component_info, {
        buffer = bufnr,
        desc = "Nuxt DX: Component info",
      })

      vim.keymap.set("n", "<leader>nr", plugin.refresh_cache, {
        buffer = bufnr,
        desc = "Nuxt DX: Refresh cache",
      })

      -- === Fuzzy Navigation ===
      vim.keymap.set("n", "<leader>np", plugin.show_page_picker, {
        buffer = bufnr,
        desc = "Nuxt DX: Jump to page",
      })

      vim.keymap.set("n", "<leader>nc", plugin.show_component_picker, {
        buffer = bufnr,
        desc = "Nuxt DX: Jump to component",
      })

      vim.keymap.set("n", "<leader>nj", plugin.show_combined_picker, {
        buffer = bufnr,
        desc = "Nuxt DX: Jump to page/component",
      })

      -- === Find Usages ===
      vim.keymap.set("n", "<leader>nf", plugin.find_usages, {
        buffer = bufnr,
        desc = "Nuxt DX: Find usages",
      })

      vim.keymap.set("n", "<leader>nu", plugin.show_usage_stats, {
        buffer = bufnr,
        desc = "Nuxt DX: Usage statistics",
      })

      -- === API Testing ===
      vim.keymap.set("n", "<leader>nt", plugin.test_endpoint, {
        buffer = bufnr,
        desc = "Nuxt DX: Test API endpoint",
      })

      -- === Test Files ===
      vim.keymap.set("n", "<leader>ntt", plugin.toggle_test_file, {
        buffer = bufnr,
        desc = "Nuxt DX: Toggle test file",
      })

      vim.keymap.set("n", "<leader>ntr", plugin.run_test, {
        buffer = bufnr,
        desc = "Nuxt DX: Run test",
      })

      vim.keymap.set("n", "<leader>ntc", plugin.create_test_file, {
        buffer = bufnr,
        desc = "Nuxt DX: Create test file",
      })

      -- === Data Fetching ===
      vim.keymap.set("n", "<leader>ndf", plugin.find_data_fetch_usages, {
        buffer = bufnr,
        desc = "Nuxt DX: Find data fetch usages",
      })

      vim.keymap.set("n", "<leader>ndc", plugin.suggest_data_fetch_conversion, {
        buffer = bufnr,
        desc = "Nuxt DX: Convert data fetch",
      })

      vim.keymap.set("n", "<leader>ndi", plugin.check_data_fetch_issues, {
        buffer = bufnr,
        desc = "Nuxt DX: Check data fetch issues",
      })

      -- === Scaffolding ===
      vim.keymap.set("n", "<leader>nn", plugin.new_file, {
        buffer = bufnr,
        desc = "Nuxt DX: New file (scaffold)",
      })

      vim.keymap.set("n", "<leader>ns", plugin.show_snippets, {
        buffer = bufnr,
        desc = "Nuxt DX: Show snippets",
      })

      -- === Migration ===
      vim.keymap.set("n", "<leader>nm", plugin.show_migration_hints, {
        buffer = bufnr,
        desc = "Nuxt DX: Migration hints",
      })

      vim.keymap.set("n", "<leader>nM", plugin.apply_migration_fixes, {
        buffer = bufnr,
        desc = "Nuxt DX: Apply migration fixes",
      })

      -- === Virtual Modules ===
      vim.keymap.set("n", "<leader>nv", plugin.show_virtual_modules, {
        buffer = bufnr,
        desc = "Nuxt DX: Virtual modules",
      })

      -- === Health & Diagnostics ===
      vim.keymap.set("n", "<leader>nh", plugin.show_health_report, {
        buffer = bufnr,
        desc = "Nuxt DX: Health report",
      })
    end,
  })
end

return M

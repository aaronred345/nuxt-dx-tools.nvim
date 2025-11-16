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
      
      vim.keymap.set("n", "gd", plugin.goto_definition, {
        buffer = bufnr,
        desc = "Nuxt DX: Go to definition",
      })

      vim.keymap.set("n", "K", plugin.show_hover, {
        buffer = bufnr,
        desc = "Nuxt DX: Show hover",
      })

      vim.keymap.set("n", "<leader>ni", plugin.show_component_info, {
        buffer = bufnr,
        desc = "Nuxt DX: Component info",
      })

      vim.keymap.set("n", "<leader>nr", plugin.refresh_cache, {
        buffer = bufnr,
        desc = "Nuxt DX: Refresh cache",
      })
    end,
  })
end

return M

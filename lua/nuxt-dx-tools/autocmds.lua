-- Autocommand setup
local M = {}

function M.setup(plugin)
  local api = vim.api
  local group = api.nvim_create_augroup("NuxtDXTools", { clear = true })

  api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    pattern = { "*.vue", "*.ts", "*.js" },
    callback = function()
      require("nuxt-dx-tools.utils").find_nuxt_root(false)
    end,
  })

  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.d.ts",
    callback = function(ev)
      if ev.file:match("%.nuxt") then
        plugin.refresh_cache()
      end
    end,
  })

  api.nvim_create_user_command("NuxtDXRefresh", plugin.refresh_cache, {
    desc = "Refresh Nuxt DX Tools cache"
  })
  
  api.nvim_create_user_command("NuxtDXComponentInfo", plugin.show_component_info, {
    desc = "Show component info under cursor"
  })
end

return M

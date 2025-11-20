-- Minimal init for running tests

-- Add current directory to package path
local function add_pack(name)
  local path = vim.fn.stdpath("data") .. "/site/pack/deps/start/" .. name
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.system({"git", "clone", "--depth=1", "https://github.com/" .. name, path})
  end
  vim.opt.runtimepath:append(path)
end

-- Install plenary if not already installed
add_pack("nvim-lua/plenary.nvim")

-- Add the plugin itself to the runtime path
vim.opt.runtimepath:append(".")

-- Set up minimal vim options for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.hidden = true

-- Don't actually start LSP server during tests
vim.g.nuxt_dx_tools_no_lsp = true

print("Minimal init loaded for testing")

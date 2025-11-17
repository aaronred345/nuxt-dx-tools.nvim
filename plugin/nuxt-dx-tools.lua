-- Plugin initialization
if vim.g.loaded_nuxt_dx_tools then
  return
end
vim.g.loaded_nuxt_dx_tools = 1

-- Auto-start LSP server for Nuxt projects
local function start_lsp_server()
  -- Check if we're in a Nuxt project
  local nuxt_root = vim.fn.finddir('.nuxt', '.;')
  if nuxt_root == '' then
    return
  end

  -- Find the plugin installation directory
  local plugin_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h')
  local lsp_server_path = plugin_path .. '/lsp-server/dist/server.js'

  -- Check if the LSP server is built
  if vim.fn.filereadable(lsp_server_path) == 0 then
    vim.notify('[Nuxt DX Tools] LSP server not found. Run: cd ' .. plugin_path .. '/lsp-server && npm install && npm run build', vim.log.levels.WARN)
    return
  end

  -- Check if LSP server is already running for this buffer
  local clients = vim.lsp.get_clients({ name = 'nuxt-dx-tools-lsp' })
  if #clients > 0 then
    return
  end

  -- Start the LSP server
  vim.lsp.start({
    name = 'nuxt-dx-tools-lsp',
    cmd = { 'node', lsp_server_path, '--stdio' },
    root_dir = vim.fs.dirname(vim.fs.find({ '.nuxt', 'nuxt.config.ts', 'nuxt.config.js' }, { upward = true })[1]),
    filetypes = { 'vue', 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
    init_options = {
      enableHover = true,
      enableDefinition = true,
      enableCompletion = true,
    },
  })
end

-- Auto-start LSP for Vue, TS, and JS files in Nuxt projects
vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = { 'vue', 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
  callback = function()
    vim.schedule(start_lsp_server)
  end,
})

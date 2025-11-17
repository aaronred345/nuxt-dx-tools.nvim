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

  -- Get the root directory
  local root_files = vim.fs.find({ '.nuxt', 'nuxt.config.ts', 'nuxt.config.js' }, { upward = true })
  if #root_files == 0 then
    return
  end
  local root_dir = vim.fs.dirname(root_files[1])

  -- Check if LSP server is already attached to THIS buffer
  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf, name = 'nuxt-dx-tools-lsp' })
  if #clients > 0 then
    -- Already attached to this buffer
    return
  end

  -- Create a log file for our LSP server
  local log_file = plugin_path .. '/lsp-server/nuxt-lsp-server.log'
  local log_handle = io.open(log_file, 'a')
  if log_handle then
    log_handle:write(string.format('[%s] Starting LSP server attach attempt\n', os.date('%Y-%m-%d %H:%M:%S')))
    log_handle:close()
  end

  -- Create error log file
  local error_log_file = plugin_path .. '/lsp-server/server-error.log'

  -- Start or attach the LSP server to this buffer
  local client_id = vim.lsp.start({
    name = 'nuxt-dx-tools-lsp',
    cmd = { 'node', lsp_server_path, '--stdio' },
    root_dir = root_dir,
    filetypes = { 'vue', 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
    init_options = {
      enableHover = true,
      enableDefinition = true,
      enableCompletion = true,
    },
    on_attach = function(client, bufnr)
      local msg = string.format('[Nuxt DX Tools] LSP attached! client_id=%s bufnr=%s\nLogs: %s', client.id, bufnr, log_file)
      vim.notify(msg, vim.log.levels.INFO)
    end,
    on_exit = function(code, signal, client_id)
      local err_log = io.open(error_log_file, 'a')
      if err_log then
        err_log:write(string.format('[%s] Server exited! code=%s signal=%s client_id=%s\n',
          os.date('%Y-%m-%d %H:%M:%S'), code or 'nil', signal or 'nil', client_id or 'nil'))
        err_log:close()
      end
      if code ~= 0 then
        vim.notify(string.format('[Nuxt DX Tools] LSP server crashed! Exit code: %s. Check: %s', code, error_log_file), vim.log.levels.ERROR)
      end
    end,
    handlers = {
      ['textDocument/hover'] = function(err, result, ctx, config)
        local log_h = io.open(log_file, 'a')
        if log_h then
          log_h:write(string.format('[%s] HOVER request received! err=%s result=%s\n',
            os.date('%H:%M:%S'), err or 'nil', result and 'yes' or 'nil'))
          log_h:close()
        end
        return vim.lsp.handlers['textDocument/hover'](err, result, ctx, config)
      end,
    },
  })

  if client_id then
    vim.notify('[Nuxt DX Tools] LSP started with client_id: ' .. client_id, vim.log.levels.DEBUG)
  end
end

-- Auto-start LSP for Vue, TS, and JS files in Nuxt projects
vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = { 'vue', 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' },
  callback = function()
    vim.schedule(start_lsp_server)
  end,
})

-- Also try to attach when opening files (in case FileType doesn't fire)
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
  pattern = { '*.vue', '*.ts', '*.js', '*.tsx', '*.jsx' },
  callback = function()
    vim.schedule(start_lsp_server)
  end,
})

-- Debug command to check LSP status
vim.api.nvim_create_user_command('NuxtDXLspInfo', function()
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

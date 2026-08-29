-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- 当光标停止移动或重新获得终端焦点时，检查文件是否在外部被修改
vim.api.nvim_create_autocmd({ "FocusGained", "CursorHold", "CursorHoldI" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = "*",
})

-- 阻止 LSP 附加到 diffview/fugitive 等非真实文件缓冲区，
-- 否则 gopls 会因 DocumentURI scheme 不是 file 而报 -32700。
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lazyvim_lsp_detach_virtual_buffers", { clear = true }),
  callback = function(args)
    local bufname = vim.api.nvim_buf_get_name(args.buf)
    if bufname:find("^diffview://") or bufname:find("^fugitive://") then
      vim.schedule(function()
        pcall(vim.lsp.buf_detach_client, args.buf, args.data.client_id)
      end)
    end
  end,
})

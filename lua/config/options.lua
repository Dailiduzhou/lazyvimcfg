-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- 与系统剪贴板同步（Windows 下 Neovim 内置 Win32 provider，无需额外工具）
vim.opt.clipboard = "unnamedplus"

-- wl-clipboard 只在 Linux/Wayland 上存在。
-- 在 Windows 上设置它会导致 y 复制报 E475 ('wl-copy' is not executable)，
-- p 粘贴报 "clipboard: provider returned invalid data"。
if vim.fn.has("linux") == 1 then
  vim.g.clipboard = {
    name = "wl-clipboard",
    copy = {
      ["+"] = "wl-copy",
      ["*"] = "wl-copy",
    },
    paste = {
      ["+"] = "wl-paste --no-newline",
      ["*"] = "wl-paste --no-newline",
    },
    cache_enabled = 0,
  }
end
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.omni_sql_no_default_maps = 1

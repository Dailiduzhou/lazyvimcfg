local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- clangd 参数兜底。
-- 原因：LazyVim 的 `lang.clangd` extra 比 `plugins/` 晚解析，而 lazy.nvim 合并 opts 时
-- 对**列表是整份覆盖**（不是逐项合并），extra 里的 `servers.clangd.cmd` 会把
-- plugins/lsp.lua 里写的那份整份顶掉。所以所有 spec 解析完（setup 返回时）、
-- 插件还没加载前，在合并结果上再盖一次。
-- 注意：这段依赖 lazy 内部结构，升级 lazy.nvim 后如果报错就直接删掉（只是让
-- clangd 回退到 extra 的默认参数，不影响使用）。
local function patch_clangd_cmd()
  local ok, spec = pcall(require, "plugins.lsp")
  if not ok or type(spec) ~= "table" then
    return
  end

  local plugin = require("lazy.core.config").plugins["nvim-lspconfig"]
  local cmd = spec.opts and spec.opts.servers and spec.opts.servers.clangd and spec.opts.servers.clangd.cmd
  if not (plugin and cmd) then
    return
  end

  local opts = require("lazy.core.plugin").values(plugin, "opts")
  opts.servers = opts.servers or {}
  opts.servers.clangd = opts.servers.clangd or {}
  opts.servers.clangd.cmd = cmd
end

patch_clangd_cmd()
